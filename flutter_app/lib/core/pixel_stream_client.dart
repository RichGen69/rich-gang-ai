import 'dart:async';

/// PIXEL-STREAM CLIENT CONTRACT (2026-10-25, Richard's direction:
/// an Unreal Engine 5 triple-A Room streamed to the phone over
/// WebRTC from edge GPU nodes).
///
/// WHAT THIS FILE IS: the client-side contract the app will speak
/// to a pixel stream with — states, configuration, and the one
/// implementation that exists today.
///
/// WHAT EXISTS TODAY, honestly: [UnavailablePixelStreamClient]
/// only. There is no UE5 render node, no signalling server, no
/// GPU host, and no stream URL in this environment, so the client
/// reports UNAVAILABLE with the reason attached — the same
/// explicit-error pattern as edge_inference, which returns errors
/// instead of pretending a local runtime exists. A real WebRTC
/// pixel-stream implementation (flutter_webrtc + the Pixel
/// Streaming signalling protocol) is a later slice, built against
/// a real stream, not against this file's promises.
///
/// NOTHING HERE RENDERS: no frame, no video view, no fake
/// "streaming" state is ever emitted. The Room screen keeps
/// showing its existing Flutter/glTF stage until a real stream
/// connects, and the state machine below is what will tell it
/// when that happens.
enum PixelStreamState {
  /// Never attempted.
  idle,

  /// A connect is in flight.
  connecting,

  /// Frames are arriving from a real render node.
  streaming,

  /// No stream can exist right now (no node, no URL, no host).
  unavailable,

  /// A real stream failed after connecting.
  error,
}

class PixelStreamStatus {
  const PixelStreamStatus(this.state, [this.reason = '']);

  final PixelStreamState state;

  /// Human-readable reason, always present for [PixelStreamState]
  /// unavailable/error, always empty otherwise. Reasons name the
  /// missing piece, never a vague failure.
  final String reason;
}

class PixelStreamConfig {
  const PixelStreamConfig({
    required this.signallingUrl,
    required this.streamId,
  });

  /// The Pixel Streaming signalling server URL (ws/wss). Empty
  /// means unconfigured — never defaulted to a guessed host.
  final String signallingUrl;

  /// The stream id on that signalling server.
  final String streamId;

  bool get isConfigured =>
      signallingUrl.isNotEmpty && streamId.isNotEmpty;
}

abstract class PixelStreamClient {
  PixelStreamStatus get status;

  Stream<PixelStreamStatus> get statusChanges;

  /// Connects to a configured stream. If [config] is not
  /// configured, the client moves to unavailable with the reason
  /// and returns false — it never pretends to connect.
  Future<bool> connect(PixelStreamConfig config);

  Future<void> disconnect();
}

/// The only implementation that exists until a real render node
/// does: every connect attempt lands in unavailable, with the
/// reason naming exactly what is missing.
class UnavailablePixelStreamClient implements PixelStreamClient {
  final _controller = StreamController<PixelStreamStatus>.broadcast();

  PixelStreamStatus _status =
      const PixelStreamStatus(PixelStreamState.idle);

  @override
  PixelStreamStatus get status => _status;

  @override
  Stream<PixelStreamStatus> get statusChanges => _controller.stream;

  @override
  Future<bool> connect(PixelStreamConfig config) async {
    if (!config.isConfigured) {
      _emit(const PixelStreamStatus(
        PixelStreamState.unavailable,
        'No pixel stream is configured: no signalling URL and no '
        'stream id. No UE5 render node has been deployed.',
      ));
      return false;
    }
    _emit(const PixelStreamStatus(
      PixelStreamState.unavailable,
      'No pixel stream implementation exists yet: no UE5 render '
      'node, no GPU host, and no signalling server to connect to. '
      'The stream client contract is specified, not built.',
    ));
    return false;
  }

  @override
  Future<void> disconnect() async {
    _emit(const PixelStreamStatus(PixelStreamState.idle));
  }

  void _emit(PixelStreamStatus next) {
    _status = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
