import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Hands-free chatting: speak → agent replies → agent speaks →
/// listen again, until Richard stops it or the restraint layer does.
///
/// Built on speech_to_text (verified pub.dev package, device speech
/// recognition — on Android that's the phone's own recogniser; its
/// accuracy and language support are the device's, and the UI says
/// so). The loop is a state machine the views drive:
///
///   idle → listening → thinking → speaking → listening …
///
/// Recognition errors move it to [HandsFreeState.error] with the
/// recogniser's own message — never a silent retry loop pretending
/// to hear.
enum HandsFreeState { idle, listening, thinking, speaking, error }

class HandsFreeController extends ChangeNotifier {
  HandsFreeController({SpeechToText? stt}) : _stt = stt ?? SpeechToText();
  final SpeechToText _stt;

  HandsFreeState state = HandsFreeState.idle;
  String? error;
  String lastHeard = '';
  bool available = false;

  /// Called with the final recognised text each turn.
  Future<void> Function(String heard)? onFinal;

  /// Called when the agent's spoken reply finishes (or immediately,
  /// in text-only mode) so the loop can listen again.
  Future<void> Function(String heard)? speakReply;

  bool _active = false;
  bool get active => _active;

  Future<bool> start() async {
    error = null;
    available = await _stt.initialize(
      onError: (e) {
        error = e.errorMsg;
        state = HandsFreeState.error;
        notifyListeners();
      },
    );
    if (!available) {
      error = 'Speech recognition is not available on this device.';
      state = HandsFreeState.error;
      notifyListeners();
      return false;
    }
    _active = true;
    await _listen();
    return true;
  }

  Future<void> _listen() async {
    if (!_active) return;
    state = HandsFreeState.listening;
    notifyListeners();
    await _stt.listen(
      onResult: (result) async {
        lastHeard = result.recognizedWords;
        if (!result.finalResult) {
          notifyListeners();
          return;
        }
        final heard = result.recognizedWords.trim();
        await _stt.stop();
        if (heard.isEmpty) {
          await _listen();
          return;
        }
        state = HandsFreeState.thinking;
        notifyListeners();
        final handler = onFinal;
        if (handler != null) await handler(heard);
        if (!_active) return;
        state = HandsFreeState.speaking;
        notifyListeners();
        final speaker = speakReply;
        if (speaker != null) await speaker(heard);
        if (_active) await _listen();
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() async {
    _active = false;
    await _stt.stop();
    state = HandsFreeState.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    // The speech engine outlives its owner otherwise: leaving the
    // chat screen while hands-free was on kept the mic listening.
    _active = false;
    unawaited(_stt.stop());
    super.dispose();
  }
}
