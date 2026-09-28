const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync('lockscreen/LockContext.qml', 'utf8');

function block(text, marker) {
    const start = text.indexOf('{', text.indexOf(marker));
    let depth = 1, end = start + 1;
    for (; depth; end++) {
        if (text[end] === '{') depth++;
        if (text[end] === '}') depth--;
    }
    return text.slice(start + 1, end - 1);
}
function context() {
    const s = {
        permitted: true, succeeded: false, waiting: false, coolingDown: false,
        failed: false, statusMessage: '', clears: 0, unlocks: 0, replies: [],
        clearInput() { s.clears++; }, authenticated() { s.unlocks++; },
        retryTimer: {restart() {}, stop() {}},
        PamResult: {Success: 0, Failed: 1, Error: 2},
        pam: {active: false, start() { this.active = true; return true; },
            abort() { this.active = false; }, respond(v) { s.replies.push(v); }}
    };
    Object.defineProperties(s, {
        active: {get: () => s.pam.active},
        canBegin: {get: () => s.permitted && !s.active && !s.coolingDown && !s.succeeded},
        canRespond: {get: () => s.permitted && s.active && s.waiting && !s.succeeded}
    });
    s.root = s;
    vm.createContext(s);
    for (const [name, args] of [['begin',''], ['respond','value'], ['reset',''], ['failure','message']])
        vm.runInContext(`function ${name}(${args}) {${block(source, `function ${name}(`)}}`, s);
    s.deliver = (prompt, visible = false, required = true) => {
        Object.assign(s, {message: prompt, responseRequired: required, responseVisible: visible});
        vm.runInContext(block(source, 'onPamMessage:'), s);
    };
    s.complete = result => { s.result = result; s.pam.active = false; vm.runInContext(block(source, 'onCompleted:'), s); };
    return s;
}

test('each PAM prompt waits for a distinct nonempty user response', () => {
    const s = context(); s.begin(); s.deliver('Password');
    assert.deepEqual(s.replies, []);
    s.respond(''); assert.deepEqual(s.replies, []);
    s.respond('sample'); s.respond('duplicate');
    assert.deepEqual(s.replies, ['sample']);
    s.deliver('OTP'); assert.equal(s.waiting, true);
    assert.deepEqual(s.replies, ['sample']);
    s.respond('123456'); assert.deepEqual(s.replies, ['sample', '123456']);
    s.complete(0); assert.equal(s.unlocks, 1);
});
test('visible prompts and informational messages never auto-respond', () => {
    const s = context(); s.begin(); s.deliver('Username', true);
    assert.equal(s.responseVisible, true); s.respond('sample');
    s.deliver('Touch your security key', false, false);
    assert.equal(s.waiting, false); assert.equal(s.replies.length, 1);
});
test('failure, error, cancel and success while unpermitted cannot unlock', () => {
    for (const result of [1, 2]) {
        const s = context(); s.begin(); s.complete(result);
        assert.equal(s.unlocks, 0); assert.equal(s.coolingDown, true);
    }
    const s = context(); s.begin(); s.reset();
    assert.equal(s.active, false); assert.equal(s.unlocks, 0);
    s.permitted = false; s.complete(0); assert.equal(s.unlocks, 0);
});
test('only guarded success releases protocol lock; preview is separate', () => {
    const real = fs.readFileSync('lock.qml', 'utf8');
    assert.equal((real.match(/sessionLock\.locked = false/g) || []).length, 1);
    assert.match(real, /authState\.succeeded && sessionLock\.secure && !root\.suspendPending/);
    assert.doesNotMatch(real, /Qt\.quit|MockAuth|FileView|secureMarker/);
    assert.match(real, /Quickshell\.watchFiles = false/);
    const preview = fs.readFileSync('lock-preview.qml', 'utf8');
    assert.doesNotMatch(preview, /WlSessionLock|LockContext/);
});

test('suspend owner rejects stale ack and pending unlock, gates auth before command', () => {
    const real = fs.readFileSync('lock.qml', 'utf8');
    for (const state of [{secure: false}, {locked: false}, {releasing: true},
                         {succeeded: true}, {suspendPending: true}]) {
        const s = {sessionLock: {secure: true, locked: true, ...state},
            releasing: !!state.releasing, suspendPending: !!state.suspendPending,
            authState: {succeeded: !!state.succeeded, reset() {}},
            suspendProcess: {running: false}};
        s.root = s; vm.createContext(s);
        const result = vm.runInContext(`(function() {${block(real, 'function suspend():')}})()`, s);
        assert.equal(result, false); assert.equal(s.suspendProcess.running, false);
    }
    const s = {sessionLock: {secure: true, locked: true}, releasing: false,
        suspendPending: false, authState: {succeeded: false, reset() {
            assert.equal(s.suspendPending, true);
        }}, suspendProcess: {running: false}};
    s.root = s; vm.createContext(s);
    assert.equal(vm.runInContext(`(function() {${block(real, 'function suspend():')}})()`, s), true);
    assert.equal(s.suspendProcess.running, true);
});
