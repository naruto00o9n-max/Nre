import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/shared/utils/streaming_png.dart';

Future<Uint8List> longPattern({int width = 800, int height = 15000}) async {
  final writer = await StripPngWriter.open(width, height);
  try {
    for (int y = 0; y < height; y += 256) {
      final rows = (height - y).clamp(1, 256);
      final bytes = Uint8List(width * rows * 4);
      for (int row = 0; row < rows; row++) {
        for (int x = 0; x < width; x++) {
          final i = (row * width + x) * 4;
          bytes[i] = x % 256;
          bytes[i + 1] = (y + row) % 256;
          bytes[i + 2] = (x + y + row) % 256;
          bytes[i + 3] = 255;
        }
      }
      await writer.add(bytes);
    }
    return await writer.finish();
  } finally {
    await writer.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'stream PNG 800 x 15000: check every channel of all 12 million pixels',
    () async {
      final png = await longPattern();
      final codec = await ui.instantiateImageCodec(png);
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
      expect(mismatches, 0);
      final evidence = Directory('test-output');
      await evidence.create(recursive: true);
      await File('${evidence.path}/pattern-800x15000.png').writeAsBytes(png);
      frame.image.dispose();
      codec.dispose();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
