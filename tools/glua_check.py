#!/usr/bin/env python3
"""Chequeo de sintaxis GLua sin GMod.

Traduce las extensiones de GLua (!=, &&, ||, !, //, /* */, continue) a Lua 5.1
y compila cada archivo con LuaJIT (paquete pip `lupa`). No ejecuta nada.

Uso:  python3 tools/glua_check.py [carpeta ...]
"""
import os
import re
import sys

from lupa import luajit21 as lupa_rt

IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def translate(src):
    out = []
    i, n = 0, len(src)
    prev_ident = None

    def long_bracket(pos):
        m = re.match(r"\[(=*)\[", src[pos:])
        if not m:
            return None
        close = "]" + m.group(1) + "]"
        end = src.find(close, pos + len(m.group(0)))
        return n if end < 0 else end + len(close)

    while i < n:
        c = src[i]
        two = src[i:i + 2]
        if two == "--":
            end = long_bracket(i + 2)
            if end is not None:
                out.append(re.sub(r"[^\n]", " ", src[i:end]))
                i = end
            else:
                j = src.find("\n", i)
                j = n if j < 0 else j
                out.append(" " * (j - i))
                i = j
            continue
        if two == "//":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
            continue
        if two == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", src[i:j]))
            i = j
            continue
        if c == "[":
            end = long_bracket(i)
            if end is not None:
                out.append(src[i:end])
                i = end
                continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                elif src[j] == "\n":
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
            continue
        if two == "!=":
            out.append("~=")
            i += 2
            continue
        if two == "&&":
            out.append(" and")
            i += 2
            continue
        if two == "||":
            out.append(" or ")
            i += 2
            continue
        if c == "!":
            out.append(" not ")
            i += 1
            continue
        m = IDENT.match(src, i)
        if m:
            word = m.group(0)
            if word == "continue" and prev_ident != ".":
                out.append("do end  ")
            else:
                out.append(word)
            i = m.end()
            prev_ident = word
            continue
        if not c.isspace():
            prev_ident = c
        out.append(c)
        i += 1
    return "".join(out)


def main(paths):
    lua = lupa_rt.LuaRuntime()
    compile_ = lua.eval("function(s, name) local f, e = loadstring(s, name) return e end")
    bad = 0
    total = 0
    for root in paths or ["."]:
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if d not in (".git", "_retirados", "node_modules")]
            for fn in fns:
                if not fn.endswith(".lua"):
                    continue
                p = os.path.join(dp, fn)
                total += 1
                with open(p, encoding="utf-8", errors="replace") as fh:
                    src = fh.read()
                if src.startswith("﻿"):
                    src = src[1:]
                err = compile_(translate(src), "@" + p)
                if err:
                    bad += 1
                    print(err)
    print(f"{total} archivos, {bad} con errores de sintaxis")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
