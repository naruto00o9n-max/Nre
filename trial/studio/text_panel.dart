import 'dart:io';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'library_store.dart';

Future<Color?> chooseColor(BuildContext context, Color initial) async {
  var selected = initial;
  return showDialog<Color>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('اللون'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: selected,
          onColorChanged: (value) => selected = value,
          enableAlpha: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selected),
          child: const Text('اختيار'),
        ),
      ],
    ),
  );
}

class StudioFonts {
  static final families = <String, String>{
    'NotoSansArabic': 'عربي حديث',
    'NotoNaskhArabic': 'نسخ عربي',
  };
  static Future<void> load(LibraryStore library) async {
    final directory = Directory('${library.root.path}/fonts');
    if (!await directory.exists()) return;
    final index = library.file('fonts/names.json');
    final names = await index.exists()
        ? jsonDecode(await index.readAsString()) as Map<String, dynamic>
        : <String, dynamic>{};
    await for (final entity in directory.list()) {
      if (entity is File &&
          (entity.path.endsWith('.ttf') || entity.path.endsWith('.otf'))) {
        final family = entity.uri.pathSegments.last;
        final loader = FontLoader(family)
          ..addFont(
            entity.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          );
        await loader.load();
        families[family] =
            names[family] as String? ??
            family.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    }
  }

  static Future<String?> import(LibraryStore library) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (result?.files.single.path == null) return null;
    final source = result!.files.single;
    final extension = source.name.toLowerCase().endsWith('.otf')
        ? 'otf'
        : 'ttf';
    final family = 'font-${DateTime.now().microsecondsSinceEpoch}.$extension';
    final target = library.file('fonts/$family');
    await target.parent.create(recursive: true);
    await File(source.path!).copy(target.path);
    try {
      final loader = FontLoader(family)
        ..addFont(
          target.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await loader.load();
      families[family] = source.name;
      final index = library.file('fonts/names.json');
      final names = await index.exists()
          ? jsonDecode(await index.readAsString()) as Map<String, dynamic>
          : <String, dynamic>{};
      names[family] = source.name;
      final temp = library.file('fonts/names.next.json');
      await temp.writeAsString(jsonEncode(names), flush: true);
      await temp.rename(index.path);
    } catch (_) {
      await target.delete();
      rethrow;
    }
    return family;
  }
}

Future<TextLayer?> showTextPanel(
  BuildContext context,
  LibraryStore library, {
  TextLayer? layer,
}) => showModalBottomSheet<TextLayer>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: const Color(0xF2212532),
  builder: (_) => TextPanel(library: library, initial: layer),
);

class TextPanel extends StatefulWidget {
  const TextPanel({super.key, required this.library, this.initial});
  final LibraryStore library;
  final TextLayer? initial;
  @override
  State<TextPanel> createState() => _TextPanelState();
}

