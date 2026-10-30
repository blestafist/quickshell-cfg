const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('modules/launcher/Launcher.qml', 'utf8');

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

function context() {
    const primary = {name: 'DP-1'};
    const secondary = {name: 'HDMI-A-1'};
    const queued = [];
    const s = {
        opened: false, presented: false, openingRequested: false,
        targetScreen: null, message: '', showingHidden: false, pendingCommand: [],
        Config: {MachineConfig: {primaryMonitor: primary.name}},
        Quickshell: {screens: [primary, secondary], env: () => '/run/niri.sock'},
        Qt: {callLater: fn => queued.push(fn)},
        search: {text: '', focuses: 0, forceActiveFocus() { this.focuses++; }},
        filterResults() {}, focusedOutput: {running: false},
        sheet: {reveal: 1}, commandRunner: {starts: 0, startDetached() { this.starts++; }},
        queued, primary, secondary,
    };
    vm.createContext(s);
    for (const name of ['open', 'finishOpen', 'presentOnTarget', 'close', 'toggle', 'activate', 'runPendingCommand', 'finishDismissal'])
        vm.runInContext(functionSource(name), s);
    return s;
}

test('launcher opens on focused output and focuses search after mapping', () => {
    const s = context();
    s.open();
    assert.equal(s.focusedOutput.running, true);
    assert.equal(s.presented, false);
    s.finishOpen('{"name":"HDMI-A-1"}');
    assert.equal(s.targetScreen, s.secondary);
    assert.equal(s.presented, true);
    assert.equal(s.opened, false);
    s.queued.shift()();
    assert.equal(s.opened, true);
    assert.equal(s.search.focuses, 1);
});

test('failed output query and disconnected monitor fall back safely', () => {
    for (const output of ['', 'null', '{"name":"disconnected"}']) {
        const s = context();
        s.openingRequested = true;
        s.finishOpen(output);
        assert.equal(s.targetScreen, s.primary);
    }
    const s = context();
    s.Quickshell.screens = [];
    s.openingRequested = true;
    s.finishOpen('');
    assert.equal(s.presented, false);
    assert.equal(s.openingRequested, false);
});

test('toggle cancels pending output query without reopening from its result', () => {
    const s = context();
    s.open();
    s.toggle();
    s.finishOpen('{"name":"HDMI-A-1"}');
    assert.equal(s.presented, false);
    assert.equal(s.opened, false);
});

test('close before deferred opening cannot revive the launcher', () => {
    const s = context();
    s.openingRequested = true;
    s.finishOpen('{"name":"HDMI-A-1"}');
    s.sheet.reveal = 0;
    s.close();
    s.queued.shift()();
    assert.equal(s.opened, false);
    assert.equal(s.presented, false);
});

test('application launch waits for dismissal and retains desktop path as one argument', () => {
    const s = context();
    s.targetScreen = s.secondary;
    s.opened = s.presented = s.openingRequested = true;
    s.activate({kind: 'application', desktopFile: '/apps/My App.desktop'});
    assert.equal(s.commandRunner.starts, 0);
    assert.equal(s.opened, false);
    assert.equal(s.presented, true);
    assert.deepEqual(Array.from(s.pendingCommand), ['gio', 'launch', '/apps/My App.desktop']);
    assert.match(source, /if \(!presented\)\s+Qt.callLater\(finishDismissal\)/);
    s.presented = false;
    s.finishDismissal();
    s.runPendingCommand();
    assert.equal(s.commandRunner.starts, 1);
});

test('dismissal does not launch anything or forcibly switch monitors', () => {
    const s = context();
    s.finishDismissal();
    assert.equal(s.commandRunner.starts, 0);
    assert.doesNotMatch(source, /focus-monitor|restoreOutput|launchOutputName/);
});

test('each opening resolves the newly focused monitor instead of reusing the previous one', () => {
    const s = context();
    s.openingRequested = true;
    s.finishOpen('{"name":"HDMI-A-1"}');
    assert.equal(s.targetScreen, s.secondary);
    s.sheet.reveal = 0;
    s.close();
    s.open();
    s.finishOpen('{"name":"DP-1"}');
    assert.equal(s.targetScreen, s.primary);
});

test('launcher uses overlay exclusive focus throughout presentation', () => {
    assert.match(source, /WlrLayershell.layer: WlrLayer.Overlay/);
    assert.match(source, /WlrLayershell.keyboardFocus: presented \? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None/);
});

test('liquid shell preserves full-size content, reduced motion and dismissal lifecycle', () => {
    assert.match(source, /LiquidSurface \{/);
    assert.match(source, /expanded: root.opened/);
    assert.match(source, /animationsEnabled: Config.ShellConfig.animationsEnabled/);
    assert.match(source, /onCollapsed:.*if \(!root.opened\) root.presented = false/);
    assert.doesNotMatch(source, /transform: Scale|Behavior on reveal/);
});
