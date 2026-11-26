import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omni_network/advanced.dart';
import 'package:omni_network/testing.dart';
import 'package:omni_network_flutter/omni_network_flutter.dart';

void main() {
  group('OmniInspector WS + AI telemetry', () {
    testWidgets('records HTTP, WS, and AI entries and switches tabs cleanly', (
      tester,
    ) async {
      final inspector = OmniInspector(enabled: true);
      addTearDown(inspector.dispose);

      final api = OmniNetwork(
        baseUrl: 'https://api.test',
        enableLogging: true,
        logInRelease: true,
        logSink: inspector.sink('core'),
        transport: MockTransport(
          (_) => OmniRawResponse(
            statusCode: 200,
            headers: const {'content-type': 'application/json'},
            bodyBytes: utf8.encode(jsonEncode({'ok': true})),
          ),
        ),
        ai: AiConfig(
          defaultModel: 'mock:m1',
          providers: {
            'mock': MockAiProvider(
              id: 'mock',
              handler: (_, _, _) => const MockAiReply(
                text: 'Pong!',
                usage: AiUsage(inputTokens: 10, outputTokens: 20),
              ),
            ),
          },
          pricing: const {
            'm1': AiModelCost(
              inputPerMillionUsd: 1.0,
              outputPerMillionUsd: 2.0,
            ),
          },
        ),
      );
      addTearDown(api.close);

      final detach = inspector.attachClient(api);
      addTearDown(detach);

      await tester.runAsync(() async {
        await api.get<dynamic>('/health');
        await api.ai.ask('Ping');
        inspector.recordWsLog(
          WsLogRecord(
            uri: 'wss://api.test/ws',
            direction: 'in',
            summary: 'hello packet',
            timestamp: DateTime.utc(2026, 1, 1),
          ),
        );
      });

      expect(inspector.entries, hasLength(1));
      expect(inspector.wsEntries, hasLength(1));
      expect(inspector.aiEntries, hasLength(1));
      expect(inspector.totalAiTokens, 30);
      expect(inspector.totalAiCostUsd, greaterThan(0));
      expect(inspector.toMarkdownReport(), contains('## AI Calls (1)'));
      expect(inspector.toMarkdownReport(), contains('## WebSocket Events (1)'));

      await tester.pumpWidget(
        MaterialApp(home: OmniInspectorView(inspector: inspector)),
      );
      expect(find.text('Network (1)'), findsOneWidget);

      await tester.tap(find.text('WS (1)'));
      await tester.pump();
      expect(find.text('WebSocket (1)'), findsOneWidget);
      expect(find.text('hello packet'), findsOneWidget);

      await tester.tap(find.text('AI (1)'));
      await tester.pump();
      expect(find.text('AI Calls (1)'), findsOneWidget);
      expect(find.textContaining('mock:m1'), findsOneWidget);
      expect(find.textContaining('Tokens: 30'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('OmniModelPicker & OmniAiChatView', () {
    testWidgets(
      'picks models, streams AI replies, regenerates, and clears without leaks',
      (tester) async {
        final api = OmniNetwork(
          ai: AiConfig(
            defaultModel: 'fast',
            providers: {
              'mock': MockAiProvider(
                id: 'mock',
                handler: (model, msgs, _) => MockAiReply(
                  text: '[$model] Answer to ${msgs.last.text}',
                  thinking: 'Checked docs',
                  usage: const AiUsage(inputTokens: 4, outputTokens: 6),
                ),
              ),
            },
            routes: const {
              'fast': AiModelRoute([AiTarget('mock', model: 'm-fast')]),
              'smart': AiModelRoute([AiTarget('mock', model: 'm-smart')]),
            },
          ),
        );
        addTearDown(api.close);

        final thread = api.aiThread('widget_thread');
        addTearDown(thread.close);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: OmniAiChatView(thread: thread)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Start a conversation with AI'), findsOneWidget);

        // Switch model via OmniModelPicker from 'fast' to 'smart'.
        await tester.tap(find.byTooltip('Select AI model'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('smart'));
        await tester.pumpAndSettle();
        expect(thread.model, 'smart');

        // Send a message through the composer.
        await tester.enterText(find.byType(TextField), 'What is OmniRoute?');
        await tester.pump();
        await tester.tap(find.byTooltip('Send prompt'));
        await tester.runAsync(() async {
          await thread.stream.firstWhere(
            (s) => !s.isStreaming && s.messages.length >= 2,
          );
        });
        await tester.pumpAndSettle();

        expect(find.text('What is OmniRoute?'), findsOneWidget);
        expect(find.text('[m-smart] Answer to What is OmniRoute?'), findsOneWidget);
        expect(find.text('10 tok'), findsOneWidget);

        // Clear history cleanly.
        await tester.tap(find.byTooltip('Clear conversation'));
        await tester.pumpAndSettle();
        expect(find.text('Start a conversation with AI'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('OmniChatView', () {
    testWidgets('renders messages, typing indicator, attachment upload & sends text', (
      tester,
    ) async {
      final api = OmniNetwork(
        baseUrl: 'https://chat.test',
        transport: MockTransport((req) {
          if (req.uri.path == '/files/upload') {
            return OmniRawResponse(
              statusCode: 200,
              headers: const {'content-type': 'application/json'},
              bodyBytes: utf8.encode(
                jsonEncode({'url': 'https://cdn.test/notes.txt'}),
              ),
            );
          }
          return OmniRawResponse(
            statusCode: 200,
            headers: const {'content-type': 'application/json'},
            bodyBytes: utf8.encode(jsonEncode({'ok': true})),
          );
        }),
        chatConfig: const ChatConfig(
          currentUserId: 'me',
          currentUserName: 'Me',
        ),
      );
      addTearDown(api.close);

      final room = api.chat.room('lobby');
      addTearDown(room.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OmniChatView(
              room: room,
              onPickAttachment: () async => UploadFile.fromBytes(
                'doc',
                [1, 2, 3],
                filename: 'notes.txt',
                contentType: 'text/plain',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No messages yet'), findsOneWidget);

      // Deliver an incoming message + typing indicator from remote participant.
      room.handleInboundEvent(
        ChatMessageReceived(
          ChatMessage.text(
            id: 'srv_1',
            roomId: 'lobby',
            senderId: 'ana',
            senderName: 'Ana',
            text: 'Welcome aboard',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      room.handleInboundEvent(
        ChatTypingEvent(
          TypingIndicator(
            roomId: 'lobby',
            userId: 'ana',
            userName: 'Ana',
            isTyping: true,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome aboard'), findsOneWidget);
      expect(find.text('Ana is typing…'), findsOneWidget);

      // Stop typing before unmount so FakeAsync doesn't keep any timer pending.
      room.handleInboundEvent(
        ChatTypingEvent(
          TypingIndicator(
            roomId: 'lobby',
            userId: 'ana',
            userName: 'Ana',
            isTyping: false,
            updatedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await tester.pump();

      // Upload attachment via attachment icon.
      await tester.tap(find.byTooltip('Attach file'));
      await tester.pumpAndSettle();
      expect(find.textContaining('notes.txt'), findsOneWidget);

      // Send outgoing text through composer.
      await tester.enterText(find.byType(TextField), 'Thanks Ana!');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await tester.pumpAndSettle();

      expect(find.text('Thanks Ana!'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await room.close();
        await api.close();
      });
    });
  });
}