class _TextPanelState extends State<TextPanel> {
  late final TextEditingController _text;
  late TextLayer layer;
  @override
  void initState() {
    super.initState();
    layer =
        widget.initial?.copyWith() ??
        TextLayer(
          text: '',
          colorMode: LayerBackgroundMode.onlyColor,
          color: Colors.white,
          maxTextWidth: 220,
          textStyle: const TextStyle(fontFamily: 'NotoSansArabic'),
          align: TextAlign.center,
        );
    _text = TextEditingController(text: layer.text);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  TextStyle get style =>
      layer.textStyle ?? const TextStyle(fontFamily: 'NotoSansArabic');
  void _style(TextStyle value) => setState(() => layer.textStyle = value);
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChange,
  ) => Row(
    children: [
      SizedBox(
        width: 90,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          onChanged: (v) => setState(() => onChange(v)),
        ),
      ),
      SizedBox(
        width: 46,
        child: Text(value.toStringAsFixed(1), textDirection: TextDirection.ltr),
      ),
    ],
  );
  Future<void> _color(int type) async {
    final result = await chooseColor(
      context,
      type == 0
          ? layer.color
          : type == 1
          ? layer.background
          : layer.outlineColor,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (type == 0) {
        layer.color = result;
      } else if (type == 1) {
        layer.background = result;
        layer.colorMode = LayerBackgroundMode.backgroundAndColor;
      } else {
        layer.outlineColor = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * .75).clamp(300, 720),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'خصائص النص',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    layer.text = _text.text;
                    if (layer.text.trim().isNotEmpty) {
                      Navigator.pop(context, layer);
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('تطبيق'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _text,
                    autofocus: layer.text.isEmpty,
                    minLines: 3,
                    maxLines: 6,
                    textAlign: layer.align,
                    decoration: const InputDecoration(
                      hintText: 'اكتب النص هنا',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF101218),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _text.text.isEmpty ? 'معاينة النص' : _text.text,
                      textAlign: layer.align,
                      style: style.copyWith(
                        color: layer.color,
                        fontSize: (24 * layer.fontScale).clamp(8, 70),
                        backgroundColor:
                            layer.colorMode == LayerBackgroundMode.onlyColor
                            ? null
                            : layer.background,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              StudioFonts.families.containsKey(style.fontFamily)
                              ? style.fontFamily
                              : 'NotoSansArabic',
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'الخط'),
                          items: StudioFonts.families.entries
                              .map(
                                (f) => DropdownMenuItem(
                                  value: f.key,
                                  child: Text(
                                    f.value,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: f.key),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              _style(style.copyWith(fontFamily: value)),
                        ),
                      ),
                      IconButton(
                        tooltip: 'استيراد خط TTF / OTF',
                        icon: const Icon(Icons.file_upload_outlined),
                        onPressed: () async {
                          try {
                            final family = await StudioFonts.import(
                              widget.library,
                            );
                            if (family != null && mounted) {
                              _style(style.copyWith(fontFamily: family));
                            }
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر تحميل الخط: $error'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final item in [
                        (TextAlign.right, Icons.format_align_right),
                        (TextAlign.center, Icons.format_align_center),
                        (TextAlign.left, Icons.format_align_left),
                      ])
                        IconButton.filledTonal(
                          isSelected: layer.align == item.$1,
                          onPressed: () =>
                              setState(() => layer.align = item.$1),
                          icon: Icon(item.$2),
                        ),
                      IconButton.filledTonal(
                        isSelected: style.fontWeight == FontWeight.bold,
                        onPressed: () => _style(
                          style.copyWith(
                            fontWeight: style.fontWeight == FontWeight.bold
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        icon: const Icon(Icons.format_bold),
                      ),
                      IconButton.filledTonal(
                        isSelected: style.fontStyle == FontStyle.italic,
                        onPressed: () => _style(
                          style.copyWith(
                            fontStyle: style.fontStyle == FontStyle.italic
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                        icon: const Icon(Icons.format_italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _color(0),
                        icon: Icon(Icons.circle, color: layer.color),
                        label: const Text('لون النص'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _color(1),
                        icon: Icon(Icons.circle, color: layer.background),
                        label: const Text('الخلفية'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _color(2),
                        icon: Icon(Icons.circle, color: layer.outlineColor),
                        label: const Text('الحدود'),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('خلفية النص'),
                    value: layer.colorMode != LayerBackgroundMode.onlyColor,
                    onChanged: (v) => setState(
                      () => layer.colorMode = v
                          ? LayerBackgroundMode.backgroundAndColor
                          : LayerBackgroundMode.onlyColor,
                    ),
                  ),
                  _slider(
                    'حجم الخط',
                    layer.fontScale * 24,
                    6,
                    240,
                    (v) => layer.fontScale = v / 24,
                  ),
                  _slider(
                    'عرض المربع',
                    layer.maxTextWidth ?? 240,
                    30,
                    600,
                    (v) => layer.maxTextWidth = v,
                  ),
                  _slider(
                    'تباعد الحروف',
                    style.letterSpacing ?? 0,
                    -2,
                    20,
                    (v) => layer.textStyle = style.copyWith(letterSpacing: v),
                  ),
                  _slider(
                    'تباعد الأسطر',
                    style.height ?? 1.4,
                    .8,
                    3,
                    (v) => layer.textStyle = style.copyWith(height: v),
                  ),
                  _slider(
                    'سمك الحدود',
                    layer.outlineWidth,
                    0,
                    12,
                    (v) => layer.outlineWidth = v,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
