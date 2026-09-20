#!/usr/bin/env python3
"""Builds dist/LanguageItaly.qm (Turkish content) from translations/tr.json.

Sources come from the stock English .qm (translations/en_full.json), numerus rules are
copied from the stock Italian .qm. Validates coverage and placeholders before writing.
"""
import json, re, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import qm

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EN = os.path.join(ROOT, "translations", "en_full.json")
TR = os.path.join(ROOT, "translations", "tr.json")
STOCK_IT = os.path.join(ROOT, "stock", "LanguageItaly.qm")
OUT = os.path.join(ROOT, "dist", "LanguageItaly.qm")

en = json.load(open(EN, encoding="utf-8"))
tr = json.load(open(TR, encoding="utf-8"))
_, numerus = qm.read_qm(STOCK_IT)

errors, out, untranslated = [], [], []
for m in en:
    src = m["source"]
    if src not in tr:
        errors.append(f"missing translation: {m['context']} | {src!r}")
        continue
    t = tr[src]
    if t is None or t == "":
        untranslated.append(src)
        t = None
    else:
        for ph in re.findall(r"%\d+|%n", src):
            if ph not in t:
                errors.append(f"placeholder {ph} missing in: {src!r} -> {t!r}")
        if src.count("\n") and not t.count("\n"):
            errors.append(f"newline dropped in: {src!r} -> {t!r}")
    out.append({"context": m["context"], "source": src, "comment": m.get("comment", ""),
                "translations": [t]})

unused = sorted(set(tr) - {m["source"] for m in en})
if unused:
    print("warning: unused keys in tr.json:", unused, file=sys.stderr)
if errors:
    print("\n".join(errors), file=sys.stderr); sys.exit(1)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
qm.write_qm(OUT, out, numerus)
print(f"wrote {OUT}: {len(out)} messages, {len(untranslated)} left untranslated {untranslated}")
