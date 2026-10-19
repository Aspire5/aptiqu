import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as font_test;
import 'font_manifest.dart';

void useProductionFontFixtures() {
  GoogleFonts.config.allowRuntimeFetching = false;
  font_test.assetManifest = TestFontManifest();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (!key.startsWith('test/fonts/')) {
          // Keep real app images/manifests available alongside font fixtures.
          final asset = File('build/unit_test_assets/$key');
          return asset.existsSync()
              ? ByteData.sublistView(asset.readAsBytesSync())
              : null;
        }
        final file = key.split('/').last.replaceFirst('SpaceGrotesk', 'Outfit');
        return ByteData.sublistView(
          File('test/fonts/phase_a/$file').readAsBytesSync(),
        );
      });
}

Future<void> loadProductionFontFixtures(
  WidgetTester tester,
) => tester.runAsync(() async {
  await GoogleFonts.pendingFonts();
  var directory = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 8; i++) {
    final icons = File(
      '${directory.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
      break;
    }
    directory = directory.parent;
  }
});
