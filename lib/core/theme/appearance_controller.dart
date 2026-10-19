import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get/get.dart';

/// Device-local presentation preference. Account/session storage is untouched.
class AppearanceController extends GetxController {
  static const storageKey = 'aptiqu.appearance';
  final FlutterSecureStorage storage;
  final mode = ThemeMode.system.obs;
  final saveError = RxnString();
  Future<void>? _writes;
  int _revision = 0;

  AppearanceController({FlutterSecureStorage? storage})
    : storage = storage ?? const FlutterSecureStorage();

  Future<void> load() async {
    final revision = _revision;
    try {
      final saved = await storage.read(key: storageKey);
      if (revision != _revision) return;
      mode.value = ThemeMode.values.firstWhere(
        (value) => value.name == saved,
        orElse: () => ThemeMode.system,
      );
    } catch (_) {
      if (revision == _revision) mode.value = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode next) {
    mode.value = next;
    saveError.value = null;
    final revision = ++_revision;
    // Serialize writes so rapid choices persist the last choice, not the last
    // storage operation to finish.
    Future<void> save() async {
      try {
        await storage.write(key: storageKey, value: next.name);
        if (revision == _revision) saveError.value = null;
      } catch (_) {
        if (revision == _revision) {
          saveError.value =
              'Changed for this session. Could not save your appearance.';
        }
      }
    }

    final previous = _writes;
    final pending = previous == null ? save() : previous.then((_) => save());
    _writes = pending;
    return pending;
  }
}
