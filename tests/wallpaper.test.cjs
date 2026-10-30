const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const motion = {};
vm.createContext(motion);
vm.runInContext(fs.readFileSync('modules/wallpaper/WallpaperMotion.js', 'utf8').replace(/^\.pragma library\s*/, ''), motion);

test('filmstrip cards never overlap during fractional dragging, including focus handovers', () => {
    for (const [base, hero, height] of [[174, 560, 262], [140, 410, 240], [90, 243, 160]]) {
        for (let position = -2; position < 5; position += 0.013) {
            for (let index = -10; index < 10; index++) {
                const a = motion.card(index - position, base, hero, height, 12);
                const b = motion.card(index + 1 - position, base, hero, height, 12);
                assert.ok(b.offset - b.width / 2 - (a.offset + a.width / 2) >= 12 - 1e-9);
                assert.ok(Object.values(a).every(Number.isFinite));
                assert.ok(a.height > 0 && a.opacity >= 0 && a.opacity <= 1);
            }
        }
    }
});

test('virtual window is bounded and preserves global card positions at its edges', () => {
    for (const count of [0, 1, 7, 89, 100000]) {
        const slots = Math.min(count, 21);
        for (const position of [0, 0.5, 3, 40, Math.max(0, count - 1)]) {
            const start = motion.windowStart(position, count, slots);
            assert.ok(start >= 0 && start + slots <= count);
            assert.ok(slots <= 21);
            if (position < count) assert.ok(position >= start && position < start + Math.max(1, slots));
        }
    }
});

test('recycled carousel keeps every existing texture except the one entering its window', () => {
    const slots = 21;
    for (let start = 0; start < 100; start++) {
        const before = Array.from({length: slots}, (_, slot) => motion.slotIndex(slot, start, slots));
        const after = Array.from({length: slots}, (_, slot) => motion.slotIndex(slot, start + 1, slots));
        assert.equal(after.filter((value, slot) => value !== before[slot]).length, 1);
        assert.equal(new Set(before).size, slots);
        assert.ok(before.every(value => value >= start && value < start + slots));
    }
});

test('search supports Unicode, spaces and literal metacharacters, without mutating the library', () => {
    const entries = [{relative: 'Природа/Снег 01.png'}, {relative: 'Anime/[Night].jpg'}, {relative: 'sky.png'}];
    assert.equal(motion.filter(entries, '  СНЕГ ').length, 1);
    assert.equal(motion.filter(entries, '[night]')[0], entries[1]);
    assert.equal(motion.filter(entries, '.*').length, 0);
    assert.equal(motion.filter(entries, ''), entries);
    assert.equal(entries.length, 3);
});

const picker = fs.readFileSync('modules/wallpaper/WallpaperPicker.qml', 'utf8');
const bar = fs.readFileSync('modules/bar/Bar.qml', 'utf8');
const service = fs.readFileSync('services/Wallpapers.qml', 'utf8');

function functionSource(name) {
    const start = picker.indexOf(`function ${name}(`);
    assert.notEqual(start, -1);
    let depth = 0;
    for (let i = picker.indexOf('{', start); i < picker.length; i++) {
        if (picker[i] === '{') depth++;
        if (picker[i] === '}' && --depth === 0) return picker.slice(start, i + 1);
    }
    throw new Error(`Unclosed function ${name}`);
}

function state() {
    const s = {
        phase: 'flying', opened: true, applySucceeded: false, flightProgress: 1,
        pendingEntry: {path: '/chosen.png'}, wallpapers: {error: ''},
        handoff: {source: 'file:///chosen.png'}, flight: {stop() {}}, focusGallery() {},
        scrollClock: {running: true}, longTravel: {stop() {}}, travelOpacity: 0,
        snap: {stop() {}}, search: {focus: true}, trackingApply: true,
    };
    s.root = s;
    vm.createContext(s);
    for (const name of ['finishFlight', 'fail', 'close']) vm.runInContext(functionSource(name), s);
    return s;
}

