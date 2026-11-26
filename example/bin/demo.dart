import 'dart:io';

import 'package:omni_route_example/demo_backend.dart';

Future<void> main() async {
  stdout.writeln(
    '======================================================================',
  );
  stdout.writeln(
    '  OmniRoute + OmniNetwork Live Demo: Normal API vs Modified API',
  );
  stdout.writeln(
    '======================================================================\n',
  );

  final demo = ApiComparisonCoordinator(
    enableColors: true,
    onTerminalOutput: (line) => stdout.writeln(line),
  );

  stdout.writeln('--- [1] NORMAL / CLASSIC API CALL (No Auto Color Log) ---');
  await demo.callNormalApi(id: 101);
  stdout.writeln();

  stdout.writeln(
    '--- [2] MODIFIED API CALL (enableLogging: true, logResponse: true, ANSI Colors) ---',
  );
  await demo.callModifiedApi(id: 103);
  stdout.writeln(demo.lastModifiedOutput);
  stdout.writeln();

  stdout.writeln(
    '--- [3] MODIFIED API: Full 500-Line JSON Response Print Test ---',
  );
  final report = await demo.callLargePayloadApi();
  final prettyLines = demo.lastModifiedTerminalBlock.split('\n').length;
  stdout.writeln(
    'Printed full /long-report lines count: $prettyLines lines (totalRows=${report['totalRows']})',
  );
  stdout.writeln();

  stdout.writeln(
    '--- [4] RUNTIME TOGGLE: logResponse = false (Hide Body, Keep Status) ---',
  );
  demo.modifiedClient.logResponse = false;
  await demo.callModifiedApi(id: 102);
  stdout.writeln(demo.lastModifiedOutput);
  stdout.writeln();

  stdout.writeln('--- [5] RUNTIME TOGGLE: enableLogging = false (Silent) ---');
  demo.modifiedClient.enableLogging = false;
  await demo.callModifiedApi(id: 104);
  stdout.writeln(
    'Silent call finished cleanly -> ${demo.lastModifiedOutput.split('\n').first}',
  );
  stdout.writeln();

  stdout.writeln(
    '--- [6] OmniApiHub Multi-Env (dev -> prod) + Typed Endpoint ---',
  );
  final devRes = await demo.hub.primary.get<Map<String, dynamic>>(
    '/students/101',
  );
  await demo.hub.useEnvironment('prod');
  final prodRes = await demo.hub.callEndpoint(
    StudentApiEndpoints.byId,
    serviceName: 'core',
    path: {'id': 102},
  );
  stdout.writeln('dev response: $devRes');
  stdout.writeln(
    'prod response (${demo.hub.activeEnvironmentName}, baseUrl=${demo.hub.currentEnvironment?.variables['core']}): $prodRes',
  );
  stdout.writeln();

  stdout.writeln('--- [7] WebSocket Event + Correlated RPC Demo ---');
  final wsTotal = await demo.callWebSocketDemo(a: 18, b: 24);
  stdout.writeln('${demo.lastWsOutput} (verified total=$wsTotal)');
  stdout.writeln();

  stdout.writeln(
    '--- [8] Multi-Model AI (OpenAI/Gemini router + Streaming) ---',
  );
  await demo.callAiStreamingDemo(
    'Explain OmniPage.screen and page-entry Bloc registration',
  );
  stdout.writeln(demo.lastAiOutput);

  await demo.dispose();
}
