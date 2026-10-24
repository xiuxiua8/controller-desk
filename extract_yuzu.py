"""Extract the original Yuzu/Eden vector arrays without redrawing or changing vertices.

SPDX-License-Identifier: GPL-3.0-or-later
Source copyright 2020 yuzu Emulator Project, 2026 Eden Emulator Project.
Adaptation date: 2026-10-23.
"""
import json
import pathlib
import re
root = pathlib.Path(__file__).resolve().parent
source = (root / 'Vendor/Yuzu/configure_input_player_widget.cpp').read_text()
arrays = {}
for count, name, values in re.findall(r'constexpr std::array<float, (\d+) \* 2> (\w+) = \{(.*?)\};', source, re.S):
    numbers = [float(n.rstrip('f')) for n in re.findall(r'[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?f?', values)]
    assert len(numbers) == int(count) * 2, (name, len(numbers))
    arrays[name] = numbers
assert len(arrays) >= 35
assert max(map(abs, arrays['house'])) < 2, 'Fractional literals such as .73f must keep their decimal point'
output = {'generated': 'Do not edit. Run extract_yuzu.py.', 'source': 'Yuzu/Eden PlayerControlPreview', 'license': 'GPL-3.0-or-later', 'arrays': arrays}
(root / 'Resources/yuzu-vectors.json').write_text(json.dumps(output, separators=(',', ':')))
print(f'Extracted {len(arrays)} unchanged Yuzu vector arrays.')
