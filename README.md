# NapPing

I built this because my girlfriend always falls asleep when we are watching something on my laptop, but I cannot see her eyes when she is resting on my shoulder.

NapPing is a lightweight macOS app that watches the camera feed and notifies me when she likely fell asleep.

## Getting started

1. Open the project in Xcode 15 or newer:
   ```bash
   open NapPing.xcodeproj
   ```
2. Select the **NapPing** scheme and run. The app can run in the menu bar or Dock, based on Settings.
3. On first launch grant camera access. If macOS previously denied access, visit **System Settings → Privacy & Security → Camera** and re-enable "NapPing".

## How it works

- NapPing captures video from the built-in camera.
- It runs a lightweight eye-closure detector.
- If it sees sustained closed eyes, it shows a slide-down **Sleep detected** notification near the notch.
- You can enable camera preview, notifications, or both.

## Notes

- Sleep detection uses an on-device Vision-based eye-closure heuristic.
- Sleep detection still requires camera access, even if camera preview is off.
- You can change modes from Settings or the Dock menu: notifications only, camera only, both, or off.

## Notes & testing

- Build with hardened runtime enabled; signing uses your default Automatic team (set in the project settings).
- The generated placeholder icon lives under `NapPing/Assets.xcassets/AppIcon.appiconset`. Replace it with production artwork before shipping.
- The repo currently includes only the macOS project; keep it separate from your Next.js site as requested. Create a new git repo here if desired.
