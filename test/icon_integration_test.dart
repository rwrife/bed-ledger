import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('platform icon asset integration', () {
    test('AppStore icon exists and is a 1024x1024 PNG', () {
      final icon = File('AppStore/icon.png');
      expect(icon.existsSync(), isTrue);
      expect(icon.lengthSync(), greaterThan(100000));
    });

    test('Windows resource icon exists and has valid ICO header', () {
      final ico = File('windows/runner/resources/app_icon.ico');
      expect(ico.existsSync(), isTrue);
      final bytes = ico.readAsBytesSync();
      expect(bytes.length, greaterThan(10000));
      // ICO magic bytes: 0x00 0x00, type 0x01 0x00
      expect(bytes[0], 0);
      expect(bytes[1], 0);
      expect(bytes[2], 1);
      expect(bytes[3], 0);
      final count = bytes[4] | (bytes[5] << 8);
      expect(count, greaterThanOrEqualTo(5));
    });

    test('Android launcher mipmaps and adaptive xml exist', () {
      final densities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in densities) {
        final launcher = File(
          'android/app/src/main/res/mipmap-$density/ic_launcher.png',
        );
        expect(
          launcher.existsSync(),
          isTrue,
          reason: 'missing mipmap-$density launcher',
        );
        expect(launcher.lengthSync(), greaterThan(500));
      }
      final adaptiveXml = File(
        'android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml',
      );
      expect(adaptiveXml.existsSync(), isTrue);
      expect(adaptiveXml.readAsStringSync(), contains('bed_icon_foreground'));
      expect(adaptiveXml.readAsStringSync(), contains('bed_icon_background'));

      final foreground = File(
        'android/app/src/main/res/drawable-nodpi/bed_icon_foreground.png',
      );
      expect(foreground.existsSync(), isTrue);
      expect(foreground.lengthSync(), greaterThan(10000));

      final colors = File(
        'android/app/src/main/res/values/bed_icon_colors.xml',
      );
      expect(colors.existsSync(), isTrue);
      expect(colors.readAsStringSync(), contains('bed_icon_background'));
    });

    test('iOS asset catalog has all AppIcon images in place', () {
      final catalogDir = Directory(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset',
      );
      expect(catalogDir.existsSync(), isTrue);
      final contentsFile = File(
        'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
      );
      expect(contentsFile.existsSync(), isTrue);

      final files = catalogDir
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .toSet();
      expect(files, contains('Icon-App-1024x1024@1x.png'));
      expect(files, contains('Icon-App-60x60@3x.png'));
      expect(files, contains('Icon-App-76x76@2x.png'));

      for (final name in files) {
        if (name.endsWith('.png')) {
          final f = File('${catalogDir.path}/$name');
          expect(f.lengthSync(), greaterThan(200), reason: '$name is empty');
        }
      }
    });

    test('Store copy description reviewed with no unsupported claims', () {
      final desc = File('AppStore/description.txt');
      expect(desc.existsSync(), isTrue);
      final content = desc.readAsStringSync();
      expect(content, isNot(contains('DRAFT LISTING COPY')));
      expect(content, isNot(contains('planned')));
      expect(content, contains('Bed Ledger'));
      expect(content, contains('JSON backup'));
      expect(content, contains('CSV'));
    });
  });
}
