import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/src/realtime/ws_protocol.dart'
    show resolveWsAuthForPlatform;
import 'package:omni_network/testing.dart';
import 'package:test/test.dart';

void main() {
  group('OmniNetwork.ws & RPC', () {
    test(
      'shares auth headers, supports typed on/emit & correlated request RPC, and logs redacted frames',
      () async {
        String? seenAuthHeader;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        server.listen((req) async {
          seenAuthHeader = req.headers.value('authorization');
          final ws = await WebSocketTransformer.upgrade(req);
          ws.listen((raw) {
            final msg = jsonDecode(raw as String) as Map<String, Object?>;
            final event = msg['event'];
            if (event == 'sum' && msg['id'] != null) {
              final data = msg['data']! as Map<String, Object?>;
              final total = (data['a']! as num) + (data['b']! as num);
              ws.add(
                jsonEncode({
                  'id': msg['id'],
                  'event': 'sum',
                  'data': {'total': total},
                }),
              );
            } else if (event == 'hello') {
              ws.add(
                jsonEncode({
                  'event': 'welcome',
                  'data': {'token': 'SECRET-ECHO', 'ok': true},
                }),
              );
            }
          });
        });

        final logs = <WsLogRecord>[];
        final api = OmniNetwork(
          wsBaseUrl: 'ws://127.0.0.1:${server.port}',
          headers: {'authorization': 'Bearer SUPER-SECRET-TOKEN'},
          enableLogging: true,
          logInRelease: true,
        );
        addTearDown(api.close);
        final logSub = api.realtimeLogs.listen(logs.add);
        addTearDown(logSub.cancel);

        final socket = api.ws('/realtime', auth: true);
        addTearDown(socket.close);

        await socket.states.firstWhere((s) => s == WebSocketState.open);
        expect(seenAuthHeader, 'Bearer SUPER-SECRET-TOKEN');

        final welcomed = socket
            .on<Map<String, dynamic>>('welcome')
            .first;
        socket.emit('hello', {'user': 'ana'});
        final welcomePayload = await welcomed;
        expect(welcomePayload['ok'], isTrue);

        final rpcResult = await socket.request<int>(
          'sum',
          data: {'a': 19, 'b': 23},
          decoder: (j) => j['total'] as int,
        );
        expect(rpcResult, 42);

        expect(logs, isNotEmpty);
        final allLogText = logs.map((e) => '${e.uri} ${e.summary}').join('\n');
        expect(allLogText, isNot(contains('SUPER-SECRET-TOKEN')));
        expect(allLogText, isNot(contains('SECRET-ECHO')));
      },
    );

    test(
      'resolveWsAuthForPlatform handles browser queryParam & firstMessage safely',
      () {
        final q = resolveWsAuthForPlatform(
          uri: Uri.parse('wss://chat.example.com/ws'),
          headers: const {'authorization': 'Bearer JWT-123'},
          webAuthMode: const WsWebAuthMode.queryParam(paramName: 'access_token'),
          supportsHandshakeHeaders: false,
          bearerOrToken: null,
        );
        expect(q.$2, isEmpty);
        expect(q.$1.queryParameters['access_token'], 'JWT-123');
        expect(q.$3, isNull);

        final fm = resolveWsAuthForPlatform(
          uri: Uri.parse('wss://chat.example.com/ws'),
          headers: const {'authorization': 'Bearer JWT-123'},
          webAuthMode: const WsWebAuthMode.firstMessage(
            event: 'authenticate',
            typeKey: 'type',
            tokenKey: 'jwt',
          ),
          supportsHandshakeHeaders: false,
          bearerOrToken: null,
        );
        expect(fm.$2, isEmpty);
        expect(fm.$3, contains('"type":"authenticate"'));
        expect(fm.$3, contains('"jwt":"JWT-123"'));
      },
    );
  });

  group('OmniNetwork.sse', () {
    test('supports POST streaming bodies with auth: false', () async {
      TransportRequest? captured;
      final api = OmniNetwork(
        baseUrl: 'https://stream.test',
        headers: {'authorization': 'Bearer SHOULD-SKIP'},
        transport: MockTransport((req) {
          captured = req;
          return OmniRawResponse(
            statusCode: 200,
            headers: const {'content-type': 'text/event-stream'},
            bodyBytes: utf8.encode(
              'event: chunk\ndata: part1\n\ndata: part2\n\n',
            ),
          );
        }, chunkSize: 12),
      );
      addTearDown(api.close);

      final sse = api.sse(
        '/generate',
        method: HttpMethod.post,
        body: {'prompt': 'hi'},
        auth: false,
        maxReconnects: 0,
      );
      addTearDown(sse.close);

      final events = await sse.events.take(2).toList();
      expect(events.map((e) => (e.event, e.data)), [
        ('chunk', 'part1'),
        ('message', 'part2'),
      ]);
      expect(captured!.method, HttpMethod.post);
      expect(utf8.decode(captured!.body!), contains('"prompt":"hi"'));
    });
  });

  group('OmniApiHub & Declarative Endpoints', () {
    test(
      'switches environments, rate-limits, loads remote config, and invokes protocol specs',
      () async {
        final seenUris = <Uri>[];
        final seenBodies = <String>[];
        final mockTransport = MockTransport((req) {
          seenUris.add(req.uri);
          if (req.body != null) {
            seenBodies.add(utf8.decode(req.body!));
          }
          if (req.uri.path.endsWith('/graphql')) {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/json'},
              bodyBytes: utf8.encode(
                jsonEncode({
                  'data': {
                    'viewer': {'name': 'Juwel'},
                  },
                }),
              ),
            );
          }
          if (req.uri.path.endsWith('/items')) {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/json'},
              bodyBytes: utf8.encode(jsonEncode({'ok': true})),
            );
          }
          return OmniRawResponse(
            statusCode: 200,
            headers: const {'content-type': 'application/json'},
            bodyBytes: utf8.encode(jsonEncode({'env': req.uri.host})),
          );
        });

        final hub = OmniApiHub(
          activeEnvironment: 'dev',
          environments: {
            'dev': const OmniEnvironment(
              name: 'dev',
              variables: {
                'core': 'https://dev.api.test',
                'ws': 'wss://dev.api.test',
              },
              headers: {'x-env': 'dev'},
            ),
            'prod': const OmniEnvironment(
              name: 'prod',
              variables: {
                'core': 'https://prod.api.test',
                'ws': 'wss://prod.api.test',
              },
              headers: {'x-env': 'prod'},
            ),
          },
          services: {
            'core': const ServiceConfig.fromVar(
              baseUrlVar: 'core',
              wsUrlVar: 'ws',
              rateLimit: RateLimit(
                maxRequests: 2,
                per: Duration(milliseconds: 50),
              ),
            ),
          },
          ai: AiConfig(
            defaultModel: 'fast',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (_, msgs, _) =>
                    MockAiReply(text: '{"summary":"${msgs.last.text}"}'),
              ),
            },
            routes: const {
              'fast': AiModelRoute([AiTarget('mock', model: 'm1')]),
            },
          ),
          transportOverride: mockTransport,
        );
        addTearDown(hub.close);

        // Rate limit: 3 sequential GET calls should take >= ~40ms because 3rd waits.
        final sw = Stopwatch()..start();
        await Future.wait([
          hub.primary.get<Map<String, dynamic>>('/ping'),
          hub.primary.get<Map<String, dynamic>>('/ping'),
          hub.primary.get<Map<String, dynamic>>('/ping'),
        ]);
        expect(seenUris.first.host, 'dev.api.test');
        expect(sw.elapsedMilliseconds, greaterThanOrEqualTo(35));

        final nextEnv = hub.changes.first;
        await hub.useEnvironment('prod');
        expect(await nextEnv, 'prod');

        final gqlSpec = GraphqlEndpoint<String>(
          query: 'query Viewer { viewer { name } }',
          dataKey: 'viewer',
          decoder: (j) => j['name'] as String,
        );
        final name = await hub.callGraphql(gqlSpec);
        expect(name, 'Juwel');
        expect(seenUris.last.host, 'prod.api.test');

        // Declarative AI endpoint returning structured JSON output.
        final aiSpec = AiEndpoint<String>(
          buildPrompt: (i) => 'Summarize ${i['topic']}',
          decoder: (j) => j['summary'] as String,
        );
        final summary = await hub.callAi(aiSpec, input: {'topic': 'OmniRoute'});
        expect(summary, 'Summarize OmniRoute');

        // Remote config dynamically swaps endpoint & adds AI route.
        await hub.loadRemoteConfig({
          'services': {
            'payments': {'baseUrl': 'https://pay.remote.test'},
          },
          'ai': {
            'routes': {
              'custom_alias': [
                {'provider': 'mock', 'model': 'm2'},
              ],
            },
          },
        });
        expect(hub.hasService('payments'), isTrue);
        await hub.callEndpoint(
          Endpoint.get<Map<String, dynamic>>('/items'),
          serviceName: 'payments',
        );
        expect(seenUris.last.host, 'pay.remote.test');
        final aliasReply = await hub.ai.ask('hi', model: 'custom_alias');
        expect(aliasReply, '{"summary":"hi"}');
      },
    );
  });

  group('Multi-AI providers wire adapters', () {
    test('OpenAiProvider handles chat, tool calls & SSE stream', () async {
      var callNo = 0;
      final api = OmniNetwork(
        transport: MockTransport((req) {
          callNo++;
          expect(req.headers['authorization'], 'Bearer sk-test');
          if (req.uri.path.endsWith('/chat/completions')) {
            final body = jsonDecode(utf8.decode(req.body!)) as Map<String, Object?>;
            if (body['stream'] == true) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'text/event-stream'},
                bodyBytes: utf8.encode(
                  'data: ${jsonEncode({'choices': [{'delta': {'content': 'Hello '}}]})}\n\n'
                  'data: ${jsonEncode({'choices': [{'delta': {'content': 'world'}, 'finish_reason': 'stop'}], 'usage': {'prompt_tokens': 3, 'completion_tokens': 2, 'total_tokens': 5}})}\n\n'
                  'data: [DONE]\n\n',
                ),
              );
            }
            if (callNo == 1) {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'model': 'gpt-4o-mini',
                    'choices': [
                      {
                        'finish_reason': 'tool_calls',
                        'message': {
                          'role': 'assistant',
                          'content': '',
                          'tool_calls': [
                            {
                              'id': 'call_1',
                              'type': 'function',
                              'function': {
                                'name': 'add',
                                'arguments': '{"a":4,"b":6}',
                              },
                            },
                          ],
                        },
                      },
                    ],
                    'usage': {'prompt_tokens': 5, 'completion_tokens': 4},
                  }),
                ),
              );
            }
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/json'},
              bodyBytes: utf8.encode(
                jsonEncode({
                  'model': 'gpt-4o-mini',
                  'choices': [
                    {
                      'finish_reason': 'stop',
                      'message': {'role': 'assistant', 'content': '10'},
                    },
                  ],
                  'usage': {'prompt_tokens': 8, 'completion_tokens': 1},
                }),
              ),
            );
          }
          return OmniRawResponse(statusCode: 404);
        }, chunkSize: 16),
        ai: AiConfig(
          providers: {
            'openai': OpenAiProvider(apiKey: () => 'sk-test'),
          },
        ),
      );
      addTearDown(api.close);

      final answer = await api.ai.ask(
        'What is 4+6?',
        model: 'openai:gpt-4o-mini',
        options: AiRequestOptions(
          tools: [
            AiTool.function(
              name: 'add',
              description: 'Add two numbers',
              parameters: const {'type': 'object'},
              execute: (args) => (args['a']! as num) + (args['b']! as num),
            ),
          ],
        ),
      );
      expect(answer, '10');

      final streamed = await api.ai
          .stream('hi', model: 'openai:gpt-4o-mini')
          .toList();
      final completed = streamed.whereType<AiCompleted>().single;
      expect(completed.response.text, 'Hello world');
      expect(completed.response.usage.totalTokens, 5);
    });

    test('GeminiProvider, AnthropicProvider & OllamaProvider parse wire responses', () async {
      final api = OmniNetwork(
        transport: MockTransport((req) {
          final p = req.uri.path;
          if (p.contains(':streamGenerateContent')) {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'text/event-stream'},
              bodyBytes: utf8.encode(
                'data: ${jsonEncode({'candidates': [{'content': {'parts': [{'thought': true, 'text': 'plan '}, {'text': 'Gem'}]}}]})}\n\n'
                'data: ${jsonEncode({'candidates': [{'finishReason': 'STOP', 'content': {'parts': [{'text': 'ini'}]}}], 'usageMetadata': {'promptTokenCount': 2, 'candidatesTokenCount': 3, 'totalTokenCount': 5}})}\n\n',
              ),
            );
          }
          if (p.contains(':embedContent')) {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/json'},
              bodyBytes: utf8.encode(
                jsonEncode({
                  'embedding': {'values': [0.6, 0.8]},
                }),
              ),
            );
          }
          if (p.endsWith('/messages')) {
            expect(req.headers['x-api-key'], 'ant-key');
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'text/event-stream'},
              bodyBytes: utf8.encode(
                'data: ${jsonEncode({'type': 'message_start', 'message': {'usage': {'input_tokens': 4}}})}\n\n'
                'data: ${jsonEncode({'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'thinking_delta', 'thinking': 'think '}})}\n\n'
                'data: ${jsonEncode({'type': 'content_block_delta', 'index': 1, 'delta': {'type': 'text_delta', 'text': 'Claude OK'}})}\n\n'
                'data: ${jsonEncode({'type': 'message_delta', 'delta': {'stop_reason': 'end_turn'}, 'usage': {'output_tokens': 2}})}\n\n',
              ),
            );
          }
          if (p.endsWith('/api/chat')) {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/x-ndjson'},
              bodyBytes: utf8.encode(
                '${jsonEncode({'message': {'content': 'Local '}, 'done': false})}\n'
                '${jsonEncode({'message': {'content': 'Llama'}, 'done': true, 'prompt_eval_count': 3, 'eval_count': 2})}\n',
              ),
            );
          }
          return OmniRawResponse(statusCode: 404);
        }, chunkSize: 16),
        ai: AiConfig(
          providers: {
            'gemini': GeminiProvider(apiKey: () => 'gem-key'),
            'claude': AnthropicProvider(apiKey: () => 'ant-key'),
            'ollama': OllamaProvider(baseUrl: 'http://127.0.0.1:11434'),
          },
        ),
      );
      addTearDown(api.close);

      final gemEvents = await api.ai
          .stream('hi', model: 'gemini:gemini-2.5-flash')
          .toList();
      expect(gemEvents.whereType<AiThinkingDelta>().single.text, 'plan ');
      expect(gemEvents.whereType<AiCompleted>().single.response.text, 'Gemini');

      final vec = await api.ai.embed('doc', model: 'gemini:text-embedding-004');
      expect(vec, [0.6, 0.8]);

      final claudeDone = (await api.ai
              .stream('hi', model: 'claude:claude-3-7-sonnet-latest')
              .toList())
          .whereType<AiCompleted>()
          .single;
      expect(claudeDone.response.thinking, 'think ');
      expect(claudeDone.response.text, 'Claude OK');

      final ollamaDone = (await api.ai
              .stream('hi', model: 'ollama:llama3.2')
              .toList())
          .whereType<AiCompleted>()
          .single;
      expect(ollamaDone.response.text, 'Local Llama');
    });
  });

  group('OmniAi routing, failover, RAG, structured output & budget', () {
    test(
      'fails over across providers, computes cost, enforces budget cap, runs tool endpoints & RAG',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('omni_vec_test_');
        addTearDown(() async {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });

        final api = OmniNetwork(
          baseUrl: 'https://app.test',
          transport: MockTransport((req) {
            if (req.uri.path == '/weather/dhaka') {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(jsonEncode({'tempC': 29})),
              );
            }
            return OmniRawResponse(statusCode: 404);
          }),
        );
        addTearDown(api.close);

        final endpointTool = AiTool.fromEndpoint(
          Endpoint.get<Map<String, dynamic>>('/weather/{city}'),
          client: api,
          name: 'get_weather',
          description: 'Fetches current weather for a city',
          parameters: const {'type': 'object'},
        );

        var weatherCalls = 0;
        api.configureAi(
          AiConfig(
            defaultModel: 'smart',
            providers: {
              'down': MockAiProvider(
                id: 'down',
                handler: (_, _, _) => throw HttpFailure(
                  OmniRawResponse(statusCode: 503),
                ),
              ),
              'backup': MockAiProvider(
                id: 'backup',
                handler: (_, msgs, opts) {
                  if (opts.tools.isNotEmpty && weatherCalls == 0) {
                    weatherCalls++;
                    return const MockAiReply(
                      text: '',
                      toolCalls: [
                        AiToolCallPart(
                          id: 't1',
                          name: 'get_weather',
                          arguments: {'city': 'dhaka'},
                        ),
                      ],
                    );
                  }
                  if (opts.jsonMode) {
                    return const MockAiReply(
                      text: '```json\n{"city":"Dhaka","temp":29}\n```',
                    );
                  }
                  final toolResults = msgs.last.parts
                      .whereType<AiToolResultPart>()
                      .toList();
                  if (toolResults.isNotEmpty) {
                    return MockAiReply(
                      text: 'Answer with ${jsonEncode(toolResults.first.result)}',
                      usage: const AiUsage(inputTokens: 1000, outputTokens: 1000),
                    );
                  }
                  return MockAiReply(
                    text: 'Answer with ${msgs.last.text}',
                    usage: const AiUsage(inputTokens: 1000, outputTokens: 1000),
                  );
                },
                embedder: (text) => text.contains('Dhaka')
                    ? [1.0, 0.0]
                    : [0.0, 1.0],
              ),
            },
            routes: const {
              'smart': AiModelRoute([
                AiTarget('down', model: 'm-down'),
                AiTarget('backup', model: 'm-backup'),
              ]),
            },
            pricing: const {
              'm-backup': AiModelCost(
                inputPerMillionUsd: 1.0,
                outputPerMillionUsd: 2.0,
              ),
            },
            maxSessionBudgetUsd: 0.01,
          ),
        );

        final telemetry = <AiCallLogRecord>[];
        final telSub = api.ai.telemetry.listen(telemetry.add);
        addTearDown(telSub.cancel);

        // Failover + Endpoint tool execution.
        final scopedAi = api.ai.withTools([endpointTool]);
        final reply = await scopedAi.ask('How hot is Dhaka?');
        expect(reply, contains('tempC'));
        expect(telemetry.any((r) => r.usedFallback && r.error == null), isTrue);

        // Structured JSON decoding strips ```json fences.
        final parsed = await api.ai.generateObject<Map<String, dynamic>>(
          'Return Dhaka weather JSON',
          decoder: (j) => j,
        );
        expect(parsed['city'], 'Dhaka');

        // Vector RAG: MemoryVectorStore + FileVectorStore persistence.
        final fileVec = FileVectorStore(directory: tempDir.path);
        final emb = api.ai.embedder('backup:emb');
        await fileVec.upsertAll([
          VectorDocument(
            id: 'd1',
            text: 'Dhaka temperature is 29C today',
            embedding: await emb('Dhaka'),
          ),
          VectorDocument(
            id: 'd2',
            text: 'Tokyo is rainy',
            embedding: await emb('Tokyo'),
          ),
        ]);
        final hits = await fileVec.search('Dhaka', embedder: emb, topK: 1);
        expect(hits.single.document.id, 'd1');

        final ragAnswer = await api.ai.askWithContext(
          question: 'Dhaka temp?',
          context: hits,
        );
        expect(ragAnswer, contains('Dhaka'));

        // Parallel compare & budget exhaustion guard.
        final comparison = await api.ai.compare(
          'Compare test',
          models: ['backup:m-backup'],
        );
        expect(comparison['backup:m-backup']!.usage.estimatedCostUsd, greaterThan(0));

        // After enough priced calls, budget cap throws RequestFailure.
        await expectLater(
          () async {
            for (var i = 0; i < 10; i++) {
              await api.ai.ask('burn', model: 'backup:m-backup');
            }
          }(),
          throwsA(isA<RequestFailure>()),
        );
      },
    );
  });

  group('OmniAiThread & OmniChatClient / OmniChatRoom (@ai + persistence)', () {
    test(
      'OmniAiThread streams, cancels, switches model, summarizes, and restores from FileChatStore',
      () async {
        final dir = await Directory.systemTemp.createTemp('omni_chat_store_');
        addTearDown(() async {
          if (await dir.exists()) await dir.delete(recursive: true);
        });
        final store = FileChatStore(directory: dir.path);

        final api = OmniNetwork(
          ai: AiConfig(
            defaultModel: 'mock:fast',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                streamChunkSize: 3,
                chunkDelay: const Duration(milliseconds: 5),
                handler: (model, msgs, _) {
                  if (msgs.last.text.contains('Summarize')) {
                    return const MockAiReply(text: 'Condensed summary');
                  }
                  return MockAiReply(
                    text: 'Reply from $model',
                    thinking: 'Reason step',
                  );
                },
              ),
            },
          ),
        );
        addTearDown(api.close);

        final thread = api.aiThread(
          'support_1',
          store: store,
          contextPolicy: const SlidingWindowContext(
            maxMessages: 2,
            summarizeOlderWithModel: 'mock:fast',
          ),
        );
        final states = <AiThreadState>[];
        final sub = thread.stream.listen(states.add);
        addTearDown(sub.cancel);

        final msg1 = await thread.sendAndWait('Hello one');
        expect(msg1.text, 'Reply from fast');
        expect(msg1.thinking, 'Reason step');
        expect(states.any((s) => s.isStreaming && s.streamingText.isNotEmpty), isTrue);

        thread.switchModel('mock:smart');
        expect(thread.model, 'mock:smart');

        // Trigger cancellation on a slow stream.
        final slowThread = api.aiThread(
          'slow_1',
          model: 'mock:slow',
          store: store,
        );
        final slowDone = Completer<void>();
        late StreamSubscription<AiThreadState> slowSub;
        slowSub = slowThread.stream.listen((s) {
          if (s.streamingText.isNotEmpty) {
            slowThread.stopGenerating();
          }
          if (!s.isStreaming && s.lastError != null && !slowDone.isCompleted) {
            slowDone.complete();
          }
        });
        addTearDown(slowSub.cancel);
        unawaited(slowThread.send('long prompt').drain<void>());
        await slowDone.future;

        // Re-create thread with same id & store -> restores persisted turns!
        final restoredThread = OmniAiThread(
          id: 'support_1',
          ai: api.ai,
          model: 'mock:fast',
          store: store,
        );
        addTearDown(restoredThread.close);
        await restoredThread.restore();
        expect(restoredThread.state.messages, hasLength(2));
        await restoredThread.sendAndWait('Hello two');
        final regen = await restoredThread.regenerateLast();
        expect(regen, isNotNull);
        await restoredThread.clear();
        expect(restoredThread.state.messages, isEmpty);
      },
    );

    test(
      'OmniChatRoom delivers optimistically, handles ack/typing/reactions/upload/pagination & @ai replies',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));

        final sockets = <WebSocket>[];
        server.listen((req) async {
          final ws = await WebSocketTransformer.upgrade(req);
          sockets.add(ws);
          ws.listen((raw) {
            if (ws.closeCode != null) return;
            final frame = jsonDecode(raw as String) as Map<String, Object?>;
            final event = frame['event'];
            final data = frame['data'] is Map
                ? Map<String, Object?>.from(frame['data']! as Map)
                : const <String, Object?>{};
            try {
              if (event == 'chat.send') {
                ws.add(
                  jsonEncode({
                    'event': 'chat.ack',
                    'data': {
                      'roomId': data['roomId'],
                      'localId': data['localId'],
                      'serverId': 'srv_${data['localId']}',
                      'status': 'sent',
                    },
                  }),
                );
              } else if (event == 'chat.reaction') {
                ws.add(
                  jsonEncode({
                    'event': 'chat.reaction',
                    'data': {
                      'roomId': data['roomId'],
                      'messageId': data['messageId'],
                      'emoji': data['emoji'],
                      'userId': 'peer_bob',
                      'added': true,
                    },
                  }),
                );
              }
            } catch (_) {}
          });
        });

        final api = OmniNetwork(
          baseUrl: 'https://chat.test',
          wsBaseUrl: 'ws://127.0.0.1:${server.port}',
          transport: MockTransport((req) {
            if (req.uri.path == '/files/upload') {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({'url': 'https://cdn.test/photo.png'}),
                ),
              );
            }
            if (req.uri.path == '/history') {
              return OmniRawResponse(
                statusCode: 200,
                headers: const {'content-type': 'application/json'},
                bodyBytes: utf8.encode(
                  jsonEncode({
                    'items': [
                      {
                        'id': 'old_1',
                        'roomId': 'room_1',
                        'senderId': 'bob',
                        'parts': [
                          {'kind': 'text', 'text': 'Older message'},
                        ],
                        'createdAt': DateTime.utc(2025, 1, 1).toIso8601String(),
                      },
                    ],
                  }),
                ),
              );
            }
            return OmniRawResponse(statusCode: 404);
          }),
          ai: AiConfig(
            defaultModel: 'mock:helper',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (_, msgs, _) =>
                    MockAiReply(text: 'AI heard: ${msgs.last.text}'),
              ),
            },
          ),
          chatConfig: const ChatConfig(
            wsPath: '/chat',
            currentUserId: 'me_ana',
            currentUserName: 'Ana',
          ),
        );
        addTearDown(api.close);

        api.chat.connect();
        await api.chat.socket!.states.firstWhere((s) => s == WebSocketState.open);

        final room = api.chat.room('room_1', historyEndpoint: '/history');
        final botThread = api.aiThread('room_bot');
        room.attachAiAssistant(botThread);

        // Load older history via pagination.
        final older = await room.loadOlderMessages();
        expect(older.single.text, 'Older message');

        // Send optimistic message & verify ack updates status to sent & server id.
        final ackCompleter = Completer<void>();
        late StreamSubscription<List<ChatMessage>> ackSub;
        String? pendingLocalId;
        ackSub = room.messagesStream.listen((list) {
          if (pendingLocalId != null &&
              list.any(
                (m) =>
                    m.localId == pendingLocalId &&
                    m.status == MessageDeliveryStatus.sent &&
                    m.id.startsWith('srv_'),
              ) &&
              !ackCompleter.isCompleted) {
            ackCompleter.complete();
          }
        });
        addTearDown(ackSub.cancel);
        final sent = await room.sendText('Hi team!');
        pendingLocalId = sent.localId;
        if (room.messages.any(
              (m) =>
                  m.localId == sent.localId &&
                  m.status == MessageDeliveryStatus.sent &&
                  m.id.startsWith('srv_'),
            ) &&
            !ackCompleter.isCompleted) {
          ackCompleter.complete();
        }
        await ackCompleter.future;

        // Send file attachment via HTTP upload.
        final fileMsg = await room.sendFile(
          UploadFile.fromBytes(
            'photo',
            Uint8List.fromList([1, 2, 3]),
            filename: 'photo.png',
            contentType: 'image/png',
          ),
          caption: 'Look!',
        );
        expect(fileMsg.parts.whereType<ChatMediaPart>().single.url, contains('photo.png'));

        // Toggle reaction + remote reaction update.
        final reactFuture = room.messagesStream.firstWhere(
          (list) => list.any(
            (m) => (m.reactions['🔥'] ?? const []).contains('peer_bob'),
          ),
        );
        await room.toggleReaction(fileMsg.id, '🔥');
        await reactFuture;

        // Hybrid @ai mention inside human chat room generates an AI message!
        final botReplyFuture = room.messagesStream.firstWhere(
          (list) => list.any((m) => m.isAi && m.text.contains('deploy steps')),
        );
        await room.sendText('@ai explain deploy steps');
        final withBot = await botReplyFuture;
        expect(
          withBot.lastWhere((m) => m.isAi).text,
          'AI heard: explain deploy steps',
        );

        // Simulate peer typing over raw socket.
        final typingFuture = room.typingStream.firstWhere(
          (m) => m.containsKey('bob'),
        );
        sockets.single.add(
          jsonEncode({
            'event': 'chat.typing',
            'data': {
              'roomId': 'room_1',
              'userId': 'bob',
              'userName': 'Bob',
              'isTyping': true,
            },
          }),
        );
        final typing = await typingFuture;
        expect(typing['bob']!.userName, 'Bob');

        // Cleanup client before sockets cleanly.
        await api.close();
        for (final s in sockets) {
          await s.close();
        }
      },
    );
  });
}
