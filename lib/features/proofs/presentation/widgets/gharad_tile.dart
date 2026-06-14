import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/wassit_provider.dart';
import '../screens/selection/models.dart';

class GharadTile extends ConsumerStatefulWidget {
  const GharadTile({
    super.key,
    required this.option,
    required this.isChecked,
    required this.isDisabled,
    required this.expandedPanel,
    required this.index,
    required this.totalCount,
    required this.isCompact,
    required this.onCheckChanged,
    required this.onPanelTap,
  });

  final GharadOption option;
  final bool isChecked;
  final bool isDisabled;
  final ExpandedPanel? expandedPanel;
  final int index;
  final int totalCount;
  final bool isCompact;
  final ValueChanged<bool?> onCheckChanged;
  final void Function(int, PanelSection, bool) onPanelTap;

  @override
  ConsumerState<GharadTile> createState() => _GharadTileState();
}

class _GharadTileState extends ConsumerState<GharadTile> {
  final LayerLink _tooltipLink = LayerLink();
  OverlayEntry? _tooltipEntry;
  final List<PlatformFile> _optionFiles = [];
  String? _optionUploadError;

  late List<String> _autoFieldLabels;
  late List<TextEditingController> _autoFieldControllers;

  final TextEditingController _extraNatureController = TextEditingController();
  final TextEditingController _extraSourceController = TextEditingController();

  static const String _extraNatureHint =
      'إجراء مهني – تعليمات موكل – واقعة مؤثرة – ملاحظة قانونية – ظرف استعجالي – توضيح إضافي – أخرى';

  static const String _extraSourceHint =
      'الموكل – المحامي – طرف في النزاع – وثيقة رسمية – تصريح شفهي – ملاحظة مهنية';

  @override
  void initState() {
    super.initState();
    _syncAutoFields();
  }

