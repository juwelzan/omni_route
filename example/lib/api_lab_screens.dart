import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omni_network_flutter/omni_network_flutter.dart';
import 'package:omni_route/omni_route.dart';

import 'demo_backend.dart';

/// State exposed by [ApiLabCubit] driving side-by-side Normal vs Modified API
/// comparison across real public websites, logger toggles, `OmniApiHub`,
/// live Postman WebSocket Echo RPC, and Multi-Model AI.
@immutable
class ApiLabState {
  const ApiLabState({
    this.userId = 1,
    this.busy = false,
    this.enableLogging = true,
    this.logResponse = true,
    this.logColors = false,
    this.activeEnv = 'live',
    this.normalResponse =
        'Tap "Call Normal API" -> https://jsonplaceholder.typicode.com/users/1',
    this.modifiedResponse =
        'Tap "Call Modified API" -> https://jsonplaceholder.typicode.com/users/1',
    this.modifiedTerminalBox = '',
    this.hubOutput =
        'Tap "Call 3 Public Websites" -> DummyJSON + Open-Meteo + PokeAPI',
    this.wsOutput =
        'Tap "Run Live WS Echo + RPC" -> wss://ws.postman-echo.com/raw',
    this.totalCapturedLogs = 0,
  });

  final int userId;
  final bool busy;
  final bool enableLogging;
  final bool logResponse;
  final bool logColors;
  final String activeEnv;
  final String normalResponse;
  final String modifiedResponse;
  final String modifiedTerminalBox;
  final String hubOutput;
  final String wsOutput;
  final int totalCapturedLogs;

  ApiLabState copyWith({
    int? userId,
    bool? busy,
    bool? enableLogging,
    bool? logResponse,
    bool? logColors,
    String? activeEnv,
    String? normalResponse,
    String? modifiedResponse,
    String? modifiedTerminalBox,
    String? hubOutput,
    String? wsOutput,
    int? totalCapturedLogs,
  }) => ApiLabState(
    userId: userId ?? this.userId,
    busy: busy ?? this.busy,
    enableLogging: enableLogging ?? this.enableLogging,
    logResponse: logResponse ?? this.logResponse,
    logColors: logColors ?? this.logColors,
    activeEnv: activeEnv ?? this.activeEnv,
    normalResponse: normalResponse ?? this.normalResponse,
    modifiedResponse: modifiedResponse ?? this.modifiedResponse,
    modifiedTerminalBox: modifiedTerminalBox ?? this.modifiedTerminalBox,
    hubOutput: hubOutput ?? this.hubOutput,
    wsOutput: wsOutput ?? this.wsOutput,
    totalCapturedLogs: totalCapturedLogs ?? this.totalCapturedLogs,
  );
}

/// Coordinates [ApiComparisonCoordinator] and [OmniInspector] inside the
/// Flutter example app (`useLiveNetwork: true` by default).
class ApiLabCubit extends Cubit<ApiLabState> {
  ApiLabCubit({bool useLiveNetwork = true}) : super(const ApiLabState()) {
    demo = ApiComparisonCoordinator(
      useLiveNetwork: useLiveNetwork,
      enableColors: false,
      onTerminalOutput: (line) => debugPrint(line),
    );
    inspector = OmniInspector(enabled: true)..attachClient(demo.modifiedClient);
    _inspectorSub = demo.modifiedClient.logStream.listen(inspector.log);
  }

  late final ApiComparisonCoordinator demo;
  late final OmniInspector inspector;
  late final StreamSubscription<Object?> _inspectorSub;

  void selectUserId(int id) {
    if (isClosed) return;
    emit(state.copyWith(userId: id));
  }

