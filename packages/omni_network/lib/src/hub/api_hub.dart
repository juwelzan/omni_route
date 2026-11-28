import 'dart:async';

import 'package:omni_network/omni_network.dart';

import '../ai/ai_models.dart';
import '../ai/omni_ai.dart';
import '../chat/chat_store.dart';
import '../chat/omni_chat_client.dart';
import '../core/cancel_token.dart';
import '../core/interceptor.dart';
import '../core/omni_network.dart';
import '../core/omni_network_exception.dart';
import '../core/omni_request.dart';
import '../endpoint/endpoint.dart';
import '../log/network_log.dart';
import '../log/pretty_log.dart';
import '../log/redactor.dart';
import '../queue/queued_request.dart';
import '../realtime/sse.dart';
import '../realtime/web_socket.dart';
import '../transport/transport.dart';
import 'api_environment.dart';

/// Central configuration hub orchestrating multiple named API backends,
/// multi-environment switching (`dev`/`staging`/`prod`), runtime remote config
/// loading, shared logging/redaction, WebSocket/SSE channels, `OmniAi`
/// multi-model routing, and `OmniChatClient`.
final class OmniApiHub {
  /// Creates an API configuration hub.
  OmniApiHub({
    String activeEnvironment = 'default',
    Map<String, OmniEnvironment> environments = const {},
    Map<String, ServiceConfig> services = const {},
    AiConfig ai = const AiConfig(),
    this.logSink,
    this.redactor = const Redactor(),
    this.logOptions = const LogOptions(),
    Transport? transportOverride,
    WebSocketConnector? wsConnectorOverride,
  }) : _activeEnv = activeEnvironment,
       _environments = Map.of(environments),
       _serviceConfigs = Map.of(services),
       _aiConfig = ai,
       // ignore: prefer_initializing_formals
       _transportOverride = transportOverride,
       // ignore: prefer_initializing_formals
       _wsConnectorOverride = wsConnectorOverride;

  /// Shared [LogSink] attached across all built service clients.
  final LogSink? logSink;

  /// Shared redaction policy.
  final Redactor redactor;

  /// Shared logger formatting defaults.
  final LogOptions logOptions;

  final Map<String, OmniEnvironment> _environments;
  final Map<String, ServiceConfig> _serviceConfigs;
  final Map<String, OmniNetwork> _clients = {};
  final Map<String, OmniChatClient> _chats = {};
  final StreamController<String> _envChanges =
      StreamController<String>.broadcast();
  final Transport? _transportOverride;
  final WebSocketConnector? _wsConnectorOverride;

  String _activeEnv;
  AiConfig _aiConfig;
  OmniNetwork? _aiSupportClient;
  OmniAi? _ai;
  bool _closed = false;

  /// Currently selected environment key.
  String get activeEnvironmentName => _activeEnv;

  /// Active [OmniEnvironment] profile, or `null` if `'default'` wasn't defined.
  OmniEnvironment? get currentEnvironment => _environments[_activeEnv];

  /// All registered service names.
  Iterable<String> get serviceNames => _serviceConfigs.keys;

  /// Broadcast stream emitting environment name whenever [useEnvironment] or
  /// [loadRemoteConfig] switches settings.
  Stream<String> get changes => _envChanges.stream;

  /// Sets or replaces header [name] dynamically across all currently built
  /// service clients as well as future service builds on this hub.
  void setGlobalHeader(String name, String value) {
    final lower = name.toLowerCase();
    for (final client in _clients.values) {
      client.setHeader(lower, value);
    }
    final support = _aiSupportClient;
    support?.setHeader(lower, value);
    for (final entry in _serviceConfigs.entries) {
      _serviceConfigs[entry.key] = entry.value.copyWith(
        headers: {...entry.value.headers, lower: value},
      );
    }
  }

  /// Removes a global header [name] across active and configured services.
  void removeGlobalHeader(String name) {
    final lower = name.toLowerCase();
    for (final client in _clients.values) {
      client.removeHeader(lower);
    }
    _aiSupportClient?.removeHeader(lower);
    for (final entry in _serviceConfigs.entries) {
      final next = Map<String, String>.of(entry.value.headers)..remove(lower);
      _serviceConfigs[entry.key] = entry.value.copyWith(headers: next);
    }
  }

