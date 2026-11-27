import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:omni_route/omni_route.dart';

import 'demo_backend.dart';

/// Color mode exposed in the UI (`auto` respects platform ANSI detection,
/// `on` forces ANSI colors in terminal logs, `off` prints plain text + emojis).
enum LogColorMode { auto, on, off }

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
    this.colorMode = LogColorMode.auto,
    this.activeEnv = 'live',
    this.normalResponse =
        'Tap "Call Normal API" -> https://jsonplaceholder.typicode.com/users/1',
    this.normalJson = '',
    this.normalStatus,
    this.modifiedResponse =
        'Tap "Call Modified API" -> https://jsonplaceholder.typicode.com/users/1',
    this.modifiedJson = '',
    this.modifiedStatus,
    this.modifiedTerminalBox = '',
    this.hubOutput =
        'Tap "Call 3 Public Websites" -> DummyJSON + Open-Meteo + PokeAPI',
    this.multiApiJson = '',
    this.wsOutput =
        'Tap "Run Live WS Echo + RPC" -> wss://ws.postman-echo.com/raw',
    this.totalCapturedLogs = 0,
  });

  final int userId;
  final bool busy;
  final bool enableLogging;
  final bool logResponse;
  final LogColorMode colorMode;
  final String activeEnv;
  final String normalResponse;
  final String normalJson;
  final int? normalStatus;
  final String modifiedResponse;
  final String modifiedJson;
  final int? modifiedStatus;
  final String modifiedTerminalBox;
  final String hubOutput;
  final String multiApiJson;
  final String wsOutput;
  final int totalCapturedLogs;

  ApiLabState copyWith({
    int? userId,
    bool? busy,
    bool? enableLogging,
    bool? logResponse,
    LogColorMode? colorMode,
    String? activeEnv,
    String? normalResponse,
    String? normalJson,
    int? normalStatus,
    String? modifiedResponse,
    String? modifiedJson,
    int? modifiedStatus,
    String? modifiedTerminalBox,
    String? hubOutput,
    String? multiApiJson,
    String? wsOutput,
    int? totalCapturedLogs,
  }) => ApiLabState(
    userId: userId ?? this.userId,
    busy: busy ?? this.busy,
    enableLogging: enableLogging ?? this.enableLogging,
    logResponse: logResponse ?? this.logResponse,
    colorMode: colorMode ?? this.colorMode,
    activeEnv: activeEnv ?? this.activeEnv,
    normalResponse: normalResponse ?? this.normalResponse,
    normalJson: normalJson ?? this.normalJson,
    normalStatus: normalStatus ?? this.normalStatus,
    modifiedResponse: modifiedResponse ?? this.modifiedResponse,
    modifiedJson: modifiedJson ?? this.modifiedJson,
    modifiedStatus: modifiedStatus ?? this.modifiedStatus,
    modifiedTerminalBox: modifiedTerminalBox ?? this.modifiedTerminalBox,
    hubOutput: hubOutput ?? this.hubOutput,
    multiApiJson: multiApiJson ?? this.multiApiJson,
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
      // `null` = auto-detect terminal/Android ANSI color support while avoiding
      // iOS os_log `\^[` escape garbage; UI still renders full colors below.
      enableColors: null,
      onTerminalOutput: (line) => debugPrint(line),
    );
    inspector = OmniInspector(enabled: true)..attachClient(demo.modifiedClient);
    _inspectorSub = demo.networkLogs.listen(
      (entry) => inspector.sink(entry.label).log(entry.record),
    );
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
      emit(
        state.copyWith(
          busy: false,
          normalResponse: demo.lastNormalOutput,
          normalJson: demo.lastNormalJson,
          normalStatus: demo.lastNormalStatus ?? 200,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          normalStatus: 500,
          normalResponse: 'Error: $e',
        ),
      );
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
          modifiedJson: demo.lastModifiedJson,
          modifiedStatus: demo.lastModifiedStatus ?? 200,
          modifiedTerminalBox: terminalBox,
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          modifiedStatus: 500,
          modifiedResponse: 'Error: $e',
        ),
      );
    }
  }

  /// Triggers a real 404 Client Warning to preview Amber/Orange warning colors.
  Future<void> runWarningDemo() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    await demo.callWarningDemo();
    if (isClosed) return;
    emit(
      state.copyWith(
        busy: false,
        modifiedResponse: demo.lastModifiedOutput,
        modifiedJson: demo.lastModifiedJson,
        modifiedStatus: 404,
        modifiedTerminalBox: demo.modifiedClient.enableLogging
            ? demo.lastModifiedTerminalBlock
            : '(enableLogging is false — silent)',
        totalCapturedLogs: demo.modifiedOutputLog.length,
      ),
    );
  }

  /// Triggers a 500 Server Error to preview bright Red error colors.
  Future<void> runErrorDemo() async {
    if (isClosed) return;
    emit(state.copyWith(busy: true));
    await demo.callErrorDemo();
    if (isClosed) return;
    emit(
      state.copyWith(
        busy: false,
        modifiedResponse: demo.lastModifiedOutput,
        modifiedJson: demo.lastModifiedJson,
        modifiedStatus: 500,
        modifiedTerminalBox: demo.modifiedClient.enableLogging
            ? demo.lastModifiedTerminalBlock
            : '(enableLogging is false — silent)',
        totalCapturedLogs: demo.modifiedOutputLog.length,
      ),
    );
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
          modifiedJson: demo.lastModifiedJson,
          modifiedStatus: 201,
          modifiedTerminalBox: demo.modifiedClient.enableLogging
              ? demo.lastModifiedTerminalBlock
              : '(enableLogging is false — silent)',
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
    } catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          busy: false,
          modifiedStatus: 500,
          modifiedResponse: 'Error: $e',
        ),
      );
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
          modifiedJson: demo.lastModifiedJson,
          modifiedStatus: 200,
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
      emit(
        state.copyWith(
          busy: false,
          hubOutput: summary,
          multiApiJson: demo.lastMultiApiJson,
          modifiedTerminalBox: demo.modifiedClient.enableLogging
              ? demo.lastModifiedTerminalBlock
              : state.modifiedTerminalBox,
          totalCapturedLogs: demo.modifiedOutputLog.length,
        ),
      );
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
    await demo.switchHubEnvironment(env);
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

  void setColorMode(LogColorMode mode) {
    final mapped = switch (mode) {
      LogColorMode.auto => null,
      LogColorMode.on => true,
      LogColorMode.off => false,
    };
    demo.setLogColors(mapped);
    emit(state.copyWith(colorMode: mode));
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

  void _copy(BuildContext context, String text, String label) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          content: Text('Copied $label'),
        ),
      );
  }

  static String _stripAnsi(String input) =>
      input.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

  static Color _logKindColor(InspectorLogKind k, Brightness b) {
    final dark = b == Brightness.dark;
    return switch (k) {
      InspectorLogKind.httpResponse =>
        dark ? const Color(0xFF4ADE80) : Colors.green.shade700,
      InspectorLogKind.httpRequest =>
        dark ? const Color(0xFFE879F9) : Colors.purple.shade600,
      InspectorLogKind.httpWarning || InspectorLogKind.warning =>
        dark ? const Color(0xFFFB923C) : Colors.orange.shade800,
      InspectorLogKind.httpError || InspectorLogKind.error =>
        dark ? const Color(0xFFF87171) : Colors.red.shade700,
      InspectorLogKind.route =>
        dark ? const Color(0xFFC084FC) : Colors.deepPurple.shade600,
      InspectorLogKind.blocCreate =>
        dark ? const Color(0xFF86EFAC) : Colors.teal.shade700,
      InspectorLogKind.blocEvent || InspectorLogKind.blocTransition =>
        dark ? const Color(0xFF2DD4BF) : Colors.teal.shade800,
      InspectorLogKind.ws =>
        dark ? const Color(0xFF38BDF8) : Colors.lightBlue.shade700,
      InspectorLogKind.ai =>
        dark ? const Color(0xFF818CF8) : Colors.indigo.shade600,
      InspectorLogKind.info =>
        dark ? const Color(0xFF60A5FA) : Colors.blue.shade700,
    };
  }

  static String _fmtClock(DateTime dt) {
    final t = dt.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  void _openInspectorLogs(BuildContext context, ApiLabCubit cubit) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => OmniInspectorView(
          inspector: cubit.inspector,
          initialTab: InspectorTab.logs,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  static Color _statusAccent(int? status, Brightness b) {
    final dark = b == Brightness.dark;
    if (status == null) {
      return dark ? const Color(0xFF60A5FA) : Colors.blueGrey.shade700;
    }
    if (status >= 500) {
      return dark ? const Color(0xFFF87171) : Colors.red.shade700;
    }
    if (status >= 400) {
      return dark ? const Color(0xFFFB923C) : Colors.orange.shade800;
    }
    if (status >= 300) {
      return dark ? const Color(0xFF38BDF8) : Colors.blue.shade700;
    }
    return dark ? const Color(0xFF4ADE80) : Colors.green.shade700;
  }

  static Color _darkStatusAccent(int? status) {
    if (status == null) return const Color(0xFF38BDF8);
    if (status >= 500) return const Color(0xFFF87171);
    if (status >= 400) return const Color(0xFFFB923C);
    if (status >= 300) return const Color(0xFF38BDF8);
    return const Color(0xFF4ADE80);
  }

  Widget _coloredBannerText(String text, Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: accent.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: accent.withValues(alpha: 0.68)),
    ),
    child: SelectionArea(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = readBloc<ApiLabCubit>();
    final lab = watchBloc<ApiLabCubit>().state;
    final brightness = Theme.of(context).brightness;
    final normalAccent = _statusAccent(lab.normalStatus, brightness);
    final modifiedAccent = _statusAccent(lab.modifiedStatus, brightness);

    return Scaffold(
      appBar: AppBar(
        title: Text('$screenTitle ($routePath)'),
        actions: [
          IconButton(
            tooltip: 'Open All Logs & Copy Inspector',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _openInspectorLogs(context, cubit),
          ),
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
                      IconButton(
                        tooltip: 'Copy Normal API JSON',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () => _copy(
                          context,
                          lab.normalJson.isNotEmpty
                              ? lab.normalJson
                              : lab.normalResponse,
                          'Normal API response',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runNormalApi,
                        child: const Text('Call Normal API'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _coloredBannerText(lab.normalResponse, normalAccent),
                  if (lab.normalJson.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ColoredJsonBox(
                      jsonText: lab.normalJson,
                      accent: _darkStatusAccent(lab.normalStatus),
                    ),
                  ],
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
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade700,
                        ),
                        onPressed: lab.busy ? null : cubit.runWarningDemo,
                        child: const Text('404 Warning'),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                        ),
                        onPressed: lab.busy ? null : cubit.runErrorDemo,
                        child: const Text('500 Error'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _copy(
                          context,
                          lab.modifiedJson.isNotEmpty
                              ? lab.modifiedJson
                              : lab.modifiedResponse,
                          'Modified API JSON',
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Full JSON'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                      SegmentedButton<LogColorMode>(
                        segments: const [
                          ButtonSegment(
                            value: LogColorMode.auto,
                            label: Text('Colors: Auto'),
                          ),
                          ButtonSegment(
                            value: LogColorMode.on,
                            label: Text('On'),
                          ),
                          ButtonSegment(
                            value: LogColorMode.off,
                            label: Text('Off'),
                          ),
                        ],
                        selected: {lab.colorMode},
                        onSelectionChanged: (s) => cubit.setColorMode(s.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _coloredBannerText(lab.modifiedResponse, modifiedAccent),
                  if (lab.modifiedJson.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ColoredJsonBox(
                      jsonText: lab.modifiedJson,
                      accent: _darkStatusAccent(lab.modifiedStatus),
                    ),
                  ],
                  if (lab.modifiedTerminalBox.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Formatted Colored Terminal Preview (Captured ${lab.totalCapturedLogs} calls):',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _copy(
                            context,
                            _stripAnsi(lab.modifiedTerminalBox),
                            'Terminal Log',
                          ),
                          icon: const Icon(Icons.copy, size: 15),
                          label: const Text('Copy Log'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _ColoredAnsiTerminalBox(ansiText: lab.modifiedTerminalBox),
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
                      OutlinedButton.icon(
                        onPressed: () => _copy(
                          context,
                          lab.multiApiJson.isNotEmpty
                              ? lab.multiApiJson
                              : lab.hubOutput,
                          'Hub API JSON',
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Hub JSON'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _coloredBannerText(
                    lab.hubOutput,
                    lab.hubOutput.startsWith('Hub error')
                        ? _statusAccent(500, brightness)
                        : _statusAccent(200, brightness),
                  ),
                  if (lab.multiApiJson.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _ColoredJsonBox(
                      jsonText: lab.multiApiJson,
                      accent: const Color(0xFF38BDF8),
                    ),
                  ],
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
                      IconButton(
                        tooltip: 'Copy WebSocket Output',
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () =>
                            _copy(context, lab.wsOutput, 'WS output'),
                      ),
                      OutlinedButton(
                        onPressed: lab.busy ? null : cubit.runWebSocketRpc,
                        child: const Text('Run Live WS Echo + RPC'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _coloredBannerText(
                    lab.wsOutput,
                    lab.wsOutput.startsWith('WS error')
                        ? _statusAccent(500, brightness)
                        : _statusAccent(300, brightness),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 5. Separate API & App Logs (Talker-Style 1-Click Copy)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ListenableBuilder(
                listenable: cubit.inspector,
                builder: (context, _) {
                  final brightness = Theme.of(context).brightness;
                  final logs = cubit.inspector.logs;
                  final visible = logs.take(6).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '5. Separate Logs & 1-Click Copy (${logs.length})',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (logs.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _copy(
                                context,
                                logs.map((e) => e.copyText).join('\n\n${'=' * 48}\n\n'),
                                'All ${logs.length} logs',
                              ),
                              icon: const Icon(Icons.copy_all, size: 16),
                              label: const Text('Copy All'),
                            ),
                          FilledButton.tonalIcon(
                            onPressed: () => _openInspectorLogs(context, cubit),
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('All Logs'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        const Text(
                          'Run any API or navigate to see separate color-coded log cards.',
                        )
                      else
                        for (final entry in visible)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _logKindColor(
                                entry.kind,
                                brightness,
                              ).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _logKindColor(
                                  entry.kind,
                                  brightness,
                                ).withValues(alpha: 0.65),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${entry.tag} | ${_fmtClock(entry.timestamp)}'
                                        '${entry.duration != null ? ' ${entry.duration!.inMilliseconds}ms' : ''}',
                                        style: TextStyle(
                                          color: _logKindColor(
                                            entry.kind,
                                            brightness,
                                          ),
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 11.5,
                                        ),
                                      ),
                                      if (entry.subtitle.isNotEmpty)
                                        Text(
                                          entry.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                                if (entry.copyBody != null &&
                                    entry.copyBody!.isNotEmpty)
                                  TextButton(
                                    onPressed: () => _copy(
                                      context,
                                      entry.copyBody!,
                                      '${entry.tag} JSON',
                                    ),
                                    child: const Text('Copy JSON'),
                                  ),
                                IconButton(
                                  tooltip: 'Copy ${entry.tag} log',
                                  icon: Icon(
                                    Icons.copy,
                                    size: 18,
                                    color: _logKindColor(entry.kind, brightness),
                                  ),
                                  onPressed: () => _copy(
                                    context,
                                    entry.copyText,
                                    '${entry.tag} log',
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 6. Routing Systems Showcase Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '6. Routing Systems Showcase',
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

/// Renders ANSI-colored `PrettyLogSink` terminal blocks natively inside Flutter
/// with full per-token syntax highlighting (even on platforms like iOS whose
/// system console strips/escapes ANSI codes).
class _ColoredAnsiTerminalBox extends StatelessWidget {
  const _ColoredAnsiTerminalBox({required this.ansiText});

  final String ansiText;

  static final RegExp _ansiPattern = RegExp(r'\x1B\[([0-9;]*)m');

  static const Map<int, Color> _palette = {
    15: Color(0xFFFFFFFF), // bright white
    40: Color(0xFF4ADE80), // green (2xx)
    78: Color(0xFF86EFAC), // soft emerald
    43: Color(0xFF2DD4BF), // teal
    196: Color(0xFFF87171), // red (5xx / failure)
    214: Color(0xFFFB923C), // amber (4xx warning)
    208: Color(0xFFFB923C), // orange (warning)
    39: Color(0xFF38BDF8), // blue (3xx / GET)
    171: Color(0xFFE879F9), // magenta (http-request)
    81: Color(0xFF67E8F9), // cyan (JSON keys)
    186: Color(0xFFFDE68A), // yellow (JSON strings)
    141: Color(0xFFC4B5FD), // violet (numbers)
    205: Color(0xFFF472B6), // pink (true/false/null)
    250: Color(0xFFD1D5DB), // light grey (punctuation)
    252: Color(0xFFE5E7EB), // body text
    244: Color(0xFF9CA3AF), // dim labels
    45: Color(0xFF22D3EE), // notes & payload summary
  };

  List<TextSpan> _parseAnsi(String input) {
    final spans = <TextSpan>[];
    var currentColor = const Color(0xFFE2E8F0);
    Color? currentBg;
    var bold = false;
    var index = 0;

    for (final match in _ansiPattern.allMatches(input)) {
      if (match.start > index) {
        spans.add(
          TextSpan(
            text: input.substring(index, match.start),
            style: TextStyle(
              color: currentColor,
              backgroundColor: currentBg,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
      }
      final code = match.group(1) ?? '';
      if (code.isEmpty || code == '0') {
        currentColor = const Color(0xFFE2E8F0);
        currentBg = null;
        bold = false;
      } else {
        final parts = code.split(';');
        for (var i = 0; i < parts.length; i++) {
          final p = parts[i];
          if (p == '1') {
            bold = true;
          } else if (p == '38' &&
              i + 2 < parts.length &&
              parts[i + 1] == '5') {
            final colorNum = int.tryParse(parts[i + 2]);
            if (colorNum != null && _palette.containsKey(colorNum)) {
              currentColor = _palette[colorNum]!;
            }
            i += 2;
          } else if (p == '48' &&
              i + 2 < parts.length &&
              parts[i + 1] == '5') {
            final bgNum = int.tryParse(parts[i + 2]);
            if (bgNum == 196) {
              currentBg = const Color(0xFFDC2626);
            } else if (bgNum == 214 || bgNum == 208) {
              currentBg = const Color(0xFFD97706);
            }
            i += 2;
          }
        }
      }
      index = match.end;
    }

    if (index < input.length) {
      spans.add(
        TextSpan(
          text: input.substring(index),
          style: TextStyle(
            color: currentColor,
            backgroundColor: currentBg,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      );
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectionArea(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.35,
              ),
              children: _parseAnsi(ansiText),
            ),
            maxLines: 20,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// Renders syntax-highlighted JSON inside dark rounded boxes matching the
/// outcome status accent (`green` success, `orange` warning, `red` error).
class _ColoredJsonBox extends StatelessWidget {
  const _ColoredJsonBox({required this.jsonText, required this.accent});

  final String jsonText;
  final Color accent;

  List<TextSpan> _highlight(String input) {
    final spans = <TextSpan>[];
    final lines = input.split('\n');
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      var i = 0;
      while (i < line.length) {
        final c = line[i];
        if (c == '"') {
          var j = i + 1;
          var escaped = false;
          while (j < line.length) {
            final d = line[j];
            j++;
            if (escaped) {
              escaped = false;
            } else if (d == r'\') {
              escaped = true;
            } else if (d == '"') {
              break;
            }
          }
          var k = j;
          while (k < line.length && line[k] == ' ') {
            k++;
          }
          final isKey = k < line.length && line[k] == ':';
          spans.add(
            TextSpan(
              text: line.substring(i, j),
              style: TextStyle(
                color: isKey
                    ? const Color(0xFF67E8F9)
                    : const Color(0xFFFDE68A),
                fontWeight: isKey ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
          i = j;
        } else if ('{}[],:'.contains(c)) {
          spans.add(
            TextSpan(
              text: c,
              style: const TextStyle(color: Color(0xFFCBD5E1)),
            ),
          );
          i++;
        } else if (c == '-' ||
            (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39)) {
          var j = i + 1;
          while (j < line.length && '0123456789eE+-.'.contains(line[j])) {
            j++;
          }
          spans.add(
            TextSpan(
              text: line.substring(i, j),
              style: const TextStyle(color: Color(0xFFC4B5FD)),
            ),
          );
          i = j;
        } else if (line.startsWith('true', i) ||
            line.startsWith('null', i) ||
            line.startsWith('false', i)) {
          final n = line.startsWith('false', i) ? 5 : 4;
          spans.add(
            TextSpan(
              text: line.substring(i, i + n),
              style: const TextStyle(
                color: Color(0xFFF472B6),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
          i += n;
        } else {
          spans.add(TextSpan(text: c, style: TextStyle(color: accent)));
          i++;
        }
      }
      if (li + 1 < lines.length) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.72), width: 1.15),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectionArea(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.35,
                color: Color(0xFFE2E8F0),
              ),
              children: _highlight(jsonText),
            ),
            maxLines: 14,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
