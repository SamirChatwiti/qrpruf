import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:video_player/video_player.dart';
import '../../../../core/providers/wassit_provider.dart';
import '../../data/models/draft.dart';

// Note: Navigation targets like CaptureScreen, PreviewScreen, and WassitSummaryPage 
// will be implemented or updated in subsequent steps.

class SelectMoment extends ConsumerWidget {
  const SelectMoment({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     final allDrafts = ref.watch(wassitProvider).drafts;
     final drafts = allDrafts.where((d) => d.intentions?.contains('توثيق لحظة') ?? false).toList();

     return Column(
       children: [
         const SizedBox(height: 12),
         Text(
            'توثيق لحظة مهمة',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'Cairo'),
         ),
         const SizedBox(height: 12),
         
         // Top Action: Add New
         Center(
           child: ElevatedButton.icon(
             onPressed: () {
               context.push('/capture-hub');
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text('البدء بتسجيل لحظة...')),
               );
             },
             icon: const Icon(Icons.camera_alt),
             label: const Text('تسجيل لحظة', style: TextStyle(fontFamily: 'Cairo')),
             style: ElevatedButton.styleFrom(
               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
               backgroundColor: Theme.of(context).primaryColor,
               foregroundColor: Theme.of(context).colorScheme.onPrimary,
             ),
           ),
         ),
         
         const SizedBox(height: 16),
         
         // Draft List
         if (drafts.isEmpty)
             Center(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 32.0),
                   child: Column(
                     mainAxisAlignment: MainAxisAlignment.center,
                     children: [
                       Icon(Icons.history, size: 48, color: Theme.of(context).dividerColor),
                       const SizedBox(height: 8),
                       Text('لا توجد لحظات مسجلة', style: TextStyle(color: Theme.of(context).hintColor, fontFamily: 'Cairo')),
                     ],
                   ),
                 ),
               )
         else
             ListView.builder(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 shrinkWrap: true,
                 physics: const NeverScrollableScrollPhysics(),
                 itemCount: drafts.length,
                 itemBuilder: (context, index) {
                   return _MomentDraftCard(draft: drafts[index]);
                 },
               ),
         
         const SizedBox(height: 12),
         
         // Sticky Bottom Button
         Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             children: [
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton.icon(
                   onPressed: () => context.push('/capture-hub'),
                   icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                   label: const Text('إضافة وسائط (الخطوة 2)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Theme.of(context).primaryColor,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     elevation: 4,
                   ),
                 ),
               ),
               if (allDrafts.isNotEmpty) ...[
                 const SizedBox(height: 12),
                 SizedBox(
                   width: double.infinity,
                   child: OutlinedButton.icon(
                     onPressed: () => context.push('/summary'),
                     icon: Icon(Icons.checklist_rtl, color: Theme.of(context).primaryColor, size: 22),
                     label: Text(
                       'مراجعة التوثيقات (${allDrafts.length})',
                       style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                     ),
                     style: OutlinedButton.styleFrom(
                       side: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                       padding: const EdgeInsets.symmetric(vertical: 14),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     ),
                   ),
                 ),
               ],
             ],
           ),
         ),
       ],
     );
  }
}

class _MomentDraftCard extends ConsumerWidget {
  final Draft draft;
  const _MomentDraftCard({required this.draft});

  void _previewDraft(BuildContext context, Draft draft) {
    switch (draft.type) {
      case MediaType.image:
        Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImage(path: draft.originalPath)));
      case MediaType.video:
        Navigator.push(context, MaterialPageRoute(builder: (_) => _VideoPreview(path: draft.originalPath)));
      case MediaType.audio:
        Navigator.push(context, MaterialPageRoute(builder: (_) => _AudioPreview(path: draft.originalPath)));
      case MediaType.text:
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IconData icon;
    Color color; 
    switch(draft.type) {
      case MediaType.image: icon = Icons.image; color = Colors.blue; break;
      case MediaType.video: icon = Icons.videocam; color = Colors.red; break;
      case MediaType.audio: icon = Icons.mic; color = Colors.orange; break;
      case MediaType.text: icon = Icons.text_fields; color = Colors.green; break;
    }

    return Dismissible(
      key: Key(draft.id),
      onDismissed: (_) {
        ref.read(wassitProvider.notifier).removeDraft(draft.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('عنصر ${draft.type.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                  Text(draft.id, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 10)),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility_outlined, color: Colors.blue),
                  onPressed: () => _previewDraft(context, draft),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () {
                    ref.read(wassitProvider.notifier).removeDraft(draft.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenImage extends StatelessWidget {
  final String path;
  const _FullScreenImage({required this.path});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
    body: Center(child: InteractiveViewer(child: Image.file(File(path), fit: BoxFit.contain))),
  );
}

class _VideoPreview extends StatefulWidget {
  final String path;
  const _VideoPreview({required this.path});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _ctrl;
  bool _ready = false;
  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path))
      ..initialize().then((_) { if (mounted) setState(() => _ready = true); _ctrl.play(); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
    body: Center(child: _ready
      ? GestureDetector(
          onTap: () => _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play(),
          child: AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl)),
        )
      : const CircularProgressIndicator(color: Color(0xFF5BBDB1))),
  );
}

class _AudioPreview extends StatefulWidget {
  final String path;
  const _AudioPreview({required this.path});
  @override
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _playing = s == PlayerState.playing); });
  }
  @override
  void dispose() { _player.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
    body: Center(child: IconButton(
      iconSize: 80,
      icon: Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: const Color(0xFF5BBDB1)),
      onPressed: () async {
        if (_playing) { await _player.pause(); }
        else { await _player.play(DeviceFileSource(widget.path)); }
      },
    )),
  );
}
