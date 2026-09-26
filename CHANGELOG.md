# Changelog

## 1.0.14

- Draw the clickable circled information symbol as yellow text, without a button texture.

## 1.0.13

- Put controls and actions in label, control, reset, info order with a consistent gap.
- Use WoW's gold circled information icon instead of a question-mark button.
- Align monitor width fields with their labels and move Restore Default beside the profile selector.

## 1.0.12

- Move the enable switch beside its label and the info button after the switch; tighten Profiles spacing and remove Save widths.
- Turn reduced camera movement off while enabled so WoW's shoulder offset can take effect.
- Show the result when enabling, estimating, or adjusting the offset slider, including if WoW does not accept the value.

## 1.0.11

- Use one enable switch; automatically set the two supporting WoW camera CVars and restore their previous values on disable.
- Remove the two supporting camera options from profiles and explain the behavior in an info popup.
- Add a Reset camera defaults button that disables the selected profile and resets all three affected camera CVars to WoW defaults.

## 1.0.10

- Save each monitor width on Enter or when its field loses focus, with visible confirmation.
- Show confirmation and the resulting value when applying an estimated offset, including when the addon is disabled.

## 1.0.9

- Match the requested settings switch layout: label on the left, rectangular track on the right, and a thumb that moves right for On.

## 1.0.8

- Use on/off switches for the enable control and both WoW camera settings.
- Set centering off and reduced movement on when enabling Camera Offset; allow either setting to be adjusted afterward.

## 1.0.7

- Open the addon settings on an About page with version, author, category, license, source link, and slash-command reference.
- Move camera controls into a Camera tab and add slash commands for the Camera, Profiles, and About pages.

## 1.0.4

- Remember pre-activation camera values separately for each character.

## 1.0.3

- Add account-wide profiles with per-character selection and a Profiles settings tab.
- Add a per-profile enable switch with immediate camera restoration on disable.
- Use WoW's own CVar defaults for the built-in Default profile; a fresh install makes no camera changes.
- Migrate existing settings into a Previous Camera Offset profile.

## 1.0.1

- Apply three camera CVars at login.
- Save a live adjustable shoulder offset and monitor widths.
- Add an estimate button and AddOns settings panel.
