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
