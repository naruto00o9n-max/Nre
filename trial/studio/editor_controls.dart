import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pro_image_editor/shared/widgets/layer/interaction_helper/layer_interaction_button.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_image_editor/core/models/layers/layer_interaction.dart';
import 'package:pro_image_editor/features/main_editor/services/layer_copy_manager.dart';
import 'package:pro_image_editor/designs/frosted_glass/frosted_glass.dart';

Future<void> showLayers(BuildContext context, ProImageEditorState editor) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xF2212532),
      builder: (_) => LayerPanel(editor: editor),
    );

class LayerPanel extends StatefulWidget {
  const LayerPanel({super.key, required this.editor});
  final ProImageEditorState editor;
  @override
  State<LayerPanel> createState() => _LayerPanelState();
}

class _LayerPanelState extends State<LayerPanel> {
  ProImageEditorState get editor => widget.editor;
  final copy = LayerCopyManager();
  Layer? _opacityOriginal;
  void _replace(Layer original, Layer changed) {
    editor.replaceLayer(
      index: editor.getLayerStackIndex(original),
      layer: changed,
    );
    setState(() {});
  }

  void _toggleVisibility(Layer layer) {
    final changed = copy.copyLayer(layer);
    final hidden = layer.meta?['studioHidden'] == true;
    changed.meta = {
      ...?layer.meta,
      'studioHidden': !hidden,
      'studioOpacity': hidden
          ? (layer.meta?['studioOpacity'] ?? 1.0)
          : layer.opacity,
    };
    changed.opacity = hidden
        ? (layer.meta?['studioOpacity'] as num? ?? 1).toDouble()
        : 0;
    changed.interaction = layer.interaction.copyWith();
    if (hidden && layer.meta?['studioInteraction'] is Map) {
      changed.interaction = LayerInteraction.fromMap(
        Map<String, dynamic>.from(layer.meta!['studioInteraction']),
      );
    } else if (!hidden) {
      changed.meta!['studioInteraction'] = layer.interaction.toMap();
      changed.interaction.toggleAll(false);
    }
    _replace(layer, changed);
  }

  void _lock(Layer layer) {
    final changed = copy.copyLayer(layer);
    changed.interaction = layer.interaction.copyWith();
    changed.interaction.toggleAll(!layer.interaction.enableMove);
    _replace(layer, changed);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'الطبقات',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${editor.activeLayers.length + 1}',
                  style: const TextStyle(color: Colors.white38),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    editor.openTextEditor();
                  },
                  icon: const Icon(Icons.text_fields),
                  tooltip: 'إضافة نص',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    editor.openPaintEditor();
                  },
                  icon: const Icon(Icons.brush_outlined),
                  tooltip: 'إضافة رسم',
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              itemCount: editor.activeLayers.length,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) {
                final length = editor.activeLayers.length;
                editor.moveLayerListPosition(
                  oldIndex: length - 1 - oldIndex,
                  newIndex: length - 1 - newIndex,
                );
                setState(() {});
              },
              itemBuilder: (context, row) {
                final index = editor.activeLayers.length - 1 - row;
                final layer = editor.activeLayers[index];
                final hidden = layer.meta?['studioHidden'] == true;
                final selected = editor.selectedLayer?.id == layer.id;
                final title = layer is TextLayer
                    ? layer.text
                    : layer is PaintLayer
                    ? 'رسم ${index + 1}'
                    : (layer.meta?['name'] as String? ?? 'عنصر ${index + 1}');
                return Container(
                  key: ValueKey(layer.id),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF394263)
                        : Colors.white.withValues(alpha: .04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFFADB5FF)
                          : Colors.transparent,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _toggleVisibility(layer),
                            icon: Icon(
                              hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white24),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              layer is TextLayer
                                  ? Icons.text_fields
                                  : layer is PaintLayer
                                  ? Icons.brush_outlined
                                  : Icons.image_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                editor.selectLayerByIndex(index);
                                setState(() {});
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: hidden ? null : () => _lock(layer),
                            icon: Icon(
                              layer.interaction.enableMove
                                  ? Icons.lock_open_outlined
                                  : Icons.lock_outline,
                            ),
                          ),
                          ReorderableDragStartListener(
                            index: row,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Icon(Icons.drag_handle),
                            ),
                          ),
                        ],
                      ),
                      if (selected) ...[
                        Row(
                          children: [
                            const SizedBox(width: 16),
                            Text('${(layer.opacity * 100).round()}%'),
                            Expanded(
                              child: Slider(
                                value: layer.opacity,
                                onChanged: hidden
                                    ? null
                                    : (v) {
                                        _opacityOriginal ??= copy.copyLayer(
                                          layer,
                                        );
                                        final changed = copy.copyLayer(layer)
                                          ..opacity = v;
                                        editor.replaceLayer(
                                          index: index,
                                          layer: changed,
                                          skipUpdateHistory: true,
                                        );
                                        setState(() {});
                                      },
                                onChangeEnd: hidden
                                    ? null
                                    : (v) {
                                        final original = _opacityOriginal;
                                        if (original == null) return;
                                        final changed = copy.copyLayer(
                                          editor.activeLayers[index],
                                        )..opacity = v;
                                        editor.replaceLayer(
                                          index: index,
                                          layer: original,
                                          skipUpdateHistory: true,
                                        );
                                        editor.replaceLayer(
                                          index: index,
                                          layer: changed,
                                        );
                                        editor.selectLayerByIndex(index);
                                        _opacityOriginal = null;
                                        setState(() {});
                                      },
                              ),
                            ),
                            IconButton(
                              tooltip: 'نسخ الطبقة',
                              onPressed: () {
                                editor.addLayer(
                                  copy.duplicateLayer(layer),
                                  autoCorrectZoomScale: false,
                                  autoCorrectZoomOffset: false,
                                );
                                setState(() {});
                              },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                            if (layer is TextLayer)
                              IconButton(
                                tooltip: 'تحرير النص',
                                onPressed: () {
                                  Navigator.pop(context);
                                  editor.editTextLayer(layer);
                                },
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            IconButton(
                              tooltip: 'حذف الطبقة',
                              onPressed: () {
                                editor.removeLayer(layer);
                                setState(() {});
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline),
            title: Text('الصورة الأصلية'),
            subtitle: Text('محفوظة مستقلة عن التعديلات'),
          ),
        ],
      ),
    ),
  );
}

