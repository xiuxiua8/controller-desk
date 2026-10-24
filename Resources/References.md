# ControllerDesk references

ControllerDesk is GPL-3.0-or-later. Its native SwiftUI Joy-Con preview is adapted from Yuzu/Eden PlayerControlPreview. Original vector vertices are extracted unchanged with extract_yuzu.py; DrawDualController, DrawDualBody, trigger, symbol, stick and motion-cube drawing operations are ported to direct CoreGraphics drawing. The connection sidebar is original; Xbox artwork is attributed below. This is a drawing-layer port, not the complete Yuzu Qt application.

- Yuzu/Eden PlayerControlPreview: https://github.com/eden-emulator/mirror/blob/master/src/yuzu/configuration/configure_input_player_widget.cpp . Original source included in Vendor/Yuzu. Copyright 2020 yuzu Emulator Project (GPL-2.0-or-later); Copyright 2026 Eden Emulator Project (GPL-3.0-or-later). Adapted 2026-10-23 for SwiftUI, actual macOS input and per-device colors. The combined work is GPL-3.0-or-later. No warranty. See LICENSE.
- Yuzu Joy-Con color readout: https://github.com/eden-emulator/mirror/blob/master/src/input_common/helpers/joycon_protocol/generic_functions.cpp . SPI COLOR_DATA 0x6050: RGB body, RGB buttons, two RGB grips. The app reads those actual bytes, caches them locally by Bluetooth address, and uses neutral gray until a real color has been read. Erased 0xffffff data is rejected. User-provided controller names do not determine color.
- SDL Nintendo HID protocol implementation: https://github.com/libsdl-org/SDL/blob/main/src/joystick/hidapi/SDL_hidapi_switch.c . Reference for packet formats and calibration units. Protocol parsing is implemented independently.
- blueutil 2.14.0: https://github.com/toy/blueutil . Bundled local CLI handles Bluetooth actions. Its MIT license is included as blueutil-LICENSE.txt.
- Apple GameController: https://developer.apple.com/documentation/gamecontroller
- Xbox Series SVG artwork: Copyright (c) 2024 Al. Lopez, MIT License, https://github.com/AL2009man/Gamepad-Asset-Pack . Original SVG and license are included in Vendor/GamepadAssetPack. make_xbox_preview.py generates a local document with real-time native-input highlights, thumbstick movement, analog triggers, and direction markers. Its WKWebView uses a nonpersistent data store and a CSP that blocks network requests. Xbox artwork is a standard Carbon Black appearance, not a hardware-reported casing color.

This app does not create multi-host capability in controller firmware. Local rest calibration only affects this app's test display.

Connection actions affect only the selected group. Other connected controllers remain untouched. Explicit Disconnect is separate from Connect. Connect first attempts an existing bond, then waits for physical SYNC and rebuilds a stale target bond when authoritative system/HID evidence confirms the target is offline. A connected half of a Joy-Con pair is always preserved.

## Mobapad M6 HD vector artwork, version 1.1

Official shape references: https://www.mobapad.com/products/mobapad-m6-hd

The approved version 1.0 photo layout and source coordinate system are retained as
local development references; the official photos are not distributed here. Version 1.1 renders only paths,
polygons, circles, rectangles and text. Shell outlines, octagonal gates, moving caps,
face buttons, directional sectors, Home/Capture glyphs, configuration buttons,
inner rail keys and top-view shoulders/triggers are separate editable vector regions.
SL/SR highlight directly on the black edges of the main front view. No raster image,
embedded image data, photographic layer or image filter is used in the preview.
make_mobapad_preview.py is the authoring source and generates the standalone SVG as
well as the local live HTML document. The standalone SVG resolves CSS variables for
vector-editor compatibility. Product design and trademarks belong to Mobapad; this
is independent artwork, not an official Mobapad application.

Controller Desk 1.1 uses independent direct-rendered trigger meters and percentages.
Each draw reads a single current input value, with no interpolation or easing.
The device selection, motion-side selection and correction-display preference are
saved locally across launches under the existing application identity.

Directional refinements: both M6 HD and Xbox previews select exactly one of eight
outer cells in a three-by-three directional grid, including diagonal input. The
center remains neutral. Xbox directional tiles are clipped to the original D-pad
bowl path; shoulder highlights duplicate the original curved surface path and clip
at its physical seams. No rectangular shoulder markers or direction dots remain.
M6 HD main and top-view stick groups move from the same measured stick values.
