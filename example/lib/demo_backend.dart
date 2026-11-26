import 'dart:async';
import 'dart:convert';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Sample decoded domain model used across Normal & Modified API calls.
class StudentRecord {
  const StudentRecord({
    required this.id,
    required this.name,
    required this.department,
    required this.score,
  });

  factory StudentRecord.fromJson(Map<String, dynamic> json) => StudentRecord(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String,
    department: json['department'] as String? ?? 'CSE',
    score: (json['score'] as num?)?.toDouble() ?? 0,
  );

  final int id;
  final String name;
  final String department;
  final double score;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'department': department,
    'score': score,
  };

  @override
  String toString() =>
      'StudentRecord(id: $id, name: $name, department: $department, score: $score)';
}

/// Declarative typed [Endpoint] specs for the Modified API style.
abstract final class StudentApiEndpoints {
  static final byId = Endpoint.get<StudentRecord>(
    '/students/{id}',
    decoder: StudentRecord.fromJson,
  );
  static final list = Endpoint.getList<StudentRecord>(
    '/students',
    decoder: StudentRecord.fromJson,
  );
  static final create = Endpoint.post<StudentRecord>(
    '/students',
    decoder: StudentRecord.fromJson,
  );
}

/// Builds a shared mock HTTP + chat backend so the demo and Flutter example app
/// run reliably offline without external keys or servers.
OmniMock createExampleHttpBackend() {
  final students = <Map<String, Object?>>[
    {'id': 101, 'name': 'Rahim', 'department': 'CSE', 'score': 94.5},
    {'id': 102, 'name': 'Karim', 'department': 'EEE', 'score': 88.0},
    {'id': 103, 'name': 'Ayesha', 'department': 'SWE', 'score': 97.0},
    {'id': 104, 'name': 'Nusrat', 'department': 'AI', 'score': 91.5},
  ];

  return OmniMock()
    ..get('/students', (_) => MockResponse.json(students))
    ..get('/students/{id}', (req) {
      final id = int.tryParse(req.pathParams['id'] ?? '');
      final hit = students.cast<Map<String, Object?>?>().firstWhere(
        (s) => s?['id'] == id,
        orElse: () => null,
      );
      if (hit == null) {
        return MockResponse.json({'error': 'Student not found'}, status: 404);
      }
      return MockResponse.json(hit);
    })
    ..post('/students', (req) {
      final body = Map<String, Object?>.from(req.json! as Map);
      final next = {
        'id': 101 + students.length,
        'name': body['name'] ?? 'New Student',
        'department': body['department'] ?? 'CSE',
        'score': body['score'] ?? 90.0,
      };
      students.add(next);
      return MockResponse.json(next, status: 201);
    })
    ..get('/long-report', (_) {
      // Generates a large multi-line JSON response (~500 lines pretty-printed)
      // to demonstrate full unfiltered terminal response printing.
      final rows = [
        for (var i = 1; i <= 100; i++)
          {
            'lineId': i,
            'student': 'Student #$i',
            'status': i.isEven ? 'active' : 'honors',
            'score': 75 + (i % 25),
          },
      ];
      return MockResponse.json({
        'report': 'Full Multi-Line Payload (~500 lines)',
        'totalRows': rows.length,
        'rows': rows,
      });
    })
    ..get('/history', (_) {
      return MockResponse.json({
        'items': [
          {
            'id': 'hist_1',
            'roomId': 'classroom',
            'senderId': 'mentor_ana',
            'senderName': 'Mentor Ana',
            'parts': [
              {
                'kind': 'text',
                'text': 'Welcome! Type anything or ask @ai a question.',
              },
            ],
            'createdAt': DateTime.utc(2026, 11, 20, 9, 0).toIso8601String(),
          },
        ],
      });
    })
    ..post(
      '/files/upload',
      (_) => MockResponse.json({'url': 'https://cdn.omni.local/syllabus.pdf'}),
    );
}

class _InMemoryWebSocketSink implements WebSocketSink {
  _InMemoryWebSocketSink(this._onAdd, this._onClose);

  final void Function(dynamic data) _onAdd;
  final Future<void> Function(int? code, String? reason) _onClose;
  final Completer<void> _done = Completer<void>();
  bool _closed = false;

