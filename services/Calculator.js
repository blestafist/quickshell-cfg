// Standalone QML script; intentionally no .pragma library or Node exports.
// Angles are radians. Outside calls, 1,5 means 1.5. Within a call commas
// separate arguments, unless that call has a top-level semicolon: min(1,5;2,5).
// Use sqrt(1.5), not sqrt(1,5). Whitespace cannot split a decimal number.
// A direct percent RHS of + or - is relative to the LHS; other operators
// use its fractional value. Parentheses and unary signs preserve percent status.
function evaluate(input, ans) {
    var maxLength = 2048;
    var maxTokens = 512;
    var maxDepth = 64;
    var tokens = [];
    var position = 0;
    var depth = 0;

    function fail(message) { throw new Error(message); }
    function result(value, percent) {
        if (!Number.isFinite(value))
            fail("Результат не является конечным числом");
        return { value: value === 0 ? 0 : value, percent: !!percent };
    }
    function peek(text) { return tokens[position].text === text; }
    function take(text) {
        if (!peek(text)) return false;
        position++;
        return true;
    }
    function expect(text) {
        if (!take(text)) fail("Ожидается «" + text + "»");
    }

    function call(name, args) {
        var arity = 1;
        var fn;
        switch (name) {
        case "sqrt": fn = Math.sqrt; break;
        case "abs": fn = Math.abs; break;
        case "sin": fn = Math.sin; break;
        case "cos": fn = Math.cos; break;
        case "tan": fn = Math.tan; break;
        case "asin": fn = Math.asin; break;
        case "acos": fn = Math.acos; break;
        case "atan": fn = Math.atan; break;
        case "log": fn = Math.log10; break;
        case "ln": fn = Math.log; break;
        case "exp": fn = Math.exp; break;
        case "floor": fn = Math.floor; break;
        case "ceil": fn = Math.ceil; break;
        case "round": fn = Math.round; break;
        case "pow": fn = Math.pow; arity = 2; break;
        case "min": fn = Math.min; arity = -1; break;
        case "max": fn = Math.max; arity = -1; break;
        default: fail("Неизвестная функция: " + name);
        }
        if ((arity === -1 && args.length === 0) || (arity !== -1 && args.length !== arity))
            fail("Неверное число аргументов: " + name);
        return result(fn.apply(Math, args));
    }

    function primary(decimalComma) {
        var token = tokens[position];
        if (token.kind === "number") {
            position++;
            var text = token.text;
            var next = tokens[position + 1];
            if (decimalComma && peek(",") && next && next.kind === "number"
                    && token.end === tokens[position].start
                    && tokens[position].end === next.start
                    && /^[0-9]+$/.test(text)
                    && /^[0-9]+(?:[eE][+-]?[0-9]+)?$/.test(next.text)) {
                text += "." + next.text;
                position += 2;
            }
            return result(Number(text));
        }
        if (take("(")) {
            var grouped = expression(decimalComma);
            expect(")");
            return grouped;
        }
        if (token.kind === "name") {
            position++;
            var name = token.text;
            if (name === "pi") return result(Math.PI);
            if (name === "e") return result(Math.E);
            if (name === "ans") {
                if (typeof ans !== "number" || !Number.isFinite(ans))
                    fail("Предыдущий результат недоступен");
                return result(ans);
            }
            expect("(");
            // Only separators at this call's own nesting level select its mode.
            var level = 0;
            var semicolons = false;
            for (var i = position; i < tokens.length; i++) {
                var t = tokens[i].text;
                if (t === "(" ) level++;
                else if (t === ")") {
                    if (level === 0) break;
                    level--;
                } else if (t === ";" && level === 0) semicolons = true;
            }
            var args = [];
            if (!peek(")")) {
                do {
                    args.push(expression(semicolons).value);
                } while (take(semicolons ? ";" : ","));
            }
            expect(")");
            return call(name, args);
        }
        fail("Ожидается число или выражение");
    }

    function power(decimalComma) {
        var left = primary(decimalComma);
        while (take("%")) left = result(left.value / 100, true);
        if (take("^") || take("**"))
            return result(Math.pow(left.value, unary(decimalComma).value));
        return left;
    }
    function unary(decimalComma) {
        if (++depth > maxDepth) fail("Слишком сложное выражение");
        var value;
        if (take("+")) value = unary(decimalComma);
        else if (take("-")) {
            var operand = unary(decimalComma);
            value = result(-operand.value, operand.percent);
        } else value = power(decimalComma);
        depth--;
        return value;
    }
    function product(decimalComma) {
        var left = unary(decimalComma);
        while (true) {
            var divide = false;
            if (take("*")) { /* explicit multiplication */ }
            else if (take("/")) divide = true;
            else if (!peek("(") && tokens[position].kind !== "name") break;
            var right = unary(decimalComma);
            if (divide && right.value === 0) fail("Деление на ноль");
            left = result(divide ? left.value / right.value : left.value * right.value);
        }
        return left;
    }
    function expression(decimalComma) {
        var left = product(decimalComma);
        while (peek("+") || peek("-")) {
            var subtract = take("-");
            if (!subtract) expect("+");
            var right = product(decimalComma);
            var amount = right.percent ? left.value * right.value : right.value;
            left = result(subtract ? left.value - amount : left.value + amount);
        }
        return left;
    }

    try {
        if (typeof input !== "string") fail("Введите выражение");
        if (input.length > maxLength) fail("Выражение слишком длинное");
        if (!input.trim()) return { ok: false, error: "" };
        var offset = 0;
        while (offset < input.length) {
            if (/\s/.test(input.charAt(offset))) { offset++; continue; }
            var rest = input.slice(offset);
            var match = /^(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?/.exec(rest);
            var kind = "number";
            if (!match) { match = /^[a-zA-Z_][a-zA-Z_0-9]*/.exec(rest); kind = "name"; }
            if (!match) { match = /^(?:\*\*|[+\-*/^()%.,;])/.exec(rest); kind = "symbol"; }
            if (!match) fail("Недопустимый символ: " + input.charAt(offset));
            tokens.push({ kind: kind, text: match[0], start: offset, end: offset + match[0].length });
            if (tokens.length > maxTokens) fail("Слишком сложное выражение");
            offset += match[0].length;
        }
        tokens.push({ kind: "end", text: "" });
        var value = expression(true).value;
        if (tokens[position].kind !== "end") fail("Неожиданный символ: " + tokens[position].text);
        // Display rounding hides ordinary floating-point noise without changing value.
        return { ok: true, value: value, text: String(Number(value.toPrecision(15))) };
    } catch (error) {
        return { ok: false, error: error.message || "Не удалось вычислить выражение" };
    }
}