  /// Probes [path] (default `'/health'`) concurrently across every registered
  /// service, reporting status code, latency, and any error.
  Future<Map<String, ServiceHealth>> healthCheckAll({
    String path = '/health',
    Duration timeout = const Duration(seconds: 5),
    bool auth = false,
  }) async {
    final names = _serviceConfigs.keys.toList(growable: false);
    final entries = await Future.wait([
      for (final name in names)
        () async {
          final sw = Stopwatch()..start();
          try {
            final res = await service(
              name,
            ).sendRaw(OmniRequest.get(path, timeout: timeout, skipAuth: !auth));
            return MapEntry(
              name,
              ServiceHealth(
                serviceName: name,
                isHealthy: res.isSuccess,
                statusCode: res.statusCode,
                latency: sw.elapsed,
              ),
            );
          } catch (e) {
            return MapEntry(
              name,
              ServiceHealth(
                serviceName: name,
                isHealthy: false,
                latency: sw.elapsed,
                error: '$e',
              ),
            );
          }
        }(),
    ]);
    return {for (final e in entries) e.key: e.value};
  }

  /// Converts an entire [EndpointRegistry] into callable [AiTool] definitions
  /// backed by [serviceName] (or [primary]).
  List<AiTool> toolsFromRegistry(
    EndpointRegistry registry, {
    String? serviceName,
  }) => AiTool.fromRegistry(
    registry,
    client: serviceName == null ? primary : service(serviceName),
  );

  /// Default or `'core'` service client (falls back to the first registered
  /// service when `'default'`/`'core'` are absent).
  OmniNetwork get primary {
    if (_serviceConfigs.containsKey('default')) return service('default');
    if (_serviceConfigs.containsKey('core')) return service('core');
    if (_serviceConfigs.isNotEmpty) return service(_serviceConfigs.keys.first);
    return _ensureSupportClient();
  }

  /// Unified Multi-AI engine configured on this hub (shares hub logging and
  /// test transport overrides).
  OmniAi get ai =>
      _ai ??= OmniAi(client: _ensureSupportClient(), config: _aiConfig);

  OmniNetwork _ensureSupportClient() => _aiSupportClient ??= OmniNetwork(
    transport: _transportOverride,
    wsConnector: _wsConnectorOverride,
    enableLogging: currentEnvironment?.enableLogging ?? false,
    logSink: logSink,
    redactor: redactor,
    logOptions: logOptions,
  );

  /// Whether a service named [name] is configured in this hub.
  bool hasService(String name) => _serviceConfigs.containsKey(name);

  /// Registers or updates [config] for service [name] dynamically at runtime.
  ///
  /// Any existing cached client for [name] is safely closed and rebuilt lazily
  /// on the next [service] call.
  Future<void> registerService(String name, ServiceConfig config) async {
    _serviceConfigs[name] = config;
    final old = _clients.remove(name);
    if (old != null) await old.close();
  }

  /// Registers or updates an [OmniEnvironment] profile dynamically.
  void registerEnvironment(OmniEnvironment environment) {
    _environments[environment.name] = environment;
  }

  /// Returns the configured [OmniNetwork] client for [name] (creating it on
  /// first access).
  OmniNetwork service(String name) {
    if (_closed) throw const ClosedFailure();
    return _clients[name] ??= _buildClient(name);
  }

  /// Switches the active environment to [environmentName], rebuilding cached
  /// service clients cleanly and notifying [changes].
  Future<void> useEnvironment(String environmentName) async {
    if (!_environments.containsKey(environmentName)) {
      throw ArgumentError.value(
        environmentName,
        'environmentName',
        'Environment not registered (available: ${_environments.keys.join(', ')})',
      );
    }
    _activeEnv = environmentName;
    final oldClients = _clients.values.toList();
    _clients.clear();
    for (final c in oldClients) {
      await c.close();
    }
    _aiSupportClient?.enableLogging = currentEnvironment?.enableLogging ?? false;
    final oldChat = _chats.values.toList();
    _chats.clear();
    for (final ch in oldChat) {
      await ch.close();
    }
    if (!_envChanges.isClosed) _envChanges.add(environmentName);
  }

