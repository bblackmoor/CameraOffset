# Camera Offset

A small World of Warcraft retail addon for a game window stretched across two monitors. It keeps the 3D world visible across the window and lets you shift the character toward the center of the left monitor.

At each character login, it sets:

```text
/console CameraKeepCharacterCentered 0
/console CameraReduceUnexpectedMovement 0
/console test_cameraOverShoulder <your saved offset>
```

The initial offset is **3**. Open **Options → AddOns → Camera Offset** or type `/cameraoffset` to adjust it live. Enter the pixel widths of your left and right monitors and choose **Try estimated offset** for a starting point, then fine tune with the slider. Your offset and monitor widths are saved for later logins. Monitor widths alone cannot determine the exact CVar value; camera zoom, model, and mounts can affect how it looks.

This addon does not change WoW's display mode or resize its window. Continue using your window manager for that.

## Install

Download a ZIP from [Releases](https://github.com/bblackmoor/CameraOffset/releases) and extract its `CameraOffset` folder into `World of Warcraft/_retail_/Interface/AddOns/`. Restart WoW.

Development ZIPs are available from [Actions](https://github.com/bblackmoor/CameraOffset/actions/workflows/release.yml) after pushes to `main`. Each development build is retained for 90 days.

## Development

The tracked `.githooks/pre-commit` hook automatically sets `## Version` to `1.0.<commit count>` and builds `dist/CameraOffset-<version>.zip`. Activate it in a clone with:

```sh
git config core.hooksPath .githooks
```

Push a matching `v<version>` tag to publish a permanent release ZIP. The GitHub workflow checks that the tag matches the TOC version.

Licensed under GPL-3.0. See [LICENSE](LICENSE).
