# Green Screen Shot

Android Flutter camera studio for recording a person or object in front of a physical green screen.

Features: front/rear camera, video plus microphone, high resolution, flash, timer, green-screen framing guide, gallery save, and GitHub Actions APK build.

Current version records the camera feed; the green screen is the physical background used during filming. It does not yet perform AI background removal or chroma-key compositing.

Next stage can add person segmentation, chroma-key preview, background image/video replacement, transparent export, and object-aware segmentation. Generic object support should use chroma-key or a dedicated segmentation model.

Build: run the GitHub Actions workflow named Build Green Screen Shot APK. The APK is uploaded as green-screen-shot-release.
