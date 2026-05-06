import 'dart:convert';
import 'dart:io';

const String _defaultSourcePath = 'assets/content/hisn_al_muslim.json';
const String _fallbackSourcePath = 'assets/contents/hisn_source.json';
const String _defaultOutputDir = 'assets/contents/hisn';

Future<void> main(List<String> args) async {
  final String sourcePath = args.isNotEmpty
      ? args[0]
      : File(_defaultSourcePath).existsSync()
      ? _defaultSourcePath
      : _fallbackSourcePath;
  final String outputDir = args.length > 1 ? args[1] : _defaultOutputDir;

  final File sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Hisn source JSON was not found: $sourcePath');
    exitCode = 1;
    return;
  }

  final Object? decoded = jsonDecode(await sourceFile.readAsString());
  if (decoded is! Map) {
    stderr.writeln('Hisn source JSON must be a top-level object.');
    exitCode = 1;
    return;
  }

  final Directory categoryDirectory = Directory('$outputDir/categories');
  categoryDirectory.createSync(recursive: true);

  final JsonEncoder encoder = JsonEncoder.withIndent('  ');
  final List<Map<String, Object?>> index = <Map<String, Object?>>[];
  int generatedCategories = 0;
  int generatedDuas = 0;
  int writes = 0;

  for (final MapEntry<dynamic, dynamic> entry in decoded.entries) {
    final String? title = _stringOrNull(entry.key);
    final Object? value = entry.value;
    if (title == null || title.trim().isEmpty || value is! Map) {
      continue;
    }

    final int categoryNumber = index.length + 1;
    final String id = categoryNumber.toString().padLeft(3, '0');
    final String assetPath = '$outputDir/categories/$id.json';
    final List<Object?> text = _listOrEmpty(value['text']);
    final List<Object?> footnote = _listOrEmpty(
      value['footnote'] ?? value['reference'] ?? value['references'],
    );

    final Map<String, Object?> categoryJson = <String, Object?>{
      'id': id,
      'title': title,
      'text': text,
      if (footnote.isNotEmpty) 'footnote': footnote,
    };

    final String categoryContent = '${encoder.convert(categoryJson)}\n';
    if (await _writeIfChanged(File(assetPath), categoryContent)) {
      writes++;
    }

    index.add(<String, Object?>{
      'id': id,
      'title': title,
      'duaCount': text.length,
      'footnoteCount': footnote.length,
      'asset': assetPath,
    });
    generatedCategories++;
    generatedDuas += text.length;
  }

  final String indexContent = '${encoder.convert(index)}\n';
  if (await _writeIfChanged(File('$outputDir/index.json'), indexContent)) {
    writes++;
  }

  stdout.writeln(
    'Generated $generatedCategories Hisn categories with $generatedDuas duas '
    'under $outputDir ($writes files changed).',
  );
}

List<Object?> _listOrEmpty(Object? value) {
  if (value == null) return const <Object?>[];
  if (value is List) return value;
  return <Object?>[value];
}

String? _stringOrNull(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

Future<bool> _writeIfChanged(File file, String content) async {
  if (file.existsSync()) {
    final String existing = await file.readAsString();
    if (existing == content) return false;
  }

  file.parent.createSync(recursive: true);
  await file.writeAsString(content, encoding: utf8);
  return true;
}
