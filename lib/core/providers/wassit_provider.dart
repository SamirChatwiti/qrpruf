import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qrpruf/features/proofs/data/models/draft.dart';
import 'package:geocoding/geocoding.dart';

class WassitState {
  final List<Draft> drafts;
  final Placemark? cachedLocation;
  final int sessionVideoSeconds;
  final int sessionAudioSeconds;
  final int sessionImageBytes;
  final int sessionVideoBytes;
  final int sessionAudioBytes;

  const WassitState({
    this.drafts = const [],
    this.cachedLocation,
    this.sessionVideoSeconds = 0,
    this.sessionAudioSeconds = 0,
    this.sessionImageBytes = 0,
    this.sessionVideoBytes = 0,
    this.sessionAudioBytes = 0,
  });

  bool get canAddPhoto => drafts.where((d) => d.type == MediaType.image).length < 3;
  bool get canAddVideo => drafts.where((d) => d.type == MediaType.video).length < 3;
  bool get canAddAudio => drafts.where((d) => d.type == MediaType.audio).length < 3;
  bool get canAddText => drafts.where((d) => d.type == MediaType.text).length < 3;

  WassitState copyWith({
    List<Draft>? drafts,
    Placemark? cachedLocation,
    int? sessionVideoSeconds,
    int? sessionAudioSeconds,
    int? sessionImageBytes,
    int? sessionVideoBytes,
    int? sessionAudioBytes,
  }) {
    return WassitState(
      drafts: drafts ?? this.drafts,
      cachedLocation: cachedLocation ?? this.cachedLocation,
      sessionVideoSeconds: sessionVideoSeconds ?? this.sessionVideoSeconds,
      sessionAudioSeconds: sessionAudioSeconds ?? this.sessionAudioSeconds,
      sessionImageBytes: sessionImageBytes ?? this.sessionImageBytes,
      sessionVideoBytes: sessionVideoBytes ?? this.sessionVideoBytes,
      sessionAudioBytes: sessionAudioBytes ?? this.sessionAudioBytes,
    );
  }
}

class WassitNotifier extends Notifier<WassitState> {
  static const _storage = FlutterSecureStorage();
  
  String get _draftKey {
    final user = Supabase.instance.client.auth.currentUser;
    return 'wassit_drafts_${user?.id ?? 'anonymous'}';
  }

  @override
  WassitState build() {
    _loadDrafts();
    return const WassitState();
  }

  Future<void> _loadDrafts() async {
    try {
      final jsonStr = await _storage.read(key: _draftKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = jsonDecode(jsonStr);
        final drafts = jsonList.map((j) => Draft.fromJson(j as Map<String, dynamic>)).toList();
        
        final todayUtc = DateTime.now().toUtc().toIso8601String().split('T')[0];
        final validDrafts = drafts.where((d) {
          return d.timestamp.toUtc().toIso8601String().split('T')[0] == todayUtc;
        }).toList();

        state = state.copyWith(drafts: validDrafts);
        
        if (validDrafts.length != drafts.length) {
          _saveDrafts(validDrafts);
        }
      }
    } catch (e) {
      debugPrint('Error loading drafts: $e');
    }
  }
  
