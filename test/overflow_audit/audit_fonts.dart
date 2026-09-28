import 'dart:io';

import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Loads real fonts so layout in tests matches devices (the default test font
/// renders every glyph 1em wide, which invents overflows).
///
/// - Google Fonts: static TTFs named `<Family>-<weight>.ttf` in [dir] are
///   registered under the base family (`Inter`, `PlusJakartaSans`), which
///   google_fonts lists as the fallback for its per-weight families.
/// - Roboto + Material Icons from the Flutter SDK.
Future<void> loadAuditFonts(String dir) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  final byFamily = <String, List<File>>{};
  if (dir.isNotEmpty && Directory(dir).existsSync()) {
    for (final f in Directory(dir).listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) {
      final name = f.uri.pathSegments.last.replaceAll('.ttf', '');
      final family = name.split('-').first;
      final weight = name.split('-').last;
      byFamily.putIfAbsent(family, () => []).add(f);
      // google_fonts' own per-weight family name, e.g. Inter_regular / Inter_700
      byFamily.putIfAbsent('${family}_${weight == '400' ? 'regular' : weight}', () => []).add(f);
    }
  }

  final sdk = Platform.environment['FLUTTER_ROOT'];
  if (sdk != null) {
    final material = Directory('$sdk/bin/cache/artifacts/material_fonts');
    if (material.existsSync()) {
      byFamily['Roboto'] = material
          .listSync()
          .whereType<File>()
          .where((f) => RegExp(r'roboto-[a-z]+\.ttf$').hasMatch(f.path))
          .toList();
      final icons = File('${material.path}/materialicons-regular.otf');
      if (icons.existsSync()) byFamily['MaterialIcons'] = [icons];
    }
  }

  for (final entry in byFamily.entries) {
    final loader = FontLoader(entry.key);
    for (final file in entry.value) {
      loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()))));
    }
    await loader.load();
  }
}
