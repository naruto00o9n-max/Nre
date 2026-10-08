import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LibraryNode {
  LibraryNode({
    required this.id,
    required this.name,
    required this.folder,
    this.parent,
    this.original,
    this.width = 0,
    this.height = 0,
    this.revision,
    this.export,
    this.trashed = false,
    DateTime? modified,
  }) : modified = modified ?? DateTime.now();
  final String id;
  String name;
  final bool folder;
  String? parent;
  final String? original;
  final int width, height;
  String? revision, export;
  bool trashed;
  DateTime modified;
  factory LibraryNode.fromJson(Map<String, dynamic> data) => LibraryNode(
    id: data['id'],
    name: data['name'],
    folder: data['folder'],
    parent: data['parent'],
    original: data['original'],
    width: data['width'] ?? 0,
    height: data['height'] ?? 0,
    revision: data['revision'],
    export: data['export'],
    trashed: data['trashed'] ?? false,
    modified: DateTime.parse(data['modified']),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'folder': folder,
    'parent': parent,
    'original': original,
    'width': width,
    'height': height,
    'revision': revision,
    'export': export,
    'trashed': trashed,
    'modified': modified.toIso8601String(),
  };
}

/// Files are immutable; the index switches to a revision only after it is durable.
class LibraryStore extends ChangeNotifier {
  LibraryStore(this.root);
  final Directory root;
  final List<LibraryNode> nodes = [];
  Future<void> _queue = Future.value();
  static Future<LibraryStore> open() async {
    final directory = await getApplicationSupportDirectory();
    final store = LibraryStore(Directory('${directory.path}/manhwa-library'));
    await store.load();
    return store;
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}-${nodes.length}';
  File file(String relative) => File('${root.path}/$relative');
  List<LibraryNode> children(String? parent) =>
      nodes.where((n) => n.parent == parent && !n.trashed).toList()..sort(
        (a, b) => a.folder != b.folder
            ? (a.folder ? -1 : 1)
            : a.name.compareTo(b.name),
      );
  List<LibraryNode> get recent =>
      nodes.where((n) => !n.folder && !_hidden(n)).toList()
        ..sort((a, b) => b.modified.compareTo(a.modified));
  bool _hidden(LibraryNode node) =>
      node.trashed ||
      (node.parent != null &&
          _hidden(nodes.firstWhere((n) => n.id == node.parent)));
  Future<void> load() async {
    await root.create(recursive: true);
    final index = file('library.json');
    if (await index.exists()) {
      try {
        _decode(await index.readAsString());
      } catch (_) {
        final backup = file('library.backup.json');
        if (!await backup.exists()) rethrow;
        _decode(await backup.readAsString());
      }
    }
  }

  void _decode(String data) {
    final json = jsonDecode(data) as Map<String, dynamic>;
    if (json['version'] != 1) {
      throw const FormatException('نسخة المعرض غير مدعومة');
    }
    final restored = (json['nodes'] as List)
        .map((n) => LibraryNode.fromJson(Map<String, dynamic>.from(n)))
        .toList();
    nodes
      ..clear()
      ..addAll(restored);
  }

  Future<void> _persist() {
    final contents = jsonEncode({
      'version': 1,
      'nodes': nodes.map((n) => n.toJson()).toList(),
    });
    final operation = _queue.catchError((Object _) {}).then((_) async {
      final index = file('library.json');
      final temporary = file('library.next.json');
      await temporary.writeAsString(contents, flush: true);
      if (await index.exists()) {
        await index.copy(file('library.backup.json').path);
      }
      await temporary.rename(index.path);
    });
    _queue = operation;
    return operation.then((_) => notifyListeners());
  }

  Future<LibraryNode> createFolder(String name, String? parent) async {
    if (name.trim().isEmpty) throw ArgumentError('اسم المجلد مطلوب');
    final node = LibraryNode(
      id: _id(),
      name: name.trim(),
      folder: true,
      parent: parent,
    );
    nodes.add(node);
    try {
      await _persist();
    } catch (_) {
      nodes.remove(node);
      rethrow;
    }
    return node;
  }

