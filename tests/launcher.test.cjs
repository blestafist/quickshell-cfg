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
        targetScreen: null, launchOutputName: '', message: '', showingHidden: false, pendingCommand: [],
        outputFocusChanged: false, focusLauncherOutput: {running: false},
        restoreOutput: {starts: 0, startDetached() { this.starts++; }},
        Config: {MachineConfig: {primaryMonitor: primary.name}},
        Quickshell: {screens: [primary, secondary], env: () => '/run/niri.sock'},
        Qt: {callLater: fn => queued.push(fn)},
        search: {text: '', focuses: 0, forceActiveFocus() { this.focuses++; }},
        filterResults() {}, focusedOutput: {running: false},
        sheet: {reveal: 1}, commandRunner: {starts: 0, startDetached() { this.starts++; }},
        queued, primary, secondary,
    };
    vm.createContext(s);
    for (const name of ['open', 'finishOpen', 'presentOnTarget', 'close', 'toggle', 'activate', 'runPendingCommand', 'finishDismissal', 'restoreOutputFocus'])
        vm.runInContext(functionSource(name), s);
    return s;
}

test('launcher stays on primary, remembers focused output for launch and focuses search after mapping', () => {
    const s = context();
    s.open();
    assert.equal(s.focusedOutput.running, true);
    assert.equal(s.presented, false);
    s.finishOpen('{"name":"HDMI-A-1"}');
    assert.equal(s.targetScreen, s.primary);
    assert.equal(s.launchOutputName, s.secondary.name);
    assert.equal(s.presented, false);
    assert.deepEqual(Array.from(s.focusLauncherOutput.command),
        ['niri', 'msg', 'action', 'focus-monitor', 'DP-1']);
    s.presentOnTarget();
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
    s.presentOnTarget();
    s.sheet.reveal = 0;
    s.close();
    s.queued.shift()();
    assert.equal(s.opened, false);
    assert.equal(s.presented, false);
});

test('application launch waits for dismissal and retains output and quoted desktop path', () => {
    const s = context();
    s.targetScreen = s.primary;
    s.launchOutputName = s.secondary.name;
    s.opened = s.presented = s.openingRequested = true;
    s.activate({kind: 'application', desktopFile: '/apps/My App.desktop'});
    assert.equal(s.commandRunner.starts, 0);
    assert.equal(s.opened, false);
    assert.equal(s.presented, true);
    assert.deepEqual(Array.from(s.pendingCommand).slice(3),
        ['launcher', 'HDMI-A-1', 'gio', 'launch', '/apps/My App.desktop']);
    assert.match(s.pendingCommand[2], /focus-monitor "\$1".*exec "\$@"/);
    assert.match(source, /if \(!presented\)\s+Qt.callLater\(finishDismissal\)/);
    s.presented = false;
    s.finishDismissal();
    s.runPendingCommand();
    assert.equal(s.commandRunner.starts, 1);
});

test('dismissal restores original output without launching an application', () => {
    const s = context();
    s.outputFocusChanged = true;
    s.launchOutputName = s.secondary.name;
    s.finishDismissal();
    assert.deepEqual(Array.from(s.restoreOutput.command),
        ['niri', 'msg', 'action', 'focus-monitor', 'HDMI-A-1']);
    assert.equal(s.restoreOutput.starts, 1);
    s.finishDismissal();
    assert.equal(s.restoreOutput.starts, 1);
});

test('cancelled output focus transfer does not map the launcher', () => {
    const s = context();
    s.openingRequested = true;
    s.finishOpen('{"name":"HDMI-A-1"}');
    s.close();
    s.presentOnTarget();
    assert.equal(s.presented, false);
    assert.equal(s.queued.length, 0);
});

test('launcher uses overlay exclusive focus throughout presentation', () => {
    assert.match(source, /WlrLayershell.layer: WlrLayer.Overlay/);
    assert.match(source, /WlrLayershell.keyboardFocus: presented \? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None/);
});

test('reveal bounces only on opening, with bounded shape morph and reduced-motion support', () => {
    assert.match(source, /property real progress: Math.max\(0, Math.min\(1, reveal\)\)/);
    const reveal = source.slice(source.indexOf('Behavior on reveal'), source.indexOf('Behavior on height'));
    assert.match(reveal, /enabled: Config.ShellConfig.animationsEnabled/);
    assert.match(reveal, /duration: root.opened \? 420 : 280/);
    assert.match(reveal, /easing.type: root.opened \? Easing.OutBack : Easing.OutCubic/);
});
