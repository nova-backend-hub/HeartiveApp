# Heartive for iOS

iPhone application for [heartivelovestv.pages.dev](https://heartivelovestv.pages.dev) matching the exact dark-orange aesthetics, mobile navigation bar, and full video playback support.

---

## Features
- **Exact Styling & Theme**: Deep midnight dark theme (`#09090d`), warm orange accent (`#ffa500`), and glass surfaces matching Heartive.
- **Full Navigation**:
  - Top bar with Heartive branding, surprise me button, refresh, and back control.
  - Native bottom tab bar: **Home**, **Movies**, **Series**, **Search**, **My List**.
- **Video & Media Playback**: Configured with inline media playback, auto-orientation support for landscape video viewing, and full-screen video capability.
- **Sideload Ready**: Can be sideloaded with Sideloadly, AltStore, SideStore, or TrollStore.

---

## How to Build the `.ipa` via GitHub Actions

1. Create a new repository on [GitHub](https://github.com/new) (e.g. `HeartiveApp`).
2. Push this project from your PC:
   ```powershell
   cd C:\Users\dawoo\.gemini\antigravity\scratch\HeartiveApp
   git init
   git add .
   git commit -m "Initial commit for Heartive iOS app"
   git branch -M main
   git remote add origin https://github.com/<YOUR_USERNAME>/HeartiveApp.git
   git push -u origin main
   ```
3. Open your repo on GitHub and click the **Actions** tab.
4. When the build finishes, download **`Heartive-ipa`** (contains `Heartive.ipa`) from **Artifacts**.
5. Drag into **Sideloadly** and install on your iPhone.
