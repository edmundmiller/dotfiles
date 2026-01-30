/* esm.sh - @byjohann/toon@0.6.0 */
var fe = Object.defineProperty;
var ce = (e, t, n) =>
  t in e ? fe(e, t, { enumerable: !0, configurable: !0, writable: !0, value: n }) : (e[t] = n);
var m = (e, t, n) => ce(e, typeof t != "symbol" ? t + "" : t, n);
var C = "null",
  K = "true",
  j = "false";
var k = { comma: ",", tab: "	", pipe: "|" },
  E = k.comma;
function H(e) {
  return e
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\n/g, "\\n")
    .replace(/\r/g, "\\r")
    .replace(/\t/g, "\\t");
}
function D(e) {
  let t = "",
    n = 0;
  for (; n < e.length; ) {
    if (e[n] === "\\") {
      if (n + 1 >= e.length)
        throw new SyntaxError("Invalid escape sequence: backslash at end of string");
      let r = e[n + 1];
      if (r === "n") {
        ((t += `
`),
          (n += 2));
        continue;
      }
      if (r === "t") {
        ((t += "	"), (n += 2));
        continue;
      }
      if (r === "r") {
        ((t += "\r"), (n += 2));
        continue;
      }
      if (r === "\\") {
        ((t += "\\"), (n += 2));
        continue;
      }
      if (r === '"') {
        ((t += '"'), (n += 2));
        continue;
      }
      throw new SyntaxError(`Invalid escape sequence: \\${r}`);
    }
    ((t += e[n]), n++);
  }
  return t;
}
function N(e, t) {
  let n = t + 1;
  for (; n < e.length; ) {
    if (e[n] === "\\" && n + 1 < e.length) {
      n += 2;
      continue;
    }
    if (e[n] === '"') return n;
    n++;
  }
  return -1;
}
function F(e, t, n = 0) {
  let r = !1,
    i = n;
  for (; i < e.length; ) {
    if (e[i] === "\\" && i + 1 < e.length && r) {
      i += 2;
      continue;
    }
    if (e[i] === '"') {
      ((r = !r), i++);
      continue;
    }
    if (e[i] === t && !r) return i;
    i++;
  }
  return -1;
}
function p(e) {
  return e === K || e === j || e === C;
}
function le(e) {
  if (!e || (e.length > 1 && e[0] === "0" && e[1] !== ".")) return !1;
  let t = Number(e);
  return !Number.isNaN(t) && Number.isFinite(t);
}
function R(e, t) {
  if (e.trimStart().startsWith('"')) return;
  let n = e.indexOf("[");
  if (n === -1) return;
  let r = e.indexOf("]", n);
  if (r === -1) return;
  let i = r + 1,
    s = i,
    f = e.indexOf("{", r);
  if (f !== -1 && f < e.indexOf(":", r)) {
    let d = e.indexOf("}", f);
    d !== -1 && (s = d + 1);
  }
  if (((i = e.indexOf(":", Math.max(r, s))), i === -1)) return;
  let c = n > 0 ? e.slice(0, n) : void 0,
    l = e.slice(i + 1).trim(),
    u = e.slice(n + 1, r),
    a;
  try {
    a = ue(u, t);
  } catch (d) {
    return;
  }
  let { length: h, delimiter: o, hasLengthMarker: ie } = a,
    U;
  if (f !== -1 && f < i) {
    let d = e.indexOf("}", f);
    d !== -1 && d < i && (U = B(e.slice(f + 1, d), o).map((se) => V(se.trim())));
  }
  return {
    header: { key: c, length: h, delimiter: o, fields: U, hasLengthMarker: ie },
    inlineValues: l || void 0,
  };
}
function ue(e, t) {
  let n = !1,
    r = e;
  r.startsWith("#") && ((n = !0), (r = r.slice(1)));
  let i = t;
  r.endsWith("	")
    ? ((i = k.tab), (r = r.slice(0, -1)))
    : r.endsWith("|") && ((i = k.pipe), (r = r.slice(0, -1)));
  let s = Number.parseInt(r, 10);
  if (Number.isNaN(s)) throw new TypeError(`Invalid array length: ${e}`);
  return { length: s, delimiter: i, hasLengthMarker: n };
}
function B(e, t) {
  let n = [],
    r = "",
    i = !1,
    s = 0;
  for (; s < e.length; ) {
    let f = e[s];
    if (f === "\\" && s + 1 < e.length && i) {
      ((r += f + e[s + 1]), (s += 2));
      continue;
    }
    if (f === '"') {
      ((i = !i), (r += f), s++);
      continue;
    }
    if (f === t && !i) {
      (n.push(r.trim()), (r = ""), s++);
      continue;
    }
    ((r += f), s++);
  }
  return ((r || n.length > 0) && n.push(r.trim()), n);
}
function Q(e) {
  return e.map((t) => M(t));
}
function M(e) {
  let t = e.trim();
  if (!t) return "";
  if (t.startsWith('"')) return V(t);
  if (p(t)) {
    if (t === K) return !0;
    if (t === j) return !1;
    if (t === C) return null;
  }
  return le(t) ? Number.parseFloat(t) : t;
}
function V(e) {
  let t = e.trim();
  if (t.startsWith('"')) {
    let n = N(t, 0);
    if (n === -1) throw new SyntaxError("Unterminated string: missing closing quote");
    if (n !== t.length - 1) throw new SyntaxError("Unexpected characters after closing quote");
    return D(t.slice(1, n));
  }
  return t;
}
function oe(e, t) {
  let n = t;
  for (; n < e.length && e[n] !== ":"; ) n++;
  if (n >= e.length || e[n] !== ":") throw new SyntaxError("Missing colon after key");
  let r = e.slice(t, n).trim();
  return (n++, { key: r, end: n });
}
function ae(e, t) {
  let n = N(e, t);
  if (n === -1) throw new SyntaxError("Unterminated quoted key");
  let r = D(e.slice(t + 1, n)),
    i = n + 1;
  if (i >= e.length || e[i] !== ":") throw new SyntaxError("Missing colon after key");
  return (i++, { key: r, end: i });
}
function de(e, t) {
  return e[t] === '"' ? ae(e, t) : oe(e, t);
}
function W(e) {
  return e.trim().startsWith("[") && F(e, ":") !== -1;
}
function he(e) {
  return F(e, ":") !== -1;
}
function O(e, t, n, r) {
  if (r.strict && e !== t) throw new RangeError(`Expected ${t} ${n}, but got ${e}`);
}
function me(e, t, n) {
  if (e.atEnd()) return;
  let r = e.peek();
  if (r && r.depth === t && r.content.startsWith("- "))
    throw new RangeError(`Expected ${n} list array items, but found more`);
}
function Ee(e, t, n) {
  if (e.atEnd()) return;
  let r = e.peek();
  if (r && r.depth === t && !r.content.startsWith("- ") && ge(r.content, n.delimiter))
    throw new RangeError(`Expected ${n.length} tabular rows, but found more`);
}
function q(e, t, n, r, i) {
  if (!r) return;
  let s = n.filter((f) => f.lineNumber > e && f.lineNumber < t);
  if (s.length > 0)
    throw new SyntaxError(
      `Line ${s[0].lineNumber}: Blank lines inside ${i} are not allowed in strict mode`
    );
}
function ge(e, t) {
  let n = e.indexOf(":"),
    r = e.indexOf(t);
  return n === -1 || (r !== -1 && r < n);
}
function Le(e, t) {
  let n = e.peek();
  if (!n) throw new ReferenceError("No content to decode");
  if (W(n.content)) {
    let r = R(n.content, E);
    if (r) return (e.advance(), $(r.header, r.inlineValues, e, 0, t));
  }
  return e.length === 1 && !ye(n) ? M(n.content.trim()) : X(e, 0, t);
}
function ye(e) {
  let t = e.content;
  if (t.startsWith('"')) {
    let n = N(t, 0);
    return n === -1 ? !1 : n + 1 < t.length && t[n + 1] === ":";
  } else return t.includes(":");
}
function X(e, t, n) {
  let r = {};
  for (; !e.atEnd(); ) {
    let i = e.peek();
    if (!i || i.depth < t) break;
    if (i.depth === t) {
      let [s, f] = J(i, e, t, n);
      r[s] = f;
    } else break;
  }
  return r;
}
function G(e, t, n, r) {
  let i = R(e, E);
  if (i && i.header.key) {
    let l = $(i.header, i.inlineValues, t, n, r);
    return { key: i.header.key, value: l, followDepth: n + 1 };
  }
  let { key: s, end: f } = de(e, 0),
    c = e.slice(f).trim();
  if (!c) {
    let l = t.peek();
    return l && l.depth > n
      ? { key: s, value: X(t, n + 1, r), followDepth: n + 1 }
      : { key: s, value: {}, followDepth: n + 1 };
  }
  return { key: s, value: M(c), followDepth: n + 1 };
}
function J(e, t, n, r) {
  t.advance();
  let { key: i, value: s } = G(e.content, t, n, r);
  return [i, s];
}
function $(e, t, n, r, i) {
  return t ? Oe(e, t, i) : e.fields && e.fields.length > 0 ? Ie(e, n, r, i) : Ae(e, n, r, i);
}
function Oe(e, t, n) {
  if (!t.trim()) return (O(0, e.length, "inline array items", n), []);
  let r = Q(B(t, e.delimiter));
  return (O(r.length, e.length, "inline array items", n), r);
}
function Ae(e, t, n, r) {
  let i = [],
    s = n + 1,
    f,
    c;
  for (; !t.atEnd() && i.length < e.length; ) {
    let l = t.peek();
    if (!l || l.depth < s) break;
    if (l.depth === s && l.content.startsWith("- ")) {
      (f === void 0 && (f = l.lineNumber), (c = l.lineNumber));
      let u = Se(t, s, e.delimiter, r);
      i.push(u);
      let a = t.current();
      a && (c = a.lineNumber);
    } else break;
  }
  return (
    O(i.length, e.length, "list array items", r),
    r.strict && f !== void 0 && c !== void 0 && q(f, c, t.getBlankLines(), r.strict, "list array"),
    r.strict && me(t, s, e.length),
    i
  );
}
function Ie(e, t, n, r) {
  let i = [],
    s = n + 1,
    f,
    c;
  for (; !t.atEnd() && i.length < e.length; ) {
    let l = t.peek();
    if (!l || l.depth < s) break;
    if (l.depth === s) {
      (f === void 0 && (f = l.lineNumber), (c = l.lineNumber), t.advance());
      let u = B(l.content, e.delimiter);
      O(u.length, e.fields.length, "tabular row values", r);
      let a = Q(u),
        h = {};
      for (let o = 0; o < e.fields.length; o++) h[e.fields[o]] = a[o];
      i.push(h);
    } else break;
  }
  return (
    O(i.length, e.length, "tabular rows", r),
    r.strict &&
      f !== void 0 &&
      c !== void 0 &&
      q(f, c, t.getBlankLines(), r.strict, "tabular array"),
    r.strict && Ee(t, s, e),
    i
  );
}
function Se(e, t, n, r) {
  let i = e.next();
  if (!i) throw new ReferenceError("Expected list item");
  let s = i.content.slice(2);
  if (W(s)) {
    let f = R(s, E);
    if (f) return $(f.header, f.inlineValues, e, t, r);
  }
  return he(s) ? be(i, e, t, r) : M(s);
}
function be(e, t, n, r) {
  let { key: i, value: s, followDepth: f } = G(e.content.slice(2), t, n, r),
    c = { [i]: s };
  for (; !t.atEnd(); ) {
    let l = t.peek();
    if (!l || l.depth < f) break;
    if (l.depth === f && !l.content.startsWith("- ")) {
      let [u, a] = J(l, t, f, r);
      c[u] = a;
    } else break;
  }
  return c;
}
var ke = class {
  constructor(e, t = []) {
    m(this, "lines");
    m(this, "index");
    m(this, "blankLines");
    ((this.lines = e), (this.index = 0), (this.blankLines = t));
  }
  getBlankLines() {
    return this.blankLines;
  }
  peek() {
    return this.lines[this.index];
  }
  next() {
    return this.lines[this.index++];
  }
  current() {
    return this.index > 0 ? this.lines[this.index - 1] : void 0;
  }
  advance() {
    this.index++;
  }
  atEnd() {
    return this.index >= this.lines.length;
  }
  get length() {
    return this.lines.length;
  }
  peekAtDepth(e) {
    let t = this.peek();
    if (!(!t || t.depth < e) && t.depth === e) return t;
  }
  hasMoreAtDepth(e) {
    return this.peekAtDepth(e) !== void 0;
  }
};
function Te(e, t, n) {
  if (!e.trim()) return { lines: [], blankLines: [] };
  let r = e.split(`
`),
    i = [],
    s = [];
  for (let f = 0; f < r.length; f++) {
    let c = r[f],
      l = f + 1,
      u = 0;
    for (; u < c.length && c[u] === " "; ) u++;
    let a = c.slice(u);
    if (!a.trim()) {
      let o = w(u, t);
      s.push({ lineNumber: l, indent: u, depth: o });
      continue;
    }
    let h = w(u, t);
    if (n) {
      let o = 0;
      for (; o < c.length && (c[o] === " " || c[o] === "	"); ) o++;
      if (c.slice(0, o).includes("	"))
        throw new SyntaxError(`Line ${l}: Tabs are not allowed in indentation in strict mode`);
      if (u > 0 && u % t !== 0)
        throw new SyntaxError(
          `Line ${l}: Indentation must be exact multiple of ${t}, but found ${u} spaces`
        );
    }
    i.push({ raw: c, indent: u, content: a, depth: h, lineNumber: l });
  }
  return { lines: i, blankLines: s };
}
function w(e, t) {
  return Math.floor(e / t);
}
function y(e) {
  if (e === null) return null;
  if (typeof e == "string" || typeof e == "boolean") return e;
  if (typeof e == "number") return Object.is(e, -0) ? 0 : Number.isFinite(e) ? e : null;
  if (typeof e == "bigint")
    return e >= Number.MIN_SAFE_INTEGER && e <= Number.MAX_SAFE_INTEGER ? Number(e) : e.toString();
  if (e instanceof Date) return e.toISOString();
  if (Array.isArray(e)) return e.map(y);
  if (e instanceof Set) return Array.from(e).map(y);
  if (e instanceof Map) return Object.fromEntries(Array.from(e, ([t, n]) => [String(t), y(n)]));
  if (Me(e)) {
    let t = {};
    for (let n in e) Object.prototype.hasOwnProperty.call(e, n) && (t[n] = y(e[n]));
    return t;
  }
  return null;
}
function g(e) {
  return e === null || typeof e == "string" || typeof e == "number" || typeof e == "boolean";
}
function I(e) {
  return Array.isArray(e);
}
function S(e) {
  return e !== null && typeof e == "object" && !Array.isArray(e);
}
function Me(e) {
  if (e === null || typeof e != "object") return !1;
  let t = Object.getPrototypeOf(e);
  return t === null || t === Object.prototype;
}
function A(e) {
  return e.every((t) => g(t));
}
function _e(e) {
  return e.every((t) => I(t));
}
function Z(e) {
  return e.every((t) => S(t));
}
function Ce(e) {
  return /^[A-Z_][\w.]*$/i.test(e);
}
function Ne(e, t = ",") {
  return !(
    !e ||
    e !== e.trim() ||
    p(e) ||
    Re(e) ||
    e.includes(":") ||
    e.includes('"') ||
    e.includes("\\") ||
    /[[\]{}]/.test(e) ||
    /[\n\r\t]/.test(e) ||
    e.includes(t) ||
    e.startsWith("-")
  );
}
function Re(e) {
  return /^-?\d+(?:\.\d+)?(?:e[+-]?\d+)?$/i.test(e) || /^0\d+$/.test(e);
}
function b(e, t) {
  return e === null ? C : typeof e == "boolean" || typeof e == "number" ? String(e) : Be(e, t);
}
function Be(e, t = ",") {
  return Ne(e, t) ? e : `"${H(e)}"`;
}
function T(e) {
  return Ce(e) ? e : `"${H(e)}"`;
}
function Y(e, t = ",") {
  return e.map((n) => b(n, t)).join(t);
}
function L(e, t) {
  var c, l;
  let n = t == null ? void 0 : t.key,
    r = t == null ? void 0 : t.fields,
    i = (c = t == null ? void 0 : t.delimiter) != null ? c : ",",
    s = (l = t == null ? void 0 : t.lengthMarker) != null ? l : !1,
    f = "";
  if ((n && (f += T(n)), (f += `[${s || ""}${e}${i !== E ? i : ""}]`), r)) {
    let u = r.map((a) => T(a));
    f += `{${u.join(i)}}`;
  }
  return ((f += ":"), f);
}
var $e = class {
  constructor(e) {
    m(this, "lines", []);
    m(this, "indentationString");
    this.indentationString = " ".repeat(e);
  }
  push(e, t) {
    let n = this.indentationString.repeat(e);
    this.lines.push(n + t);
  }
  pushListItem(e, t) {
    this.push(e, `- ${t}`);
  }
  toString() {
    return this.lines.join(`
`);
  }
};
function xe(e, t) {
  if (g(e)) return b(e, t.delimiter);
  let n = new $e(t.indent);
  return (I(e) ? v(void 0, e, n, 0, t) : S(e) && x(e, n, 0, t), n.toString());
}
function x(e, t, n, r) {
  let i = Object.keys(e);
  for (let s of i) z(s, e[s], t, n, r);
}
function z(e, t, n, r, i) {
  let s = T(e);
  g(t)
    ? n.push(r, `${s}: ${b(t, i.delimiter)}`)
    : I(t)
      ? v(e, t, n, r, i)
      : S(t) &&
        (Object.keys(t).length === 0
          ? n.push(r, `${s}:`)
          : (n.push(r, `${s}:`), x(t, n, r + 1, i)));
}
function v(e, t, n, r, i) {
  if (t.length === 0) {
    let s = L(0, { key: e, delimiter: i.delimiter, lengthMarker: i.lengthMarker });
    n.push(r, s);
    return;
  }
  if (A(t)) {
    let s = _(t, i.delimiter, e, i.lengthMarker);
    n.push(r, s);
    return;
  }
  if (_e(t) && t.every((s) => A(s))) {
    Ue(e, t, n, r, i);
    return;
  }
  if (Z(t)) {
    let s = ee(t);
    s ? we(e, t, s, n, r, i) : P(e, t, n, r, i);
    return;
  }
  P(e, t, n, r, i);
}
function Ue(e, t, n, r, i) {
  let s = L(t.length, { key: e, delimiter: i.delimiter, lengthMarker: i.lengthMarker });
  n.push(r, s);
  for (let f of t)
    if (A(f)) {
      let c = _(f, i.delimiter, void 0, i.lengthMarker);
      n.pushListItem(r + 1, c);
    }
}
function _(e, t, n, r) {
  let i = L(e.length, { key: n, delimiter: t, lengthMarker: r }),
    s = Y(e, t);
  return e.length === 0 ? i : `${i} ${s}`;
}
function we(e, t, n, r, i, s) {
  let f = L(t.length, { key: e, fields: n, delimiter: s.delimiter, lengthMarker: s.lengthMarker });
  (r.push(i, `${f}`), te(t, n, r, i + 1, s));
}
function ee(e) {
  if (e.length === 0) return;
  let t = e[0],
    n = Object.keys(t);
  if (n.length !== 0 && Pe(e, n)) return n;
}
function Pe(e, t) {
  for (let n of e) {
    if (Object.keys(n).length !== t.length) return !1;
    for (let r of t) if (!(r in n) || !g(n[r])) return !1;
  }
  return !0;
}
function te(e, t, n, r, i) {
  for (let s of e) {
    let f = Y(
      t.map((c) => s[c]),
      i.delimiter
    );
    n.push(r, f);
  }
}
function P(e, t, n, r, i) {
  let s = L(t.length, { key: e, delimiter: i.delimiter, lengthMarker: i.lengthMarker });
  n.push(r, s);
  for (let f of t) re(f, n, r + 1, i);
}
function ne(e, t, n, r) {
  let i = Object.keys(e);
  if (i.length === 0) {
    t.push(n, "-");
    return;
  }
  let s = i[0],
    f = T(s),
    c = e[s];
  if (g(c)) t.pushListItem(n, `${f}: ${b(c, r.delimiter)}`);
  else if (I(c))
    if (A(c)) {
      let l = _(c, r.delimiter, s, r.lengthMarker);
      t.pushListItem(n, l);
    } else if (Z(c)) {
      let l = ee(c);
      if (l) {
        let u = L(c.length, {
          key: s,
          fields: l,
          delimiter: r.delimiter,
          lengthMarker: r.lengthMarker,
        });
        (t.pushListItem(n, u), te(c, l, t, n + 1, r));
      } else {
        t.pushListItem(n, `${f}[${c.length}]:`);
        for (let u of c) ne(u, t, n + 1, r);
      }
    } else {
      t.pushListItem(n, `${f}[${c.length}]:`);
      for (let l of c) re(l, t, n + 1, r);
    }
  else
    S(c) &&
      (Object.keys(c).length === 0
        ? t.pushListItem(n, `${f}:`)
        : (t.pushListItem(n, `${f}:`), x(c, t, n + 2, r)));
  for (let l = 1; l < i.length; l++) {
    let u = i[l];
    z(u, e[u], t, n + 1, r);
  }
}
function re(e, t, n, r) {
  if (g(e)) t.pushListItem(n, b(e, r.delimiter));
  else if (I(e) && A(e)) {
    let i = _(e, r.delimiter, void 0, r.lengthMarker);
    t.pushListItem(n, i);
  } else S(e) && ne(e, t, n, r);
}
function Ke(e, t) {
  return xe(y(e), He(t));
}
function je(e, t) {
  let n = De(t),
    r = Te(e, n.indent, n.strict);
  if (r.lines.length === 0)
    throw new TypeError("Cannot decode empty input: input must be a non-empty string");
  return Le(new ke(r.lines, r.blankLines), n);
}
function He(e) {
  var t, n, r;
  return {
    indent: (t = e == null ? void 0 : e.indent) != null ? t : 2,
    delimiter: (n = e == null ? void 0 : e.delimiter) != null ? n : E,
    lengthMarker: (r = e == null ? void 0 : e.lengthMarker) != null ? r : !1,
  };
}
function De(e) {
  var t, n;
  return {
    indent: (t = e == null ? void 0 : e.indent) != null ? t : 2,
    strict: (n = e == null ? void 0 : e.strict) != null ? n : !0,
  };
}
export { E as DEFAULT_DELIMITER, k as DELIMITERS, je as decode, Ke as encode };
//# sourceMappingURL=toon.mjs.map
