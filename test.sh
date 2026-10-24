#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/tests
python3 extract_yuzu.py
python3 make_xbox_preview.py
python3 make_mobapad_preview.py
xcrun swiftc -swift-version 5 -warnings-as-errors Sources/Core.swift Tests/CoreTests.swift -o build/tests/core-tests
build/tests/core-tests
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter Tests/HIDTests.m -framework Foundation -framework IOKit -o build/tests/hid-tests
build/tests/hid-tests
xcrun swiftc -swift-version 5 -warnings-as-errors Sources/RealtimeTrigger.swift Tests/TriggerMeterTests.swift -framework AppKit -framework SwiftUI -o build/tests/trigger-tests
build/tests/trigger-tests
node Tests/MobapadPreviewTests.js