test('visual completion never claims success before awww confirms, and waiting restores visible UI', () => {
    const s = state();
    s.finishFlight();
    assert.equal(s.phase, 'waiting');
    assert.equal(s.opened, true);
    assert.equal(s.flightProgress, 0);
    s.applySucceeded = true;
    s.finishFlight();
    assert.equal(s.opened, false);
    assert.equal(s.phase, 'idle');
    assert.equal(s.handoff.source, '');
    assert.equal(s.flightProgress, 0);
});

test('failed handoff returns to the shelf and retains the selected wallpaper', () => {
    const s = state();
    s.selectedIndex = 42;
    s.fail('daemon unavailable');
    assert.equal(s.phase, 'idle');
    assert.equal(s.opened, true);
    assert.equal(s.flightProgress, 0);
    assert.equal(s.selectedIndex, 42);
    assert.equal(s.wallpapers.error, 'daemon unavailable');
});

test('picker covers all bar islands without changing exclusive space, and keeps left-click launcher', () => {
    assert.match(bar, /exclusiveZone: barHeight/);
    assert.match(bar, /height: wallpaperPicker.presented \? root.height : root.barHeight/);
    assert.match(bar, /onRightClicked: wallpaperPicker.toggle\(\)/);
    assert.match(bar, /if \(wallpaperPicker.opened\) wallpaperPicker.close\(\)\s+else root.launcher.open\(\)/);
    assert.match(bar, /closeMode: wallpaperPicker.opened/);
    assert.match(picker, /seedWidth: root.seedWidth/);
    assert.match(service, /Config.ShellConfig.animationsEnabled \? Config.ShellConfig.wallpaperTransitionDuration : 0/);
    assert.doesNotMatch(service, /swww|sh", "-c|matugen/);
});

test('clock stays above the closing shelf and the distro toggle has no decoration', () => {
    const distro = fs.readFileSync('modules/bar/DistroButton.qml', 'utf8');
    assert.match(bar, /id: leftContent\s+objectName: "barLeftContent"\s+z: wallpaperPicker.presented \? 20 : 0/);
    assert.match(bar, /opacity: wallpaperPicker.barContentOpacity\s+enabled: !wallpaperPicker.presented/);
    assert.match(bar, /x: leftContent.x \+ distroSlot.x\s+y: leftContent.y \+ distroSlot.y/);
    assert.match(picker, /barContentOpacity: 1 - Motion.smoothstep\(0, 0.23, shelf.contentProgress\)/);
    assert.match(distro, /background: null/);
    assert.match(distro, /hoverEnabled: false/);
    assert.match(distro, /MouseArea\s*\{\s*anchors.fill: parent\s+acceptedButtons: Qt.RightButton\s+onClicked: root.rightClicked\(\)/);
    assert.doesNotMatch(distro, /TapHandler/);
    assert.doesNotMatch(distro, /border\.|root\.(activeFocus|hovered|down)/);
});

test('dismissal interrupts even a busy flight and drops its late callbacks', () => {
    const s = state();
    s.busy = true;
    s.close();
    assert.equal(s.opened, false);
    assert.equal(s.trackingApply, false);
    assert.equal(s.phase, 'idle');
    assert.equal(s.flightProgress, 0);
    assert.equal(s.handoff.source, '');
    assert.equal(s.scrollClock.running, false);
    assert.equal(s.travelOpacity, 1);
    assert.equal(s.search.focus, false);
});

test('minimal Material controls stay below the filmstrip and no original is decoded in the shell', () => {
    const image = fs.readFileSync('modules/wallpaper/WallpaperImage.qml', 'utf8');
    assert.doesNotMatch(picker, /id: header|text: "ОБОИ"|Колесо \/|pendingEntry\.url|captionShade|glyph:/);
    assert.ok(picker.indexOf('id: search') > picker.indexOf('id: footer'));
    assert.doesNotMatch(image, /layer.enabled/);
    assert.match(image, /cache: false/);
    assert.match(image, /fillTransform: Qt.matrix4x4/);
});
