// Dart imports:
import 'dart:math';
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pro_image_editor/designs/frosted_glass/frosted_glass.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import 'package:flutter/services.dart';

import '/shared/widgets/demo_build_stickers.dart';

import 'package:example/studio/library_store.dart';
import 'package:example/studio/library_screen.dart';
import 'package:example/studio/text_panel.dart';
import 'package:example/studio/editor_controls.dart';
import 'package:example/studio/image_layers.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

/// The frosted glass design example
class FrostedGlassExample extends StatefulWidget {
  /// Creates a new [FrostedGlassExample] widget.
  const FrostedGlassExample({
    super.key,
    required this.image,
    required this.library,
    required this.project,
    this.history,
    this.enableAutosave = true,
  });

  /// The URL of the image to display.
  final File image;
  final LibraryStore library;
  final LibraryNode project;
  final String? history;
  final bool enableAutosave;

  @override
  State<FrostedGlassExample> createState() => _FrostedGlassExampleState();
}

class _FrostedGlassExampleState extends State<FrostedGlassExample> {
  final editorKey = GlobalKey<ProImageEditorState>();
  final platformDesignMode = ImageEditorDesignMode.material;
  final bool _useMaterialDesign = true;
  Timer? _autosave;
  Future<void>? _saving;
  bool _showAddText = false, _exported = false;
  Object? _exportError;
  Offset? _tapPoint, _newTextPoint;
  Future<TextLayer?> _createText() async {
    final point = _newTextPoint;
    _newTextPoint = null;
    final layer = await showTextPanel(context, widget.library);
    final editor = editorKey.currentState;
    if (layer != null && editor != null && point != null) {
      layer.offset =
          (point - editor.sizesManager.bodySize.center(Offset.zero)) /
          editor.editorScaleFactor;
    }
    return layer;
  }

  @override
  void initState() {
    super.initState();
    StudioFonts.load(widget.library).catchError((Object error) {
      if (mounted) showFailure(context, error);
    });
  }

  @override
  void dispose() {
    _autosave?.cancel();
    super.dispose();
  }

  void _scheduleSave() {
    if (!widget.enableAutosave) return;
    _autosave?.cancel();
    _autosave = Timer(const Duration(seconds: 1), () async {
      if (!mounted) return;
      try {
        await _save();
      } catch (error) {
        if (mounted) showFailure(context, error);
      }
    });
  }