  Future<LibraryNode> importImage(
    File source,
    String name,
    String? parent,
  ) async {
    final id = _id();
    final relative = 'projects/$id/original.image';
    final target = file(relative);
    await target.parent.create(recursive: true);
    await source.copy(target.path);
    final probe = await target.open();
    final header = await probe.read(26);
    await probe.close();
    if (header.length >= 26 &&
        listEquals(header.take(8).toList(), [
          137,
          80,
          78,
          71,
          13,
          10,
          26,
          10,
        ]) &&
        header[24] == 16) {
      await target.parent.delete(recursive: true);
      throw const FormatException(
        'صور PNG ذات 16 بت تحتاج مسار معالجة آخر. لم نُحوّل الأصل إلى 8 بت.',
      );
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(target.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final node = LibraryNode(
        id: id,
        name: name,
        folder: false,
        parent: parent,
        original: relative,
        width: descriptor.width,
        height: descriptor.height,
      );
      // No resizing: refuse an unsupported canvas instead of silently degrading it.
      if (node.width > 15360 ||
          node.height > 15360 ||
          node.width * node.height > 24000000) {
        throw const FormatException(
          'هذه الصورة تتجاوز حدود النسخة الحالية (15360 بكسل للضلع و24 مليون بكسل). لم نُصغّر الأصل.',
        );
      }
      nodes.add(node);
      try {
        await _persist();
      } catch (_) {
        nodes.remove(node);
        rethrow;
      }
      return node;
    } catch (_) {
      await target.parent.delete(recursive: true);
      rethrow;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  Future<void> rename(LibraryNode node, String name) async {
    if (name.trim().isEmpty) return;
    node.name = name.trim();
    node.modified = DateTime.now();
    await _persist();
  }

  bool canMove(LibraryNode node, String? parent) {
    while (parent != null) {
      if (parent == node.id) return false;
      final candidate = nodes
          .where((n) => n.id == parent && n.folder && !n.trashed)
          .firstOrNull;
      if (candidate == null) return false;
      parent = candidate.parent;
    }
    return true;
  }

  Future<void> move(LibraryNode node, String? parent) async {
    if (!canMove(node, parent)) {
      throw ArgumentError('لا يمكن نقل المجلد داخل نفسه');
    }
    node.parent = parent;
    await _persist();
  }

  Future<void> trash(LibraryNode node) async {
    node.trashed = true;
    await _persist();
  }

  Future<void> restore(LibraryNode node) async {
    node.trashed = false;
    await _persist();
  }

  Future<String?> state(LibraryNode node) async =>
      node.revision == null ? null : file(node.revision!).readAsString();
  Future<void> save(LibraryNode node, String state, {Uint8List? png}) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final base = 'projects/${node.id}';
    final revision = '$base/state-$stamp.json';
    await file(revision).writeAsString(state, flush: true);
    String? exported;
    if (png != null) {
      if (png.length < 24 ||
          !listEquals(png.take(8).toList(), [
            137,
            80,
            78,
            71,
            13,
            10,
            26,
            10,
          ])) {
        throw const FormatException('فشل التصدير؛ لم تُستبدل الصورة الأصلية');
      }
      exported = '$base/export-$stamp.png';
      await file(exported).writeAsBytes(png, flush: true);
    }
    final oldRevision = node.revision, oldExport = node.export;
    node.revision = revision;
    node.export = exported ?? node.export;
    node.modified = DateTime.now();
    try {
      await _persist();
    } catch (_) {
      node.revision = oldRevision;
      node.export = oldExport;
      rethrow;
    }
    // Preserve one previous revision for recovery, without accumulating exports.
    final keep = {revision, node.export, oldRevision, oldExport, node.original};
    await for (final entity in file(revision).parent.list()) {
      final relative = entity.path.substring(root.path.length + 1);
      if (!keep.contains(relative) && entity is File) await entity.delete();
    }
  }
}
