import 'package:flutter/services.dart';

class TestFontManifest implements AssetManifest {
  @override
  List<String> listAssets() => [
    for (final family in ['Outfit', 'PlusJakartaSans', 'SpaceGrotesk'])
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
      ])
        'test/fonts/$family-$weight.ttf',
  ];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}
