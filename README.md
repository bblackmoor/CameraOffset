# Camera Offset

A small World of Warcraft retail addon for a game window stretched across two monitors. It keeps the 3D world visible across the window and lets you shift the character toward the center of the left monitor.

When the selected profile is enabled, it applies:

```text
/console CameraKeepCharacterCentered 0
/console CameraReduceUnexpectedMovement 0
/console test_cameraOverShoulder <your saved offset>
```

Open **Options → AddOns → Camera Offset** or type `/cameraoffset` to see the About page, with version, source, and command information. Use the **Camera** tab (or `/cameraoffset camera`) for the controls and the **Profiles** tab (or `/cameraoffset profiles`) for profiles. `/cameraoffset about` also opens About. The built-in **Default** profile starts disabled and uses WoW's default shoulder offset. A fresh install does not change the camera. The single enable switch automatically turns **Keep character centered** and **Reduce unexpected camera movement** off, then applies the saved shoulder offset. Reduced movement must be off for shoulder offset to take effect in current WoW. Turning the addon off restores the three camera values saved before activation for that character, without reloading the UI. The **?** button beside the switch explains this in game. **Reset camera defaults** turns the switch off, resets all three camera values to WoW's defaults, and clears the saved pre-activation values for the current character.

The **Profiles** tab lets you select, create, copy, rename, and delete profiles. Profiles hold the enable switch, shoulder offset, and both monitor widths. They are shared account-wide, with each character remembering its selection. Default can be edited or restored to its initial values, but cannot be renamed or deleted. Existing installations from the original addon get a selected **Previous Camera Offset** profile containing their earlier settings; disabling it restores WoW's default camera values because the original version did not record the prior values.

Enter the pixel widths of your left and right monitors. Each field saves when you press Enter or leave it, and the page confirms the saved value. Choose **Try estimated offset** for a starting point; the page shows the saved estimate and whether WoW accepted it. Fine tune with the slider, which also shows the current result. Monitor widths alone cannot determine the exact CVar value; camera zoom, model, and mounts can affect how it looks.

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