  @override
  void add(dynamic data) {
    if (_closed) return;
    scheduleMicrotask(() {
      if (!_closed) _onAdd(data);
    });
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {
    await for (final item in stream) {
      add(item);
    }
  }

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    if (_closed) return _done.future;
    _closed = true;
    await _onClose(closeCode, closeReason);
    if (!_done.isCompleted) _done.complete();
    return _done.future;
  }

  @override
  Future<dynamic> get done => _done.future;
}

/// Offline in-memory [WebSocketChannel] supporting `emit`, correlated RPC
/// `request`, and `OmniChatClient` delivery acks + `@ai`/echo frames.
class InMemoryWebSocketChannel
    with StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  InMemoryWebSocketChannel({this.onServerEvent});

  final void Function(String summary)? onServerEvent;

  final StreamController<dynamic> _inbound = StreamController<dynamic>();

  int? _closeCode;
  String? _closeReason;
  int _msgSeq = 0;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => Future<void>.value();

  @override
  Stream<dynamic> get stream => _inbound.stream;

  @override
  late final WebSocketSink sink = _InMemoryWebSocketSink(
    _handleClientPacket,
    (code, reason) async {
      _closeCode = code ?? 1000;
      _closeReason = reason;
      if (!_inbound.isClosed) {
        unawaited(_inbound.close());
      }
    },
  );

  void _sendToClient(Map<String, Object?> payload) {
    if (_inbound.isClosed) return;
    final encoded = jsonEncode(payload);
    _inbound.add(encoded);
  }

  void _handleClientPacket(dynamic raw) {
    if (raw is! String) return;
    if (raw == '{"type":"ping"}' || raw == 'ping') {
      _sendToClient({'event': 'pong'});
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final packet = Map<String, Object?>.from(decoded);
      final event = packet['event'] as String?;
      final id = packet['id'] as String?;
      final data = packet['data'];

      if (event == 'sum' && id != null && data is Map) {
        final a = (data['a'] as num?) ?? 0;
        final b = (data['b'] as num?) ?? 0;
        onServerEvent?.call('RPC sum($a, $b) -> ${a + b}');
        _sendToClient({
          'id': id,
          'event': 'sum',
          'data': {'total': a + b},
        });
      } else if (event == 'hello') {
        onServerEvent?.call('Received hello -> sending server_notice');
        _sendToClient({
          'event': 'server_notice',
          'data': {
            'greeting': 'WebSocket connected live!',
            'payload': data,
          },
        });
      } else if (event == 'chat.send' && data is Map) {
        final roomId = data['roomId'];
        final localId = data['localId'];
        final serverId = 'srv_${++_msgSeq}';
        onServerEvent?.call('Ack chat message $localId -> $serverId');
        _sendToClient({
          'event': 'chat.ack',
          'data': {'roomId': roomId, 'localId': localId, 'serverId': serverId},
        });
      }
    } catch (_) {}
  }
}

