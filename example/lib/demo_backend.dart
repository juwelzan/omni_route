import 'dart:async';
import 'dart:convert';

import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// User record from JSONPlaceholder (`https://jsonplaceholder.typicode.com/users/{id}`).
class PublicUser {
  const PublicUser({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.city,
    required this.companyName,
  });

  factory PublicUser.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    final company = json['company'];
    return PublicUser(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? 'Unknown',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      city: address is Map ? (address['city'] as String? ?? '') : '',
      companyName: company is Map ? (company['name'] as String? ?? '') : '',
    );
  }

  final int id;
  final String name;
  final String username;
  final String email;
  final String city;
  final String companyName;

  @override
  String toString() =>
      'PublicUser(id: $id, name: $name, @$username, city: $city, company: $companyName)';
}

/// Created post returned by `POST https://jsonplaceholder.typicode.com/posts`.
class CreatedPost {
  const CreatedPost({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  factory CreatedPost.fromJson(Map<String, dynamic> json) => CreatedPost(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String? ?? '',
    body: json['body'] as String? ?? '',
    userId: (json['userId'] as num?)?.toInt() ?? 1,
  );

  final int id;
  final String title;
  final String body;
  final int userId;

  @override
  String toString() => 'CreatedPost(id: $id, title: "$title", userId: $userId)';
}

/// Product from DummyJSON (`https://dummyjson.com/products/{id}`).
class PublicProduct {
  const PublicProduct({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.rating,
    required this.brand,
  });

  factory PublicProduct.fromJson(Map<String, dynamic> json) => PublicProduct(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String? ?? '',
    category: json['category'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0,
    brand: json['brand'] as String? ?? 'Generic',
  );

  final int id;
  final String title;
  final String category;
  final double price;
  final double rating;
  final String brand;

  @override
  String toString() =>
      'PublicProduct(id: $id, title: "$title", \$$price, rating: $rating, brand: $brand)';
}

/// Live forecast from Open-Meteo (`https://api.open-meteo.com/v1/forecast`).
class DhakaWeather {
  const DhakaWeather({
    required this.temperatureC,
    required this.windSpeedKmh,
    required this.time,
  });

  factory DhakaWeather.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? const {};
    return DhakaWeather(
      temperatureC: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      windSpeedKmh: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      time: current['time'] as String? ?? '',
    );
  }

  final double temperatureC;
  final double windSpeedKmh;
  final String time;

  @override
  String toString() =>
      'DhakaWeather(temp: $temperatureC°C, wind: $windSpeedKmh km/h, time: $time)';
}

/// Pokémon summary from PokéAPI (`https://pokeapi.co/api/v2/pokemon/{name}`).
class PokemonInfo {
  const PokemonInfo({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.baseExperience,
  });

  factory PokemonInfo.fromJson(Map<String, dynamic> json) => PokemonInfo(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    height: (json['height'] as num?)?.toInt() ?? 0,
    weight: (json['weight'] as num?)?.toInt() ?? 0,
    baseExperience: (json['base_experience'] as num?)?.toInt() ?? 0,
  );

  final int id;
  final String name;
  final int height;
  final int weight;
  final int baseExperience;

  @override
  String toString() =>
      'PokemonInfo(id: $id, name: $name, height: $height, weight: $weight, xp: $baseExperience)';
}

/// Typed `Endpoint` specifications targeting free public developer REST APIs.
abstract final class PublicApiEndpoints {
  static final userById = Endpoint.get<PublicUser>(
    '/users/{id}',
    decoder: PublicUser.fromJson,
  );
  static final createPost = Endpoint.post<CreatedPost>(
    '/posts',
    decoder: CreatedPost.fromJson,
  );
  static final allPosts = Endpoint.get<List<dynamic>>('/posts');
  static final productById = Endpoint.get<PublicProduct>(
    '/products/{id}',
    decoder: PublicProduct.fromJson,
  );
  static final dhakaWeather = Endpoint.get<DhakaWeather>(
    '/v1/forecast',
    query: const {
      'latitude': 23.8103,
      'longitude': 90.4125,
      'current': 'temperature_2m,wind_speed_10m',
    },
    decoder: DhakaWeather.fromJson,
  );
  static final pokemonByName = Endpoint.get<PokemonInfo>(
    '/pokemon/{name}',
    decoder: PokemonInfo.fromJson,
  );
}

/// Offline mirror ONLY used when `useLiveNetwork: false` (e.g. hermetic
/// `flutter_test` sandbox where `TestWidgetsFlutterBinding` blocks outbound
/// `HttpClient` sockets). Live `dart run bin/demo.dart` and `ExampleApp()`
/// run with `useLiveNetwork: true` against the real public websites!
OmniMock createOfflinePublicMirrorMock() {
  final samplePosts = [
    for (var i = 1; i <= 100; i++)
      {
        'userId': (i % 10) + 1,
        'id': i,
        'title': 'Public post #$i',
        'body': 'Mirror payload body line for post $i inside OmniNetwork',
      },
  ];
  final users = {
    1: {
      'id': 1,
      'name': 'Leanne Graham',
      'username': 'Bret',
      'email': 'Sincere@april.biz',
      'address': {'city': 'Gwenborough'},
      'company': {'name': 'Romaguera-Crona'},
    },
    2: {
      'id': 2,
      'name': 'Ervin Howell',
      'username': 'Antonette',
      'email': 'Shanna@melissa.tv',
      'address': {'city': 'Wisokyburgh'},
      'company': {'name': 'Deckow-Crist'},
    },
    3: {
      'id': 3,
      'name': 'Clementine Bauch',
      'username': 'Samantha',
      'email': 'Nathan@yesenia.net',
      'address': {'city': 'McKenziehaven'},
      'company': {'name': 'Romaguera-Jacobson'},
    },
    4: {
      'id': 4,
      'name': 'Patricia Lebsack',
      'username': 'Karianne',
      'email': 'Julianne.OConner@kory.org',
      'address': {'city': 'South Elvis'},
      'company': {'name': 'Robel-Corkery'},
    },
  };

  MockResponse pokemonHandler(MockRequest req) => MockResponse.json({
    'id': 25,
    'name': req.pathParams['name'] ?? 'pikachu',
    'height': 4,
    'weight': 60,
    'base_experience': 112,
  });

  return OmniMock()
    ..get('/users/{id}', (req) {
      final id = int.tryParse(req.pathParams['id'] ?? '1') ?? 1;
      return MockResponse.json(users[id] ?? users[1]!);
    })
    ..get('/posts', (_) => MockResponse.json(samplePosts))
    ..post('/posts', (req) {
      final body = Map<String, Object?>.from(req.json! as Map);
      return MockResponse.json({...body, 'id': 101}, status: 201);
    })
    ..get('/products/{id}', (req) {
      final id = int.tryParse(req.pathParams['id'] ?? '1') ?? 1;
      return MockResponse.json({
        'id': id,
        'title': 'Essence Mascara Lash Princess',
        'category': 'beauty',
        'price': 9.99,
        'rating': 2.56,
        'brand': 'Essence',
      });
    })
    ..get(
      '/v1/forecast',
      (_) => MockResponse.json({
        'current': {
          'time': '2026-11-27T00:00',
          'temperature_2m': 24.5,
          'wind_speed_10m': 6.2,
        },
      }),
    )
    ..get('/pokemon/{name}', pokemonHandler)
    ..get('/api/v2/pokemon/{name}', pokemonHandler)
    ..get('/history', (_) => MockResponse.json(<Object?>[]))
    ..post(
      '/files/upload',
      (_) => MockResponse.json({'url': 'https://cdn.omni.local/file.png'}),
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

/// Offline in-memory [WebSocketChannel] supporting echo RPC (mirroring
/// `wss://ws.postman-echo.com/raw`) as well as `OmniChatClient` delivery acks.
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
  late final WebSocketSink sink = _InMemoryWebSocketSink(_handleClientPacket, (
    code,
    reason,
  ) async {
    _closeCode = code ?? 1000;
    _closeReason = reason;
    if (!_inbound.isClosed) {
      unawaited(_inbound.close());
    }
  });

  void _sendToClient(Map<String, Object?> payload) {
    if (_inbound.isClosed) return;
    _inbound.add(jsonEncode(payload));
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
      final data = packet['data'];

      if (event == 'chat.send' && data is Map) {
        final roomId = data['roomId'];
        final localId = data['localId'];
        final serverId = 'srv_${++_msgSeq}';
        onServerEvent?.call('Ack chat $localId -> $serverId');
        _sendToClient({
          'event': 'chat.ack',
          'data': {'roomId': roomId, 'localId': localId, 'serverId': serverId},
        });
      } else {
        // Mirror Postman WebSocket Echo (`wss://ws.postman-echo.com/raw`).
        onServerEvent?.call('Echoed frame: $event');
        _sendToClient(packet);
      }
    } catch (_) {}
  }
}

/// Runs BOTH Normal (classic) and Modified (new) API styles against REAL free
/// public developer APIs:
/// - `https://jsonplaceholder.typicode.com` (Users, Posts list, POST /posts)
/// - `https://dummyjson.com` (Products catalog)
/// - `https://api.open-meteo.com` (Live Dhaka weather)
/// - `https://pokeapi.co/api/v2` (Pokémon stats)
/// - `wss://ws.postman-echo.com/raw` (Live public WebSocket Echo + RPC)
class ApiComparisonCoordinator {
  ApiComparisonCoordinator({
    this.useLiveNetwork = true,
    this.enableColors,
    this.onTerminalOutput,
  }) {
    final offlineMirror = useLiveNetwork
        ? null
        : createOfflinePublicMirrorMock();
    chatMockBackend = createOfflinePublicMirrorMock();

    // 1. NORMAL / CLASSIC STYLE:
    //    - Targets real https://jsonplaceholder.typicode.com without global
    //      decoders, without auto colored logging (`enableLogging: false`), and
    //      with manual `PublicUser.fromJson(...)` parsing.
    normalClient = OmniNetwork(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      transport: offlineMirror,
      enableLogging: true,
      logResponse: true,
      timeout: const Duration(seconds: 15),
      logColors: enableColors,
      logOptions: LogOptions(separate: true, colors: enableColors),
    );
    _normalLogSub = normalClient.logStream.listen(
      (r) => _emitLabelledLog('normal', r),
    );

    // 2. MODIFIED API STYLE:
    //    - Targets https://jsonplaceholder.typicode.com + wss://ws.postman-echo.com
    //    - Built-in terminal response printing (`enableLogging`, `logResponse`,
    //      `logColors`) + global `decoders`, `OmniCache`, `RetryPolicy`, `OmniAi`.
    modifiedClient = OmniNetwork(
      baseUrl: 'https://jsonplaceholder.typicode.com',
      wsBaseUrl: 'wss://ws.postman-echo.com',
      transport: offlineMirror,
      decoders: const {
        PublicUser: PublicUser.fromJson,
        CreatedPost: CreatedPost.fromJson,
        PublicProduct: PublicProduct.fromJson,
        DhakaWeather: DhakaWeather.fromJson,
        PokemonInfo: PokemonInfo.fromJson,
      },
      cache: OmniCache(),
      retry: const RetryPolicy(maxAttempts: 2),
      timeout: const Duration(seconds: 15),
      enableLogging: true,
      logResponse: true,
      logColors: enableColors,
      logOptions: LogOptions(summary: true, separate: true, colors: enableColors),
      logInRelease: true,
      wsConnector: useLiveNetwork
          ? null
          : (uri, protocols, headers) => InMemoryWebSocketChannel(),
      ai: AiConfig(
        defaultModel: 'smart',
        providers: {
          // Plug real keys with `--dart-define`:
          // 'openai': OpenAiProvider(apiKey: () => const String.fromEnvironment('OPENAI_API_KEY')),
          // 'gemini': GeminiProvider(apiKey: () => const String.fromEnvironment('GEMINI_API_KEY')),
          'openai': MockAiProvider(
            id: 'openai',
            streamChunkSize: 6,
            handler: (model, msgs, _) => MockAiReply(
              text:
                  '[OpenAI/$model] Live API guide for "${msgs.last.text}": '
                  'JSONPlaceholder, DummyJSON, Open-Meteo, PokeAPI & Postman WS ready!',
              thinking: 'Inspected public API schemas and routePath graph.',
              usage: const AiUsage(inputTokens: 20, outputTokens: 28),
            ),
          ),
          'gemini': MockAiProvider(
            id: 'gemini',
            streamChunkSize: 6,
            handler: (model, msgs, _) => MockAiReply(
              text:
                  '[Gemini/$model] Fast public-API reply for "${msgs.last.text}".',
              thinking: 'Checked cached OmniApiHub endpoints.',
              usage: const AiUsage(inputTokens: 14, outputTokens: 18),
            ),
          ),
        },
        routes: const {
          'smart': AiModelRoute([
            AiTarget('openai', model: 'gpt-4o-mini'),
            AiTarget('gemini', model: 'gemini-2.5-flash'),
          ]),
          'fast': AiModelRoute([AiTarget('gemini', model: 'gemini-2.5-flash')]),
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
    );

    _logSub = modifiedClient.logStream.listen((r) {
      _recordTerminalBox(r);
      _emitLabelledLog('modified', r);
    });

    // 3. MULTI-WEBSITE PUBLIC API HUB:
    //    Manages 4 distinct real developer APIs simultaneously + env switching.
    hub = OmniApiHub(
      activeEnvironment: 'live',
      environments: {
        'live': OmniEnvironment(
          name: 'live',
          variables: {
            'jsonplaceholder': 'https://jsonplaceholder.typicode.com',
            'dummyjson': 'https://dummyjson.com',
            'weather': 'https://api.open-meteo.com',
            'pokeapi': 'https://pokeapi.co/api/v2',
          },
          enableLogging: true,
        ),
        'sandbox': OmniEnvironment(
          name: 'sandbox',
          variables: {
            'jsonplaceholder': 'https://jsonplaceholder.typicode.com',
            'dummyjson': 'https://dummyjson.com',
            'weather': 'https://api.open-meteo.com',
            'pokeapi': 'https://pokeapi.co/api/v2',
          },
          headers: {'x-sandbox': 'true'},
          enableLogging: true,
        ),
      },
      services: {
        'jsonplaceholder': ServiceConfig.fromVar(
          baseUrlVar: 'jsonplaceholder',
          decoders: const {
            PublicUser: PublicUser.fromJson,
            CreatedPost: CreatedPost.fromJson,
          },
        ),
        'dummyjson': ServiceConfig.fromVar(
          baseUrlVar: 'dummyjson',
          decoders: const {PublicProduct: PublicProduct.fromJson},
        ),
        'weather': ServiceConfig.fromVar(
          baseUrlVar: 'weather',
          decoders: const {DhakaWeather: DhakaWeather.fromJson},
        ),
        'pokeapi': ServiceConfig.fromVar(
          baseUrlVar: 'pokeapi',
          decoders: const {PokemonInfo: PokemonInfo.fromJson},
        ),
      },
      logOptions: LogOptions(
        summary: true,
        separate: true,
        responseBody: true,
        colors: enableColors,
      ),
      transportOverride: offlineMirror,
    );
    _attachHubLogStreams();

    // Dedicated in-memory chat room backend for instant message acks & `@ai`.
    chatClient = OmniNetwork(
      baseUrl: 'https://chat.local',
      wsBaseUrl: 'wss://chat.local',
      transport: chatMockBackend,
      wsConnector: (uri, protocols, headers) => InMemoryWebSocketChannel(),
      enableLogging: false,
      chatConfig: const ChatConfig(
        wsPath: '/chat',
        currentUserId: 'me_dev',
        currentUserName: 'Juwel',
      ),
    );
    chatClient.chat.connect();

    aiThread = modifiedClient.aiThread(
      'example_ai_thread',
      systemPrompt: 'You help developers test public REST & WebSocket APIs inside OmniRoute.',
    );
    chatRoom = chatClient.chat.room(
      'public_api_room',
      historyEndpoint: '/history',
    )..attachAiAssistant(modifiedClient.aiThread('room_ai_bot'));
  }

  final bool useLiveNetwork;
  final bool? enableColors;
  final void Function(String terminalLine)? onTerminalOutput;

  late final OmniMock chatMockBackend;
  late final OmniNetwork normalClient;
  late final OmniNetwork modifiedClient;
  late final OmniNetwork chatClient;
  late final OmniApiHub hub;
  late final OmniAiThread aiThread;
  late final OmniChatRoom chatRoom;
  late final StreamSubscription<NetworkLogRecord> _normalLogSub;
  late final StreamSubscription<NetworkLogRecord> _logSub;
  final List<StreamSubscription<NetworkLogRecord>> _hubLogSubs = [];
  final StreamController<({String label, NetworkLogRecord record})>
  _allLogRecords = StreamController.broadcast();

  /// Unified labelled log stream from `normalClient`, `modifiedClient`, and
  /// every `OmniApiHub` service so an inspector receives all API calls without
  /// `requestId` collisions across clients.
  Stream<({String label, NetworkLogRecord record})> get networkLogs =>
      _allLogRecords.stream;

  late final PrettyLogSink _uiPreviewWithBodySink = PrettyLogSink(
    options: const LogOptions(summary: true, responseBody: true, colors: true),
    printer: (formatted) {
      if (modifiedClient.logResponse) {
        lastModifiedTerminalBlock = formatted;
        modifiedOutputLog.add(formatted);
      }
    },
  );

  late final PrettyLogSink _uiPreviewCompactSink = PrettyLogSink(
    options: const LogOptions(summary: true, responseBody: false, colors: true),
    printer: (formatted) {
      if (!modifiedClient.logResponse) {
        lastModifiedTerminalBlock = formatted;
        modifiedOutputLog.add(formatted);
      }
    },
  );

  String lastNormalOutput = '';
  String lastNormalJson = '';
  String lastModifiedOutput = '';
  String lastModifiedJson = '';
  String lastModifiedTerminalBlock = '';
  String lastMultiApiOutput = '';
  String lastMultiApiJson = '';
  String lastWsOutput = '';
  String lastAiOutput = '';
  final List<String> modifiedOutputLog = [];

  static const JsonEncoder _prettyJson = JsonEncoder.withIndent('  ');

  void _emitLabelledLog(String label, NetworkLogRecord record) {
    if (!_allLogRecords.isClosed) {
      _allLogRecords.add((label: label, record: record));
    }
    if (record.kind == NetworkLogKind.response && record.body != null) {
      final body = record.body!;
      final formatted = _formatBodyForCopy(body);
      if (label == 'normal') {
        lastNormalJson = formatted;
      } else if (label == 'modified') {
        lastModifiedJson = formatted;
      }
    }
  }

  static String _formatBodyForCopy(String raw) {
    try {
      return _prettyJson.convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  void _attachHubLogStreams() {
    for (final sub in _hubLogSubs) {
      unawaited(sub.cancel());
    }
    _hubLogSubs.clear();
    for (final name in const ['jsonplaceholder', 'dummyjson', 'weather', 'pokeapi']) {
      _hubLogSubs.add(
        hub.service(name).logStream.listen((r) {
          _recordTerminalBox(r);
          _emitLabelledLog(name, r);
        }),
      );
    }
  }

  /// Updates `logColors` (`null` = auto, `true` = force ANSI, `false` = off)
  /// across `normalClient`, `modifiedClient`, and active `hub` services.
  void setLogColors(bool? colors) {
    normalClient.logColors = colors;
    modifiedClient.logColors = colors;
    for (final name in const ['jsonplaceholder', 'dummyjson', 'weather', 'pokeapi']) {
      hub.service(name).logColors = colors;
    }
  }

  /// Switches [hub] environment and keeps log streams attached.
  Future<void> switchHubEnvironment(String env) async {
    await hub.useEnvironment(env);
    _attachHubLogStreams();
    setLogColors(modifiedClient.logColors);
  }

  void _recordTerminalBox(NetworkLogRecord record) {
    if (!modifiedClient.isLogging) return;
    _uiPreviewWithBodySink.log(record);
    _uiPreviewCompactSink.log(record);
  }

  /// Normal / Classic API call (`normalClient` -> `jsonplaceholder.typicode.com`).
  Future<PublicUser> callNormalApi({int id = 1}) async {
    final raw = await normalClient.get<Map<String, dynamic>>(
      '/users/$id',
      cache: CachePolicy.noCache,
    );
    final decoded = PublicUser.fromJson(raw);
    lastNormalJson = _prettyJson.convert(raw);
    final output =
        '[NORMAL API RESULT -> jsonplaceholder.typicode.com/users/$id]\n'
        'Raw JSON keys: ${raw.keys.take(5).join(', ')}...\n'
        'Manual Decoded: $decoded';
    lastNormalOutput = output;
    onTerminalOutput?.call(output);
    return decoded;
  }

  /// Modified API call (`Endpoint` + global `decoders` + `Result` + auto log).
  Future<Result<PublicUser>> callModifiedApi({int id = 2}) async {
    final res = await modifiedClient
        .call(
          PublicApiEndpoints.userById,
          path: {'id': id},
          cache: CachePolicy.noCache,
        )
        .asResult();
    lastModifiedOutput = switch (res) {
      Ok(:final value) =>
        '[MODIFIED API RESULT -> jsonplaceholder.typicode.com/users/$id]\n'
            'Auto-Decoded Ok: $value\n'
            'enableLogging=${modifiedClient.enableLogging}, '
            'logResponse=${modifiedClient.logResponse}, '
            'logColors=${modifiedClient.logColors}',
      Err(:final error) => '[MODIFIED API ERROR] $error',
    };
    return res;
  }

  /// Real `POST https://jsonplaceholder.typicode.com/posts` returning HTTP 201.
  Future<CreatedPost> callCreatePostDemo({
    String title = 'OmniNetwork Live Test',
    String body = 'Sent directly to jsonplaceholder.typicode.com/posts',
  }) async {
    return modifiedClient.call(
      PublicApiEndpoints.createPost,
      body: {'title': title, 'body': body, 'userId': 1},
    );
  }

  /// Fetches real `/posts` (~100 posts -> ~700+ lines pretty JSON) to verify full
  /// unclipped terminal response printing.
  Future<List<dynamic>> callLargePayloadApi() async {
    return modifiedClient.call(
      PublicApiEndpoints.allPosts,
      cache: CachePolicy.noCache,
    );
  }

  /// Concurrently queries 3 distinct free public APIs via `OmniApiHub`:
  /// DummyJSON (Products), Open-Meteo (Live Dhaka Weather), and PokéAPI.
  Future<String> callMultiWebsitePublicApis({
    int productId = 1,
    String pokemon = 'pikachu',
  }) async {
    final results = await Future.wait([
      hub.callEndpoint(
        PublicApiEndpoints.productById,
        serviceName: 'dummyjson',
        path: {'id': productId},
      ),
      hub.callEndpoint(PublicApiEndpoints.dhakaWeather, serviceName: 'weather'),
      hub.callEndpoint(
        PublicApiEndpoints.pokemonByName,
        serviceName: 'pokeapi',
        path: {'name': pokemon},
      ),
    ]);
    final product = results[0] as PublicProduct;
    final weather = results[1] as DhakaWeather;
    final poke = results[2] as PokemonInfo;
    final summary =
        '[MULTI-WEBSITE PUBLIC HUB (${hub.activeEnvironmentName})]\n'
        '• dummyjson.com -> $product\n'
        '• open-meteo.com -> $weather\n'
        '• pokeapi.co -> $poke';
    lastMultiApiOutput = summary;
    lastMultiApiJson = _prettyJson.convert({
      'environment': hub.activeEnvironmentName,
      'dummyjson': {'id': product.id, 'title': product.title, 'price': product.price},
      'open_meteo': {'temperatureC': weather.temperatureC, 'windSpeedKmh': weather.windSpeedKmh},
      'pokeapi': {'name': poke.name, 'height': poke.height, 'weight': poke.weight},
    });
    return summary;
  }

  /// Connects to `wss://ws.postman-echo.com/raw` (real live echo WebSocket),
  /// emits an event frame and runs a correlated RPC `request` echoed by server!
  Future<int> callWebSocketDemo({int a = 18, int b = 24}) async {
    final socket = modifiedClient.ws('/raw', auth: false);
    if (socket.state != WebSocketState.open) {
      await socket.states.firstWhere((s) => s == WebSocketState.open);
    }
    final helloEcho = socket.on<Map<String, dynamic>>('hello_live').first;
    socket.emit('hello_live', {'app': 'OmniRoute', 'target': 'postman-echo'});
    final echoedNotice = await helloEcho;

    final rpcReply = await socket.request<Map<String, dynamic>>(
      'echo_rpc',
      data: {'a': a, 'b': b, 'sum': a + b},
    );
    final echoedSum = (rpcReply['sum'] as num).toInt();
    lastWsOutput =
        'WS Live Echo (${echoedNotice['target']}) | '
        'RPC echo_rpc($a+$b) = $echoedSum';
    await socket.close();
    return echoedSum;
  }

  /// Streams Multi-Model AI response.
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
    await _normalLogSub.cancel();
    await _logSub.cancel();
    for (final sub in _hubLogSubs) {
      await sub.cancel();
    }
    await _allLogRecords.close();
    await aiThread.close();
    await chatRoom.close();
    await chatClient.close();
    await hub.close();
    await modifiedClient.close();
    await normalClient.close();
  }
}
