import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_shaders/flutter_shaders.dart';

class ChromaKeyPreview extends StatelessWidget {
  final CameraController controller;
  final Widget background;
  final double threshold;
  final double softness;

  const ChromaKeyPreview({
    super.key,
    required this.controller,
    required this.background,
    this.threshold = 0.18,
    this.softness = 0.08,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) return const SizedBox.shrink();

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        ShaderBuilder(
          assetKey: 'shaders/chroma_key.frag',
          (context, shader, child) {
            shader
              ..setFloat(0, MediaQuery.sizeOf(context).width)
              ..setFloat(1, MediaQuery.sizeOf(context).height)
              ..setFloat(2, threshold)
              ..setFloat(3, softness);
            return ShaderMask(
              shaderCallback: (_) => shader,
              blendMode: BlendMode.srcATop,
              child: child,
            );
          },
          child: CameraPreview(controller),
        ),
      ],
    );
  }
}
