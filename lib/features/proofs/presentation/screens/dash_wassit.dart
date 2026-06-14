import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'dart:io';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:go_router/go_router.dart';

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/providers/gharad_provider.dart';
import '../../../../core/providers/wassit_provider.dart';
import '../../../../core/services/proof_service.dart';
import '../../../../core/services/native_video_recorder.dart';
import '../../data/models/draft.dart';
import '../widgets/wassit_step_indicator.dart';

enum WassitLiveKind {
  audio,
  image,
  video,
  text,
}

class DashWassitPage extends ConsumerStatefulWidget {
  const DashWassitPage({super.key});

  @override
  ConsumerState<DashWassitPage> createState() => _DashWassitPageState();
}

class _DashWassitPageState extends ConsumerState<DashWassitPage> {
  WassitLiveKind _activeLive = WassitLiveKind.image;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  final TextEditingController _textController = TextEditingController();

  int _currentAudioLimitSeconds = 120;
  int _audioElapsed = 0;
  Timer? _audioDisplayTimer;
  final Stopwatch _audioStopwatch = Stopwatch();

  File? _capturedFile;
  MediaType? _capturedType;
  bool _isSaving = false;
  String? _cameraError;
  int _lastChargedVideoSeconds = 0;
  int _lastChargedAudioSeconds = 0;
  int _lastChargedImageBytes = 0;
  int _lastChargedVideoBytes = 0;
  int _lastChargedAudioBytes = 0;

  VideoPlayerController? _videoPlayerController;
  bool _videoPreviewInitialized = false;
  final AudioPlayer _previewAudioPlayer = AudioPlayer();
  bool _isPreviewAudioPlaying = false;
  @override
  void initState() {
    super.initState();
    _initCamera();
    _warmUpGps();
  }

