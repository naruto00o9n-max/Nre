import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:example/studio/app.dart';
import 'package:example/studio/library_store.dart';
import 'package:example/studio/editor_controls.dart';
import 'package:example/studio/image_layers.dart';
import 'package:example/features/design_examples/frosted_glass_example.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'long_png_test.dart' show longPattern;

final evidencePath = Platform.isIOS || Platform.isAndroid
    ? '${Directory.systemTemp.path}/test-output'
    : 'test-output';

Future<void> loadFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final proIcons = FontLoader('ProImageEditorIcons')
    ..addFont(
      rootBundle.load(
        'packages/pro_image_editor/assets/fonts/ProImageEditorIcons.ttf',
      ),
    );
  await proIcons.load();
  for (final font in ['NotoSansArabic', 'NotoNaskhArabic']) {
    final loader = FontLoader(font)
      ..addFont(rootBundle.load('assets/fonts/$font.ttf'));
    await loader.load();
  }
}

Future<void> snapshot(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final render = tester.binding.renderViews.first;
    // The screenshot reads the test view's compositor layer for review artifacts.
    // ignore: invalid_use_of_protected_member
    final layer = render.layer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & render.size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(evidencePath).create(recursive: true);
    await File('$evidencePath/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  testWidgets('home and nested gallery at phone width', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final directory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('studio-ui-test'),
    ))!;
    late LibraryStore library;
    await tester.runAsync(() async {
      library = LibraryStore(directory);
      await library.load();
      await loadFonts();
      final work = await library.createFolder('القس المجنون', null);
      await library.createFolder('الفصل الأول', work.id);
    });
    await tester.pumpWidget(StudioApp(library: library));
    await tester.pumpAndSettle();
    await snapshot(tester, 'home');
    await tester.tap(find.text('معرض أعمالي'));
    await tester.pumpAndSettle();
    expect(find.text('القس المجنون'), findsOneWidget);
    await snapshot(tester, 'gallery');
    await tester.tap(find.text('القس المجنون'));
    await tester.pumpAndSettle();
    expect(find.text('الفصل الأول'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => directory.delete(recursive: true));
    library.dispose();
  });
  testWidgets(
    '800 x 15000 canvas: pinch, text properties, layers, PNG export, reopen',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late LibraryStore library;
      late LibraryNode project;
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('studio-editor-test'),
      ))!;
      await tester.runAsync(() async {
        library = LibraryStore(Directory('${directory.path}/library'));
        await library.load();
        await loadFonts();
        final png = await longPattern();
        final source = File('${directory.path}/long.png');
        await source.writeAsBytes(png);
        project = await library.importImage(source, 'صورة طويلة', null);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'NotoSansArabic',
          ),
          home: FrostedGlassExample(
            image: library.file(project.original!),
            library: library,
            project: project,
            enableAutosave: false,
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      final editor = tester.state<ProImageEditorState>(
        find.byType(ProImageEditor),
      );
      expect(editor.sizesManager.originalImageSize, const Size(800, 15000));
      final before = editor.interactiveViewer.currentState!.scaleFactor;
      final first = await tester.startGesture(
        const Offset(170, 450),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(260, 450),
        pointer: 2,
      );
      for (int step = 1; step <= 8; step++) {
        await first.moveTo(Offset(170 - step * 8.0, 450));
        await second.moveTo(Offset(260 + step * 8.0, 450));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pump();
      await first.up();
      await second.up();
      await tester.pumpAndSettle();
      expect(
        editor.interactiveViewer.currentState!.scaleFactor,
        greaterThan(before),
      );
      editor.resetZoom();
      await tester.pumpAndSettle();
      editor.addHistory();
      await tester.pumpAndSettle();
      // This exercises the actual patched rendering path, not merely the encoder.
      final baseline = await tester.runAsync(() => editor.captureEditorImage());
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(baseline!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 800);
        expect(frame.image.height, 15000);
        final data = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final pixels = data!.buffer.asUint8List();
        var mismatches = 0;
        for (int y = 0; y < 15000; y++) {
          for (int x = 0; x < 800; x++) {
            final i = (y * 800 + x) * 4;
            if (pixels[i] != x % 256 ||
                pixels[i + 1] != y % 256 ||
                pixels[i + 2] != (x + y) % 256 ||
                pixels[i + 3] != 255) {
              mismatches++;
            }
          }
        }
        expect(
          mismatches,
          0,
          reason:
              'full editor export must preserve the unedited original pixels',
        );
        await File('$evidencePath/editor-800x15000.png').writeAsBytes(baseline);
        frame.image.dispose();
        codec.dispose();
      });
      editor.zoomTo(
        scale: 18,
        offset: Offset(
          -17 * editor.sizesManager.bodySize.width / 2,
          -17 * editor.sizesManager.bodySize.height / 2,
        ),
      );
      await tester.pumpAndSettle();
      editor.openTextEditor();
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'نص عربي للتجربة');
      await tester.pumpAndSettle();
      await snapshot(tester, 'text-panel');
      await tester.tap(find.text('تطبيق'));
      await tester.pumpAndSettle();
      expect(
        editor.activeLayers.whereType<TextLayer>().single.text,
        'نص عربي للتجربة',
      );
      editor.selectLayerByIndex(editor.activeLayers.length - 1);
      await tester.pumpAndSettle();
      await snapshot(tester, 'text-handles');
      final handle = find.byType(TextWidthHandle);
      expect(handle, findsOneWidget);
      final oldWidth =
          editor.activeLayers.whereType<TextLayer>().single.maxTextWidth ?? 240;
      await tester.drag(handle, const Offset(36, 0));
      await tester.pumpAndSettle();
      expect(
        editor.activeLayers.whereType<TextLayer>().single.maxTextWidth,
        greaterThan(oldWidth),
      );
      await tester.tap(find.byTooltip('الطبقات'));
      await tester.pumpAndSettle();
      expect(find.text('الصورة الأصلية'), findsOneWidget);
      await snapshot(tester, 'layers');
      await tester.tapAt(const Offset(200, 130));
      await tester.pumpAndSettle();
      await snapshot(tester, 'editor');
      // A file-backed image layer must survive project saves and re-imports.
      final resource = 'projects/${project.id}/resources/overlay.png';
      await tester.runAsync(() async {
        final target = library.file(resource);
        await target.parent.create(recursive: true);
        await target.writeAsBytes(await longPattern(width: 80, height: 100));
      });
      final meta = <String, dynamic>{'ratio': .8};
      editor.addLayer(
        WidgetLayer(
          widget: restoreImageLayer(library, 'resource:$resource', meta: meta),
          exportConfigs: WidgetLayerExportConfigs(
            id: 'resource:$resource',
            meta: meta,
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      editor.clearLayerSelection();
      await tester.pumpAndSettle();
      final editedPng = await tester.runAsync(
        () => editor.captureEditorImage(),
      );
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(editedPng!);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 800);
        expect(frame.image.height, 15000);
        final bytes = (await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        var changes = 0;
        for (int y = 0; y < 15000; y++) {
          for (int x = 0; x < 800; x++) {
            final i = (y * 800 + x) * 4;
            if (bytes[i] != x % 256 ||
                bytes[i + 1] != y % 256 ||
                bytes[i + 2] != (x + y) % 256) {
              changes++;
            }
          }
        }
        expect(changes, greaterThan(100));
        expect(changes, lessThan(500000));
        final last = (800 * 15000 - 1) * 4;
        expect(bytes.sublist(last, last + 4), [
          799 % 256,
          14999 % 256,
          (799 + 14999) % 256,
          255,
        ]);
        frame.image.dispose();
        codec.dispose();
      });
      final state = await tester.runAsync(() async {
        final exported = await editor.exportStateHistory(
          configs: const ExportEditorConfigs(
            historySpan: ExportHistorySpan.current,
          ),
        );
        final json = await exported.toJson();
        await library.save(project, json, png: editedPng);
        return json;
      });
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'NotoSansArabic',
          ),
          home: FrostedGlassExample(
            image: library.file(project.original!),
            library: library,
            project: project,
            enableAutosave: false,
            history: state,
          ),
        ),
      );
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();
      final reopened = tester.state<ProImageEditorState>(
        find.byType(ProImageEditor),
      );
      expect(
        reopened.activeLayers.whereType<TextLayer>().single.text,
        'نص عربي للتجربة',
      );
      expect(reopened.activeLayers.whereType<WidgetLayer>().length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.runAsync(() => directory.delete(recursive: true));
      library.dispose();
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
