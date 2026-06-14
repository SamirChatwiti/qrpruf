/// Enum for panel sections
enum PanelSection { autoFields, reportTemplate }

/// Model for expanded panel state
class ExpandedPanel {
  const ExpandedPanel({required this.index, required this.section});

  final int index;
  final PanelSection section;
}

/// Model for Gharad options
class GharadOption {
  const GharadOption({
    required this.title,
    required this.description,
    this.autoFields,
    this.reportTemplate,
    this.iconPath,
  });

  final String title;
  final String description;
  final String? autoFields;
  final String? reportTemplate;
  final String? iconPath;
}
