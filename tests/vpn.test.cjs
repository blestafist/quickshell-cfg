const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('services/Vpn.qml', 'utf8');

function block(marker) {
    const start = source.indexOf('{', source.indexOf(marker));
    let depth = 1, end = start + 1;
    for (; depth; end++) {
        if (source[end] === '{') depth++;
        if (source[end] === '}') depth--;
    }
    return source.slice(start + 1, end - 1);
}

function context(connected = false) {
    const s = {
        autoConnect: true, startupAttempted: false, startupAttempts: 0,
        startupConnecting: false, savedTargetType: 'country',
        savedTargetValue: 'AT', savedTargetLabel: 'Austria', connects: 0,
        disconnects: 0, actionCompleted() {},
        retryTimer: {
            running: false,
            restart() { this.running = true; },
            stop() { this.running = false; }
        },
        backend: {
            connected, busy: false, startupRefreshDone: true,
            connectTarget() { s.connects++; },
            disconnect() { s.disconnects++; }
        }
    };
    s.root = s;
    vm.createContext(s);
    for (const [name, args] of [['disconnect', ''], ['cancelStartupAutoConnect', ''],
                               ['connectTarget', 'target, remember = true'], ['tryAutoConnect', '']]) {
        vm.runInContext(`function ${name}(${args}) {${block(`function ${name}(`)}}`, s);
    }
    s.complete = success => vm.runInContext(`(function(success) {${block('onActionCompleted:')}})(${success})`, s);
    s.retry = () => { s.retryTimer.running = false; s.tryAutoConnect(); };
    return s;
}

test('disconnect cancels startup even before the initial status arrives', () => {
    const s = context();
    s.backend.startupRefreshDone = false;
    s.disconnect();
    s.backend.startupRefreshDone = true;
    s.complete(true);
    s.tryAutoConnect();
    assert.equal(s.disconnects, 1);
    assert.equal(s.connects, 0);
    assert.equal(s.autoConnect, true);
});

test('an existing connection consumes startup; disconnect does not reconnect', () => {
    const s = context(true);
    s.tryAutoConnect();
    assert.equal(s.startupAttempted, true);
    s.disconnect();
    s.backend.connected = false;
    s.complete(true);
    s.tryAutoConnect();
    assert.equal(s.connects, 0);
});

test('only startup connection failures retry, with a delay and four-attempt limit', () => {
    const s = context();
    s.tryAutoConnect();
    for (let attempt = 1; attempt <= 4; attempt++) {
        assert.equal(s.connects, attempt);
        s.complete(false);
        assert.equal(s.retryTimer.running, attempt < 4);
        s.tryAutoConnect();
        assert.equal(s.connects, attempt);
        if (attempt < 4) s.retry();
    }
    assert.equal(s.startupAttempts, 4);
});

test('manual disconnect cancels a queued retry even when disconnect fails', () => {
    const s = context();
    s.tryAutoConnect();
    s.complete(false);
    s.disconnect();
    assert.equal(s.retryTimer.running, false);
    s.complete(false);
    s.retry();
    assert.equal(s.connects, 1);
});

test('manual connection cancels startup retries and is not itself retried', () => {
    const s = context();
    s.tryAutoConnect();
    s.complete(false);
    s.connectTarget({type: 'server', value: 'AT#1', label: 'AT#1'});
    assert.equal(s.retryTimer.running, false);
    s.complete(false);
    s.retry();
    assert.equal(s.connects, 2);
    assert.equal(s.savedTargetValue, 'AT#1');
});

test('unrelated command failure does not rearm completed startup', () => {
    const s = context();
    s.tryAutoConnect();
    s.complete(true);
    s.complete(false);
    s.tryAutoConnect();
    assert.equal(s.connects, 1);
    assert.equal(s.retryTimer.running, false);
});

test('disabled auto-connect never starts a connection', () => {
    const s = context();
    s.autoConnect = false;
    s.tryAutoConnect();
    s.complete(false);
    assert.equal(s.connects, 0);
});
