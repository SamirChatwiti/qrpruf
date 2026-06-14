enum AudioSource {
  live,
  upload,
}

class AudioDraftHandle {
  final AudioSource source;
  final String reference;

  /// Horodatage réel de la capture (local, non engageant)
  final DateTime createdAt;

  /// Préparation future (non engageante)
  final String? gpsInfo;
  final String? blockchainTimestamp;

  AudioDraftHandle({
    required this.source,
    required this.reference,
    required this.createdAt,
    this.gpsInfo,
    this.blockchainTimestamp,
  });
}

class WassitAudioDraft {
  /// RÈGLES OFFICIELLES
  static const int maxLiveSimultaneous = 1;
  static const int maxLiveSuccessive = 3;
  static const int maxUpload = 5;

  final List<AudioDraftHandle> _handles = [];

  List<AudioDraftHandle> get handles => List.unmodifiable(_handles);

  int get liveCount =>
      _handles.where((h) => h.source == AudioSource.live).length;

  int get uploadCount =>
      _handles.where((h) => h.source == AudioSource.upload).length;

  bool canAddLive() => liveCount < maxLiveSuccessive;

  bool canAddUpload() => uploadCount < maxUpload;

  void addLive(
    String reference, {
    String? gpsInfo,
    String? blockchainTimestamp,
  }) {
    if (!canAddLive()) return;

    _handles.add(
      AudioDraftHandle(
        source: AudioSource.live,
        reference: reference,
        createdAt: DateTime.now(),
        gpsInfo: gpsInfo,
        blockchainTimestamp: blockchainTimestamp,
      ),
    );
  }

  void addUpload(String reference) {
    if (!canAddUpload()) return;

    _handles.add(
      AudioDraftHandle(
        source: AudioSource.upload,
        reference: reference,
        createdAt: DateTime.now(),
      ),
    );
  }

  void remove(AudioDraftHandle handle) {
    _handles.remove(handle);
  }

  /// 🔒 Suppression par référence (utilisé par l’UI)
  void removeByReference(String reference) {
    _handles.removeWhere((h) => h.reference == reference);
  }

  bool get isValid => _handles.isNotEmpty;
}
