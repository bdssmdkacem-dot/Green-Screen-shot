# Green Screen Shot — Live Green Screen Studio

This version adds a live chroma-key rendering path.

## Modes
- **Chroma Key:** works with a physical green screen and is the general solution for both people and objects.
- **AI segmentation:** planned as a separate mode for people when the background is not green. A person-only segmentation model is not used as the generic object solution.

## Live compositor
The preview pipeline is:

Camera -> Flutter texture -> GPU fragment shader -> green mask + soft edge -> foreground over background.

The shader removes saturated green, softens the transition, and performs limited green-spill suppression.

## Backgrounds
The UI can use:
- solid color;
- a selected image;
- a looping selected video.

## Next production step
To export the exact composited frames rather than only preview them, the recorder should move to a GPU/native recording surface (MediaCodec/Surface on Android). This avoids capturing a UI screenshot and preserves real video quality.