  /// Normal / Classic API call (`normalClient` -> JSONPlaceholder).
  Future<void> runNormalApi() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      await demo.callNormalApi(id: state.userId);
      if (isClosed) return;
      emit(state.copyWith(busy: false, normalResponse: demo.lastNormalOutput));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, normalResponse: 'Error: $e'));
    }
  }

  /// Modified API call (`modifiedClient`, `Endpoint`, global `decoders`,
  /// `Result`, and colored/configurable terminal logger).
  Future<void> runModifiedApi() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      await demo.callModifiedApi(id: state.userId);
      final terminalBox = demo.modifiedClient.enableLogging
          ? demo.lastModifiedTerminalBlock
          : '(enableLogging is false — request stayed silent)';
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          modifiedResponse: demo.lastModifiedOutput,
          modifiedTerminalBox: terminalBox,
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, modifiedResponse: 'Error: $e'));
    }
  }

  /// Real `POST https://jsonplaceholder.typicode.com/posts` (HTTP 201).
  Future<void> runCreatePost() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      final created = await demo.callCreatePostDemo();
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          modifiedResponse: '[POST 201 CREATED]\n$created',
          modifiedTerminalBox: demo.modifiedClient.enableLogging
              ? demo.lastModifiedTerminalBlock
              : '(enableLogging is false — silent)',
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, modifiedResponse: 'Error: $e'));
    }
  }

  /// Fetches `/posts` (100 real items -> ~600+ lines pretty JSON) to verify
  /// full unclipped terminal printing.
  Future<void> runLargePayloadApi() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      final posts = await demo.callLargePayloadApi();
      final lines = demo.lastModifiedTerminalBlock.split('\n').length;
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          modifiedResponse:
              '[FULL PUBLIC PAYLOAD TEST]\n'
              'totalPosts=${posts.length} | Printed $lines lines in log (no truncation)',
          modifiedTerminalBox: demo.modifiedClient.enableLogging
              ? demo.lastModifiedTerminalBlock
              : '(enableLogging is false — silent)',
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, modifiedResponse: 'Error: $e'));
    }
  }

  /// Queries 3 distinct free public websites concurrently via `OmniApiHub`.
  Future<void> runMultiWebsiteHub() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      final summary = await demo.callMultiWebsitePublicApis(
        productId: state.userId,
        pokemon: 'pikachu',
      );
      if (isClosed) return;
      emit(state.copyWith(busy: false, hubOutput: summary));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, hubOutput: 'Hub error: $e'));
    }
  }

  /// Connects WebSocket (`wss://ws.postman-echo.com/raw`), sends `hello_live`
  /// and performs correlated RPC `echo_rpc`.
  Future<void> runWebSocketRpc() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    try {
      final total = await demo.callWebSocketDemo(a: 18, b: 24);
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          wsOutput: '${demo.lastWsOutput} (verified=$total)',
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, wsOutput: 'WS error: $e'));
    }
  }

  Future<void> runCompareBoth() async {
    await runNormalApi();
    await runModifiedApi();
    await runMultiWebsiteHub();
  }

  Future<void> switchEnvironment(String env) async {
    await demo.hub.useEnvironment(env);
    if (isClosed) return;
    emit(
      state.copyWith(
        activeEnv: env,
        hubOutput:
            'Switched OmniApiHub env -> "$env" (jsonplaceholder=${demo.hub.currentEnvironment?.variables['jsonplaceholder']})',
      ),
    );
  }

  void setEnableLogging(bool value) {
    demo.modifiedClient.enableLogging = value;
    emit(state.copyWith(enableLogging: value));
  }

  void setLogResponse(bool value) {
    demo.modifiedClient.logResponse = value;
    emit(state.copyWith(logResponse: value));
  }

  void setLogColors(bool value) {
    demo.modifiedClient.logColors = value;
    emit(state.copyWith(logColors: value));
  }

  @override
  Future<void> close() async {
    await _inspectorSub.cancel();
    await demo.dispose();
    return super.close();
  }
}

/// Classic pre-registered Bloc kept solely to demonstrate traditional
/// `OmniPage('/classic-student/:id', ..., name: 'classic_student')`.
class ClassicStudentBloc extends Cubit<String?> {
  ClassicStudentBloc() : super(null);

  void load(int id) {
    emit('ClassicStudent(id: $id, name: "Classic #$id", dept: "CSE")');
  }
}

/// Nested `OmniShell` chrome wrapping `/api`, `/api/ai-chat`, and `/api/chat`.
class ApiLabShellFrame extends StatelessWidget {
  const ApiLabShellFrame({
    super.key,
    required this.state,
    required this.child,
  });