  Future<void> _warmUpGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
      await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
    } catch (_) {}
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        _cameraController = CameraController(
          cameras[0],
          ResolutionPreset.medium,
          enableAudio: true,
          fps: 24,
          videoBitrate: 1000000,
          audioBitrate: 64000,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() => _isCameraInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera Initialization Error: $e');
      if (mounted) setState(() => _cameraError = 'تعذّر تشغيل الكاميرا.\nتحقق من صلاحيات الكاميرا في الإعدادات.');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _audioRecorder.dispose();
    _textController.dispose();
    _audioDisplayTimer?.cancel();
    _videoPlayerController?.dispose();
    _previewAudioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initVideoPreview(String path) async {
    try {
      await _videoPlayerController?.dispose();
      _videoPlayerController = VideoPlayerController.file(File(path));
      await _videoPlayerController!.initialize();
    } catch (e) {
      debugPrint('Video preview init error: $e');
      _videoPlayerController = null;
    }
    if (mounted) setState(() => _videoPreviewInitialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null && _capturedType != null) {
      return _buildReviewUI();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const WassitStepIndicator(activeStep: 2),
            Expanded(
              child: Stack(
                children: [
                   _buildContentArea(),
                   _buildCaptureControls(),
                ],
              ),
            ),
            _buildSkipButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(bottom: BorderSide(width: 0.50, color: Color(0xFF282828))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white, size: 24),
            onPressed: () {
              final drafts = ref.read(wassitProvider).drafts;
              if (drafts.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('لا توجد وسائط للمشاركة بعد', style: TextStyle(fontFamily: 'Cairo')),
                ));
                return;
              }
              Share.share('جلسة توثيق QRpruf — ${drafts.length} عنصر');
            },
          ),
          const Text(
            'إضافة وسائط داعمة',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Color(0xFFF9F9F9),
              fontSize: 20,
              fontFamily: 'Cairo',
              fontWeight: FontWeight.w500,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea() {
    if (_activeLive == WassitLiveKind.image || _activeLive == WassitLiveKind.video) {
      if (_cameraError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, color: Colors.red, size: 56),
                const SizedBox(height: 16),
                Text(_cameraError!, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 14, height: 1.6)),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () { setState(() => _cameraError = null); _initCamera(); },
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5BBDB1), foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        );
      }
      if (!_isCameraInitialized) return const Center(child: CircularProgressIndicator(color: Color(0xFF319B8F)));
      return CameraPreview(_cameraController!);
    }
    
    if (_activeLive == WassitLiveKind.text) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: const Color(0xFF121212),
        child: TextField(
          controller: _textController,
          maxLines: 15,
          style: const TextStyle(color: Colors.white, fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'أدخل النص هنا...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            border: InputBorder.none,
          ),
        ),
      );
    }
    
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isRecording && _activeLive == WassitLiveKind.audio) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildAudioRecordingOverlay(),
              ),
              const SizedBox(height: 24),
            ],
            Icon(Icons.mic, size: 80, color: _isRecording ? Colors.red : Colors.white24),
            if (_isRecording && _activeLive == WassitLiveKind.audio)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('جاري التسجيل...', style: TextStyle(color: Colors.red, fontFamily: 'Cairo')),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMainAction() async {
    final allowance = _packAllowance();
    if (!(allowance[_activeLive] ?? true)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'هذه الميزة غير متاحة في باقتك الحالية. قم بترقية الباقة للوصول إليها.',
          textAlign: TextAlign.right,
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.red[800],
        action: SnackBarAction(
          label: 'ترقية',
          textColor: Colors.white,
          onPressed: () => context.push('/pack'),
        ),
      ));
      return;
    }
    switch (_activeLive) {
      case WassitLiveKind.image:
        await _takePhoto();
        break;
      case WassitLiveKind.video:
        await _toggleVideo();
        break;
      case WassitLiveKind.audio:
        await _toggleAudio();
        break;
      case WassitLiveKind.text:
        await _saveText();
        break;
    }
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_isCameraInitialized) return;
    try {
      final image = await _cameraController!.takePicture();
      final sizeBytes = File(image.path).lengthSync();
      final sessionBytesUsed = ref.read(wassitProvider).sessionImageBytes;
      final remainingBytes = await ProofService().getRemainingQuotaBySize(
        MediaType.image, sessionBytesUsed: sessionBytesUsed,
      );
      if (!mounted) return;
      if (sizeBytes > remainingBytes) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('تم استنفاد الحصة اليومية للصور (10 MB). يتجدد الحد غداً.',
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      ref.read(wassitProvider.notifier).addSessionImageBytes(sizeBytes);
      _lastChargedImageBytes = sizeBytes;
      setState(() {
         _capturedFile = File(image.path);
         _capturedType = MediaType.image;
      });
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
       }
    }
  }

  static const double _maxVideoMB = 50.0;
  static const double _maxAudioMB = 2.0;

  Future<String> _applyVideoSizeLimit(String path) async {
    final sizeMB = File(path).lengthSync() / (1024 * 1024);
    if (sizeMB <= _maxVideoMB) return path;
    try {
      final info = await VideoCompress.getMediaInfo(path);
      final durationSec = ((info.duration ?? 0) / 1000);
      if (durationSec > 0) {
        final targetSeconds = (durationSec * (_maxVideoMB / sizeMB)).floor().clamp(1, 3600);
        return await ProofService().trimMedia(path, targetSeconds);
      }
    } catch (_) {}
    return path;
  }

  Future<String> _applyAudioSizeLimit(String path) async {
    final sizeMB = File(path).lengthSync() / (1024 * 1024);
    if (sizeMB <= _maxAudioMB) return path;
    try {
      final info = await VideoCompress.getMediaInfo(path);
      final durationSec = ((info.duration ?? 0) / 1000);
      if (durationSec > 0) {
        final targetSeconds = (durationSec * (_maxAudioMB / sizeMB)).floor().clamp(1, 3600);
        final trimmed = await ProofService().trimMedia(path, targetSeconds);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'تم اقتصاص الصوت تلقائياً — ${targetSeconds}ث محفوظة (الحد ${_maxAudioMB.toInt()} MB)',
              style: const TextStyle(fontFamily: 'Cairo'),
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ));
        }
        return trimmed;
      }
    } catch (_) {}
    return path;
  }

  String _nextMidnight() {
    final now = DateTime.now();
    final reset = DateTime(now.year, now.month, now.day + 1);
    final h = reset.hour.toString().padLeft(2, '0');
    final m = reset.minute.toString().padLeft(2, '0');
    final d = reset.day.toString().padLeft(2, '0');
    final mo = reset.month.toString().padLeft(2, '0');
    return '$h:$m — $d/$mo/${reset.year}';
  }

  Future<void> _toggleVideo() async {
    // Video recording is handled entirely by the native activity — no in-app toggle state.
    final sessionUsed = ref.read(wassitProvider).sessionVideoSeconds;
    final sessionBytesUsed = ref.read(wassitProvider).sessionVideoBytes;
    final remainingSec = await ProofService().getRemainingVideoSeconds(
      sessionSecondsUsed: sessionUsed, sessionBytesUsed: sessionBytesUsed,
    );
    if (!mounted) return;

    if (remainingSec <= 0) {
      final reset = _nextMidnight();
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تم استنفاد الحصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text(
            'لقد وصلت إلى الحد اليومي للفيديو.\n\nسيتم تجديد الحصة في:\n$reset',
            style: const TextStyle(fontFamily: 'Cairo', height: 1.7),
            textAlign: TextAlign.right,
          ),
          actions: [ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')))],
        ),
      );
      return;
    }

    // Launch native 720p camera activity — it shows its own UI and returns a file path.
    final videoPath = await NativeVideoRecorder.recordVideo(maxSeconds: remainingSec);
    if (!mounted || videoPath == null) return;

    // Get actual duration from the recorded file.
    int elapsed = 0;
    try {
      final info = await VideoCompress.getMediaInfo(videoPath);
      elapsed = ((info.duration ?? 0) / 1000).ceil().clamp(1, remainingSec);
    } catch (_) {
      elapsed = 1;
    }

    ref.read(wassitProvider.notifier).addSessionVideo(elapsed);
    _lastChargedVideoSeconds = elapsed;

    final finalPath = await _applyVideoSizeLimit(videoPath);
    final videoSizeBytes = File(finalPath).lengthSync();
    ref.read(wassitProvider.notifier).addSessionVideoBytes(videoSizeBytes);
    _lastChargedVideoBytes = videoSizeBytes;

    setState(() {
      _capturedFile = File(finalPath);
      _capturedType = MediaType.video;
      _videoPreviewInitialized = false;
    });
    _initVideoPreview(finalPath);
  }

  Future<void> _toggleAudio() async {
    if (_isRecording) {
      _audioDisplayTimer?.cancel();
      _audioStopwatch.stop();
      final path = await _audioRecorder.stop();
      if (path != null) {
        final elapsed = _audioStopwatch.elapsed.inSeconds.clamp(1, _currentAudioLimitSeconds);
        ref.read(wassitProvider.notifier).addSessionAudio(elapsed);
        _lastChargedAudioSeconds = elapsed;
        final audioPath = await _applyAudioSizeLimit(path);
        final audioSizeBytes = File(audioPath).lengthSync();
        ref.read(wassitProvider.notifier).addSessionAudioBytes(audioSizeBytes);
        _lastChargedAudioBytes = audioSizeBytes;
        setState(() {
          _isRecording = false;
          _capturedFile = File(audioPath);
          _capturedType = MediaType.audio;
        });
      } else {
        setState(() => _isRecording = false);
      }
    } else {
      final sessionUsed = ref.read(wassitProvider).sessionAudioSeconds;
      final sessionBytesUsed = ref.read(wassitProvider).sessionAudioBytes;
      final remainingSec = await ProofService().getRemainingAudioSeconds(
        sessionSecondsUsed: sessionUsed, sessionBytesUsed: sessionBytesUsed,
      );
      if (!mounted) return;

      if (remainingSec <= 0) {
        final reset = _nextMidnight();
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('تم استنفاد الحصة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.red)),
            content: Text(
              'لقد وصلت إلى الحد اليومي للصوت.\n\nسيتم تجديد الحصة في:\n$reset',
              style: const TextStyle(fontFamily: 'Cairo', height: 1.7),
              textAlign: TextAlign.right,
            ),
            actions: [ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('حسناً', style: TextStyle(fontFamily: 'Cairo')))],
          ),
        );
        return;
      }

      final audioLimitMin = remainingSec ~/ 60;
      final audioLimitSec = remainingSec % 60;
      final audioLimitStr = audioLimitMin > 0
          ? '$audioLimitMin د ${audioLimitSec > 0 ? '$audioLimitSec ث' : ''}'.trim()
          : '$remainingSec ثانية';
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('تنبيه قبل التسجيل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
          content: Text(
            'الحد الأقصى للتسجيل هو $audioLimitStr.\n\nسيتوقف التسجيل تلقائياً عند الوصول إلى الحد ويتم حفظ الصوت.',
            style: const TextStyle(fontFamily: 'Cairo', height: 1.6),
            textAlign: TextAlign.right,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.mic),
              label: const Text('ابدأ التسجيل', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      if (await _audioRecorder.hasPermission()) {
        _currentAudioLimitSeconds = remainingSec;
        _audioElapsed = 0;
        _audioStopwatch.reset();
        _audioStopwatch.start();
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);

        Timer(Duration(seconds: remainingSec), () async {
          if (!mounted || !_isRecording) return;
          _audioDisplayTimer?.cancel();
          _audioStopwatch.stop();
          try {
            final recordedPath = await _audioRecorder.stop();
            if (!mounted) return;
            final elapsed = _audioStopwatch.elapsed.inSeconds.clamp(1, _currentAudioLimitSeconds);
            ref.read(wassitProvider.notifier).addSessionAudio(elapsed);
            _lastChargedAudioSeconds = elapsed;
            if (recordedPath != null) {
              final audioAutoPath = await _applyAudioSizeLimit(recordedPath);
              final audioAutoSizeBytes = File(audioAutoPath).lengthSync();
              ref.read(wassitProvider.notifier).addSessionAudioBytes(audioAutoSizeBytes);
              _lastChargedAudioBytes = audioAutoSizeBytes;
              setState(() {
                _isRecording = false;
                _capturedFile = File(audioAutoPath);
                _capturedType = MediaType.audio;
              });
            } else {
              setState(() => _isRecording = false);
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('انتهى الوقت — تم حفظ الصوت. الحد الأقصى للتسجيل دقيقتان.', style: TextStyle(fontFamily: 'Cairo')),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ));
          } catch (e) {
            debugPrint('Auto-stop audio error: $e');
          }
        });

        _audioDisplayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_isRecording) return;
          setState(() => _audioElapsed = _audioStopwatch.elapsed.inSeconds.clamp(0, _currentAudioLimitSeconds));
        });
      }
    }
  }

  Future<void> _saveText() async {
    if (_textController.text.isEmpty) return;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/text_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString(_textController.text);
    setState(() {
       _capturedFile = file;
       _capturedType = MediaType.text;
    });
  }

  Future<void> _saveDraft(File file, MediaType type) async {
    setState(() => _isSaving = true);
    try {
      final gharadState = ref.read(gharadProvider);
      String role = gharadState.selectedFunction ?? '';
      if (role == 'مفوض قضائي' && gharadState.isAssistantMode) role = 'مساعد مفوض';

      final proofService = ProofService();
      final draft = await proofService.createDraftFromMedia(
        file,
        type,
        intentions: gharadState.selectedGharad.toList(),
        role: role,
        knownDurationSeconds: null, // video duration resolved via VideoCompress.getMediaInfo
      );

      final quotaError = await proofService.checkDailyQuota(
        draft.type,
        durationSeconds: draft.durationSeconds,
      );
      if (quotaError != null) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(quotaError, style: const TextStyle(fontFamily: 'Cairo')),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 5),
          ));
        }
        return;
      }

      ref.read(wassitProvider.notifier).addDraft(draft);
      
      if (_capturedType == MediaType.text) _textController.clear();
      
      setState(() {
         _capturedFile = null;
         _capturedType = null;
         _isSaving = false;
      });

      if (mounted) context.push('/summary');
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo'))));
      }
    }
  }

  Widget _buildReviewUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('معاينة الوسيط', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: _isSaving 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF5BBDB1)))
        : SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildReviewContent()),
                _buildSizeBadge(),
                Padding(
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 32),
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(
                         onPressed: () {
                           if (_capturedType == MediaType.video) {
                             if (_lastChargedVideoSeconds > 0) {
                               ref.read(wassitProvider.notifier).removeSessionVideo(_lastChargedVideoSeconds);
                               _lastChargedVideoSeconds = 0;
                             }
                             if (_lastChargedVideoBytes > 0) {
                               ref.read(wassitProvider.notifier).removeSessionVideoBytes(_lastChargedVideoBytes);
                               _lastChargedVideoBytes = 0;
                             }
                           } else if (_capturedType == MediaType.audio) {
                             if (_lastChargedAudioSeconds > 0) {
                               ref.read(wassitProvider.notifier).removeSessionAudio(_lastChargedAudioSeconds);
                               _lastChargedAudioSeconds = 0;
                             }
                             if (_lastChargedAudioBytes > 0) {
                               ref.read(wassitProvider.notifier).removeSessionAudioBytes(_lastChargedAudioBytes);
                               _lastChargedAudioBytes = 0;
                             }
                           } else if (_capturedType == MediaType.image && _lastChargedImageBytes > 0) {
                             ref.read(wassitProvider.notifier).removeSessionImageBytes(_lastChargedImageBytes);
                             _lastChargedImageBytes = 0;
                           }
                           _videoPlayerController?.dispose();
                           _videoPlayerController = null;
                           _previewAudioPlayer.stop();
                           setState(() {
                             _capturedFile = null;
                             _capturedType = null;
                             _videoPreviewInitialized = false;
                             _isPreviewAudioPlaying = false;
                           });
                         },
                         style: OutlinedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           foregroundColor: const Color(0xFF5BBDB1),
                           side: const BorderSide(color: Color(0xFF5BBDB1))
                         ),
                         child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700))
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton(
                         onPressed: () => _saveDraft(_capturedFile!, _capturedType!), 
                         style: ElevatedButton.styleFrom(
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           backgroundColor: const Color(0xFF5BBDB1),
                           foregroundColor: Colors.black,
                         ),
                         child: const Text('حفظ الوسيط', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w700))
                      )),
                    ],
                  ),
                )
              ],
            ),
          ),
    );
  }

  Widget _buildSizeBadge() {
    if (_capturedFile == null || _capturedType == null || _capturedType == MediaType.text) {
      return const SizedBox.shrink();
    }
    try {
      final sizeMB = _capturedFile!.lengthSync() / (1024 * 1024);
      if (_capturedType == MediaType.image) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF1A1A1A),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.photo_size_select_large, color: Colors.white54, size: 14),
              const SizedBox(width: 6),
              Text(
                '${sizeMB.toStringAsFixed(1)} MB',
                style: const TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 12),
              ),
            ],
          ),
        );
      }
      final double limitMB = _capturedType == MediaType.video ? 50.0 : 2.0;
      final bool isOk = sizeMB <= limitMB;
      final Color color = isOk ? const Color(0xFF27AE60) : Colors.red;
      final String label = isOk
          ? 'الحجم مناسب — ${sizeMB.toStringAsFixed(1)} MB'
          : 'الحجم كبير! ${sizeMB.toStringAsFixed(1)} MB (الحد ${limitMB.toInt()} MB)';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF1A1A1A),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isOk ? Icons.check_circle_outline : Icons.warning_amber_rounded, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  Widget _buildReviewContent() {
    if (_capturedType == MediaType.image) {
      return Center(child: Image.file(_capturedFile!));
    } else if (_capturedType == MediaType.text) {
      return Container(
        color: const Color(0xFF121212),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Text(
            _capturedFile!.readAsStringSync(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Cairo'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (_capturedType == MediaType.video) {
      if (!_videoPreviewInitialized) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFF5BBDB1)));
      }
      if (_videoPlayerController == null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.video_file, color: Colors.white54, size: 64),
              const SizedBox(height: 12),
              const Text(
                'تعذّر تحميل معاينة الفيديو\nيمكنك حفظه على أي حال',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13, height: 1.6),
              ),
            ],
          ),
        );
      }
      return GestureDetector(
        onTap: () {
          if (_videoPlayerController!.value.isPlaying) {
            _videoPlayerController!.pause();
          } else {
            _videoPlayerController!.play();
          }
          setState(() {});
        },
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_videoPlayerController!),
                if (!_videoPlayerController!.value.isPlaying)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      // Audio preview
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.graphic_eq, size: 80, color: _isPreviewAudioPlaying ? const Color(0xFF5BBDB1) : Colors.white54),
            const SizedBox(height: 24),
            IconButton(
              iconSize: 72,
              icon: Icon(
                _isPreviewAudioPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                color: const Color(0xFF5BBDB1),
              ),
              onPressed: () async {
                if (_isPreviewAudioPlaying) {
                  await _previewAudioPlayer.pause();
                  setState(() => _isPreviewAudioPlaying = false);
                } else {
                  _previewAudioPlayer.onPlayerComplete.listen((_) {
                    if (mounted) setState(() => _isPreviewAudioPlaying = false);
                  });
                  await _previewAudioPlayer.play(DeviceFileSource(_capturedFile!.path));
                  setState(() => _isPreviewAudioPlaying = true);
                }
              },
            ),
            const SizedBox(height: 8),
            const Text('اضغط للاستماع', style: TextStyle(color: Colors.white54, fontFamily: 'Cairo', fontSize: 14)),
          ],
        ),
      );
    }
  }

  String _fmtTime(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _buildAudioRecordingOverlay() {
    final remaining = (_currentAudioLimitSeconds - _audioElapsed).clamp(0, _currentAudioLimitSeconds);
    final progress = _currentAudioLimitSeconds > 0 ? _audioElapsed / _currentAudioLimitSeconds : 0.0;
    final isWarning = remaining <= 20;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('تسجيل جاري', style: TextStyle(color: isWarning ? Colors.orange : Colors.white, fontFamily: 'Cairo', fontSize: 13)),
              const Spacer(),
              Text(
                '${_fmtTime(_audioElapsed)} / ${_fmtTime(_currentAudioLimitSeconds)}',
                style: TextStyle(color: isWarning ? Colors.orange : Colors.white, fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 5,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(isWarning ? Colors.red : Colors.blue),
            ),
          ),
          if (isWarning)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('المتبقي: ${_fmtTime(remaining)}', style: const TextStyle(color: Colors.orange, fontFamily: 'Cairo', fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptureControls() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(Icons.refresh, 36),
                _buildMainCaptureButton(),
                _buildCircularButton(Icons.image, 36),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildModeSwitcher(),
        ],
      ),
    );
  }

  Widget _buildCircularButton(IconData icon, double size) {
    return Container(
      width: size,
      height: size,
      decoration: const ShapeDecoration(
        color: Color(0xFF1F1F1F),
        shape: OvalBorder(),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildMainCaptureButton() {
    return GestureDetector(
      onTap: _handleMainAction,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(4),
        decoration: const ShapeDecoration(
          color: Colors.white30,
          shape: OvalBorder(),
        ),
        child: Container(
          decoration: const ShapeDecoration(
            color: Colors.white,
            shape: OvalBorder(),
          ),
          child: _isRecording ? const Icon(Icons.stop, color: Colors.red, size: 32) : null,
        ),
      ),
    );
  }

  // Returns which media kinds are allowed by the user's current pack
  Map<WassitLiveKind, bool> _packAllowance() {
    final meta = Supabase.instance.client.auth.currentUser?.userMetadata ?? {};
    final packId = (meta['pack_id'] as num?)?.toInt() ?? 0;
    const pq = {
      0: {'videoMin': 0, 'audioMin': 2},
      1: {'videoMin': 5, 'audioMin': 10},
      2: {'videoMin': 20, 'audioMin': 40},
      3: {'videoMin': 999, 'audioMin': 999},
    };
    final q = pq[packId] ?? pq[0]!;
    return {
      WassitLiveKind.image: true,
      WassitLiveKind.text:  true,
      WassitLiveKind.audio: q['audioMin']! > 0,
      WassitLiveKind.video: q['videoMin']! > 0,
    };
  }

  Widget _buildModeSwitcher() {
    final allowance = _packAllowance();
    final modes = [
      {'label': 'نص', 'kind': WassitLiveKind.text},
      {'label': 'صوت', 'kind': WassitLiveKind.audio},
      {'label': 'فيديو', 'kind': WassitLiveKind.video},
      {'label': 'صورة', 'kind': WassitLiveKind.image},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: modes.map((m) {
        final kind = m['kind'] as WassitLiveKind;
        final isActive = _activeLive == kind;
        final isLocked = !(allowance[kind] ?? true);
        return GestureDetector(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: const Text(
                  'هذه الميزة غير متاحة في باقتك الحالية. قم بترقية الباقة للوصول إليها.',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
                backgroundColor: Colors.red[800],
                action: SnackBarAction(
                  label: 'ترقية',
                  textColor: Colors.white,
                  onPressed: () => context.push('/pack'),
                ),
              ));
              return;
            }
            setState(() => _activeLive = kind);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      m['label'] as String,
                      style: TextStyle(
                        color: isLocked
                            ? Colors.white24
                            : isActive ? const Color(0xFF5BBDB1) : const Color(0xFFDDDDDD),
                        fontSize: isActive ? 16 : 14,
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isLocked)
                      Positioned(
                        top: -4,
                        right: -10,
                        child: Icon(Icons.lock, size: 10, color: Colors.white24),
                      ),
                  ],
                ),
                if (isActive && !isLocked)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFF5BBDB1),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkipButton() {
    final hasDrafts = ref.watch(wassitProvider).drafts.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextButton(
        onPressed: () => context.push('/summary'),
        child: Text(
          hasDrafts ? 'الانتقال إلى المراجعة ←' : 'لا أريد إضافة وسيط',
          style: TextStyle(
            color: hasDrafts ? const Color(0xFF5BBDB1) : const Color(0xFFB1B1B1),
            fontSize: 14,
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
