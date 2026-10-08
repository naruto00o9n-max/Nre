import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_image_editor/designs/frosted_glass/frosted_glass.dart';

import 'library_store.dart';
import '../features/design_examples/frosted_glass_example.dart';

const accent = Color(0xFFADB5FF);

class StudioHome extends StatelessWidget {
  const StudioHome({super.key, required this.library});
  final LibraryStore library;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF252841), Color(0xFF101218), Color(0xFF111E23)],
          stops: [0, .6, 1],
        ),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: library,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 28),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_outlined,
                      color: accent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مرسم',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'مساحة لأعمال المانهوا',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 42),
              const Text(
                'كل فصل،\nبلمستك.',
                style: TextStyle(
                  fontSize: 42,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'نظّم أعمالك وفصولك، واحتفظ بصورك الأصلية وتعديلاتك في مكان واحد.',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 28),
              FrostedGlassEffect(
                radius: BorderRadius.circular(24),
                color: const Color(0x338A91CB),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LibraryScreen(library: library),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(22),
                    child: Row(
                      children: [
                        Icon(
                          Icons.collections_bookmark_outlined,
                          size: 30,
                          color: accent,
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'معرض أعمالي',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'الأعمال · الفصول · المشاريع',
                                style: TextStyle(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_back_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'آخر المشاريع',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${library.recent.length} مشروع',
                    style: const TextStyle(color: Colors.white38),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (library.recent.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Text(
                    'ابدأ بإنشاء مجلد للعمل، ثم مجلد لكل فصل داخل المعرض.',
                    style: TextStyle(color: Colors.white38, height: 1.8),
                  ),
                ),
              for (final project in library.recent.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 50,
                      height: 58,
                      child: Image.file(
                        library.file(project.export ?? project.original!),
                        cacheWidth: 100,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.image_outlined),
                      ),
                    ),
                  ),
                  title: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${project.width} × ${project.height}',
                    textDirection: TextDirection.ltr,
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => openProject(context, library, project),
                ),
              const SizedBox(height: 20),
              const Text(
                'محفوظ على جهازك',
                style: TextStyle(color: Colors.white24),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> openProject(
  BuildContext context,
  LibraryStore library,
  LibraryNode project,
) async {
  try {
    final history = await library.state(project);
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrostedGlassExample(
          image: library.file(project.original!),
          library: library,
          project: project,
          history: history,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) showFailure(context, error);
  }
}

void showFailure(BuildContext context, Object error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر إكمال العملية: $error'),
        duration: const Duration(seconds: 6),
      ),
    );

Future<String?> askName(
  BuildContext context,
  String title, {
  String initial = '',
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'الاسم'),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) Navigator.pop(context, value.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  Future.delayed(const Duration(milliseconds: 400), controller.dispose);
  return result;
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.library, this.folder});
  final LibraryStore library;
  final LibraryNode? folder;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _busy = false;
  String _progress = '', _search = '';
  LibraryStore get library => widget.library;
  Future<void> _newFolder() async {
    final name = await askName(
      context,
      widget.folder == null ? 'مجلد عمل جديد' : 'مجلد جديد / فصل',
    );
    if (name == null) return;
    try {
      await library.createFolder(name, widget.folder?.id);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _import(bool files) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final List<(String, String)> selected;
      if (files) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: true,
        );
        selected =
            result?.files
                .where((f) => f.path != null)
                .map((f) => (f.path!, f.name))
                .toList() ??
            [];
      } else {
        final result = await ImagePicker().pickMultiImage();
        selected = result.map((f) => (f.path, f.name)).toList();
      }
      final errors = <String>[];
      for (var i = 0; i < selected.length; i++) {
        if (!mounted) break;
        setState(() => _progress = 'استيراد ${i + 1} من ${selected.length}');
        try {
          await library.importImage(
            File(selected[i].$1),
            selected[i].$2,
            widget.folder?.id,
          );
        } catch (error) {
          errors.add('${selected[i].$2}: $error');
        }
      }
      if (errors.isNotEmpty && mounted) showFailure(context, errors.join('\n'));
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = '';
        });
      }
    }
  }

  Future<void> _move(LibraryNode node) async {
    final destinations = library.nodes
        .where((n) => n.folder && !n.trashed && library.canMove(node, n.id))
        .toList();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'نقل إلى',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('جذر المعرض'),
              onTap: () => Navigator.pop(context, 'root'),
            ),
            for (final folder in destinations)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(folder.name),
                subtitle: Text(_path(folder)),
                onTap: () => Navigator.pop(context, folder.id),
              ),
          ],
        ),
      ),
    );
    if (choice != null) {
      await library.move(node, choice == 'root' ? null : choice);
    }
  }

  String _path(LibraryNode node) {
    final names = <String>[];
    String? parent = node.parent;
    while (parent != null) {
      final folder = library.nodes.firstWhere((n) => n.id == parent);
      names.insert(0, folder.name);
      parent = folder.parent;
    }
    return ['المعرض', ...names].join(' / ');
  }

  Future<void> _action(LibraryNode node, String action) async {
    try {
      if (action == 'rename') {
        final name = await askName(context, 'تغيير الاسم', initial: node.name);
        if (name != null) await library.rename(node, name);
      } else if (action == 'move') {
        await _move(node);
      } else {
        await library.trash(node);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('نُقل إلى المحذوفات'),
              action: SnackBarAction(
                label: 'تراجع',
                onPressed: () async {
                  await library.restore(node);
                },
              ),
            ),
          );
        }
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  void _trash() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => AnimatedBuilder(
      animation: library,
      builder: (context, _) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('المحذوفات — يمكن استعادتها')),
            for (final n in library.nodes.where((n) => n.trashed))
              ListTile(
                leading: Icon(
                  n.folder ? Icons.folder_outlined : Icons.image_outlined,
                ),
                title: Text(n.name),
                trailing: TextButton(
                  onPressed: () => library.restore(n),
                  child: const Text('استعادة'),
                ),
              ),
            if (!library.nodes.any((n) => n.trashed))
              const ListTile(title: Text('لا توجد عناصر محذوفة')),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.folder?.name ?? 'معرض أعمالي'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _trash,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'المحذوفات',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: library,
        builder: (context, _) {
          final items = library
              .children(widget.folder?.id)
              .where(
                (n) => n.name.toLowerCase().contains(_search.toLowerCase()),
              )
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.folder != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '${_path(widget.folder!)} / ${widget.folder!.name}',
                          style: const TextStyle(color: Colors.white38),
                          maxLines: 2,
                        ),
                      ),
                    TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        hintText: 'ابحث في هذا المجلد',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${items.where((n) => n.folder).length} مجلد · ${items.where((n) => !n.folder).length} صورة',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : _newFolder,
                          icon: const Icon(Icons.create_new_folder_outlined),
                          label: const Text('مجلد جديد'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_busy) ...[
                const LinearProgressIndicator(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(_progress),
                ),
              ],
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_open_rounded,
                              size: 72,
                              color: accent.withValues(alpha: .4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _search.isEmpty
                                  ? 'مساحة لفصل جديد'
                                  : 'لا توجد نتائج',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'أضف مجلدًا أو استورد صورك للبدء',
                              style: TextStyle(color: Colors.white38),
                            ),
                          ],
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: (constraints.maxWidth / 180)
                                    .floor()
                                    .clamp(2, 6),
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                childAspectRatio: .76,
                              ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _ProjectCard(
                              library: library,
                              node: item,
                              onAction: (action) => _action(item, action),
                              onTap: _busy
                                  ? null
                                  : () {
                                      if (item.folder) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LibraryScreen(
                                              library: library,
                                              folder: item,
                                            ),
                                          ),
                                        );
                                      } else {
                                        openProject(context, library, item);
                                      }
                                    },
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy
            ? null
            : () => showModalBottomSheet(
                context: context,
                showDragHandle: true,
                builder: (sheetContext) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(
                        title: Text(
                          'استيراد صور الفصل',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_outlined),
                        title: const Text('اختيار عدة صور'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _import(false);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.folder_open_outlined),
                        title: const Text('من تطبيق الملفات'),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _import(true);
                        },
                      ),
                    ],
                  ),
                ),
              ),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('إضافة صور'),
      ),
    ),
  );
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.library,
    required this.node,
    required this.onTap,
    required this.onAction,
  });
  final LibraryStore library;
  final LibraryNode node;
  final VoidCallback? onTap;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1B1F2B),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (node.folder)
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF333953), Color(0xFF212635)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.folder_rounded,
                        color: accent,
                        size: 64,
                      ),
                    ),
                  )
                else
                  Image.file(
                    library.file(node.export ?? node.original!),
                    cacheWidth: 220,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: onAction,
                      icon: const Icon(Icons.more_horiz, size: 22),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('تغيير الاسم'),
                        ),
                        PopupMenuItem(
                          value: 'move',
                          child: Text('نقل إلى مجلد'),
                        ),
                        PopupMenuItem(
                          value: 'trash',
                          child: Text('نقل إلى المحذوفات'),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!node.folder && node.revision != null)
                  const Positioned(
                    bottom: 8,
                    right: 8,
                    child: Chip(
                      label: Text(
                        'قابل للتعديل',
                        style: TextStyle(fontSize: 10),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  node.folder
                      ? '${library.children(node.id).length} عنصر'
                      : '${node.width} × ${node.height}',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textDirection: node.folder
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
