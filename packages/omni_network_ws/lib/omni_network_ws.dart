/// Server-Sent Events and WebSocket adapters for OmniNetwork.
///
/// Maintained for backward compatibility; all types now live natively inside
/// `package:omni_network/omni_network.dart` and
/// `package:omni_network/advanced.dart`.
library;

export 'package:omni_network/omni_network.dart'
    show
        SseConnection,
        SseEvent,
        SseState,
        OmniWebSocket,
        WebSocketState,
        WsWebAuthMode;
export 'package:omni_network/advanced.dart'
    show
        SseParser,
        parseSseByteStream,
        WebSocketConnector,
        WsProtocol,
        DefaultWsProtocol,
        WsInboundPacket;
