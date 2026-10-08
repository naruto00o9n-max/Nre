import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:example/studio/library_store.dart';
import 'package:pro_image_editor/shared/utils/streaming_png.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'folders, immutable originals, revisions, recovery, trash and move cycles',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'studio-library-test',
      );
      final store = LibraryStore(Directory('${directory.path}/library'));
      await store.load();
      final work = await store.createFolder('القس المجنون', null);
      final chapter = await store.createFolder('الفصل الأول', work.id);
      expect(store.canMove(work, chapter.id), false);
      await expectLater(store.move(work, chapter.id), throwsArgumentError);
      final encoder = await StripPngWriter.open(8, 10);
      late Uint8List source;
      try {
        await encoder.add(Uint8List(8 * 10 * 4)..fillRange(0, 8 * 10 * 4, 255));
        source = await encoder.finish();
      } finally {
        await encoder.dispose();
      }
      final file = File('${directory.path}/sample.png');
      await file.writeAsBytes(source);
      final project = await store.importImage(file, '001.png', chapter.id);
      await store.save(project, '{"version":1,"layers":["نص"]}', png: source);
      await store.save(project, '{"version":1,"layers":["نص معدل"]}');
      expect(await store.file(project.original!).readAsBytes(), source);
      final reopened = LibraryStore(store.root);
      await reopened.load();
      final restored = reopened.nodes.firstWhere((n) => n.id == project.id);
      expect(await reopened.state(restored), contains('نص معدل'));
      expect(restored.width, 8);
      expect(restored.height, 10);
      await reopened.trash(reopened.nodes.firstWhere((n) => n.id == work.id));
      expect(reopened.recent, isEmpty);
      await reopened.restore(reopened.nodes.firstWhere((n) => n.id == work.id));
      expect(reopened.recent.single.id, project.id);
      await reopened.file('library.json').writeAsString('broken');
      final recovered = LibraryStore(store.root);
      await recovered.load();
      expect(recovered.nodes.length, 3);
      store.dispose();
      reopened.dispose();
      recovered.dispose();
      await directory.delete(recursive: true);
    },
  );
}
