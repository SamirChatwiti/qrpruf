class ImageDraftHandle {
  final String reference;
  final DateTime createdAt;

  ImageDraftHandle({
    required this.reference,
    required this.createdAt,
  });
}

class WassitImageDraft {
  static const int maxLive = 3;
  static const int maxUpload = 5;

  final List<ImageDraftHandle> _handles = [];
  final List<String> _uploads = [];

  List<ImageDraftHandle> get handles => List.unmodifiable(_handles);
  List<String> get uploads => List.unmodifiable(_uploads);

  bool get isValid => _handles.isNotEmpty || _uploads.isNotEmpty;

  bool canAdd() => _handles.length < maxLive;
  bool canAddUpload() => _uploads.length < maxUpload;

  bool hasReference(String reference) {
    return _handles.any((h) => h.reference == reference) ||
        _uploads.contains(reference);
  }

  void addHandle(ImageDraftHandle handle) {
    if (!canAdd()) return;
    if (hasReference(handle.reference)) return;

    _handles.add(handle);
  }

  void add(String reference) {
    if (!canAdd()) return;
    if (hasReference(reference)) return;

    _handles.add(
      ImageDraftHandle(
        reference: reference,
        createdAt: DateTime.now(),
      ),
    );
  }

  void addUpload(String reference) {
    if (!canAddUpload()) return;
    if (hasReference(reference)) return;

    _uploads.add(reference);
  }

  void removeByReference(String reference) {
    _handles.removeWhere((h) => h.reference == reference);
    _uploads.removeWhere((u) => u == reference);
  }
}
