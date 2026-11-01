import 'package:flutter_test/flutter_test.dart';
import 'package:rich_gang_ai/core/pixel_stream_client.dart';

/// Pixel-stream client locks (2026-10-25): until a real UE5 render
/// node exists, the only client reports unavailable with the reason
/// attached — never a fake streaming state, never a guessed host.
void main() {
  test('an unconfigured stream reports unavailable with the reason',
      () async {
    final client = UnavailablePixelStreamClient();
    expect(client.status.state, PixelStreamState.idle);
    expect(
        await client.connect(
            const PixelStreamConfig(signallingUrl: '', streamId: '')),
        isFalse);
    expect(client.status.state, PixelStreamState.unavailable);
    expect(client.status.reason, contains('No pixel stream is configured'));
    await client.disconnect();
    expect(client.status.state, PixelStreamState.idle);
    await client.dispose();
  });

  test('a configured-looking stream still reports unavailable, '
      'because no render node exists', () async {
    final client = UnavailablePixelStreamClient();
    expect(
        await client.connect(const PixelStreamConfig(
            signallingUrl: 'wss://example.invalid', streamId: 'room')),
        isFalse);
    expect(client.status.state, PixelStreamState.unavailable);
    expect(client.status.reason, contains('No pixel stream implementation'));
    await client.dispose();
  });

  test('state changes are emitted on connect and disconnect',
      () async {
    final client = UnavailablePixelStreamClient();
    final seen = <PixelStreamState>[];
    final sub = client.statusChanges.listen((s) => seen.add(s.state));
    await client.connect(
        const PixelStreamConfig(signallingUrl: '', streamId: ''));
    await client.disconnect();
    await sub.cancel();
    expect(seen, [
      PixelStreamState.unavailable,
      PixelStreamState.idle,
    ]);
    await client.dispose();
  });
}