  /// Updates environments, service endpoints, headers, or AI model routes
  /// dynamically from a JSON config payload (e.g. Firebase Remote Config or
  /// `/app/config` endpoint).
  Future<void> loadRemoteConfig(Map<String, Object?> json) async {
    if (json['environments'] case final Map envMap) {
      for (final e in envMap.entries) {
        if (e.value is Map) {
          _environments['${e.key}'] = OmniEnvironment.fromJson(
            '${e.key}',
            Map<String, Object?>.from(e.value! as Map),
          );
        }
      }
    }
    if (json['services'] case final Map svcMap) {
      for (final e in svcMap.entries) {
        final name = '${e.key}';
        if (e.value is! Map) continue;
        final cfg = Map<String, Object?>.from(e.value! as Map);
        final existing = _serviceConfigs[name] ?? const ServiceConfig();
        _serviceConfigs[name] = existing.copyWith(
          baseUrl: cfg['baseUrl'] as String?,
          wsUrl: cfg['wsUrl'] as String?,
          headers: cfg['headers'] is Map
              ? {
                  ...existing.headers,
                  ...Map<String, String>.from(cfg['headers']! as Map),
                }
              : null,
          timeout: cfg['timeoutMs'] is int
              ? Duration(milliseconds: cfg['timeoutMs']! as int)
              : null,
          pinnedSha256: cfg['pinnedSha256'] is List
              ? [for (final p in cfg['pinnedSha256']! as List) '$p']
              : null,
        );
      }
    }
    if (json['ai'] case final Map aiJson) {
      if (aiJson['defaultModel'] case final String dm) {
        _aiConfig = AiConfig(
          defaultModel: dm,
          providers: _aiConfig.providers,
          routes: _aiConfig.routes,
          pricing: _aiConfig.pricing,
          maxSessionBudgetUsd: _aiConfig.maxSessionBudgetUsd,
          defaultTools: _aiConfig.defaultTools,
          maxToolRounds: _aiConfig.maxToolRounds,
        );
        _ai?.defaultModel = dm;
      }
      if (aiJson['routes'] case final Map routesMap) {
        final updatedRoutes = Map<String, AiModelRoute>.of(_aiConfig.routes);
        for (final entry in routesMap.entries) {
          if (entry.value is! List) continue;
          final targets = <AiTarget>[
            for (final raw in entry.value! as List)
              if (raw is Map &&
                  raw['provider'] is String &&
                  raw['model'] is String)
                AiTarget(
                  raw['provider']! as String,
                  model: raw['model']! as String,
                ),
          ];
          if (targets.isNotEmpty) {
            final route = AiModelRoute(targets);
            updatedRoutes['${entry.key}'] = route;
            _ai?.setRoute('${entry.key}', route);
          }
        }
        _aiConfig = AiConfig(
          defaultModel: _aiConfig.defaultModel,
          providers: _aiConfig.providers,
          routes: updatedRoutes,
          pricing: _aiConfig.pricing,
          maxSessionBudgetUsd: _aiConfig.maxSessionBudgetUsd,
          defaultTools: _aiConfig.defaultTools,
          maxToolRounds: _aiConfig.maxToolRounds,
        );
      }
    }
    final nextEnv = json['activeEnvironment'] as String?;
    if (nextEnv != null && _environments.containsKey(nextEnv)) {
      await useEnvironment(nextEnv);
    } else {
      final oldClients = _clients.values.toList();
      _clients.clear();
      for (final c in oldClients) {
        await c.close();
      }
      if (!_envChanges.isClosed) _envChanges.add(_activeEnv);
    }
  }

  /// Calls a REST [Endpoint] against named [service] (`'default'`/`'core'`
  /// when omitted).
  Future<T> callEndpoint<T>(
    Endpoint<T> endpoint, {
    String? serviceName,
    Map<String, Object?> path = const {},
    Map<String, Object?> query = const {},
    Object? body,
    OmniCancelToken? cancelToken,
  }) => (serviceName == null ? primary : service(serviceName)).call<T>(
    endpoint,
    path: path,
    query: query,
    body: body,
    cancelToken: cancelToken,
  );

  /// Calls a declarative [GraphqlEndpoint] against [serviceName].
  Future<T> callGraphql<T>(
    GraphqlEndpoint<T> spec, {
    String? serviceName,
    Map<String, Object?> variables = const {},
    OmniCancelToken? cancelToken,
  }) => (serviceName == null ? primary : service(serviceName)).graphql<T>(
    spec.path,
    query: spec.query,
    operationName: spec.operationName,
    dataKey: spec.dataKey,
    decoder: spec.decoder,
    variables: {...spec.defaultVariables, ...variables},
    headers: spec.headers,
    cancelToken: cancelToken,
  );

  /// Opens a typed WebSocket connection from a declarative [WsEndpoint].
  OmniWebSocket openWs<T>(
    WsEndpoint<T> spec, {
    String? serviceName,
    Map<String, Object?> query = const {},
  }) => (serviceName == null ? primary : service(serviceName)).ws(
    spec.path,
    query: {...spec.query, ...query},
  );

  /// Opens a Server-Sent Events stream from a declarative [SseEndpoint].
  SseConnection openSse<T>(
    SseEndpoint<T> spec, {
    String? serviceName,
    Map<String, Object?> query = const {},
  }) => (serviceName == null ? primary : service(serviceName)).sse(
    spec.path,
    query: {...spec.query, ...query},
  );