  Future<void> _save({Uint8List? png, bool notify = false}) async {
    _autosave?.cancel();
    final previous = _saving ?? Future<void>.value();
    final editor = editorKey.currentState;
    if (editor == null) return;
    Future<void> write() async {
      final state = await editor.exportStateHistory(
        configs: const ExportEditorConfigs(
          historySpan: ExportHistorySpan.current,
          enableMinify: false,
        ),
      );
      await widget.library.save(widget.project, await state.toJson(), png: png);
    }

    final task = previous.catchError((Object _) {}).then((_) => write());
    _saving = task;
    try {
      await task;
      if (notify && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('حُفظ المشروع بطبقاته')));
      }
    } finally {
      if (_saving == task) _saving = null;
    }
  }

  Future<void> _complete(Uint8List bytes) async {
    try {
      await _save(png: bytes);
      _exported = true;
    } catch (error) {
      _exportError = error;
    }
  }

  Future<void> _close(EditorMode mode) async {
    if (mode != EditorMode.main) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      return;
    }
    if (_exportError != null) {
      final error = _exportError!;
      _exportError = null;
      if (mounted) showFailure(context, error);
      return;
    }
    if (_exported) {
      _exported = false;
      // Wait until the engine has removed its loading dialog before presenting.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (mounted) await _exportOptions();
      return;
    }
    try {
      await _save();
      if (mounted) {
        editorKey.currentState?.isPopScopeDisabled = true;
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _exportOptions() => showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            leading: Icon(
              Icons.check_circle_outline,
              color: Colors.greenAccent,
            ),
            title: Text('حُفظ المشروع وصُدّرت الصورة'),
            subtitle: Text('PNG — يمكنك العودة وتعديل الطبقات'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('حفظ في الصور'),
            onTap: () async {
              try {
                await Gal.putImage(
                  widget.library.file(widget.project.export!).path,
                );
                if (context.mounted) Navigator.pop(context);
              } catch (error) {
                if (context.mounted) showFailure(context, error);
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('مشاركة / حفظ في الملفات'),
            onTap: () async {
              final box = context.findRenderObject() as RenderBox?;
              try {
                await SharePlus.instance.share(
                  ShareParams(
                    files: [
                      XFile(widget.library.file(widget.project.export!).path),
                    ],
                    fileNameOverrides: [
                      '${widget.project.name.replaceAll(RegExp(r'\.[^.]+$'), '')}.png',
                    ],
                    sharePositionOrigin: box == null
                        ? null
                        : box.localToGlobal(Offset.zero) & box.size,
                  ),
                );
              } catch (error) {
                if (context.mounted) showFailure(context, error);
              }
            },
          ),
        ],
      ),
    ),
  );

  /// Opens the sticker/emoji editor.
  void _openStickerEditor(ProImageEditorState editor) async {
    try {
      await addImageLayer(context, widget.library, widget.project, editor);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  /// Calculates the number of columns for the EmojiPicker.
  int _calculateEmojiColumns(BoxConstraints constraints) => max(
    1,
    (_useMaterialDesign ? 6 : 10) / 400 * constraints.maxWidth - 1,
  ).floor();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = min(
          constraints.maxWidth / widget.project.width,
          constraints.maxHeight / widget.project.height,
        );
        final maxZoom = max(1.0, 126 / fit);
        return ProImageEditor.file(
          widget.image,
          key: editorKey,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: _complete,
            onCloseEditor: _close,
            mainEditorCallbacks: MainEditorCallbacks(
              onCreateTextLayer: _createText,
              onEditTextLayer: (layer) =>
                  showTextPanel(context, widget.library, layer: layer),
              onStateHistoryChange: (_, _) => _scheduleSave(),
              onTap: () => setState(() => _showAddText = !_showAddText),
              onScaleUpdate: (_) => setState(() => _showAddText = false),
              helperLines: HelperLinesCallbacks(
                onLineHit: HapticFeedback.selectionClick,
              ),
            ),
            stickerEditorCallbacks: StickerEditorCallbacks(
              onSearchChanged: (value) {
                /// Filter your stickers
                debugPrint(value);
              },
            ),
          ),
          configs: ProImageEditorConfigs(
            imageGeneration: const ImageGenerationConfigs(
              outputFormat: OutputFormat.png,
              maxOutputSize: Size.infinite,
              cropToDrawingBounds: false,
              enableBackgroundGeneration: false,
              enableUseOriginalBytes: false,
            ),
            stateHistory: StateHistoryConfigs(
              stateHistoryLimit: 60,
              initStateHistory: widget.history == null
                  ? null
                  : ImportStateHistory.fromJson(
                      widget.history!,
                      configs: ImportEditorConfigs(
                        widgetLoader: (id, {meta}) =>
                            restoreImageLayer(widget.library, id, meta: meta),
                      ),
                    ),
            ),
            designMode: platformDesignMode,
            theme: Theme.of(context).copyWith(
              iconTheme: Theme.of(context).iconTheme
                  .copyWith(color: Colors.white),
            ),
            mainEditor: MainEditorConfigs(
              enableZoom: true,
              editorMinScale: .1,
              editorMaxScale: maxZoom,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              style: const MainEditorStyle(background: Color(0xFF111318)),
              tools: [
                SubEditorMode.paint,
                SubEditorMode.text,
                SubEditorMode.cropRotate,
                SubEditorMode.tune,
                SubEditorMode.filter,
                SubEditorMode.blur,
                SubEditorMode.emoji,
                SubEditorMode.sticker,
              ],
              widgets: MainEditorWidgets(
                wrapBody: (_, _, content) => Listener(
                  onPointerDown: (event) => _tapPoint = event.localPosition,
                  child: content,
                ),
                closeWarningDialog: (editor) async {
                  try {
                    await _save();
                    return true;
                  } catch (error) {
                    if (context.mounted) showFailure(context, error);
                    return false;
                  }
                },
                appBar: (editor, rebuildStream) => null,
                bottomBar: (editor, rebuildStream, key) => null,
                bodyItems: _buildMainBodyWidgets,
              ),
            ),
            paintEditor: PaintEditorConfigs(
              enableZoom: true,
              editorMinScale: .1,
              editorMaxScale: maxZoom,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              icons: const PaintEditorIcons(bottomNavBar: Icons.edit),
              widgets: PaintEditorWidgets(
                appBar: (paintEditor, rebuildStream) => null,
                bottomBar: (paintEditor, rebuildStream) => null,
                colorPicker: (
                  paintEditor,
                  rebuildStream,
                  currentColor,
                  setColor,
                ) => null,
                bodyItems: _buildPaintEditorBody,
              ),
              style: const PaintEditorStyle(initialStrokeWidth: 5),
            ),
            textEditor: TextEditorConfigs(
              enableMainEditorZoomFactor: true,
              defaultTextStyle: const TextStyle(fontFamily: 'NotoSansArabic'),
              initialBackgroundColorMode: LayerBackgroundMode.onlyColor,
              customTextStyles: const [
                TextStyle(fontFamily: 'NotoSansArabic'),
                TextStyle(fontFamily: 'NotoNaskhArabic'),
              ],
              style: TextEditorStyle(
                textFieldMargin: const EdgeInsets.only(top: kToolbarHeight),
                bottomBarBackground: Colors.transparent,
                bottomBarMainAxisAlignment: !_useMaterialDesign
                    ? MainAxisAlignment.spaceEvenly
                    : MainAxisAlignment.start,
              ),
              widgets: TextEditorWidgets(
                appBar: (textEditor, rebuildStream) => null,
                colorPicker: (
                  textEditor,
                  rebuildStream,
                  currentColor,
                  setColor,
                ) => null,
                bottomBar: (textEditor, rebuildStream) => null,
                bodyItems: _buildTextEditorBody,
              ),
            ),
            cropRotateEditor: CropRotateEditorConfigs(
              widgets: CropRotateEditorWidgets(
                appBar: (cropRotateEditor, rebuildStream) => null,
                bottomBar: (cropRotateEditor, rebuildStream) => ReactiveWidget(
                  stream: rebuildStream,
                  builder: (_) => FrostedGlassCropRotateToolbar(
                    configs: cropRotateEditor.configs,
                    onCancel: cropRotateEditor.close,
                    onRotate: cropRotateEditor.rotate,
                    onDone: cropRotateEditor.done,
                    onReset: cropRotateEditor.reset,
                    openAspectRatios: cropRotateEditor.openAspectRatioOptions,
                  ),
                ),
              ),
            ),
            filterEditor: FilterEditorConfigs(
              style: const FilterEditorStyle(
                filterListSpacing: 7,
                filterListMargin: EdgeInsets.fromLTRB(8, 15, 8, 10),
              ),
              widgets: FilterEditorWidgets(
                slider:
                    (
                      editorState,
                      rebuildStream,
                      value,
                      onChanged,
                      onChangeEnd,
                    ) => ReactiveWidget(
                      stream: rebuildStream,
                      builder: (_) => Slider(
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                        value: value,
                        activeColor: Colors.blue.shade200,
                      ),
                    ),
                appBar: (filterEditor, rebuildStream) => null,
                bodyItems: (filterEditor, rebuildStream) => [
                  ReactiveWidget(
                    stream: rebuildStream,
                    builder: (_) =>
                        FrostedGlassFilterAppbar(filterEditor: filterEditor),
                  ),
                ],
              ),
            ),
            tuneEditor: TuneEditorConfigs(
              widgets: TuneEditorWidgets(
                appBar: (filterEditor, rebuildStream) => null,
                bottomBar: (filterEditor, rebuildStream) => null,
                bodyItems: _buildTuneEditorBody,
              ),
            ),
            blurEditor: BlurEditorConfigs(
              widgets: BlurEditorWidgets(
                slider:
                    (
                      editorState,
                      rebuildStream,
                      value,
                      onChanged,
                      onChangeEnd,
                    ) => ReactiveWidget(
                      stream: rebuildStream,
                      builder: (_) => Slider(
                        onChanged: onChanged,
                        onChangeEnd: onChangeEnd,
                        value: value,
                        max: editorState.configs.blurEditor.maxBlur,
                        activeColor: Colors.blue.shade200,
                      ),
                    ),
                appBar: (blurEditor, rebuildStream) => null,
                bodyItems: (blurEditor, rebuildStream) => [
                  ReactiveWidget(
                    stream: rebuildStream,
                    builder: (_) =>
                        FrostedGlassBlurAppbar(blurEditor: blurEditor),
                  ),
                ],
              ),
            ),
            emojiEditor: EmojiEditorConfigs(
              checkPlatformCompatibility: !kIsWeb,
              style: EmojiEditorStyle(
                backgroundColor: Colors.transparent,
                textStyle: DefaultEmojiTextStyle.copyWith(
                  fontFamily: !kIsWeb
                      ? null
                      : GoogleFonts.notoColorEmoji().fontFamily,
                  fontSize: _useMaterialDesign ? 48 : 30,
                ),
                emojiViewConfig: EmojiViewConfig(
                  gridPadding: EdgeInsets.zero,
                  horizontalSpacing: 0,
                  verticalSpacing: 0,
                  recentsLimit: 40,
                  backgroundColor: Colors.transparent,
                  buttonMode: !_useMaterialDesign
                      ? ButtonMode.CUPERTINO
                      : ButtonMode.MATERIAL,
                  loadingIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                  columns: _calculateEmojiColumns(constraints),
                  emojiSizeMax: !_useMaterialDesign ? 32 : 64,
                  replaceEmojiOnLimitExceed: false,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(
                  enabled: false,
                ),
              ),
            ),
            stickerEditor: StickerEditorConfigs(
              builder: (setLayer, scrollController) => DemoBuildStickers(
                setLayer: setLayer,
                scrollController: scrollController,
              ),
            ),
            layerInteraction: LayerInteractionConfigs(
              widgets: studioLayerWidgets(() => editorKey.currentState),
              enableMobilePinchScale: false,
              enableMobilePinchRotate: false,
              selectable: LayerInteractionSelectable.enabled,
              initialSelected: true,
              style: LayerInteractionStyle(
                borderColor: Color(0xFFADB5FF),
                buttonRadius: 15,
                removeAreaBackgroundInactive: Colors.black12,
              ),
            ),
            dialogConfigs: DialogConfigs(
              widgets: DialogWidgets(
                loadingDialog: (message, configs) => FrostedGlassLoadingDialog(
                  message: message,
                  configs: configs,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<ReactiveWidget> _buildMainBodyWidgets(
    ProImageEditorState editor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      if (!editor.isLayerBeingTransformed)
        ReactiveWidget(
          stream: rebuildStream,
          builder: (_) => FrostedGlassActionBar(
            editor: editor,
            openStickerEditor: () => _openStickerEditor(editor),
          ),
        ),
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => editor.isSubEditorOpen
            ? const SizedBox.shrink()
            : WorkspaceTools(
                editor: editor,
                save: () async {
                  try {
                    await _save(notify: true);
                  } catch (error) {
                    if (mounted) showFailure(context, error);
                  }
                },
                addText: () {
                  _newTextPoint = _tapPoint;
                  setState(() => _showAddText = false);
                  editor.openTextEditor();
                },
                showAddText: _showAddText,
                textPoint: _tapPoint,
                dismissAddText: () => setState(() => _showAddText = false),
              ),
      ),
    ];
  }

  List<ReactiveWidget> _buildPaintEditorBody(
    PaintEditorState paintEditor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      /// Appbar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) {
          return paintEditor.isActive
              ? const SizedBox.shrink()
              : FrostedGlassPaintAppbar(paintEditor: paintEditor);
        },
      ),

      /// Bottombar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => FrostedGlassPaintBottomBar(paintEditor: paintEditor),
      ),
    ];
  }

  List<ReactiveWidget> _buildTuneEditorBody(
    TuneEditorState tuneEditor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      /// Appbar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) {
          return FrostedGlassTuneAppbar(tuneEditor: tuneEditor);
        },
      ),

      /// Bottombar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => FrostedGlassTuneBottombar(tuneEditor: tuneEditor),
      ),
    ];
  }

  List<ReactiveWidget> _buildTextEditorBody(
    TextEditorState textEditor,
    Stream<dynamic> rebuildStream,
  ) {
    return [
      /// Background
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => const FrostedGlassEffect(
          radius: BorderRadius.zero,
          child: SizedBox.expand(),
        ),
      ),

      /// Slider Text size
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => Padding(
          padding: const EdgeInsets.only(top: kToolbarHeight),
          child: FrostedGlassTextSizeSlider(textEditor: textEditor),
        ),
      ),

      /// Appbar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) {
          return FrostedGlassTextAppbar(textEditor: textEditor);
        },
      ),

      /// Bottombar
      ReactiveWidget(
        stream: rebuildStream,
        builder: (_) => FrostedGlassTextBottomBar(
          configs: textEditor.configs,
          initColor: textEditor.primaryColor,
          onColorChanged: (color) {
            textEditor.primaryColor = color;
          },
          selectedStyle: textEditor.selectedTextStyle,
          onFontChange: textEditor.setTextStyle,
        ),
      ),
    ];
  }
}
