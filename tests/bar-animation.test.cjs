const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('modules/bar/Bar.qml', 'utf8');
const start = source.indexOf('function animateSize(', source.indexOf('id: rightCluster'));
const handler = source.slice(start, source.indexOf('onTargetWidthChanged:', start));

function context(expanded = true, animationsEnabled = true) {
    const s = {
        expanded,
        Config: {ShellConfig: {animationsEnabled}},
        Easing: {OutBack: 'bounce', OutCubic: 'smooth'},
        rightCluster: {width: 340, height: 42},
    };
    vm.createContext(s);
    vm.runInContext(handler, s);
    s.animation = {
        easing: {}, stops: 0, starts: 0,
        stop() { this.stops++; },
        start() { this.starts++; },
    };
    return s;
}

test('right island bounces only when expanding, on both axes', () => {
    for (const [axis, target] of [['width', 600], ['height', 500]]) {
        const s = context();
        s.animateSize(s.animation, axis, target);
        assert.equal(s.animation.to, target);
        assert.equal(s.animation.easing.type, 'bounce');
        assert.equal(s.animation.duration, 420);
        assert.equal(s.animation.starts, 1);
        s.rightCluster[axis] = target + 10;
        s.animateSize(s.animation, axis, target - 30);
        assert.equal(s.animation.easing.type, 'smooth');
        assert.equal(s.animation.duration, 280);
    }
});

test('closing mid-animation uses current size and never bounces', () => {
    const s = context(false);
    s.rightCluster.height = 230;
    s.animateSize(s.animation, 'height', 42);
    assert.equal(s.animation.from, 230);
    assert.equal(s.animation.easing.type, 'smooth');
    assert.equal(s.animation.stops, 1);
});

test('disabled animations apply right island size immediately', () => {
    const s = context(true, false);
    s.animateSize(s.animation, 'width', 600);
    assert.equal(s.rightCluster.width, 600);
    assert.equal(s.animation.stops, 1);
    assert.equal(s.animation.starts, 0);
});
