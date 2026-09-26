# Camera Offset

A small World of Warcraft retail addon for a game window stretched across two monitors. It keeps the 3D world visible across the window and lets you shift the character toward the center of the left monitor.

When the selected profile is enabled, it applies:

```text
/console CameraKeepCharacterCentered 0
/console CameraReduceUnexpectedMovement 1
/console test_cameraOverShoulder <your saved offset>
```

Open **Options → AddOns → Camera Offset** or type `/cameraoffset` to see the About page, with version, source, and command information. Use the **Camera** tab (or `/cameraoffset camera`) for the controls and the **Profiles** tab (or `/cameraoffset profiles`) for profiles. `/cameraoffset about` also opens About. The built-in **Default** profile uses WoW's camera defaults and starts disabled. A fresh install does not change the camera. Switching Camera Offset on turns **Keep character centered** off and **Reduce unexpected camera movement** on in the selected profile, and applies the profile immediately and at subsequent logins. You can change either switch afterward. Switching Camera Offset off restores the camera values saved before activation, without reloading the UI.

The **Profiles** tab lets you select, create, copy, rename, and delete profiles. Profiles hold the enable toggle, the three camera values, and both monitor widths. They are shared account-wide, with each character remembering its selection. Default can be edited or restored to WoW's defaults, but cannot be renamed or deleted. Existing installations get a selected **Previous Camera Offset** profile containing their earlier settings; disabling it restores WoW's default values because the earlier version did not record the original camera values.

Enter the pixel widths of your left and right monitors. Each field saves when you press Enter or leave it, and the page confirms the saved value. Choose **Try estimated offset** for a starting point; the page shows the saved estimate and whether it was applied to the camera. Fine tune with the slider. Monitor widths alone cannot determine the exact CVar value; camera zoom, model, and mounts can affect how it looks.

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

---

**AI Disclaimer:** AI-assisted tools were used during the development of this project. The author reviewed and approved the resulting code and documentation and remains responsible for the project.

Copyright © 2026 Brandon Blackmoor (<bblackmoor@blackgate.net>)  
Licensed under the GNU General Public License v3.0 (GPL-3.0):  
https://www.gnu.org/licenses/gpl-3.0.en.html  
Release history: [CHANGELOG.md](CHANGELOG.md)  
Source: https://github.com/bblackmoor/cameraoffset
