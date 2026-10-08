import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'library_store.dart';

Widget restoreImageLayer(
  LibraryStore library,
  String id, {
  Map<String, dynamic>? meta,
}) {
  if (!id.startsWith('resource:')) throw ArgumentError('عنصر الصورة غير معروف');
  final relative = id.substring(9);
  if (relative.contains('..') || relative.startsWith('/')) {
    throw ArgumentError('مسار غير صالح');
  }
  final ratio = (meta?['ratio'] as num? ?? 1).toDouble();
  return SizedBox(
    width: 220,
    height: 220 / ratio,
    child: Image.file(
      library.file(relative),
      fit: BoxFit.fill,
      filterQuality: FilterQuality.none,
    ),
  );
}

Future<void> addImageLayer(
  BuildContext context,
  LibraryStore library,
  LibraryNode project,
  ProImageEditorState editor,
) async {
  final mode = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('إضافة طبقة صورة')),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('من الصور'),
            onTap: () => Navigator.pop(sheet, false),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('من الملفات'),
            onTap: () => Navigator.pop(sheet, true),
          ),
        ],
      ),
    ),
  );
  if (mode == null) return;
  String? path, name;
  if (mode) {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    path = result?.files.single.path;
    name = result?.files.single.name;
  } else {
    final result = await ImagePicker().pickImage(source: ImageSource.gallery);
    path = result?.path;
    name = result?.name;
  }
  if (path == null || !context.mounted || !editor.mounted) return;
  final relative =
      'projects/${project.id}/resources/${DateTime.now().microsecondsSinceEpoch}.image';
  final target = library.file(relative);
  await target.parent.create(recursive: true);
  await File(path).copy(target.path);
  final buffer = await ui.ImmutableBuffer.fromFilePath(target.path);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width > 15360 ||
        descriptor.height > 15360 ||
        descriptor.width * descriptor.height > 24000000) {
      await target.delete();
      throw const FormatException(
        'تتجاوز الصورة حدود النسخة الحالية؛ لم نُصغّرها',
      );
    }
    final meta = <String, dynamic>{
      'ratio': descriptor.width / descriptor.height,
    };
    if (!editor.mounted) return;
    final id = 'resource:$relative';
    editor.addLayer(
      WidgetLayer(
        widget: restoreImageLayer(library, id, meta: meta),
        meta: {'name': name ?? 'صورة'},
        exportConfigs: WidgetLayerExportConfigs(id: id, meta: meta),
      ),
    );
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}
