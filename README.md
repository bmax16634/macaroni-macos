# Macaroni

Macaroni is a standalone native macOS utility that I built to fix the issues I have with macOS. The main problems I have with macOS are as follows:

1. No independent scroll settings for mouse and trackpad
2. Dock animation delay
3. No window snapping
4. No right-click create new file

In the past I have used multiple different apps to fix all these issues. My goal is to combine all of these utilities into a single utility app to make it easier to set up a fresh Mac.

## Features to fix my macOS issues

### Mouse and Trackpad Features
- Independent scroll direction settings

### Dock Features
- Instant hide and show Dock when hidden. No delay or animations. Instant response.

### Window Snapping
- Window snapping by dragging
- Window snapping shortcuts


### Finder Features
- Right-click create new file

## Requirements

- macOS 13 or later
- Apple silicon Mac

## Installation

1. Download the latest DMG from [Releases](https://github.com/bmax16634/macaroni-macos/releases).
2. Open the DMG and drag Macaroni into the Applications folder.
3. Open Macaroni and enable Accessibility permission when prompted. This is required for independent mouse scrolling, window snapping, and automatic inline Finder rename.
4. Enable the Macaroni Finder extension to use the right-click create new file option.
5. Allow Macaroni to control Finder when prompted. This lets Macaroni select and rename new files directly on the Desktop.

## Building from source

Building Macaroni requires an Apple silicon Mac running macOS 13 or later and Xcode with its command-line tools installed.

```bash
git clone https://github.com/bmax16634/macaroni-macos.git
cd macaroni-macos
swift test
./scripts/build-app.sh release
```

The locally built app is written to `build/Macaroni.app`.

## Acknowledgments

Macaroni's physical-wheel detection and trackpad-acceleration controls are adapted from [UnnaturalScrollWheels](https://github.com/ther0n/UnnaturalScrollWheels), created by [Theron Tjapkes](https://github.com/ther0n). I used Theron's app for years before building these behaviors into Macaroni. Macaroni modifies those GPLv3 portions as part of this independent project; those modifications began in 2026.

[Rectangle](https://github.com/rxhanson/Rectangle) is an open-source macOS window snapping tool. I also used this for years before adding similar functionality to Macaroni. Macaroni's window snapping is independently implemented and does not use Rectangle code.

[TinkerTool](https://www.bresink.com/osx/TinkerTool.html) is a macOS utility that I used for years for the Dock animation issues. This is not an open-source utility, so no code was borrowed, but it was still a major inspiration for Macaroni.

## Permissions

Macaroni requires Accessibility permission for independent mouse scrolling, window snapping, and automatic inline Finder rename. The Finder extension must be enabled for the right-click create new file option. Finder Automation permission lets Macaroni select and rename new files directly on the Desktop.

## License

Macaroni is licensed under GPLv3. See [LICENSE](LICENSE).
