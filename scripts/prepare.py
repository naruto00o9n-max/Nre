#!/usr/bin/env python3
"""Prepare official editor examples; keep editor UI and engine upstream-owned."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import hashlib
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'upstream'
PIN = '8305f0f1d734c96fc3bfe1411e8104ec628753f7'
assert subprocess.check_output(['git', '-C', str(SOURCE), 'rev-parse', 'HEAD'], text=True).strip() == PIN
APP = ROOT / 'app'
FILES = [
    'core/constants/example_constants.dart',
    'core/mixin/example_helper.dart',
    'features/design_examples/grounded_example.dart',
    'features/design_examples/frosted_glass_example.dart',
    'features/design_examples/whatsapp_example.dart',
    'features/preview/preview_img.dart',
    'shared/widgets/demo_build_stickers.dart',
    'shared/widgets/pixel_transparent_painter.dart',
    'shared/widgets/prepare_image_widget.dart',
]
for relative in FILES:
    target = APP / 'lib' / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SOURCE / 'example/lib' / relative, target)

generation = '''imageGeneration: const ImageGenerationConfigs(
            outputFormat: OutputFormat.png,
            maxOutputSize: Size.infinite,
            cropToDrawingBounds: false,
            enableBackgroundGeneration: false,
          ),'''
for name in ['grounded_example.dart', 'frosted_glass_example.dart', 'whatsapp_example.dart']:
    path = APP / 'lib/features/design_examples' / name
    text = path.read_text()
    assert text.count('required this.url,') == 1
    assert text.count('final String url;') == 1
    assert text.count('ProImageEditor.network(') == 1
    assert text.count('widget.url,') == 1
    assert text.count('ProImageEditorConfigs(') == 1
    text = text.replace('required this.url,', 'required this.image,')
    text = text.replace('final String url;', 'final EditorImage image;')
    text = text.replace('ProImageEditor.network(', 'ProImageEditor.autoSource(')
    text = text.replace('widget.url,', 'editorImage: widget.image,')
    text = text.replace('ProImageEditorConfigs(', 'ProImageEditorConfigs(\n          ' + generation)
    path.write_text(text)

# Copy the offline sample and bundled font notices from the official example.
(APP / 'assets').mkdir(parents=True, exist_ok=True)
shutil.copyfile(SOURCE / 'example/assets/demo.png', APP / 'assets/demo.png')
shutil.copytree(SOURCE / 'example/assets/google_fonts', APP / 'assets/google_fonts', dirs_exist_ok=True)
shutil.copyfile(ROOT / 'trial/pubspec.yaml', APP / 'pubspec.yaml')
shutil.copyfile(ROOT / 'trial/pubspec.lock', APP / 'pubspec.lock')
shutil.copyfile(ROOT / 'trial/main.dart', APP / 'lib/main.dart')
shutil.copytree(ROOT / 'trial/studio', APP / 'lib/studio', dirs_exist_ok=True)
shutil.copyfile(ROOT / 'trial/studio_editor.dart', APP / 'lib/features/design_examples/frosted_glass_example.dart')
font_pin = '5e8a3ba899557829a76cfdac30fa512bda91d7ca'
font_specs = {
    'NotoSansArabic.ttf': ('notosansarabic/NotoSansArabic%5Bwdth,wght%5D.ttf', '63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e'),
    'NotoNaskhArabic.ttf': ('notonaskharabic/NotoNaskhArabic%5Bwght%5D.ttf', '67b5a525a661b607971fbd3f96a81b89d3a768e74534fca84f18ac97e6fab72f'),
}
for name, (relative, digest) in font_specs.items():
    font = ROOT / 'trial/fonts' / name
    if not font.exists():
        with urllib.request.urlopen(f'https://raw.githubusercontent.com/google/fonts/{font_pin}/ofl/{relative}') as response:
            font.write_bytes(response.read())
    assert hashlib.sha256(font.read_bytes()).hexdigest() == digest, f'Font integrity failure: {name}'
shutil.copytree(ROOT / 'trial/fonts', APP / 'assets/fonts', dirs_exist_ok=True)
shutil.rmtree(APP / 'test', ignore_errors=True)
(APP / 'test').mkdir()
shutil.copytree(ROOT / 'trial/tests', APP / 'test', dirs_exist_ok=True)
shutil.copytree(ROOT / 'trial/integration_test', APP / 'integration_test', dirs_exist_ok=True)
(APP / 'analysis_options.yaml').write_text('include: package:flutter_lints/flutter.yaml\n')

info = APP / 'ios/Runner/Info.plist'
if info.exists():
    with info.open('rb') as stream:
        settings = plistlib.load(stream)
    settings.update({
        'CFBundleDisplayName': 'مرسم',
        'NSPhotoLibraryUsageDescription': 'Select a photo to edit with Pro Image Editor.',
        'NSPhotoLibraryAddUsageDescription': 'Save the edited image to your photo library.',
    })
    with info.open('wb') as stream:
        plistlib.dump(settings, stream)

podfile = APP / 'ios/Podfile'
if podfile.exists():
    text = podfile.read_text()
    import re
    text = re.sub(r"^#?\s*platform :ios, '[^']+'", "platform :ios, '16.4'", text, flags=re.M)
    podfile.write_text(text)
project = APP / 'ios/Runner.xcodeproj/project.pbxproj'
if project.exists():
    import re
    project.write_text(re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 16.4;', project.read_text()))
# Apply a small, auditable patch to the pinned engine, idempotently.
def original(relative):
    return subprocess.check_output(['git', '-C', str(SOURCE), 'show', f'{PIN}:{relative}'], text=True)
controller = 'lib/shared/services/content_recorder/controllers/content_recorder_controller.dart'
text = original(controller)
text = "import '/shared/utils/streaming_png.dart';\nimport '/shared/widgets/extended/repaint/extended_render_repaint_boundary.dart';\n" + text
needle = '    outputFormat ??= _configs.outputFormat;\n    image ??= await getRawRenderedImage(imageInfos: imageInfos);'
assert text.count(needle) == 1
text = text.replace(needle, '''    outputFormat ??= _configs.outputFormat;
    if (image == null && !stateHistoryScreenshot && outputFormat == OutputFormat.png &&
        _configs.maxOutputSize == Size.infinite && _configs.cropToImageBounds) {
      final boundary = containerKey.currentContext?.findRenderObject();
      if (boundary is! ExtendedRenderRepaintBoundary) throw StateError('Missing export canvas');
      return captureStripPng(boundary, imageInfos);
    }
    image ??= await getRawRenderedImage(imageInfos: imageInfos);''')
(SOURCE / controller).write_text(text)
shutil.copyfile(ROOT / 'patches/streaming_png.dart', SOURCE / 'lib/shared/utils/streaming_png.dart')
# Pixel inspection must sample the original, not a thumbnail cached at fit size.
auto_image = 'lib/shared/widgets/auto_image.dart'
text = original(auto_image).replace('fit: fit,', 'fit: fit,\n          filterQuality: FilterQuality.none,')
(SOURCE / auto_image).write_text(text)
# Release transient decode handles promptly during undo / redo.
decode = 'lib/shared/utils/decode_image.dart'
text = original(decode).replace('  return ImageInfos(', '  decodedImage.dispose();\n  return ImageInfos(', 1)
(SOURCE / decode).write_text(text)
# UI platform selection follows Flutter's target platform (also testable),
# while file access still uses dart:io on native devices.
platform = 'lib/shared/utils/platform_info.dart'
text = original(platform).replace('(kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux)',
    '(kIsWeb || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux)')
text = text.replace("import '/core/platform/io/io_helper.dart';", '')
(SOURCE / platform).write_text(text)
print('Prepared Manhwa Studio on official frosted UI with strip PNG export.')