  final OmniRouteState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labState = context.watch<ApiLabCubit>().state;
    final activePath = state.uri.path;

    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'OmniShell: $activePath',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Chip(label: Text('env: ${labState.activeEnv}')),
                ActionChip(
                  label: const Text('API Compare'),
                  onPressed: activePath == '/api'
                      ? null
                      : () => context.to<ApiCompareScreen>(),
                ),
                ActionChip(
                  label: const Text('AI Chat'),
                  onPressed: activePath == '/api/ai-chat'
                      ? null
                      : () => context.to<AiAssistantScreen>(),
                ),
                ActionChip(
                  label: const Text('WS Chat'),
                  onPressed: activePath == '/api/chat'
                      ? null
                      : () => context.to<RealtimeChatScreen>(),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Demonstrates [OmniStatefulWidget] + [OmniState] (`onReady`, `onRouteChanged`,
/// `readBloc`, `watchBloc`, `safeSetState`), real multi-website public APIs,
/// Normal vs Modified comparison, runtime logger toggles, WebSocket RPC,
/// and all routing helpers.
class ApiCompareScreen extends OmniStatefulWidget {
  const ApiCompareScreen({super.key});

  @override
  String get routePath => '/api';

  @override
  String get title => 'Public APIs, WS & AI Lab';

  @override
  State<ApiCompareScreen> createState() => _ApiCompareState();
}

class _ApiCompareState extends OmniState<ApiCompareScreen> {
  String _routeChangeNote = 'Initial mount';

  @override
  void onReady(BuildContext context) {
    final queryId = maybeParams?.queryInt('id');
    if (queryId != null) {
      readBloc<ApiLabCubit>().selectUserId(queryId);
    }
    unawaited(readBloc<ApiLabCubit>().runCompareBoth());
  }

  @override
  void onRouteChanged(OmniRouteState previous, OmniRouteState current) {
    final queryId = current.params.queryInt('id');
    safeSetState(() {
      _routeChangeNote = 'Route updated ${previous.uri} -> ${current.uri}';
    });
    if (queryId != null) {
      readBloc<ApiLabCubit>().selectUserId(queryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cubit = readBloc<ApiLabCubit>();
    final lab = watchBloc<ApiLabCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text('$screenTitle ($routePath)'),
        actions: [
          IconButton(
            tooltip: 'BottomSheet Diagnostics',
            icon: const Icon(Icons.layers_outlined),
            onPressed: () => push('/api-sheet'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_routeChangeNote, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),

          // Public User / Product ID + Run All controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Public ID:'),
              for (final id in [1, 2, 3, 4])
                ChoiceChip(
                  label: Text('$id'),
                  selected: lab.userId == id,
                  onSelected: (_) => go('/api?id=$id'),
                ),
              FilledButton.icon(
                onPressed: lab.busy ? null : cubit.runCompareBoth,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Run Normal + Modified + Hub'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. Normal / Classic API Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '1. Normal / Classic API (jsonplaceholder.typicode.com)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runNormalApi,
                        child: const Text('Call Normal API'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    lab.normalResponse,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Modified API Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2. Modified API (Endpoint + Global Decoder + Pretty Logger + POST)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton(
                        onPressed: lab.busy ? null : cubit.runModifiedApi,
                        child: const Text('Call Modified API'),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runCreatePost,
                        child: const Text('POST /posts (201)'),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runLargePayloadApi,
                        child: const Text('Print 100 Posts JSON'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: [
                      FilterChip(
                        label: const Text('enableLogging'),
                        selected: lab.enableLogging,
                        onSelected: cubit.setEnableLogging,
                      ),
                      FilterChip(
                        label: const Text('logResponse'),
                        selected: lab.logResponse,
                        onSelected: cubit.setLogResponse,
                      ),
                      FilterChip(
                        label: const Text('logColors'),
                        selected: lab.logColors,
                        onSelected: cubit.setLogColors,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    lab.modifiedResponse,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  if (lab.modifiedTerminalBox.isNotEmpty) ...[
                    const Divider(),
                    Text(
                      'Formatted Terminal Log Preview (Captured ${lab.totalCapturedLogs} calls):',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SelectableText(
                          lab.modifiedTerminalBox,
                          maxLines: 14,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 3. OmniApiHub Multi-Website Public APIs Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. OmniApiHub Multi-Website Public APIs',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: lab.busy ? null : cubit.runMultiWebsiteHub,
                        child: const Text('Call 3 Public Websites'),
                      ),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'live', label: Text('live')),
                          ButtonSegment(value: 'sandbox', label: Text('sandbox')),
                        ],
                        selected: {lab.activeEnv},
                        onSelectionChanged: (s) =>
                            cubit.switchEnvironment(s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    lab.hubOutput,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 4. WebSocket Live Echo + RPC Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '4. Public WebSocket (wss://ws.postman-echo.com/raw)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runWebSocketRpc,
                        child: const Text('Run Live WS Echo + RPC'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SelectableText(lab.wsOutput),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 5. Routing Systems Showcase Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '5. Routing Systems Showcase',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => pushTo<AiAssistantScreen, void>(),
                        child: const Text('AI Chat (/api/ai-chat)'),
                      ),
                      FilledButton.tonal(
                        onPressed: () => pushTo<RealtimeChatScreen, void>(),
                        child: const Text('Realtime Chat (/api/chat)'),
                      ),
                      OutlinedButton(
                        onPressed: () => push('/api-sheet'),
                        child: const Text('BottomSheet Route (/api-sheet)'),
                      ),
                      OutlinedButton(
                        onPressed: () => OmniRoute.pushNamed(
                          'classic_student',
                          path: {'id': lab.userId},
                        ),
                        child: const Text('Classic Named Route'),
                      ),
                      TextButton(
                        onPressed: () => go('/dashboard', animated: false),
                        child: const Text('Instant Jump (animated: false)'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-Model AI assistant route (`/api/ai-chat`) inside [OmniShell].
class AiAssistantScreen extends OmniStatelessWidget {
  const AiAssistantScreen({super.key});

  @override
  String get routePath => '/api/ai-chat';

  @override
  String get title => 'AI Assistant';

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ApiLabCubit>();
    return Scaffold(
      appBar: AppBar(title: Text('$title ($routePath)')),
      body: OmniAiChatView(
        thread: cubit.demo.aiThread,
        hintText: 'Ask OpenAI or Gemini via OmniAi router…',
      ),
    );
  }
}

/// Realtime WebSocket chat route (`/api/chat`) inside [OmniShell].
class RealtimeChatScreen extends OmniStatelessWidget {
  const RealtimeChatScreen({super.key});

  @override
  String get routePath => '/api/chat';

  @override
  String get title => 'Realtime WS Chat';

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ApiLabCubit>();
    return Scaffold(
      appBar: AppBar(title: Text('$title ($routePath)')),
      body: OmniChatView(
        room: cubit.demo.chatRoom,
        hintText: 'Message room (tip: mention @ai)…',
      ),
    );
  }
}

/// Modal bottom sheet route rendered with `OmniPages.bottomSheet`.
class ApiSheetScreen extends OmniStatelessWidget {
  const ApiSheetScreen({super.key});

  @override
  String get routePath => '/api-sheet';

  @override
  String get title => 'Router & API Diagnostics';

  @override
  Widget build(BuildContext context) {
    final lab = context.watch<ApiLabCubit>().state;
    final stackPaths = OmniRoute.stack
        .map((e) => e.routePath ?? e.location)
        .join(' -> ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title ($routePath)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Current routePath: ${OmniRoute.routePath}'),
            const SizedBox(height: 4),
            Text('Active stack: $stackPaths'),
            const SizedBox(height: 4),
            Text('Captured HTTP logs: ${lab.totalCapturedLogs}'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Classic plain `StatelessWidget` page wired via traditional `OmniPage('/path',
/// ..., name: 'classic_student')` + pre-registered global/app Bloc.
class ClassicStudentDetailScreen extends StatelessWidget {
  const ClassicStudentDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<ClassicStudentBloc>()..load(id);
    return BlocBuilder<ClassicStudentBloc, String?>(
      bloc: bloc,
      builder: (context, student) => Scaffold(
        appBar: AppBar(title: Text('Classic Route #$id')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Classic Style: OmniPage("/classic-student/:id", ..., name: "classic_student") + '
                'pre-registered OmniBloc<ClassicStudentBloc> + OmniRoute.pushNamed',
              ),
              const SizedBox(height: 12),
              Text('Loaded: $student'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Pop Classic Route'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
