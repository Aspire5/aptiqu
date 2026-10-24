import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';
import 'feedback_cue.dart';

/// Device preferences deliberately survive logout and never enter the user API.
class FeedbackPreferences extends GetxController {
  static const storageKey = 'aptiqu.feedback.v1';
  final FlutterSecureStorage storage;
  final sounds = true.obs;
  final haptics = true.obs;
  final timerAudio = TimerAudio.full.obs;
  final saveError = RxnString();
  int _revision = 0;
  Future<void>? _writes;

  FeedbackPreferences({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();

  Future<void> load() async {
    final revision = _revision;
    try {
      final value = await storage.read(key: storageKey);
      if (value == null || revision != _revision) return;
      final data = jsonDecode(value) as Map<String, dynamic>;
      sounds.value = data['sounds'] != false;
      haptics.value = data['haptics'] != false;
      timerAudio.value = TimerAudio.values.firstWhere(
        (v) => v.name == data['timer'],
        orElse: () => TimerAudio.full,
      );
    } catch (_) {
      /* Safe defaults when storage is unavailable. */
    }
  }

  Future<void> setSounds(bool value) {
    sounds.value = value;
    return _save();
  }

  Future<void> setHaptics(bool value) {
    haptics.value = value;
    return _save();
  }

  Future<void> setTimerAudio(TimerAudio value) {
    timerAudio.value = value;
    return _save();
  }

  Future<void> _save() {
    final revision = ++_revision;
    final value = jsonEncode({
      'sounds': sounds.value,
      'haptics': haptics.value,
      'timer': timerAudio.value.name,
    });
    saveError.value = null;
    Future<void> save() async {
      try {
        await storage.write(key: storageKey, value: value);
      } catch (_) {
        if (revision == _revision) {
          saveError.value =
              'Changed for now. Could not save sound preferences.';
        }
      }
    }

    final previous = _writes;
    final pending = previous == null ? save() : previous.then((_) => save());
    _writes = pending;
    return pending;
  }
}
