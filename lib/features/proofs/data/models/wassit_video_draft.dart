enum WassitVideoSource {
  live,
  upload,
  screen,
}

class VideoDraftHandle {
  /// Référence abstraite locale
  /// (jamais interprétée ici)
  final String reference;

  /// Horodatage lisible (HH:mm:ss – intl)
  final DateTime createdAt;

  VideoDraftHandle({
    required this.reference,
    required this.createdAt,
  });
}

class WassitVideoDraft {
  /// Règles de quantité (doctrine officielle)
  static const int maxLive = 3;
  static const int maxUpload = 5;

  /// Source d’intention
  final WassitVideoSource source;

  /// Pointeurs abstraits uniquement
  final List<VideoDraftHandle> _handles = [];

  WassitVideoDraft({
    required this.source,
  });

  /// Handles exposés en lecture seule
  List<VideoDraftHandle> get handles => List.unmodifiable(_handles);

  /// Draft valide s’il contient au moins une intention
  bool get isValid => _handles.isNotEmpty;

  /// Règles d’ajout selon la source
  bool canAdd() {
    switch (source) {
      case WassitVideoSource.live:
      case WassitVideoSource.screen:
        return _handles.length < maxLive;
      case WassitVideoSource.upload:
        return _handles.length < maxUpload;
    }
  }

  /// Ajout d’une intention validée
  /// (la transformation QRpruf est supposée déjà faite)
  void addHandle(VideoDraftHandle handle) {
    if (!canAdd()) return;
    _handles.add(handle);
  }

  /// Suppression explicite d’une intention
  void removeByReference(String reference) {
    _handles.removeWhere((h) => h.reference == reference);
  }

  /// Suppression totale du draft
  void clear() {
    _handles.clear();
  }
}
