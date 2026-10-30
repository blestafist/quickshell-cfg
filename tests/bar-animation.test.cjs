const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('modules/bar/Bar.qml', 'utf8');
const start = source.indexOf('function animateWidth(');
const handler = source.slice(start, source.indexOf('onTargetWidthChanged:', start));

function context(animationsEnabled = true) {
    const s = {
        width: 300, targetWidth: 500,
        Config: {ShellConfig: {animationsEnabled}},
        Easing: {OutBack: 'bounce', OutCubic: 'smooth'},
        leftIslandWidthAnimation: {
            easing: {}, stops: 0, starts: 0,
            stop() { this.stops++; },
            start() { this.starts++; },
        },
    };
    vm.createContext(s);
    vm.runInContext(handler, s);
    return s;
}

test('left island bounces when expanding', () => {
    const s = context();
    s.animateWidth();
    assert.equal(s.leftIslandWidthAnimation.from, 300);
    assert.equal(s.leftIslandWidthAnimation.to, 500);
    assert.equal(s.leftIslandWidthAnimation.easing.type, 'bounce');
    assert.equal(s.leftIslandWidthAnimation.duration, 420);
});

test('left island shrinks smoothly from current width, including interrupted expansion', () => {
    const s = context();
    s.width = 420;
    s.targetWidth = 300;
    s.animateWidth();
    assert.equal(s.leftIslandWidthAnimation.from, 420);
    assert.equal(s.leftIslandWidthAnimation.to, 300);
    assert.equal(s.leftIslandWidthAnimation.easing.type, 'smooth');
    assert.equal(s.leftIslandWidthAnimation.duration, 280);
    assert.equal(s.leftIslandWidthAnimation.stops, 1);
});

test('disabled animations apply left island width immediately', () => {
    const s = context(false);
    s.animateWidth();
    assert.equal(s.width, 500);
    assert.equal(s.leftIslandWidthAnimation.starts, 0);
});

test('clipboard opening waits for expanded state before selecting bounce on both axes', () => {
    const start = source.indexOf('function animateSize(', source.indexOf('id: musicIsland'));
    const end = source.indexOf('onTargetWidthChanged:', start);
    const pending = new Set();
    const animation = () => ({easing: {}, stop() {}, start() {}});
    const s = {
        root: {centerExpanded: false},
        musicIsland: {width: 0, height: 42},
        musicClickAnimation: {running: false},
        Config: {ShellConfig: {animationsEnabled: true}},
        Easing: {OutBack: 'bounce', OutCubic: 'smooth'},
        Qt: {callLater(fn) { pending.add(fn); }},
        targetWidth: 860, targetHeight: 192,
        islandWidthAnimation: animation(), centerHeightAnimation: animation(),
    };
    vm.createContext(s);
    vm.runInContext(source.slice(start, end), s);
    for (const axis of ['Width', 'Height']) {
        const handler = source.match(new RegExp(`onTarget${axis}Changed: (Qt.callLater\\(animate${axis}\\))`));
        assert.ok(handler);
        vm.runInContext(handler[1], s);
    }
    assert.equal(s.islandWidthAnimation.to, undefined);
    s.root.centerExpanded = true;
    for (const run of pending) run();
    assert.equal(s.islandWidthAnimation.easing.type, 'bounce');
    assert.equal(s.centerHeightAnimation.easing.type, 'bounce');
    assert.equal(s.centerHeightAnimation.to, 192);
    s.musicIsland.height = 192;
    s.targetHeight = 42;
    s.root.centerExpanded = false;
    s.animateHeight();
    assert.equal(s.centerHeightAnimation.easing.type, 'smooth');
});
