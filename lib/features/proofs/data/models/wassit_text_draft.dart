enum WassitTextSource {
  live,   // ✍️ saisie clavier
  upload, // 📄 fichier texte (upload universel)
}

class TextDraftHandle {
  /// Référence locale abstraite :
  /// - id symbolique (web)
  /// - ou path temporaire (mobile)
  final String reference;

  /// Source du texte
  final WassitTextSource source;

  /// Horodatage lisible (HH:mm:ss – intl)
  final DateTime createdAt;

  TextDraftHandle({
    required this.reference,
    required this.source,
    required this.createdAt,
  });
}

class WassitTextDraft {
  /// RÈGLES OFFICIELLES
  static const int maxLive = 1;   // 1 saisie manuelle active
  static const int maxUpload = 5; // 5 fichiers texte max

  final List<TextDraftHandle> _handles = [];

  /// Lecture seule
  List<TextDraftHandle> get handles =>
      List.unmodifiable(_handles);

  int get liveCount =>
      _handles.where((h) => h.source == WassitTextSource.live).length;

  int get uploadCount =>
      _handles.where((h) => h.source == WassitTextSource.upload).length;

  bool canAddLive() => liveCount < maxLive;

  bool canAddUpload() => uploadCount < maxUpload;

  void addLive(String reference) {
    if (!canAddLive()) return;

    // Une seule saisie live autorisée
    _handles.removeWhere(
      (h) => h.source == WassitTextSource.live,
    );

    _handles.add(
      TextDraftHandle(
        reference: reference,
        source: WassitTextSource.live,
        createdAt: DateTime.now(),
      ),
    );
  }

  void addUpload(String reference) {
    if (!canAddUpload()) return;

    _handles.add(
      TextDraftHandle(
        reference: reference,
        source: WassitTextSource.upload,
        createdAt: DateTime.now(),
      ),
    );
  }

  void removeByReference(String reference) {
    _handles.removeWhere(
      (h) => h.reference == reference,
    );
  }

  void clear() {
    _handles.clear();
  }

  /// Draft valide s’il contient au moins une intention texte
  bool get isValid => _handles.isNotEmpty;
}
