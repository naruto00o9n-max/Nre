// Native PNG export for our Pro Image Editor fork: render bounded strips,
// compress one continuous zlib stream on an isolate, never a full output bitmap.
import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../widgets/extended/repaint/extended_render_repaint_boundary.dart';
import '../utils/decode_image.dart';

Future<Uint8List> captureStripPng(
  ExtendedRenderRepaintBoundary boundary,
  ImageInfos infos,
) async {
  final imageWidth = boundary.size.width, imageHeight = boundary.size.height;
  final aspect = infos.isRotated
      ? 1 / infos.cropRectSize.aspectRatio
      : infos.cropRectSize.aspectRatio;
  final cropWidth = min(imageWidth, imageHeight * aspect);
  final cropHeight = min(imageHeight, imageWidth / aspect);
  final width = (cropWidth * infos.pixelRatio).round();
  final height = (cropHeight * infos.pixelRatio).round();
  if (width <= 0 || height <= 0) throw StateError('Empty export bounds');
  final left = max(0.0, imageWidth - cropWidth) / 2;
  final top = max(0.0, imageHeight - cropHeight) / 2;
  final ratio = width / cropWidth;
  // Keep RGBA readback under 2 MiB even for wide images.
  final rows = min(512, max(1, (2 * 1024 * 1024) ~/ (width * 4)));
  final writer = await StripPngWriter.open(width, height);
  try {
    for (int y = 0; y < height; y += rows) {
      final count = min(rows, height - y);
      final tile = await boundary.toImage(
        rect: ui.Rect.fromLTWH(
          left,
          top + y / ratio,
          (width - 1e-8) / ratio,
          (count - 1e-8) / ratio,
        ),
        pixelRatio: ratio,
      );
      try {
        final data = await tile.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null || tile.width != width || tile.height < count)
          throw StateError(
            'Invalid export strip: ${tile.width}x${tile.height}, expected ${width}x$count',
          );
        await writer.add(
          data.buffer.asUint8List(data.offsetInBytes, width * count * 4),
        );
      } finally {
        tile.dispose();
      }
    }
    return await writer.finish();
  } finally {
    await writer.dispose();
  }
}

class StripPngWriter {
  StripPngWriter._(this._directory, this._port, this._isolate);
  final Directory _directory;
  final SendPort _port;
  final Isolate _isolate;
  static Future<StripPngWriter> open(int width, int height) async {
    final directory = await Directory.systemTemp.createTemp('manhwa-png-');
    final ready = ReceivePort();
    final isolate = await Isolate.spawn(_pngWorker, [
      directory.path,
      width,
      height,
      ready.sendPort,
    ]);
    final reply = await ready.first;
    ready.close();
    if (reply is! SendPort) {
      isolate.kill();
      await directory.delete(recursive: true);
      throw StateError('$reply');
    }
    return StripPngWriter._(directory, reply, isolate);
  }

  Future<void> _request(String operation, [TransferableTypedData? data]) async {
    final response = ReceivePort();
    _port.send([operation, data, response.sendPort]);
    final result = await response.first.timeout(const Duration(minutes: 2));
    response.close();
    if (result != true) throw StateError('$result');
  }

  Future<void> add(Uint8List rgba) =>
      _request('add', TransferableTypedData.fromList([rgba]));
  Future<Uint8List> finish() async {
    await _request('finish');
    return File('${_directory.path}/output.png').readAsBytes();
  }

  Future<void> dispose() async {
    _isolate.kill(priority: Isolate.immediate);
    if (await _directory.exists()) await _directory.delete(recursive: true);
  }
}

void _pngWorker(List<dynamic> args) {
  final ready = args[3] as SendPort;
  try {
    final writer = _PngFile(
      '${args[0]}/output.png',
      args[1] as int,
      args[2] as int,
    );
    final receive = ReceivePort();
    ready.send(receive.sendPort);
    receive.listen((dynamic request) {
      final reply = request[2] as SendPort;
      try {
        if (request[0] == 'finish') {
          writer.finish();
          receive.close();
        } else {
          writer.add(
            (request[1] as TransferableTypedData).materialize().asUint8List(),
          );
        }
        reply.send(true);
      } catch (error) {
        writer.abort();
        reply.send(error.toString());
        receive.close();
      }
    });
  } catch (error) {
    ready.send(error.toString());
  }
}

class _PngFile {
  _PngFile(String path, this.width, this.height)
    : file = File(path).openSync(mode: FileMode.write) {
    file.writeFromSync([137, 80, 78, 71, 13, 10, 26, 10]);
    final header = ByteData(13)
      ..setUint32(0, width)
      ..setUint32(4, height)
      ..setUint8(8, 8)
      ..setUint8(9, 6);
    chunk('IHDR', header.buffer.asUint8List());
    compressor = ZLibEncoder(level: 6).startChunkedConversion(_ChunkSink(this));
  }
  final int width, height;
  final RandomAccessFile file;
  late final Sink<List<int>> compressor;
  int writtenRows = 0;
  bool closed = false;
  static final crcTable = List<int>.generate(256, (value) {
    var crc = value;
    for (int k = 0; k < 8; k++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
    return crc;
  });
  void chunk(String type, List<int> data) {
    final name = type.codeUnits;
    var crc = 0xffffffff;
    for (final byte in name) {
      crc = crcTable[(crc ^ byte) & 255] ^ (crc >> 8);
    }
    for (final byte in data) {
      crc = crcTable[(crc ^ byte) & 255] ^ (crc >> 8);
    }
    file.writeFromSync(
      (ByteData(4)..setUint32(0, data.length)).buffer.asUint8List(),
    );
    file.writeFromSync(name);
    file.writeFromSync(data);
    file.writeFromSync(
      (ByteData(4)..setUint32(0, crc ^ 0xffffffff)).buffer.asUint8List(),
    );
  }

  void add(Uint8List bytes) {
    final stride = width * 4;
    if (bytes.length % stride != 0 ||
        writtenRows + bytes.length ~/ stride > height)
      throw StateError('Invalid strip length');
    final row = Uint8List(stride + 1); // PNG filter 0: no quality conversion.
    for (int offset = 0; offset < bytes.length; offset += stride) {
      row.setRange(1, row.length, bytes, offset);
      compressor.add(row);
      writtenRows++;
    }
  }

  void finish() {
    if (writtenRows != height) throw StateError('Incomplete PNG');
    compressor.close();
    chunk('IEND', const []);
    file.flushSync();
    file.closeSync();
    closed = true;
  }

  void abort() {
    if (!closed) {
      file.closeSync();
      closed = true;
    }
  }
}

class _ChunkSink implements Sink<List<int>> {
  _ChunkSink(this.writer);
  final _PngFile writer;
  @override
  void add(List<int> data) {
    // zlib may emit a large chunk; split the compressed stream into valid IDATs.
    for (int offset = 0; offset < data.length; offset += 65536) {
      writer.chunk(
        'IDAT',
        data.sublist(offset, min(data.length, offset + 65536)),
      );
    }
  }

  @override
  void close() {}
}
