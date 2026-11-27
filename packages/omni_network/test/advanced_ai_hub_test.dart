import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

void main() {
  group('AiGuardrail (mask, restore, block)', () {
    test(
      'masks emails, phones, cards & secrets before provider and restores optionally',
      () async {
        String? seenByProvider;
        final api = OmniNetwork(
          ai: AiConfig(
            defaultModel: 'mock:m1',
            guardrail: const AiGuardrail.piiMask(restoreInResponse: true),
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (_, msgs, _) {
                  seenByProvider = msgs.last.text;
                  return MockAiReply(text: 'Echo: ${msgs.last.text}');
                },
              ),
            },
          ),
        );
        addTearDown(api.close);

        final out = await api.ai.ask(
          'Contact ana@example.com or +8801712345678 using sk-1234567890abcdef123456',
        );
        expect(seenByProvider, isNot(contains('ana@example.com')));
        expect(seenByProvider, isNot(contains('+8801712345678')));
        expect(seenByProvider, isNot(contains('sk-1234567890abcdef123456')));
        expect(seenByProvider, contains('[EMAIL#'));
        expect(out, contains('ana@example.com'));
      },
    );

    test('blocks prompt when AiGuardrailAction.block matches', () async {
      final api = OmniNetwork(
        ai: AiConfig(
          defaultModel: 'mock:m1',
          guardrail: const AiGuardrail(action: AiGuardrailAction.block),
          providers: {'mock': MockAiProvider(id: 'mock')},
        ),
      );
      addTearDown(api.close);

      await expectLater(
        () => api.ai.ask('Send report to ceo@corp.com'),
        throwsA(isA<RequestFailure>()),
      );
    });
  });

  group('AiSemanticCache', () {
    test(
      'serves semantic hits without calling provider again and expires by TTL',
      () async {
        var now = DateTime.utc(2026, 1, 1, 12);
        var calls = 0;
        final cache = AiSemanticCache(
          embedder: (q) async =>
              q.toLowerCase().contains('flutter') ? [1.0, 0.0] : [0.0, 1.0],
          similarityThreshold: 0.90,
          ttl: const Duration(minutes: 10),
          now: () => now,
        );

        final api = OmniNetwork(
          ai: AiConfig(
            defaultModel: 'mock:fast',
            semanticCache: cache,
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (_, msgs, _) {
                  calls++;
                  return MockAiReply(text: 'Answer #$calls: ${msgs.last.text}');
                },
              ),
            },
          ),
        );
        addTearDown(api.close);

        final r1 = await api.ai.ask('What is Flutter?');
        expect(calls, 1);
        expect(r1, contains('Answer #1'));

        // Paraphrased query maps to near-identical vector -> semantic hit (calls stays 1).
        final r2 = await api.ai.ask('Explain Flutter framework please');
        expect(calls, 1);
        expect(r2, r1);

        // Advance time past TTL -> misses cache & calls provider again.
        now = now.add(const Duration(minutes: 15));
        final r3 = await api.ai.ask('What is Flutter?');
        expect(calls, 2);
        expect(r3, contains('Answer #2'));
      },
    );
  });

  group('Streaming tools, streamObject & JSON auto-repair', () {
    test('api.ai.stream executes multi-round AiTools automatically', () async {
      var round = 0;
      final api = OmniNetwork(
        ai: AiConfig(
          defaultModel: 'mock:m1',
          providers: {
            'mock': MockAiProvider(
              id: 'mock',
              streamChunkSize: 3,
              handler: (_, msgs, _) {
                round++;
                if (round == 1) {
                  return const MockAiReply(
                    text: '',
                    toolCalls: [
                      AiToolCallPart(
                        id: 'c1',
                        name: 'multiply',
                        arguments: {'x': 6, 'y': 7},
                      ),
                    ],
                  );
                }
                final result = msgs.last.parts
                    .whereType<AiToolResultPart>()
                    .single
                    .result;
                return MockAiReply(text: 'Product=$result');
              },
            ),
          },
        ),
      );
      addTearDown(api.close);

      final events = await api.ai
          .stream(
            '6 times 7?',
            options: AiRequestOptions(
              tools: [
                AiTool.function(
                  name: 'multiply',
                  description: 'Multiply two numbers',
                  execute: (args) => (args['x']! as num) * (args['y']! as num),
                ),
              ],
            ),
          )
          .toList();

      final done = events.whereType<AiCompleted>().single;
      expect(done.response.text, 'Product=42');
      expect(round, 2);
    });

    test(
      'streamObject yields partial JSON snapshots and generateObject auto-repairs bad JSON',
      () async {
        final provider = MockAiProvider(id: 'mock');
        provider
          ..enqueue(
            () => const MockAiReply(text: '{"title":"Hel'),
          ) // malformed for generateObject
          ..enqueue(
            () => const MockAiReply(text: '{"title":"Fixed","score":99}'),
          );

        final api = OmniNetwork(
          ai: AiConfig(defaultModel: 'mock:m1', providers: {'mock': provider}),
        );
        addTearDown(api.close);

        // generateObject repairs broken JSON automatically on turn 2.
        final repaired = await api.ai.generateObject<Map<String, dynamic>>(
          'Return title and score',
          decoder: (j) => j,
        );
        expect(repaired['title'], 'Fixed');
        expect(repaired['score'], 99);

        // streamObject yields progressive partialJson snapshots until complete.
        provider.enqueue(
          () => const MockAiReply(text: '{"name":"Omni","stars":5}'),
        );
        final snapshots = await api.ai
            .streamObject<({String name, int? stars})>(
              'Info',
              decoder: (j) =>
                  (name: j['name'] as String? ?? '', stars: j['stars'] as int?),
            )
            .toList();

        expect(snapshots.length, greaterThanOrEqualTo(2));
        expect(snapshots.any((s) => !s.isComplete), isTrue);
        expect(snapshots.last.isComplete, isTrue);
        expect(snapshots.last.value, (name: 'Omni', stars: 5));
      },
    );
  });

  group('Smart routing: lowestCost, 429 cooldown & hedged requests', () {
    test(
      'routes by lowestCost, applies 429 Retry-After cooldown, and hedges stalled primary',
      () async {
        final calledModels = <String>[];
        final api = OmniNetwork(
          ai: AiConfig(
            providers: {
              'p': MockAiProvider(
                id: 'p',
                handler: (model, _, _) async {
                  calledModels.add(model);
                  if (model == 'rate_limited') {
                    throw HttpFailure(
                      OmniRawResponse(
                        statusCode: 429,
                        headers: const {'retry-after': '10'},
                      ),
                    );
                  }
                  if (model == 'slow_primary') {
                    await Future<void>.delayed(
                      const Duration(milliseconds: 120),
                    );
                    return const MockAiReply(text: 'slow');
                  }
                  return MockAiReply(text: 'from:$model');
                },
              ),
            },
            pricing: const {
              'expensive': AiModelCost(
                inputPerMillionUsd: 10.0,
                outputPerMillionUsd: 30.0,
              ),
              'cheap': AiModelCost(
                inputPerMillionUsd: 0.1,
                outputPerMillionUsd: 0.4,
              ),
            },
            routes: const {
              'budget': AiModelRoute([
                AiTarget('p', model: 'expensive'),
                AiTarget('p', model: 'cheap'),
              ], strategy: AiRoutingStrategy.lowestCost),
              'guarded': AiModelRoute([
                AiTarget('p', model: 'rate_limited'),
                AiTarget('p', model: 'fallback'),
              ]),
              'race': AiModelRoute(
                [
                  AiTarget('p', model: 'slow_primary'),
                  AiTarget('p', model: 'fast_hedge'),
                ],
                strategy: AiRoutingStrategy.hedged,
                hedgeDelay: Duration(milliseconds: 15),
              ),
            },
          ),
        );
        addTearDown(api.close);

        expect(await api.ai.ask('test', model: 'budget'), 'from:cheap');

        // First call hits 429 on 'rate_limited' -> fails over to 'fallback'.
        // Second call skips 'rate_limited' completely during cooldown!
        expect(await api.ai.ask('first', model: 'guarded'), 'from:fallback');
        calledModels.clear();
        expect(await api.ai.ask('second', model: 'guarded'), 'from:fallback');
        expect(calledModels, ['fallback']);

        // Hedged race completes with fast backup before slow primary finishes.
        expect(await api.ai.ask('race', model: 'race'), 'from:fast_hedge');
      },
    );
  });

  group('Vector RAG, Voice/Image & Wire Capabilities', () {
    test(
      'TextSplitter, embedBatch, indexText, metadata filter & hybrid search work together',
      () async {
        final dir = await Directory.systemTemp.createTemp('omni_hybrid_rag_');
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });
        final store = FileVectorStore(directory: dir.path);

        final chunks = TextSplitter.split(
          'Authentication uses short-lived JWT tokens.\n\n'
          'WebSockets automatically reconnect with backoff.',
          chunkSize: 55,
          overlap: 10,
        );
        expect(chunks.length, greaterThanOrEqualTo(2));

        final api = OmniNetwork(
          ai: AiConfig(
            defaultModel: 'mock:llm',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                embedder: (t) =>
                    t.toLowerCase().contains('jwt') ? [1.0, 0.0] : [0.2, 0.9],
              ),
            },
          ),
        );
        addTearDown(api.close);

        await api.ai.indexText(
          store: store,
          documentId: 'security_doc',
          text:
              'JWT refresh rotates tokens safely.\n\nCaching supports ETag revalidation.',
          embedModel: 'mock:emb',
          metadata: const {'topic': 'auth'},
          chunkSize: 40,
          overlap: 5,
        );
        await api.ai.indexText(
          store: store,
          documentId: 'billing_doc',
          text: 'Invoices generate monthly PDF receipts.',
          embedModel: 'mock:emb',
          metadata: const {'topic': 'billing'},
          chunkSize: 60,
          overlap: 0,
        );

        final authHits = await store.searchHybrid(
          'JWT refresh tokens',
          embedder: api.ai.embedder('mock:emb'),
          where: const {'topic': 'auth'},
          topK: 2,
        );
        expect(authHits, isNotEmpty);
        expect(
          authHits.every((h) => h.document.metadata['topic'] == 'auth'),
          isTrue,
        );
        expect(authHits.first.document.text, contains('JWT'));

        // Voice STT, TTS & Image generation via MockAiProvider & CustomAiProvider.
        final stt = await api.ai.transcribeAudio(
          Uint8List.fromList([1, 2, 3, 4]),
          mimeType: 'audio/mp3',
          model: 'mock:whisper',
        );
        expect(stt.text, contains('4 bytes'));

        final tts = await api.ai.generateSpeech(
          'Hello world',
          model: 'mock:tts',
        );
        expect(tts.bytes, isNotEmpty);

        final imgs = await api.ai.generateImage(
          'A lighthouse',
          model: 'mock:img',
        );
        expect(imgs.single.url, contains('lighthouse'));
      },
    );

    test(
      'OpenAiProvider & GeminiProvider & Anthropic promptCaching wire payloads match specs',
      () async {
        final seenRequests = <TransportRequest>[];
        final api = OmniNetwork(
          transport: MockTransport((req) {
            seenRequests.add(req);
            final path = req.uri.path;
            if (path.endsWith('/embeddings')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'data': [
                      {
                        'embedding': [1.0, 0.0],
                      },
                      {
                        'embedding': [0.0, 1.0],
                      },
                    ],
                  }),
                ),
              );
            }
            if (path.endsWith('/audio/transcriptions')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({'text': 'Hello OpenAI', 'language': 'en'}),
                ),
              );
            }
            if (path.endsWith('/audio/speech')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'audio/mpeg'},
                bodyBytes: Uint8List.fromList([9, 8, 7]),
              );
            }
            if (path.endsWith('/images/generations')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'data': [
                      {'url': 'https://img.openai.test/1.png'},
                    ],
                  }),
                ),
              );
            }
            if (path.endsWith('/messages')) {
              expect(req.headers['anthropic-beta'], contains('prompt-caching'));
              final body =
                  jsonDecode(utf8.decode(req.body!)) as Map<String, Object?>;
              expect(body['system'], isA<List<Object?>>());
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'content': [
                      {'type': 'text', 'text': 'Cached OK'},
                    ],
                    'usage': {
                      'input_tokens': 5,
                      'cache_read_input_tokens': 100,
                      'output_tokens': 3,
                    },
                  }),
                ),
              );
            }
            return OmniRawResponse(statusCode: 404);
          }),
          ai: AiConfig(
            providers: {
              'openai': OpenAiProvider(apiKey: () => 'sk'),
              'claude': AnthropicProvider(apiKey: () => 'ant'),
            },
          ),
        );
        addTearDown(api.close);

        final vecs = await api.ai.embedBatch([
          'a',
          'b',
        ], model: 'openai:text-embedding-3-small');
        expect(vecs, [
          [1.0, 0.0],
          [0.0, 1.0],
        ]);

        final tr = await api.ai.transcribeAudio(
          Uint8List.fromList([1, 2]),
          mimeType: 'audio/mp3',
          model: 'openai:whisper-1',
        );
        expect(tr.text, 'Hello OpenAI');

        final sp = await api.ai.generateSpeech('hi', model: 'openai:tts-1');
        expect(sp.bytes, [9, 8, 7]);

        final imgs = await api.ai.generateImage(
          'cat',
          model: 'openai:dall-e-3',
        );
        expect(imgs.single.url, 'https://img.openai.test/1.png');

        final cachedRes = await api.ai.chat(
          [AiMessage.system('Long context'), AiMessage.user('Hi')],
          model: 'claude:claude-3-7-sonnet-latest',
          options: const AiRequestOptions(promptCaching: true),
        );
        expect(cachedRes.usage.inputTokens, 105);

        // Gemini batchEmbedContents, audio transcription & Imagen, plus Ollama batch embed.
        final gemOllApi = OmniNetwork(
          transport: MockTransport((req) {
            final p = req.uri.path;
            if (p.contains(':batchEmbedContents')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'embeddings': [
                      {
                        'values': [0.1, 0.2],
                      },
                      {
                        'values': [0.3, 0.4],
                      },
                    ],
                  }),
                ),
              );
            }
            if (p.contains(':generateContent')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'candidates': [
                      {
                        'content': {
                          'parts': [
                            {'text': 'Gemini audio transcript'},
                          ],
                        },
                      },
                    ],
                  }),
                ),
              );
            }
            if (p.contains(':predict')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'predictions': [
                      {
                        'bytesBase64Encoded': base64Encode([1, 2, 3]),
                        'mimeType': 'image/png',
                      },
                    ],
                  }),
                ),
              );
            }
            if (p.endsWith('/api/embed')) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'embeddings': [
                      [0.5, 0.6],
                      [0.7, 0.8],
                    ],
                  }),
                ),
              );
            }
            return OmniRawResponse(statusCode: 404);
          }),
          ai: AiConfig(
            providers: {
              'gemini': GeminiProvider(apiKey: () => 'gk'),
              'ollama': OllamaProvider(baseUrl: 'http://127.0.0.1:11434'),
            },
          ),
        );
        addTearDown(gemOllApi.close);

        expect(
          await gemOllApi.ai.embedBatch([
            'x',
            'y',
          ], model: 'gemini:text-embedding-004'),
          [
            [0.1, 0.2],
            [0.3, 0.4],
          ],
        );
        expect(
          (await gemOllApi.ai.transcribeAudio(
            Uint8List.fromList([5, 6]),
            mimeType: 'audio/wav',
            model: 'gemini:gemini-2.5-flash',
          )).text,
          'Gemini audio transcript',
        );
        expect(
          (await gemOllApi.ai.generateImage(
            'robot',
            model: 'gemini:imagen-3.0',
          )).single.bytes,
          [1, 2, 3],
        );
        expect(
          await gemOllApi.ai.embedBatch([
            'a',
            'b',
          ], model: 'ollama:nomic-embed-text'),
          [
            [0.5, 0.6],
            [0.7, 0.8],
          ],
        );
      },
    );
  });

  group('Metrics Percentiles, OmniApiHub Health/Tools & ChatCipher/Search', () {
    test(
      'records P50/P95/P99 latencies and endpoint metrics, probes healthCheckAll, and bridges EndpointRegistry',
      () async {
        final registry = EndpointRegistry([
          Endpoint.get<Map<String, dynamic>>(
            '/orders/{id}',
            name: 'get_order',
            description: 'Fetch order details',
          ),
        ]);

        final hub = OmniApiHub(
          activeEnvironment: 'prod',
          environments: const {
            'prod': OmniEnvironment(
              name: 'prod',
              variables: {'orders': 'https://orders.test'},
            ),
          },
          services: const {
            'orders': ServiceConfig.fromVar(baseUrlVar: 'orders'),
          },
          ai: AiConfig(
            defaultModel: 'mock:m1',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (_, msgs, opts) {
                  final toolRes = msgs.last.parts
                      .whereType<AiToolResultPart>()
                      .toList();
                  if (toolRes.isNotEmpty) {
                    return MockAiReply(text: jsonEncode(toolRes.first.result));
                  }
                  return const MockAiReply(
                    text: '',
                    toolCalls: [
                      AiToolCallPart(
                        id: 't1',
                        name: 'get_order',
                        arguments: {'id': '77'},
                      ),
                    ],
                  );
                },
              ),
            },
          ),
          transportOverride: MockTransport((req) {
            expect(req.headers['x-tenant'], 'acme');
            if (req.uri.path == '/health') {
              return OmniRawResponse(statusCode: 200);
            }
            if (req.uri.path == '/orders/77') {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({'orderId': '77', 'paid': true}),
                ),
              );
            }
            return OmniRawResponse(statusCode: 404);
          }),
        );
        addTearDown(hub.close);

        hub.setGlobalHeader('X-Tenant', 'acme');
        final health = await hub.healthCheckAll();
        expect(health['orders']!.isHealthy, isTrue);
        expect(health['orders']!.statusCode, 200);

        final tools = hub.toolsFromRegistry(registry, serviceName: 'orders');
        final orderAnswer = await hub.ai.withTools(tools).ask('Check order 77');
        expect(orderAnswer, contains('"paid":true'));

        final metrics = hub.service('orders').metrics;
        expect(metrics.totalRequests, 2);
        expect(metrics.p95Latency, greaterThanOrEqualTo(Duration.zero));
        expect(metrics.byEndpoint['GET /orders/77']!.count, 1);
        expect(metrics.byEndpoint['GET /health']!.errorRate, 0.0);
      },
    );

    test(
      'OmniChatRoom supports ChatCipher E2EE, search(), and threadMessages()',
      () async {
        final store = MemoryChatStore();
        final cipher = _ReverseCipher();
        final api = OmniNetwork(
          baseUrl: 'https://chat.test',
          chatStore: store,
          chatConfig: ChatConfig(
            currentUserId: 'me',
            cipher: cipher,
            encryptLocalStore: true,
          ),
        );
        addTearDown(api.close);

        final room = api.chat.room('secret_room');
        final parent = await room.sendText('Secret alpha launch');
        await room.sendText('Confirmed alpha', replyToId: parent.id);
        await room.sendText('Unrelated beta note');

        // Cipher encrypted disk storage -> raw store contains reversed ciphertext!
        final rawStored = store.loadMessages('secret_room');
        expect(rawStored.first.text, isNot(contains('Secret alpha')));
        expect(rawStored.first.metadata['_e2ee'], isTrue);

        // Room search searches decrypted plaintext seamlessly!
        final hits = await room.search('alpha');
        expect(hits, hasLength(2));

        final thread = room.threadMessages(parent.id);
        expect(thread, hasLength(2));
        expect(thread.first.id, parent.id);
        expect(thread.last.replyToId, parent.id);

        // Inbound E2EE message arrives encrypted over WS -> automatically decrypted!
        final incomingFuture = room.messagesStream.firstWhere(
          (list) =>
              list.any((m) => m.id == 'srv_in_1' && m.text == 'Hidden payload'),
        );
        room.handleInboundEvent(
          ChatMessageReceived(
            ChatMessage.text(
              id: 'srv_in_1',
              roomId: 'secret_room',
              senderId: 'peer',
              text: cipher.encrypt('Hidden payload'),
            ).copyWith(metadata: const {'_e2ee': true}),
          ),
        );
        await incomingFuture;
      },
    );
  });
}

final class _ReverseCipher implements ChatCipher {
  @override
  String encrypt(String plaintext) =>
      String.fromCharCodes(plaintext.codeUnits.reversed);

  @override
  String decrypt(String ciphertext) =>
      String.fromCharCodes(ciphertext.codeUnits.reversed);
}
