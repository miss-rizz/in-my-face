# In My Face — Setup Guide

**In My Face** is a macOS menu bar app that shows a full-screen alert when a meeting is about to start, so you never miss one.

---

## Prerequisites

- **macOS 13 (Ventura) or later**
- **Xcode Command Line Tools** — install by running this in Terminal:
  ```bash
  xcode-select --install
  ```

That's it. No external packages or services needed.

---

## 1. Get the Code

```bash
git clone https://github.com/miss-rizz/in-my-face.git
cd in-my-face
```

---

## 2. Build

```bash
./build.sh
```

This compiles the app and creates `InMyFace.app` inside the `.build/` folder.

---

## 3. Install

Copy the app to your Applications folder:

```bash
cp -r .build/InMyFace.app /Applications/
```

---

## 4. Launch

```bash
open /Applications/InMyFace.app
```

**On first launch, macOS will ask for Calendar access — click Allow.**  
The app will appear as a small icon in your menu bar (top-right of your screen).

---

## 5. Auto-start on Login (optional)

To have the app start automatically when you log in:

1. Open **System Settings → General → Login Items**
2. Click **+** and add **InMyFace**

Alternatively, click the menu bar icon → **Launch at Login**.

---

## How It Works

- The app checks your macOS Calendar every 60 seconds.
- When a meeting is starting, a **full-screen alert** appears with the meeting title.
- If the invite has a meeting link (Google Meet, Zoom, Teams), a **Join** button takes you straight in.
- Click **Dismiss** to close the alert.

---

## Uninstall

```bash
rm -rf /Applications/InMyFace.app
```

Remove it from Login Items in System Settings if you added it there.
