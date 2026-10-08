#!/usr/bin/env python3
"""Prepare official editor examples; keep editor UI and engine upstream-owned."""
from pathlib import Path
import plistlib
import shutil
import subprocess

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
shutil.copyfile(ROOT / 'trial/main.dart', APP / 'lib/main.dart')
shutil.rmtree(APP / 'test', ignore_errors=True)
(APP / 'test').mkdir()
shutil.copyfile(ROOT / 'trial/launcher_test.dart', APP / 'test/launcher_test.dart')
(APP / 'analysis_options.yaml').write_text('include: package:flutter_lints/flutter.yaml\n')

info = APP / 'ios/Runner/Info.plist'
if info.exists():
    with info.open('rb') as stream:
        settings = plistlib.load(stream)
    settings.update({
        'CFBundleDisplayName': 'Pro Image Editor',
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
print('Prepared official designs from Pro Image Editor 14.10.0; PNG export without the default 2000px cap.')