/// Captures BOTH the Normal (classic) API and Modified (new) API side by side.
class ApiComparisonCoordinator {
  ApiComparisonCoordinator({
    this.enableColors = true,
    this.onTerminalOutput,
  }) {
    httpBackend = createExampleHttpBackend();

    // 1. NORMAL / CLASSIC STYLE:
    //    - Plain client with no global `decoders`, no automatic colored terminal
    //      response printing (`enableLogging: false`), and manual JSON parsing.
    normalClient = OmniNetwork(
      baseUrl: 'https://dev.api.omni.local',
      transport: httpBackend,
      enableLogging: false,
    );

    // 2. MODIFIED API STYLE:
    //    - Built-in terminal response printing (`enableLogging`, `logResponse`,
    //      `logColors`) with runtime toggle support.
    //    - Global `decoders` registry, `OmniCache`, `RetryPolicy`, `AiConfig`,
    //      and live `WebSocketConnector` + `OmniChatClient`.
    //    - `OmniApiHub` managing multi-environment (`dev`/`prod`) & endpoints.
    modifiedClient = OmniNetwork(
      baseUrl: 'https://dev.api.omni.local',
      wsBaseUrl: 'wss://ws.omni.local',
      transport: httpBackend,
      decoders: {StudentRecord: StudentRecord.fromJson},
      cache: OmniCache(),
      retry: const RetryPolicy(maxAttempts: 2),
      enableLogging: true,
      logResponse: true,
      logColors: enableColors,
      logInRelease: true,
      wsConnector: (uri, protocols, headers) => InMemoryWebSocketChannel(),
      ai: AiConfig(
        defaultModel: 'smart',
        providers: {
          // Real providers plug in seamlessly too:
          // 'openai': OpenAiProvider(apiKey: () => const String.fromEnvironment('OPENAI_API_KEY')),
          // 'gemini': GeminiProvider(apiKey: () => const String.fromEnvironment('GEMINI_API_KEY')),
          // 'claude': AnthropicProvider(apiKey: () => const String.fromEnvironment('ANTHROPIC_API_KEY')),
          'openai': MockAiProvider(
            id: 'openai',
            streamChunkSize: 6,
            handler: (model, msgs, _) => MockAiReply(
              text:
                  '[OpenAI/$model] Summary for "${msgs.last.text}": OmniRoute + OmniNetwork ready!',
              thinking: 'Evaluated routePath, page-entry Bloc scope & AI route.',
              usage: const AiUsage(inputTokens: 18, outputTokens: 22),
            ),
          ),
          'gemini': MockAiProvider(
            id: 'gemini',
            streamChunkSize: 6,
            handler: (model, msgs, _) => MockAiReply(
              text:
                  '[Gemini/$model] Fast reply for "${msgs.last.text}" via fallback/alias.',
              thinking: 'Checked cached route context.',
              usage: const AiUsage(inputTokens: 12, outputTokens: 16),
            ),
          ),
        },
        routes: const {
          'smart': AiModelRoute([
            AiTarget('openai', model: 'gpt-4o-mini'),
            AiTarget('gemini', model: 'gemini-2.5-flash'),
          ]),
          'fast': AiModelRoute([
            AiTarget('gemini', model: 'gemini-2.5-flash'),
          ]),
        },
        pricing: const {
          'gpt-4o-mini': AiModelCost(
            inputPerMillionUsd: 0.15,
            outputPerMillionUsd: 0.60,
          ),
          'gemini-2.5-flash': AiModelCost(
            inputPerMillionUsd: 0.075,
            outputPerMillionUsd: 0.30,
          ),
        },
      ),
      chatConfig: const ChatConfig(
        wsPath: '/chat',
        currentUserId: 'me_student',
        currentUserName: 'Juwel',
      ),
    );

    _logSub = modifiedClient.logStream.listen((record) {
      if (!modifiedClient.isLogging) return;
      PrettyLogSink(
        options: LogOptions(
          responseBody: modifiedClient.logResponse,
          colors: false,
        ),
        printer: (formatted) {
          lastModifiedTerminalBlock = formatted;
          modifiedOutputLog.add(formatted);
        },
      ).log(record);
    });

    hub = OmniApiHub(
      activeEnvironment: 'dev',
      environments: const {
        'dev': OmniEnvironment(
          name: 'dev',
          variables: {
            'core': 'https://dev.api.omni.local',
            'ws': 'wss://dev.ws.omni.local',
          },
          headers: {'x-env': 'dev'},
        ),
        'prod': OmniEnvironment(
          name: 'prod',
          variables: {
            'core': 'https://prod.api.omni.local',
            'ws': 'wss://prod.ws.omni.local',
          },
          headers: {'x-env': 'prod'},
        ),
      },
      services: const {
        'core': ServiceConfig.fromVar(baseUrlVar: 'core', wsUrlVar: 'ws'),
      },
      transportOverride: httpBackend,
    );

    aiThread = modifiedClient.aiThread(
      'example_ai_thread',
      systemPrompt: 'You are an expert assistant inside OmniRoute Example App.',
    );

    modifiedClient.chat.connect();
    chatRoom = modifiedClient.chat.room(
      'classroom',
      historyEndpoint: '/history',
    )..attachAiAssistant(modifiedClient.aiThread('room_ai_bot'));
  }

