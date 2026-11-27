import 'dart:io';

import 'package:omni_network/omni_network.dart';
import 'package:omni_route_example/demo_backend.dart';

Future<void> main() async {
  stdout.writeln(
    '======================================================================',
  );
  stdout.writeln(
    '  OmniRoute + OmniNetwork REAL PUBLIC APIs: Normal vs Modified Demo',
  );
  stdout.writeln(
    '======================================================================\n',
  );

  // useLiveNetwork: true -> Real HTTPS & WebSocket calls to public websites!
  final demo = ApiComparisonCoordinator(
    useLiveNetwork: true,
    enableColors: true,
    onTerminalOutput: (line) => stdout.writeln(line),
  );

  try {
    stdout.writeln(
      '--- [1] NORMAL API CALL -> https://jsonplaceholder.typicode.com/users/1 ---',
    );
    await demo.callNormalApi(id: 1);
    stdout.writeln();

    stdout.writeln(
      '--- [2] MODIFIED API GET -> https://jsonplaceholder.typicode.com/users/2 ---',
    );
    await demo.callModifiedApi(id: 2);
    stdout.writeln(demo.lastModifiedOutput);
    stdout.writeln();

    stdout.writeln(
      '--- [3] MODIFIED API POST (HTTP 201) -> jsonplaceholder.typicode.com/posts ---',
    );
    final created = await demo.callCreatePostDemo();
    stdout.writeln('Created on public server: $created');
    stdout.writeln();

    stdout.writeln(
      '--- [4] FULL PUBLIC JSON LIST (/posts -> 100 items, NO truncation) ---',
    );
    final posts = await demo.callLargePayloadApi();
    final prettyLines = demo.lastModifiedTerminalBlock.split('\n').length;
    stdout.writeln(
      'Printed full /posts response lines count: $prettyLines lines (posts=${posts.length})',
    );
    stdout.writeln();

    stdout.writeln(
      '--- [5] RUNTIME TOGGLES (logResponse=false / enableLogging=false) & 404 WARN ---',
    );
    await demo.modifiedClient.get<Map<String, dynamic>>('/users/999').asResult();
    demo.modifiedClient.logResponse = false;
    await demo.callModifiedApi(id: 3);
    demo.modifiedClient.enableLogging = false;
    await demo.callModifiedApi(id: 4);
    stdout.writeln(
      'Silent call finished cleanly -> ${demo.lastModifiedOutput.split('\n').first}',
    );
    stdout.writeln();

    stdout.writeln(
      '--- [6] OmniApiHub REAL PUBLIC APIs (DummyJSON + Open-Meteo + PokeAPI) ---',
    );
    final multiSummary = await demo.callMultiWebsitePublicApis(
      productId: 1,
      pokemon: 'pikachu',
    );
    stdout.writeln(multiSummary);
    await demo.hub.useEnvironment('sandbox');
    final product2 = await demo.hub.callEndpoint(
      PublicApiEndpoints.productById,
      serviceName: 'dummyjson',
      path: {'id': 2},
    );
    stdout.writeln('Switched hub env -> ${demo.hub.activeEnvironmentName}: $product2');
    stdout.writeln();

    stdout.writeln(
      '--- [7] REAL PUBLIC WEBSOCKET -> wss://ws.postman-echo.com/raw ---',
    );
    final wsTotal = await demo.callWebSocketDemo(a: 18, b: 24);
    stdout.writeln('${demo.lastWsOutput} (verified=$wsTotal)');
    stdout.writeln();

    stdout.writeln(
      '--- [8] Multi-Model AI (OpenAI/Gemini router + Streaming) ---',
    );
    await demo.callAiStreamingDemo(
      'Summarize JSONPlaceholder, DummyJSON, Open-Meteo & PokeAPI',
    );
    stdout.writeln(demo.lastAiOutput);
  } finally {
    await demo.dispose();
  }
}
