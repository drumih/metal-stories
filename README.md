# MetalStories

## Project Description
MetalStories is an example implementation of a Stories-style editor built with Metal. The app includes 8 filter effects and shows how to combine preprocessing, rendering passes, gestures, and photo export in an iOS workflow.

## Educational Purpose
This repository is for educational purposes. It is designed to help iOS engineers study practical Metal rendering patterns, image preprocessing, and filter implementation details.
The app uses the Metal rendering pipeline to render images on screen with a high-performance GPU-driven approach.
It demonstrates different rendering techniques with different optimization strategies (see `Rendering Techniques`) and different color-processing techniques such as color spaces, blend modes, channel mixing, etc.
This repo helps you learn the basics of Metal rendering and color processing.

## General Functionality
1. Import photos from the gallery.
2. Calculate dominant colors for the top and bottom quarters of the image to drive the background (implemented with histogram-based median color extraction per channel).
3. Rotate and scale the image with two-finger gestures.
4. Swipe through filters with a horizontal gesture.
5. Save the edited photo back to the gallery.

## Rendering Techniques
1. `Simple` (`RenderPassSimple`): draws background and image in one pass without a post-processing stage.
2. `2 Render Passes` (`RenderPassWithRegularIntermediateTexture`): first pass renders to an intermediate texture, second pass applies the selected filter.
3. `Tile Memory` (`RenderPassTileMemory`): uses a memoryless color attachment and applies post-processing in a single tile-memory-oriented pass.
4. `Direct with Depth` (`RenderPassDirectWithDepth`): uses a depth attachment for ordering and applies post-processing directly in the same render pass flow.

## Filters (8 Effects + Original Baseline)
- `Original`: baseline output with no color grading.
- `Very Simple`: lowers brightness and increases contrast for a quick punchier look.
- `Sepia`: converts to warm monochrome tones using luminance plus a sepia tint.
- `Noir Chrome`: applies high-contrast monochrome grading with cool highlight treatment.
- `Fire and Ice`: applies per-channel curves to create warm/cool split-toning.
- `Bleach Bypass`: blends a desaturated, high-contrast film-style bypass look.
- `Orange Sunset`: overlays a warm gradient and blends it with linear-light style mixing.
- `Chroma Vibrance`: boosts low-chroma colors more than already saturated colors in OKLab space.
- `Cross Process`: applies channel mixing with contrast shaping for a cross-processed color cast.

## Run the App
1. Clone the repository and open `MetalStories/MetalStories.xcodeproj` in Xcode.
2. In Xcode, select your Development Team in the target Signing & Capabilities settings.
3. Launch the project on a physical iOS device.