  final bool enableColors;
  final void Function(String terminalLine)? onTerminalOutput;

  late final OmniMock httpBackend;
  late final OmniNetwork normalClient;
  late final OmniNetwork modifiedClient;
  late final OmniApiHub hub;
  late final OmniAiThread aiThread;
  late final OmniChatRoom chatRoom;
  late final StreamSubscription<NetworkLogRecord> _logSub;

  String lastNormalOutput = '';
  String lastModifiedOutput = '';
  String lastModifiedTerminalBlock = '';
  String lastWsOutput = '';
  String lastAiOutput = '';
  final List<String> modifiedOutputLog = [];

  /// Runs the Normal / Classic HTTP request (manual JSON decode + manual print).
  Future<StudentRecord> callNormalApi({int id = 101}) async {
    final raw = await normalClient.get<Map<String, dynamic>>(
      '/students/$id',
      cache: CachePolicy.noCache,
    );
    final decoded = StudentRecord.fromJson(raw);
    final output =
        '[NORMAL API RESULT]\n'
        'Raw Map: ${jsonEncode(raw)}\n'
        'Decoded: $decoded';
    lastNormalOutput = output;
    onTerminalOutput?.call(output);
    return decoded;
  }

  /// Runs the Modified API call (auto-decoder + Result + built-in colored
  /// terminal response printing controlled by `enableLogging` / `logResponse`).
  Future<Result<StudentRecord>> callModifiedApi({int id = 101}) async {
    final res = await modifiedClient
        .call(
          StudentApiEndpoints.byId,
          path: {'id': id},
          cache: CachePolicy.noCache,
        )
        .asResult();
    lastModifiedOutput = switch (res) {
      Ok(:final value) =>
        '[MODIFIED API RESULT]\n'
        'Endpoint + Global Decoder Ok: $value\n'
        'enableLogging=${modifiedClient.enableLogging}, '
        'logResponse=${modifiedClient.logResponse}, '
        'logColors=${modifiedClient.logColors}',
      Err(:final error) => '[MODIFIED API ERROR] $error',
    };
    return res;
  }

  /// Calls the 100-row (~500 lines) JSON endpoint to prove complete response
  /// printing with `logResponse: true` (no truncation).
  Future<Map<String, dynamic>> callLargePayloadApi() async {
    return modifiedClient.get<Map<String, dynamic>>(
      '/long-report',
      cache: CachePolicy.noCache,
    );
  }

  /// Connects WebSocket, listens for typed `server_notice`, emits `hello`, and
  /// performs a correlated RPC `request<int>('sum')`.
  Future<int> callWebSocketDemo({int a = 15, int b = 27}) async {
    final socket = modifiedClient.ws('/realtime', auth: false);
    if (socket.state != WebSocketState.open) {
      await socket.states.firstWhere((s) => s == WebSocketState.open);
    }
    final noticeFuture = socket.on<Map<String, dynamic>>('server_notice').first;
    socket.emit('hello', {'from': 'ExampleApp'});
    final notice = await noticeFuture;
    final total = await socket.request<int>(
      'sum',
      data: {'a': a, 'b': b},
      decoder: (j) => (j['total'] as num).toInt(),
    );
    lastWsOutput = 'Event: ${notice['greeting']} | RPC sum($a+$b) = $total';
    await socket.close();
    return total;
  }

  /// Calls the Multi-Model AI router with streaming deltas.
  Future<String> callAiStreamingDemo(String prompt) async {
    final chunks = <String>[];
    await for (final ev in modifiedClient.ai.stream(prompt, model: 'smart')) {
      if (ev is AiTextDelta) {
        chunks.add(ev.text);
      } else if (ev is AiCompleted) {
        lastAiOutput =
            'Model: ${ev.response.model} (${ev.response.usage.totalTokens} tok)\n'
            'Reply: ${ev.response.text}';
        return ev.response.text;
      }
    }
    return chunks.join();
  }

  Future<void> dispose() async {
    await _logSub.cancel();
    await aiThread.close();
    await chatRoom.close();
    await hub.close();
    await modifiedClient.close();
    await normalClient.close();
  }
}
