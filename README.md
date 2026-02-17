# NotchCam

A lightweight macOS accessory app that floats a live feed from your built-in camera near the MacBook notch so you can check in without leaving full-screen playback. Phase 1 focuses on the overlay experience; Phase 2 will add the optional “is she sleeping?” detector that can auto-pause playback.

## Getting started

1. Open the project in Xcode 15 or newer:
   ```bash
   open NotchCam.xcodeproj
   ```
2. Select the **NotchCam** scheme and run. The app runs as an accessory (no Dock icon) and places an icon in the menu bar.
3. On first launch grant camera access. If macOS previously denied access, visit **System Settings → Privacy & Security → Camera** and re-enable "NotchCam".

## Using the overlay

- The panel floats above full-screen apps, follows you across Spaces, and remembers its size/position. Drag it wherever you want; use the menu bar item to snap it back by the notch.
- Click the menu bar icon to hide/show the panel, toggle hit-testing ("lock overlay" prevents accidental drags), or quit the app.
- The overlay uses a mirrored feed by default so it matches your intuition; tap the mirror button in the chrome to flip it back.

## Sleep detection

NotchCam includes a lightweight Vision-based sleep detector (eye-closure heuristic over face landmarks). When it detects sustained closed eyes, it shows a slide-down “Sleep detected” notification near the notch.

Notes:
- You can independently toggle **Camera preview overlay** and **Sleep detection** from the menu bar icon or Settings.
- Sleep detection still requires camera access, even if the preview overlay is disabled.

## Notes & testing

- Build with hardened runtime enabled; signing uses your default Automatic team (set in the project settings).
- The generated placeholder icon lives under `NotchCam/Assets.xcassets/AppIcon.appiconset`. Replace it with production artwork before shipping.
- The repo currently includes only the macOS project; keep it separate from your Next.js site as requested. Create a new git repo here if desired.