LayerInteractionWidgets studioLayerWidgets(
  ProImageEditorState? Function() editor,
) => LayerInteractionWidgets(
  overlayChildBuilder: (stream, info, layer, actions) => ReactiveWidget(
    stream: stream,
    builder: (_) {
      final state = editor();
      if (state == null) return const SizedBox.shrink();
      final pad = state.configs.layerInteraction.style.overlayPadding;
      final rect = Rect.fromLTRB(
        pad.left,
        pad.top,
        info.childSize.width - pad.right,
        info.childSize.height - pad.bottom,
      );
      final points =
          [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft]
              .map(
                (p) => MatrixUtils.transformPoint(info.childPaintTransform, p),
              )
              .toList();
      Widget button(
        Offset point,
        IconData icon,
        String tooltip, {
        VoidCallback? tap,
        bool rotate = false,
      }) => Positioned(
        left: point.dx - 18,
        top: point.dy - 18,
        child: LayerInteractionButton(
          icon: icon,
          cursor: SystemMouseCursors.click,
          buttonRadius: 15,
          rotation: 0,
          tooltip: tooltip,
          color: Colors.white,
          background: const Color(0xFF202431),
          onTap: tap,
          onScaleRotateDown: rotate ? actions.scaleRotateDown : null,
          onScaleRotateUp: rotate ? actions.scaleRotateUp : null,
        ),
      );
      return Positioned.fill(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _LayerFrame(points)),
              ),
            ),
            button(points[0], Icons.close, 'حذف الطبقة', tap: actions.remove),
            if (layer is TextLayer)
              button(
                points[1],
                Icons.edit_outlined,
                'تحرير النص',
                tap: actions.edit,
              ),
            button(
              points[2],
              Icons.open_in_full,
              'تكبير / تدوير',
              rotate: true,
            ),
            if (layer is TextLayer)
              Positioned(
                left: (points[1].dx + points[2].dx) / 2 - 15,
                top: (points[1].dy + points[2].dy) / 2 - 17,
                child: TextWidthHandle(layer: layer, editor: state),
              ),
          ],
        ),
      );
    },
  ),
);

class _LayerFrame extends CustomPainter {
  _LayerFrame(this.points);
  final List<Offset> points;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFADB5FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _LayerFrame oldDelegate) => true;
}

class TextWidthHandle extends StatefulWidget {
  const TextWidthHandle({super.key, required this.layer, required this.editor});
  final TextLayer layer;
  final ProImageEditorState editor;
  @override
  State<TextWidthHandle> createState() => _TextWidthHandleState();
}

