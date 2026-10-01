import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

class BackgroundSource {
  final String? imagePath;
  final String? videoPath;
  const BackgroundSource.image(this.imagePath) : videoPath = null;
  const BackgroundSource.video(this.videoPath) : imagePath = null;
  const BackgroundSource.none() : imagePath = null, videoPath = null;
}

class BackgroundLayer extends StatefulWidget {
  final BackgroundSource source;
  const BackgroundLayer({super.key, required this.source});

  @override
  State<BackgroundLayer> createState() => _BackgroundLayerState();
}

class _BackgroundLayerState extends State<BackgroundLayer> {
  VideoPlayerController? _video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BackgroundLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.videoPath != widget.source.videoPath) _load();
  }

  Future<void> _load() async {
    await _video?.dispose();
    _video = null;
    final path = widget.source.videoPath;
    if (path == null) {
      if (mounted) setState(() {});
      return;
    }
    final v = VideoPlayerController.file(File(path));
    await v.initialize();
    await v.setLooping(true);
    await v.play();
    if (mounted) setState(() => _video = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.imagePath != null) {
      return Image.file(File(widget.source.imagePath!), fit: BoxFit.cover);
    }
    if (_video != null && _video!.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    }
    return const ColoredBox(color: Colors.black);
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }
}
