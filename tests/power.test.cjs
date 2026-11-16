const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('power actions use elogind and keep guarded suspend', () => {
    const overlay = fs.readFileSync('modules/power/PowerOverlay.qml', 'utf8');
    const locker = fs.readFileSync('lock.qml', 'utf8');
    assert.match(overlay, /\["loginctl", "poweroff"\]/);
    assert.match(overlay, /\["loginctl", "reboot"\]/);
    assert.match(overlay, /"lock-and-suspend"/);
    assert.match(locker, /\["loginctl", "suspend"\]/);
    assert.doesNotMatch(overlay + locker, /systemctl/);
});

test('power menu exposes unmodified keyboard shortcuts', () => {
    const panel = fs.readFileSync('modules/bar/PowerPanel.qml', 'utf8');
    for (const [key, code, action] of [['L', 46, 'lock'], ['S', 39, 'shutdown'], ['U', 30, 'suspend'], ['R', 27, 'reboot'], ['E', 26, 'logout']]) {
        assert.match(panel, new RegExp(`${code}: "${action}"`));
        assert.match(panel, new RegExp(`key: "${key}", action: "${action}"`));
    }
    assert.match(panel, /shortcuts\[event\.nativeScanCode\]/);
    assert.match(panel, /event\.modifiers !== Qt\.NoModifier/);
    assert.match(panel, /event\.isAutoRepeat/);
    assert.match(panel, /actionRequested\(action\)/);
});

test('power menu grabs compositor focus and focuses after becoming visible', () => {
    const bar = fs.readFileSync('modules/bar/Bar.qml', 'utf8');
    assert.match(bar, /centerExpanded \|\| wallpaperPicker\.presented \|\| powerOpened \? WlrKeyboardFocus\.Exclusive/);
    assert.match(bar, /if \(powerOpened && powerPanel\.visible && powerPanel\.enabled\)\s*powerPanel\.forceActiveFocus\(\)/);
    assert.match(bar, /onVisibleChanged: if \(visible\) Qt\.callLater\(root\.focusPowerPanel\)/);
});
