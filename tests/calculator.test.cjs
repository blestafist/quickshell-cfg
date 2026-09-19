const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const vm = require('node:vm');

const context = vm.createContext(Object.create(null), {
    codeGeneration: { strings: false, wasm: false }
});
vm.runInContext(fs.readFileSync(path.join(__dirname, '../services/Calculator.js'), 'utf8'), context);
const evaluate = context.evaluate;

function succeeds(input, expected, ans) {
    const actual = evaluate(input, ans);
    assert.equal(actual.ok, true, `${input}: ${actual.error}`);
    assert.ok(Math.abs(actual.value - expected) <= 1e-12 * Math.max(1, Math.abs(expected)),
        `${input}: expected ${expected}, got ${actual.value}`);
    assert.equal(typeof actual.text, 'string');
    assert.ok(Number.isFinite(Number(actual.text)));
    return actual;
}

function fails(input, ans) {
    const actual = evaluate(input, ans);
    assert.equal(actual.ok, false, String(input));
    assert.equal(typeof actual.error, 'string');
    assert.ok(actual.error.length > 0, String(input));
    return actual;
}

test('numbers, decimal conventions, scientific notation and display', () => {
    for (const [input, expected] of [
        ['42', 42], ['.5 + 1.', 1.5], ['1,5 + 2,25', 3.75],
        ['1.2e3 + 2E-2', 1200.02], ['1,5e2', 150],
        ['min(1,5)', 1], ['min(1,5;2,5)', 1.5],
        ['pow(1,5;2)', 2.25], ['max(min(1,5;2,5), 3)', 3],
        ['min(3;2;1)', 1], ['sqrt(1.5)', Math.sqrt(1.5)]
    ]) succeeds(input, expected);
    fails('sqrt(1,5)');
    fails('1, 5');
    assert.equal(succeeds('0.1+0.2', 0.3).text, '0.3');
    assert.equal(succeeds('-0', 0).text, '0');
    assert.equal(Object.is(evaluate('-0').value, -0), false);
});

test('precedence, right-associative powers and unary signs', () => {
    for (const [input, expected] of [
        ['2+3*4', 14], ['(2+3)*4', 20], ['8/2*2', 8],
        ['2^3^2', 512], ['2**3**2', 512], ['2^3**2', 512],
        ['-2^2', -4], ['(-2)^2', 4], ['2^-2', 0.25],
        ['-2^-2', -0.25], ['--2', 2], ['2+-3', -1], ['2^-2^2', 1 / 16]
    ]) succeeds(input, expected);
});

test('relative addition/subtraction percentages and fractional multiplication', () => {
    for (const [input, expected] of [
        ['10%', 0.1], ['200+10%', 220], ['200-10%', 180],
        ['200*10%', 20], ['200/10%', 2000], ['200+10%+10%', 242],
        ['200+(-10%)', 180], ['200+(10%)', 220], ['200+10%*2', 200.2],
        ['200+(5+5)%', 220], ['50%%', 0.005], ['2^2%', Math.pow(2, 0.02)]
    ]) succeeds(input, expected);
});

test('constants, previous result and implicit multiplication', () => {
    succeeds('2pi', 2 * Math.PI);
    succeeds('2(3+4)', 14);
    succeeds('(2+3)(4+5)', 45);
    succeeds('2sin(pi/2)', 2);
    succeeds('pi(2)', Math.PI * 2);
    succeeds('e', Math.E);
    succeeds('ans*2', 14, 7);
    succeeds('ans', 0, 0);
    for (const ans of [undefined, null, '7', Infinity, NaN]) fails('ans', ans);
});

test('supported functions use radians and enforce arity', () => {
    for (const [input, expected] of [
        ['sqrt(9)', 3], ['abs(-2)', 2], ['sin(pi/2)', 1], ['cos(0)', 1],
        ['tan(pi/4)', 1], ['asin(1)', Math.PI / 2], ['acos(1)', 0],
        ['atan(1)', Math.PI / 4], ['log(100)', 2], ['ln(e)', 1],
        ['exp(1)', Math.E], ['floor(-1.2)', -2], ['ceil(-1.2)', -1],
        ['round(1.5)', 2], ['min(3,1,2)', 1], ['max(3,1,2)', 3],
        ['pow(2,3)', 8], ['sqrt(abs(-16))', 4]
    ]) succeeds(input, expected);
    for (const input of ['sin()', 'sin(1,2)', 'pow(2)', 'pow(1,2,3)', 'min()', 'max()']) fails(input);
});

test('empty input, invalid syntax, domains and non-finite results', () => {
    for (const input of ['', ' \t\n']) {
        assert.equal(evaluate(input).ok, false);
        assert.equal(evaluate(input).error, '');
    }
    for (const input of [
        null, undefined, 42, {}, '1/0', '0/0', '1/(-0)', 'sqrt(-1)',
        'ln(0)', 'log(-1)', 'acos(2)', 'exp(10000)', '1e999', '10^999',
        '(-1)^.5', '1e308*10', '(', ')', '2+', '*2', '2 3', '1.2.3',
        'min(1,)', 'pow(,2)', '2***3', 'foo(2)', 'foo', '2!'
    ]) fails(input);
    assert.equal(evaluate('1/0').error, 'Деление на ноль');
    succeeds('2+2', 4); // Failures do not leave shared parser state.
});

test('malicious input cannot access or execute JavaScript', () => {
    for (const input of [
        'process.exit()', 'globalThis', 'this', 'constructor.constructor("return 1")()',
        'eval("1+1")', 'require("fs")', 'ans=1', '1;2', '(()=>1)()',
        '[1][0]', '{a:1}', 'Math.PI', '__proto__', '1/*comment*/+2',
        'while(true){}', 'globalThis.compromised=1'
    ]) fails(input);
    assert.equal(context.compromised, undefined);
});

test('input, token and recursive nesting limits', () => {
    fails('1'.repeat(2049));
    fails(' '.repeat(2049));
    fails('1+'.repeat(300) + '1');
    fails('('.repeat(80) + '1' + ')'.repeat(80));
    fails('-'.repeat(80) + '1');
    fails('2^'.repeat(80) + '1');
    fails('sin('.repeat(80) + '0' + ')'.repeat(80));
    succeeds('('.repeat(20) + '2' + ')'.repeat(20), 2);
    succeeds('1+'.repeat(200) + '1', 201);
});