  // ... rest of the methods remain same as they use 'state' ...
  Future<void> _saveDrafts(List<Draft> drafts) async {
    try {
      final jsonList = drafts.map((d) => d.toJson()).toList();
      await _storage.write(key: _draftKey, value: jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving drafts: $e');
    }
  }

  void addDraft(Draft draft, {Future<String?>? signatureFuture}) {
    if (draft.type == MediaType.image && !state.canAddPhoto) return;
    if (draft.type == MediaType.video && !state.canAddVideo) return;
    if (draft.type == MediaType.audio && !state.canAddAudio) return;
    if (draft.type == MediaType.text && !state.canAddText) return;

    final newDrafts = [...state.drafts, draft];
    state = state.copyWith(drafts: newDrafts);
    _saveDrafts(newDrafts);

    if (signatureFuture != null) {
      signatureFuture.then((signedPath) {
        if (signedPath != null) {
          updateDraft(draft.copyWith(transformedPath: signedPath));
        }
      });
    }
  }

  void removeDraft(String id) {
    final removed = state.drafts.where((d) => d.id == id).firstOrNull;
    if (removed != null) {
      final fileSize = _fileSizeSync(removed.transformedPath);
      if (removed.type == MediaType.video) {
        state = state.copyWith(
          sessionVideoSeconds: (state.sessionVideoSeconds - removed.durationSeconds).clamp(0, 99999),
          sessionVideoBytes: (state.sessionVideoBytes - fileSize).clamp(0, 999999999),
        );
      } else if (removed.type == MediaType.audio) {
        state = state.copyWith(
          sessionAudioSeconds: (state.sessionAudioSeconds - removed.durationSeconds).clamp(0, 99999),
          sessionAudioBytes: (state.sessionAudioBytes - fileSize).clamp(0, 999999999),
        );
      } else if (removed.type == MediaType.image) {
        state = state.copyWith(
          sessionImageBytes: (state.sessionImageBytes - fileSize).clamp(0, 999999999),
        );
      }
    }
    final newDrafts = state.drafts.where((d) => d.id != id).toList();
    state = state.copyWith(drafts: newDrafts);
    _saveDrafts(newDrafts);
  }

  int _fileSizeSync(String path) {
    try {
      return File(path).lengthSync();
    } catch (_) {
      return 0;
    }
  }

  void updateDraft(Draft updatedDraft) {
    final newDrafts = state.drafts.map((d) => d.id == updatedDraft.id ? updatedDraft : d).toList();
    state = state.copyWith(drafts: newDrafts);
    _saveDrafts(newDrafts);
  }

  void addSessionVideo(int seconds) {
    state = state.copyWith(sessionVideoSeconds: state.sessionVideoSeconds + seconds);
  }

  void removeSessionVideo(int seconds) {
    state = state.copyWith(
      sessionVideoSeconds: (state.sessionVideoSeconds - seconds).clamp(0, 99999),
    );
  }

  void addSessionAudio(int seconds) {
    state = state.copyWith(sessionAudioSeconds: state.sessionAudioSeconds + seconds);
  }

  void removeSessionAudio(int seconds) {
    state = state.copyWith(
      sessionAudioSeconds: (state.sessionAudioSeconds - seconds).clamp(0, 99999),
    );
  }

  void addSessionImageBytes(int bytes) {
    state = state.copyWith(sessionImageBytes: state.sessionImageBytes + bytes);
  }

  void removeSessionImageBytes(int bytes) {
    state = state.copyWith(sessionImageBytes: (state.sessionImageBytes - bytes).clamp(0, 999999999));
  }

  void addSessionVideoBytes(int bytes) {
    state = state.copyWith(sessionVideoBytes: state.sessionVideoBytes + bytes);
  }

  void removeSessionVideoBytes(int bytes) {
    state = state.copyWith(sessionVideoBytes: (state.sessionVideoBytes - bytes).clamp(0, 999999999));
  }

  void addSessionAudioBytes(int bytes) {
    state = state.copyWith(sessionAudioBytes: state.sessionAudioBytes + bytes);
  }

  void removeSessionAudioBytes(int bytes) {
    state = state.copyWith(sessionAudioBytes: (state.sessionAudioBytes - bytes).clamp(0, 999999999));
  }

  /// Removes only the submitted drafts (by ID) and resets session counters.
  /// Other drafts created during the day are preserved.
  void clearSubmittedDrafts(List<String> submittedIds) {
    final remaining = state.drafts.where((d) => !submittedIds.contains(d.id)).toList();
    state = state.copyWith(
      drafts: remaining,
      sessionVideoSeconds: 0,
      sessionAudioSeconds: 0,
      sessionImageBytes: 0,
      sessionVideoBytes: 0,
      sessionAudioBytes: 0,
    );
    _saveDrafts(remaining);
  }

  /// Clears everything (used on logout or explicit reset).
  void clearSession() {
    state = state.copyWith(
      drafts: [],
      sessionVideoSeconds: 0,
      sessionAudioSeconds: 0,
      sessionImageBytes: 0,
      sessionVideoBytes: 0,
      sessionAudioBytes: 0,
    );
    _storage.delete(key: _draftKey);
  }
  
  void setLocation(Placemark location) {
    state = state.copyWith(cachedLocation: location);
  }
}

final wassitProvider = NotifierProvider<WassitNotifier, WassitState>(() {
  return WassitNotifier();
});
