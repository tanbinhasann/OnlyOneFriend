# OnlyOneFriend 🔒

A lightweight, native macOS desktop application that restricts Facebook Messenger (or Facebook Messages) to a **single, dedicated conversation thread**. It is designed to remove distractions by completely hiding the global Facebook header, the left-hand chats list, and the right-hand information panel, leaving only the chat feed and the compose bar.

Access is secured by a glassmorphic passcode lock screen upon launching or reopening the application.

## Key Features

- **Strict Focus Mode**: Automatically hides the top navigation bar, the left contact sidebar, and the right conversation details sidebar. Only the core message window and the compose input area are visible.
- **Passcode Protection**: Locks the app with a secure passcode on launch and whenever the window is closed and reopened.
- **Session Preservation**: Closing the window hides it instead of destroying the web session. Your Facebook login status and loaded messages are preserved in memory, meaning you won't need to re-login or run message restore processes when opening the app.
- **Window Switch Safety**: The passcode is NOT prompted when swapping back and forth between active app windows, preventing interruptions during work.
- **Local Link Interception**: Clicking links inside chats opens them in your default system browser (Safari, Chrome, etc.) to keep your workspace focused. Any redirects to the general Facebook feed or other chat threads are intercepted and automatically redirected back to your focused conversation.
- **Native File Uploads & Mic Support**: Full integration with the macOS file picker for sending photos/documents, and WebKit microphone permission mapping for audio messages.
- **Administrative Menu Controls**: Easily **Log Out**, **Change Lock Passcode**, or **Reset App Configuration** directly from the macOS App Menu bar.

## Technology Stack

- **Frontend Wrapper**: Native Swift Cocoa App (AppKit) using `WKWebView`.
- **Styling & Overrides**: Standard CSS injections and a lightweight JavaScript `MutationObserver` (to bypass Content Security Policies and override React dynamic DOM updates).
- **Security**: Secured storage using standard macOS local encryption (`UserDefaults`).

---

## How to Build & Run

### Prerequisites
- macOS Big Sur (10.15) or later
- Xcode Command Line Tools installed (run `xcode-select --install` if you don't have it)

### Build Command
Compile the Swift source code and bundle it into a standalone `.app` package by running the included build script:

```bash
chmod +x build.sh
./build.sh
```

### Run the App
Open the app via terminal:
```bash
open OnlyOneFriend.app
```
Or double-click the compiled `OnlyOneFriend.app` bundle in Finder. 
( or you can directly Install the DMG File )  

---

## Setup Instructions

1. **Configure**: On the first launch, the app will show a Setup Screen.
2. **URL**: Copy and paste the exact URL of the Messenger thread you want to lock onto. It supports:
   - `https://www.messenger.com/t/<THREAD_ID>/`
   - `https://www.facebook.com/messages/t/<THREAD_ID>`
   - `https://www.facebook.com/messages/e2ee/t/<THREAD_ID>`
3. **Set Passcode**: Create your passcode and click **Save & Lock**.
4. **Log In & Restore**: Log in to your Facebook account and complete any message restoration (E2EE key restore) if prompted. 
5. **Enjoy**: The page will automatically lock onto that single thread, hiding all other menus!

---

## Support 
<a href="https://www.buymeacoffee.com/tanbinhasann" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me a Coffee" style="height: 60px !important;width: 217px !important;" ></a>

## Author & Copyright

Created by **[tanbinhasann](https://github.com/tanbinhasann)**.

Copyright © 2026 tanbinhasann. All rights reserved.
This project is open-source under the MIT License.