  @override
  void didUpdateWidget(covariant GharadTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option.autoFields != widget.option.autoFields) {
      _syncAutoFields();
    }
  }

  @override
  void dispose() {
    _hideTooltip();
    for (final controller in _autoFieldControllers) {
      controller.dispose();
    }
    _extraNatureController.dispose();
    _extraSourceController.dispose();
    super.dispose();
  }

  void _syncAutoFields() {
    _autoFieldLabels = _parseAutoFields(widget.option.autoFields);
    _autoFieldControllers = List<TextEditingController>.generate(
      _autoFieldLabels.length,
      (_) => TextEditingController(),
    );
  }

  List<String> _parseAutoFields(String? autoFields) {
    if (autoFields == null || autoFields.trim().isEmpty) {
      return const [];
    }

    return autoFields
        .split('•')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  void _hideTooltip() {
    _tooltipEntry?.remove();
    _tooltipEntry = null;
  }

  void _toggleTooltip() {
    if (_tooltipEntry != null) {
      _hideTooltip();
      return;
    }

    _tooltipEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hideTooltip,
                  behavior: HitTestBehavior.translucent,
                ),
              ),
              CompositedTransformFollower(
                link: _tooltipLink,
                showWhenUnlinked: false,
                offset: const Offset(0, 28),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Row(
                        textDirection: TextDirection.rtl,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              widget.option.description,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _hideTooltip,
                            child: const Icon(
                              Icons.close,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_tooltipEntry!);
  }

  Future<void> _pickOptionFiles() async {
    if (_optionFiles.length >= 3) {
      setState(() {
        _optionUploadError = 'الحد الأقصى للمرفقات هو 3 ملفات.';
      });
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (!mounted) return;

    if (result == null || result.files.isEmpty) {
      setState(() {
        _optionUploadError = null;
      });
      return;
    }

    final allowed = {'pdf', 'doc', 'docx'};
    final selected = result.files.where((file) {
      final extension = file.extension?.toLowerCase();
      return extension != null && allowed.contains(extension);
    }).toList();

    if (selected.isEmpty) {
      setState(() {
        _optionUploadError = 'يرجى اختيار ملف PDF أو DOCX فقط.';
      });
      return;
    }

    setState(() {
      _optionUploadError = null;
      final remainingSlots = 3 - _optionFiles.length;
      _optionFiles.addAll(selected.take(remainingSlots));
      if (_optionFiles.length >= 3) {
        _optionUploadError = 'الحد الأقصى للمرفقات هو 3 ملفات.';
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final hasAutoFields = widget.option.autoFields?.isNotEmpty ?? false;
    final hasReportTemplate = widget.option.reportTemplate?.isNotEmpty ?? false;
    final showDescription = widget.option.description.isNotEmpty;
    final isReportExpanded = widget.expandedPanel?.index == widget.index &&
        widget.expandedPanel?.section == PanelSection.reportTemplate;
    final listItemTextStyle =
        Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12);

    final bool isExtraInfoOption = widget.index == widget.totalCount - 1;

    final wassitState = ref.watch(wassitProvider);
    final hasDrafts = wassitState.drafts.any((d) => d.intentions?.contains(widget.option.title) ?? false);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: widget.isChecked 
                ? Theme.of(context).primaryColor.withValues(alpha: 0.05) 
                : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isChecked 
                  ? Theme.of(context).primaryColor 
                  : Theme.of(context).dividerColor,
                width: 1.5,
              ),
              boxShadow: [
                if (widget.isChecked)
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: InkWell(
              onTap: widget.isDisabled
                  ? null
                  : () => widget.onCheckChanged(!widget.isChecked),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Selection Indicator (Far Right in RTL)
                        Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(6),
                          decoration: ShapeDecoration(
                            color: widget.isChecked
                                ? const Color(0xFFD4F3EC) // Surface-action-light
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                color: widget.isChecked
                                    ? const Color(0xFF5BBDB1) // Border-action
                                    : const Color(0xFFB8B8B8), // Border-default
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: widget.isChecked
                              ? Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const ShapeDecoration(
                                    color: Color(0xFF5BBDB1), // Surface-action
                                    shape: OvalBorder(),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),

                        // Title & Description Zone (Middle)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                widget.option.title,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: listItemTextStyle?.copyWith(
                                  color: const Color(0xFF111111), // Text-headings
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  height: 1.43,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                              if (showDescription) ...[
                                const SizedBox(height: 8),
                                Text(
                                  widget.option.description,
                                  textAlign: TextAlign.right,
                                  textDirection: TextDirection.rtl,
                                  style: listItemTextStyle?.copyWith(
                                    color: const Color(0xFF4B4B4B), // Text-body
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                    height: 1.17,
                                    fontFamily: 'Cairo',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Icon Container (Far Left in RTL)
                        Container(
                          width: 40,
                          height: 40,
                          padding: const EdgeInsets.all(10),
                          decoration: ShapeDecoration(
                            color: widget.isChecked
                                ? const Color(0xFFADE1D6) // Surface-action-hover-light-secondary
                                : const Color(0xFFF0F0F0), // Surface-secondary
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(1024),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              widget.option.iconPath != null
                                  ? SvgPicture.asset(
                                      widget.option.iconPath!,
                                      width: 24,
                                      height: 24,
                                      colorFilter: ColorFilter.mode(
                                        hasDrafts
                                            ? Colors.orange
                                            : (widget.isChecked
                                                ? const Color(0xFF21645F)
                                                : Theme.of(context).primaryColor),
                                        BlendMode.srcIn,
                                      ),
                                    )
                                  : Icon(
                                      Icons.attach_file,
                                      size: 20,
                                      color: hasDrafts
                                          ? Colors.orange
                                          : (widget.isChecked
                                              ? const Color(0xFF21645F)
                                              : Theme.of(context).primaryColor),
                                    ),
                              if (hasDrafts)
                                Positioned(
                                  top: -8,
                                  right: -8,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.lock, size: 10, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.isChecked) ...[
            if (_optionFiles.isNotEmpty) ...[
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _optionFiles
                    .map(
                      (file) => Row(
                        textDirection: TextDirection.rtl,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility_outlined, size: 20, color: Colors.blue),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 48),
                            onPressed: () async {
                              final path = file.path;
                              if (path != null) {
                                // Try using url_launcher for file
                                final uri = Uri.file(path);
                                try {
                                  await launchUrl(uri);
                                } catch (_) {
                                  // Fallback or ignore if no app handler
                                  debugPrint('Could not open file: $path');
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 48),
                            onPressed: () {
                              setState(() {
                                _optionFiles.remove(file);
                                if (_optionFiles.length < 3) {
                                  _optionUploadError = null;
                                }
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              file.name,
                              textAlign: TextAlign.right,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ],
            if (_optionUploadError != null) ...[
              const SizedBox(height: 6),
              Text(
                _optionUploadError!,
                textAlign: TextAlign.right,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
          if (hasAutoFields && widget.isChecked && !isExtraInfoOption)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_autoFieldLabels.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          _autoFieldLabels[index],
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: _autoFieldControllers[index],
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          if (hasReportTemplate)
            ExpandableSection(
              title: 'نموذج المحضر',
              isExpanded: isReportExpanded,
              onTap: () => widget.onPanelTap(
                widget.index,
                PanelSection.reportTemplate,
                hasReportTemplate,
              ),
              content: Text(
                widget.option.reportTemplate ?? '',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (isExtraInfoOption) ...[
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      '• طبيعة المعطى (اختياري):',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _extraNatureController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: Theme.of(context).textTheme.bodySmall,
                      keyboardType: TextInputType.multiline,
                      minLines: 2,
                      maxLines: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        hintText: _extraNatureHint,
                        hintMaxLines: 6,
                        hintStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      '• مصدر المعلومة (اختياري):',
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: TextField(
                      controller: _extraSourceController,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: Theme.of(context).textTheme.bodySmall,
                      keyboardType: TextInputType.multiline,
                      minLines: 2,
                      maxLines: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Theme.of(context).dividerColor),
                        ),
                        hintText: _extraSourceHint,
                        hintMaxLines: 6,
                        hintStyle: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ExpandableSection extends StatelessWidget {
  const ExpandableSection({
    super.key,
    required this.title,
    required this.content,
    required this.isExpanded,
    required this.onTap,
  });

  final String title;
  final Widget content;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.only(right: 8, left: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: onTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: content,
              ),
          ],
        ),
      ),
    );
  }
}
