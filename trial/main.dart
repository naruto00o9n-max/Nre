import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'features/design_examples/frosted_glass_example.dart';
import 'features/design_examples/grounded_example.dart';
import 'features/design_examples/whatsapp_example.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TrialApp());
}

class TrialApp extends StatelessWidget {
  const TrialApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Pro Image Editor',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    builder: BotToastInit(),
    navigatorObservers: [BotToastNavigatorObserver()],
    home: const TrialHome(),
  );
}

class TrialHome extends StatefulWidget {
  const TrialHome({super.key});

  @override
  State<TrialHome> createState() => _TrialHomeState();
}

class _TrialHomeState extends State<TrialHome> {
  EditorImage _image = EditorImage(assetPath: 'assets/demo.png');
  String _imageName = 'صورة التجربة';
  bool _busy = false;

  Future<void> _pick(bool fromFiles) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      String? path;
      String? name;
      if (fromFiles) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        path = result?.files.single.path;
        name = result?.files.single.name;
      } else {
        final result = await ImagePicker().pickImage(source: ImageSource.gallery);
        path = result?.path;
        name = result?.name;
      }
      if (path != null && mounted) {
        final selected = File(path);
        if (!await selected.exists()) throw StateError('تعذر فتح ملف الصورة');
        if (!mounted) return;
        setState(() {
          _image = EditorImage(file: selected);
          _imageName = name ?? 'الصورة المختارة';
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر اختيار الصورة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _open(int design) {
    final Widget editor = switch (design) {
      0 => GroundedDesignExample(image: _image),
      1 => FrostedGlassExample(image: _image),
      _ => WhatsAppExample(image: _image),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => editor));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pro Image Editor')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('اختر صورتك ثم جرّب إحدى الواجهات الجاهزة.'),
          const SizedBox(height: 20),
          Text(_imageName, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('الصور'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('الملفات'),
              ),
              TextButton(
                onPressed: _busy ? null : () => setState(() {
                  _image = EditorImage(assetPath: 'assets/demo.png');
                  _imageName = 'صورة التجربة';
                }),
                child: const Text('صورة التجربة'),
              ),
            ],
          ),
          if (_busy) const LinearProgressIndicator(),
          const Divider(height: 40),
          for (final item in [
            (0, 'Grounded', Icons.grass_outlined),
            (1, 'Frosted Glass', Icons.auto_awesome_outlined),
            (2, 'WhatsApp', Icons.chat_outlined),
          ])
            ListTile(
              leading: Icon(item.$3),
              title: Text(item.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _open(item.$1),
            ),
        ],
      ),
    ),
  );
}
