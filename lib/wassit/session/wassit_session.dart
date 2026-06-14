import '../../features/proofs/data/models/wassit_audio_draft.dart';
import '../../features/proofs/data/models/wassit_image_draft.dart';
import '../../features/proofs/data/models/wassit_video_draft.dart';
import '../../features/proofs/data/models/wassit_text_draft.dart';

/// 🔒 WASSIT SESSION — SOURCE DE VÉRITÉ LOCALE
///
/// Projet : QRpruf
/// Système : WASSIT
/// Statut  : OFFICIEL / FIGÉ / FAIT FOI
///
/// RÔLE :
/// - Mémoire locale unique de la session WASSIT
/// - Volatile, non persistée
/// - Contient au maximum UN draft par type
/// - Aucune logique juridique
/// - Aucune logique backend
///
/// RÈGLES FONDAMENTALES :
/// - 1 type = 1 Draft maximum
/// - Un Draft peut être remplacé
/// - La session meurt avec l’app
/// - Tout est réversible
class WassitSession {
  WassitSession._internal();

  /// Singleton — UNE seule session active
  static final WassitSession instance = WassitSession._internal();

  // ─────────────────────────────────────────────
  // DRAFTS — UN PAR TYPE MAXIMUM
  // ─────────────────────────────────────────────

  /// AUDIO
  WassitAudioDraft? audioDraft;

  /// IMAGE
  WassitImageDraft? imageDraft;

  /// VIDÉO (live / upload / screen)
  WassitVideoDraft? videoDraft;

  /// TEXTE (live / upload txt|pdf|doc|docx)
  WassitTextDraft? textDraft;

  // ─────────────────────────────────────────────
  // SETTERS — REMPLACEMENT EXPLICITE
  // ─────────────────────────────────────────────

  void setAudioDraft(WassitAudioDraft draft) {
    audioDraft = draft;
  }

  void setImageDraft(WassitImageDraft draft) {
    imageDraft = draft;
  }

  void setVideoDraft(WassitVideoDraft draft) {
    videoDraft = draft;
  }

  void setTextDraft(WassitTextDraft draft) {
    textDraft = draft;
  }

  // ─────────────────────────────────────────────
  // CLEARERS — SUPPRESSION VOLONTAIRE
  // ─────────────────────────────────────────────

  void clearAudioDraft() {
    audioDraft = null;
  }

  void clearImageDraft() {
    imageDraft = null;
  }

  void clearVideoDraft() {
    videoDraft = null;
  }

  void clearTextDraft() {
    textDraft = null;
  }

  // ─────────────────────────────────────────────
  // ÉTAT GLOBAL — AU MOINS UN DRAFT VALIDE
  // ─────────────────────────────────────────────

  bool get hasAnyDraft =>
      (audioDraft?.isValid ?? false) ||
      (imageDraft?.isValid ?? false) ||
      (videoDraft?.isValid ?? false) ||
      (textDraft?.isValid ?? false);

  // ─────────────────────────────────────────────
  // RESET TOTAL — FIN DE SESSION
  // ─────────────────────────────────────────────

  void clearAll() {
    audioDraft = null;
    imageDraft = null;
    videoDraft = null;
    textDraft = null;
  }
}
