const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('services/Palette.qml', 'utf8');

function functionSource(name) {
    const start = source.indexOf(`function ${name}(`);
    assert.notEqual(start, -1);
    let depth = 0;
    for (let i = source.indexOf('{', start); i < source.length; i++) {
        if (source[i] === '{') depth++;
        if (source[i] === '}' && --depth === 0) return source.slice(start, i + 1);
    }
    throw new Error(`Unclosed function ${name}`);
}

function state() {
    const s = {
        requestedPath: '', activePath: '', error: '', forceNext: false, stateFile: '/state/theme.json',
        generator: {running: false, command: []}, accepted: [],
        Config: {ShellConfig: {wallpaperThemeEnabled: true, wallpaperThemeMode: 'dark', wallpaperThemeScheme: 'scheme-tonal-spot'}},
        Quickshell: {shellPath: path => '/shell/' + path},
    };
    s.Theme = {Theme: {applyPalette: data => {s.accepted.push(data); return true;}}};
    s.root = s;
    vm.createContext(s);
    for (const name of ['request', 'generate', 'accept']) vm.runInContext(functionSource(name), s);
    return s;
}

test('palette generation is serialized and the latest requested wallpaper wins', () => {
    const s = state();
    s.request('/first image.png');
    assert.equal(s.generator.running, true);
    assert.equal(s.activePath, '/first image.png');
    assert.equal(s.generator.command[0], 'python3');
    assert.ok(s.generator.command.includes('/first image.png'));
    assert.ok(!s.generator.command.includes('sh'));
    s.request('/second.png');
    assert.equal(s.activePath, '/first image.png');
    s.accept({wallpaper: '/first image.png'}, true);
    s.accept({wallpaper: '/first image.png'});
    assert.equal(s.accepted.length, 0);
    s.generator.running = false;
    s.generate();
    assert.equal(s.activePath, '/second.png');
    s.accept({wallpaper: '/second.png'}, true);
    assert.equal(s.accepted.length, 1);
});

test('an idle shell accepts external palette updates without a reload', () => {
    const s = state();
    s.requestedPath = s.activePath = '/previous.png';
    s.accept({wallpaper: '/external.png'});
    assert.equal(s.accepted.length, 1);
    assert.equal(s.requestedPath, '/external.png');
    assert.equal(s.activePath, '/external.png');
    assert.equal(s.generator.running, false);
});

test('disabled theme generation does not replace the fallback palette', () => {
    const s = state();
    s.Config.ShellConfig.wallpaperThemeEnabled = false;
    s.request('/image.png');
    s.accept({wallpaper: '/image.png'});
    assert.equal(s.generator.running, false);
    assert.equal(s.accepted.length, 0);
});

test('explicit theme refresh bypasses saved-palette reuse, not wallpaper application', () => {
    const s = state();
    s.request('/image.png', true);
    assert.ok(s.generator.command.includes('--force'));
    assert.equal(s.forceNext, false);
    assert.doesNotMatch(source, /awww|Quickshell\.reload|\.qml"\s*\]/);
});
