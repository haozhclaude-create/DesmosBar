# DesmosBar

The Desmos graphing calculator in your Mac's menu bar. Click the ƒ icon (or press ⌘⌥D) and the calculator drops down; click away and it hides.

Unofficial. This app only shows https://www.desmos.com/calculator in a small window. It is not made by or affiliated with Desmos, and it needs an internet connection.

## What it does

- **Opens from anywhere**: click the ƒ menu bar icon, or press ⌘⌥D. Same again to hide.
- **Stays open while you type elsewhere**: if you click into a text field (or onto text) in another app, the calculator stays so you can copy numbers across. Click a blank area and it hides.
- **Movable**: drag the grabber at the top, drag the empty middle of the dark Desmos header, or hold ⌘ and drag anywhere. It reopens under the icon next time.
- **Floats above other windows**, with no Dock icon.
- **Quit**: right-click the ƒ icon.

## Install

You need macOS and the Xcode Command Line Tools (`xcode-select --install`).

```sh
git clone https://github.com/haozhclaude-create/DesmosBar.git
cd DesmosBar
./build.sh
```

This builds the app, puts it in `~/Applications/DesmosBar.app`, and starts it.

On first launch macOS asks for **Accessibility** permission (System Settings → Privacy & Security → Accessibility). The app uses it for one thing: checking whether your click landed in a text field, to decide whether to stay open. Without it the calculator still works, but hides on every click outside.

To start it at login, add DesmosBar in System Settings → General → Login Items.

## Notes

- ⌘⌥D is also the macOS shortcut for hiding the Dock. If the Dock moves when you press it, turn that shortcut off in System Settings → Keyboard → Keyboard Shortcuts → Launchpad & Dock.
- The draggable part of the Desmos header is measured from the current Desmos page layout. If Desmos redesigns its header, that spot may shift; the top grabber and ⌘-drag keep working.
- Tested on macOS 27 only.

## License

MIT
