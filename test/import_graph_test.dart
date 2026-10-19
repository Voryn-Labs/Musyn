import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('handwritten Dart imports and exports have no dependency cycles', () {
    final root = Directory.current.path;
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.endsWith('.dart') &&
              !file.path.contains('localization/'),
        );
    final sources = {
      for (final file in files)
        path.normalize(path.absolute(file.path)): file.readAsStringSync(),
    };
    final edges = <String, Set<String>>{};
    final directives = RegExp(r'''(?:import|export)\s+['"]([^'"]+)''');
    for (final entry in sources.entries) {
      edges[entry.key] = {};
      for (final match in directives.allMatches(entry.value)) {
        final uri = match[1]!;
        String? target;
        if (uri.startsWith('package:musyn/')) {
          target = path.join(
            root,
            'lib',
            uri.substring('package:musyn/'.length),
          );
        } else if (!uri.contains(':')) {
          target = path.join(path.dirname(entry.key), uri);
        }
        if (target != null && sources.containsKey(path.normalize(target))) {
          edges[entry.key]!.add(path.normalize(target));
        }
      }
    }
    final visited = <String>{};
    final active = <String>[];
    void visit(String file) {
      expect(
        active,
        isNot(contains(file)),
        reason:
            'Import cycle: ${[...active, file].map((entry) => path.relative(entry, from: root)).join(' → ')}',
      );
      if (!visited.add(file)) return;
      active.add(file);
      for (final dependency in edges[file]!) {
        visit(dependency);
      }
      active.removeLast();
    }

    for (final file in sources.keys) {
      visit(file);
    }
  });
}