  /// Executes a declarative [AiEndpoint] returning either decoded `T` or raw
  /// text if [T] is `String`.
  Future<T> callAi<T>(
    AiEndpoint<T> spec, {
    Map<String, Object?> input = const {},
    OmniCancelToken? cancelToken,
  }) async {
    final prompt = spec.buildPrompt(input);
    if (spec.decoder != null) {
      return ai.generateObject<T>(
        prompt,
        decoder: spec.decoder!,
        schema: spec.schema,
        model: spec.model,
        systemPrompt: spec.systemPrompt,
        options: spec.options,
        cancelToken: cancelToken,
      );
    }
    final text = await ai.ask(
      prompt,
      model: spec.model,
      systemPrompt: spec.systemPrompt,
      options: spec.options,
      cancelToken: cancelToken,
    );
    return text as T;
  }

  /// Obtains or creates a cached [OmniChatClient] bound to [serviceName] (or
  /// [primary]).
  OmniChatClient chat({
    String? serviceName,
    ChatConfig config = const ChatConfig(),
    ChatStore? store,
    QueueStore? offlineQueueStore,
  }) {
    final key = serviceName ?? '__primary__';
    return _chats[key] ??= OmniChatClient(
      networkClient: serviceName == null ? primary : service(serviceName),
      config: config,
      store: store,
      offlineQueueStore: offlineQueueStore,
      connector: _wsConnectorOverride,
    );
  }

  OmniNetwork _buildClient(String name) {
    final config = _serviceConfigs[name];
    if (config == null) {
      throw ArgumentError.value(
        name,
        'serviceName',
        'Service "$name" is not registered (available: ${_serviceConfigs.keys.join(', ')})',
      );
    }
    final env = currentEnvironment;
    final urls = config.resolveUrls(env);
    final mergedHeaders = <String, String>{
      if (env != null) ...env.headers,
      ...config.headers,
    };
    final limit = config.rateLimit;
    final interceptors = <OmniInterceptor>[
      if (limit != null) RateLimiterInterceptor(limit),
      ...config.interceptors,
    ];
    final effectivePins = config.pinnedSha256.isNotEmpty
        ? config.pinnedSha256
        : (env?.pinnedSha256 ?? const []);

    final client = OmniNetwork(
      baseUrl: urls.baseUrl,
      wsBaseUrl: urls.wsUrl,
      headers: mergedHeaders,
      timeout: config.timeout ?? env?.timeout ?? const Duration(seconds: 30),
      connectTimeout: config.connectTimeout,
      sendTimeout: config.sendTimeout,
      receiveTimeout: config.receiveTimeout,
      proxy: _transportOverride == null ? env?.proxy : null,
      pinnedSha256: _transportOverride == null ? effectivePins : const [],
      allowBadProxyCertificate: config.allowBadProxyCertificate,
      trustedProxyCertificateBytes: _transportOverride == null
          ? config.trustedProxyCertificateBytes
          : null,
      clientCertificateBytes: _transportOverride == null
          ? config.clientCertificateBytes
          : null,
      clientPrivateKeyBytes: _transportOverride == null
          ? config.clientPrivateKeyBytes
          : null,
      clientCertificatePassword: config.clientCertificatePassword,
      dnsOverHttps: _transportOverride == null ? config.dnsOverHttps : null,
      dnsLookup: _transportOverride == null ? config.dnsLookup : null,
      enableHttp2: _transportOverride == null
          ? (config.enableHttp2 ?? env?.enableHttp2 ?? false)
          : false,
      maxConcurrentRequests: config.maxConcurrentRequests,
      slowRequestThreshold: config.slowRequestThreshold,
      onSlowRequest: config.onSlowRequest,
      decoders: config.decoders,
      transport: _transportOverride,
      wsConnector: _wsConnectorOverride,
      responseAdapter: config.responseAdapter,
      enableLogging: env?.enableLogging ?? false,
      logSink: logSink,
      logOptions: logOptions,
      redactor: redactor,
      interceptors: interceptors,
      auth: config.auth,
      token: config.token,
      retry: config.retry,
      circuitBreaker: config.circuitBreaker,
      cache: config.cache,
    );
    client.closeAuthWithClient = false;
    return client;
  }

  /// Closes all service clients, chat clients, AI tracker, and environment
  /// change streams.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final ch in _chats.values) {
      await ch.close();
    }
    _chats.clear();
    for (final c in _clients.values) {
      await c.close();
    }
    _clients.clear();
    for (final cfg in _serviceConfigs.values) {
      final a = cfg.auth;
      if (a is OmniAuth) await a.close();
    }
    await _ai?.close();
    await _aiSupportClient?.close();
    if (!_envChanges.isClosed) await _envChanges.close();
  }
}