class _TextWidthHandleState extends State<TextWidthHandle> {
  TextLayer? original;
  double width = 0;
  int get index => widget.editor.getLayerStackIndex(widget.layer);
  @override
  Widget build(BuildContext context) => GestureInterceptor(
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        original = widget.layer.copyWith();
        width =
            widget.layer.maxTextWidth ??
            widget.layer.keyInternalSize.currentContext?.size?.width ??
            240;
      },
      onPanUpdate: (details) {
        if (original == null || index < 0) return;
        final scale = original!.scale * widget.editor.editorScaleFactor;
        final delta =
            (details.delta.dx * math.cos(original!.rotation) +
                details.delta.dy * math.sin(original!.rotation)) /
            scale;
        width = (width + delta).clamp(20, 2000);
        widget.editor.replaceLayer(
          index: index,
          layer: original!.copyWith(maxTextWidth: width),
          skipUpdateHistory: true,
        );
      },
      onPanEnd: (_) {
        if (original == null || index < 0) return;
        final i = index;
        final changed = original!.copyWith(maxTextWidth: width);
        widget.editor.replaceLayer(
          index: i,
          layer: original!,
          skipUpdateHistory: true,
        );
        widget.editor.replaceLayer(index: i, layer: changed);
        widget.editor.selectLayerByIndex(i);
        original = null;
      },
      onPanCancel: () {
        if (original != null && index >= 0) {
          widget.editor.replaceLayer(
            index: index,
            layer: original!,
            skipUpdateHistory: true,
          );
        }
        original = null;
      },
      child: Tooltip(
        message: 'عرض مربع النص',
        child: Container(
          width: 30,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFF202431),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFADB5FF)),
          ),
          child: const Icon(Icons.swap_horiz, size: 20),
        ),
      ),
    ),
  );
}

class WorkspaceTools extends StatelessWidget {
  const WorkspaceTools({
    super.key,
    required this.editor,
    required this.save,
    required this.addText,
    required this.showAddText,
    required this.dismissAddText,
    this.textPoint,
  });
  final ProImageEditorState editor;
  final VoidCallback save, addText, dismissAddText;
  final bool showAddText;
  final Offset? textPoint;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Stack(
      children: [
        Positioned(
          top: 82,
          left: 12,
          right: 12,
          child: Row(
            children: [
              FrostedGlassEffect(
                child: GestureInterceptor(
                  child: IconButton(
                    onPressed: () => showLayers(context, editor),
                    icon: const Icon(Icons.layers_outlined),
                    tooltip: 'الطبقات',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FrostedGlassEffect(
                child: GestureInterceptor(
                  child: IconButton(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined),
                    tooltip: 'حفظ المشروع',
                  ),
                ),
              ),
              const Spacer(),
              FrostedGlassEffect(
                child: GestureInterceptor(
                  child: IconButton(
                    tooltip: 'ملاءمة العرض',
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () {
                      final body = editor.sizesManager.bodySize;
                      final image = editor.sizesManager.decodedImageSize;
                      if (image.isEmpty) return;
                      final scale = (body.width / image.width).clamp(
                        .1,
                        4096.0,
                      );
                      editor.zoomTo(
                        scale: scale,
                        offset: Offset(body.width * (1 - scale) / 2, 0),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FrostedGlassEffect(
                child: GestureInterceptor(
                  child: IconButton(
                    onPressed: editor.resetZoom,
                    icon: const Icon(Icons.fit_screen),
                    tooltip: 'ملاءمة الصورة',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showAddText && !editor.hasSelectedLayers)
          Positioned(
            left: (textPoint?.dx ?? editor.sizesManager.bodySize.width / 2)
                .clamp(
                  12.0,
                  math.max(12.0, editor.sizesManager.bodySize.width - 190),
                ),
            top: (textPoint?.dy ?? editor.sizesManager.bodySize.height / 2)
                .clamp(
                  150.0,
                  math.max(150.0, editor.sizesManager.bodySize.height - 180),
                ),
            child: FrostedGlassEffect(
              radius: BorderRadius.circular(14),
              child: GestureInterceptor(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: addText,
                      icon: const Icon(Icons.text_fields),
                      label: const Text('إضافة نص'),
                    ),
                    IconButton(
                      onPressed: dismissAddText,
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          bottom: 100,
          right: 16,
          child: IgnorePointer(
            child: FrostedGlassEffect(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(
                _zoom(),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 12,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
  String _zoom() {
    final original = editor.sizesManager.originalImageSize ?? Size.zero;
    final body = editor.sizesManager.decodedImageSize;
    if (original.isEmpty || body.isEmpty) return '…';
    final fit = (body.width / original.width).clamp(
      0.0,
      body.height / original.height,
    );
    return '${((editor.interactiveViewer.currentState?.scaleFactor ?? 1) * fit * 100).toStringAsFixed(1)}%';
  }
}
