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
