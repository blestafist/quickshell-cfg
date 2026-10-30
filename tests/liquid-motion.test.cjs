const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const motion = {};
vm.createContext(motion);
vm.runInContext(fs.readFileSync('modules/launcher/LiquidMotion.js', 'utf8').replace(/^\.pragma library\s*/, ''), motion);

function trajectory(target, frequency, damping, fps = 180, initial = {position: 0, velocity: 0}) {
    const frames = [];
    let state = initial;
    for (let i = 0; i < fps; i++) {
        state = motion.spring(state.position, state.velocity, target, 1 / fps, frequency, damping);
        frames.push(state);
    }
    return frames;
}

test('spring trajectory is identical at 60, 144 and 180 Hz, including dropped frames', () => {
    for (const [frequency, damping] of [[20, 0.72], [15.5, 0.8], [26, 1], [32, 1]]) {
        for (const fps of [60, 144, 180]) {
            const final = trajectory(1, frequency, damping, fps).at(-1);
            const direct = motion.spring(0, 0, 1, 1, frequency, damping);
            assert.ok(Math.abs(final.position - direct.position) < 1e-12);
            assert.ok(Math.abs(final.velocity - direct.velocity) < 1e-12);
        }
    }
});

test('opening crown leads shoulders, with a restrained recoil and finite settling time', () => {
    const rise = trajectory(1, 20, 0.72);
    const spread = trajectory(1, 15.5, 0.8);
    assert.ok(rise[17].position > spread[17].position);
    const peak = Math.max(...rise.map(state => state.position));
    assert.ok(peak > 1.025 && peak < 1.045);
    assert.ok(Math.max(...spread.map(state => state.position)) < 1.02);
    for (const frames of [rise, spread]) {
        assert.ok(frames.findIndex(state => motion.settled(state.position, state.velocity, 1)) < 180 * 0.7);
    }
});

test('closing contracts shoulders first and drains monotonically into the edge', () => {
    const initial = {position: 1, velocity: 0};
    const rise = trajectory(0, 26, 1, 180, initial);
    const spread = trajectory(0, 32, 1, 180, initial);
    assert.ok(spread[17].position < rise[17].position);
    for (const frames of [rise, spread]) {
        let previous = 1;
        for (const state of frames) {
            assert.ok(state.position >= 0 && state.position < previous);
            previous = state.position;
        }
        assert.ok(frames.findIndex(state => motion.settled(state.position, state.velocity, 0)) < 180 * 0.45);
    }
});

test('interrupted transitions retain momentum and converge on the latest target', () => {
    let state = motion.spring(0, 0, 1, 0.08, 20, 0.72);
    const reversed = motion.spring(state.position, state.velocity, 0, 0, 26, 1);
    assert.ok(Math.abs(reversed.position - state.position) < 1e-12);
    assert.ok(Math.abs(reversed.velocity - state.velocity) < 1e-12);
    for (let i = 0; i < 50; i++) {
        const expanded = i % 2 === 0;
        state = motion.spring(state.position, state.velocity, expanded ? 1 : 0,
            0.016, expanded ? 20 : 26, expanded ? 0.72 : 1);
        assert.ok(Number.isFinite(state.position) && Number.isFinite(state.velocity));
    }
    state = motion.spring(state.position, state.velocity, 0, 1, 26, 1);
    assert.ok(motion.settled(state.position, state.velocity, 0));
});

test('liquid contour stays symmetric, finite and connected to the bottom at every phase', () => {
    for (const width of [120, 360, 972, 1056]) {
        for (const height of [0, 140, 586]) {
            for (let phase = 0; phase <= 210; phase++) {
                const rise = motion.spring(0, 0, 1, phase / 180, 20, 0.72).position;
                const spread = motion.spring(0, 0, 1, phase / 180, 15.5, 0.8).position;
                const shape = motion.geometry(width, height, 36, rise, spread);
                assert.ok(Object.values(shape).every(Number.isFinite));
                assert.equal(shape.bottom, height);
                assert.ok(Math.abs(shape.left + shape.right - width) < 1e-9);
                assert.ok(Math.abs(shape.neckLeft + shape.neckRight - width) < 1e-9);
                assert.ok(shape.neckLeft - shape.join >= -1e-9);
                assert.ok(shape.neckRight + shape.join <= width + 1e-9);
                assert.ok(shape.radius >= 0 && shape.sideLength >= 0 && shape.clipWidth >= 0);
                assert.ok(shape.top + shape.radius <= shape.bottom - shape.join + 1e-9);
            }
        }
    }
});

test('settled contour has the original content width, soft corners and edge joins', () => {
    const c = motion.geometry(972, 586, 36, 1, 1);
    assert.equal(c.top, 0);
    assert.equal(c.left, 36);
    assert.equal(c.right, 936);
    assert.equal(c.radius, 36);
    assert.equal(c.join, 36);
    assert.equal(c.clipWidth, 900);
    assert.equal(c.neckLeft - c.join, 0);
    assert.equal(c.neckRight + c.join, 972);
});
