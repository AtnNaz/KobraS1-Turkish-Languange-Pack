#!/usr/bin/env python3
"""Pure-Python reader/writer for Qt Linguist compiled translation files (.qm).

No Qt dependency. Verified by byte-identical round-trip of Anycubic's stock files.

Format (big-endian):
  16-byte magic
  sections: 1-byte tag, 4-byte length, payload
    0x42 Hashes      : sorted (elfHash(source+comment) u32, offset u32) pairs
    0x69 Messages    : per message: [Tag_Translation(3) len utf16be]* Tag_Comment(8) len utf8
                       Tag_SourceText(6) len utf8 Tag_Context(7) len utf8 Tag_End(1)
                       (messages are written sorted by context, then source, as lrelease does)
    0x88 NumerusRules: opaque bytes (copied through)
    0x2f Contexts    : optional fast-path table (not written; QTranslator works without it)
"""
import struct, sys, json

MAGIC = bytes.fromhex("3cb86418caef9c95cd211cbf60a1bddd")
TAG_END, TAG_TRANSLATION, TAG_SOURCE, TAG_CONTEXT, TAG_COMMENT = 1, 3, 6, 7, 8
SEC_HASHES, SEC_MESSAGES, SEC_NUMERUS = 0x42, 0x69, 0x88


def elf_hash(data: bytes) -> int:
    h = 0
    for b in data:
        h = ((h << 4) + b) & 0xFFFFFFFF
        g = h & 0xF0000000
        if g:
            h ^= g >> 24
        h &= ~g & 0xFFFFFFFF
    return h or 1


def read_sections(data: bytes) -> dict:
    assert data[:16] == MAGIC, "not a .qm file"
    pos, sections = 16, {}
    while pos < len(data):
        tag = data[pos]
        ln = struct.unpack(">I", data[pos + 1:pos + 5])[0]
        sections[tag] = data[pos + 5:pos + 5 + ln]
        pos += 5 + ln
    return sections


def parse_messages(blob: bytes) -> list:
    """Returns list of dicts: {context, source, comment, translations:[...]}"""
    out, p, cur = [], 0, {"translations": []}
    while p < len(blob):
        t = blob[p]; p += 1
        if t == TAG_END:
            out.append(cur); cur = {"translations": []}
            continue
        ln = struct.unpack(">I", blob[p:p + 4])[0]; p += 4
        if t == TAG_TRANSLATION:
            if ln == 0xFFFFFFFF:  # null QString (untranslated) -> None
                cur["translations"].append(None); ln = 0
            else:
                cur["translations"].append(blob[p:p + ln].decode("utf-16-be"))
        elif t == TAG_SOURCE:
            cur["source"] = blob[p:p + ln].decode("utf-8")
        elif t == TAG_CONTEXT:
            cur["context"] = blob[p:p + ln].decode("utf-8")
        elif t == TAG_COMMENT:
            cur["comment"] = blob[p:p + ln].decode("utf-8")
        else:
            raise ValueError(f"unsupported tag {t} at offset {p}")
        p += ln
    return out


def read_qm(path: str):
    sections = read_sections(open(path, "rb").read())
    msgs = parse_messages(sections.get(SEC_MESSAGES, b""))
    return msgs, sections.get(SEC_NUMERUS, b"")


def encode_message(m: dict) -> bytes:
    b = bytearray()
    for t in m.get("translations", []):
        if t is None:  # null QString: Qt writes length 0xFFFFFFFF
            b += struct.pack(">BI", TAG_TRANSLATION, 0xFFFFFFFF)
            continue
        enc = t.encode("utf-16-be")
        b += struct.pack(">BI", TAG_TRANSLATION, len(enc)) + enc
    cmt = m.get("comment", "").encode("utf-8")
    b += struct.pack(">BI", TAG_COMMENT, len(cmt)) + cmt
    src = m.get("source", "").encode("utf-8")
    b += struct.pack(">BI", TAG_SOURCE, len(src)) + src
    ctx = m.get("context", "").encode("utf-8")
    b += struct.pack(">BI", TAG_CONTEXT, len(ctx)) + ctx
    b += bytes([TAG_END])
    return bytes(b)


def write_qm(path: str, msgs: list, numerus: bytes = b""):
    # lrelease writes messages sorted by (context, source, comment) bytes, and a separate
    # hash table sorted by (elfHash(source+comment), offset).
    key = lambda m: (m.get("context", "").encode("utf-8"), m.get("source", "").encode("utf-8"),
                     m.get("comment", "").encode("utf-8"))
    messages = bytearray(); pairs = []
    for m in sorted(msgs, key=key):
        h = elf_hash(m.get("source", "").encode("utf-8") + m.get("comment", "").encode("utf-8"))
        pairs.append((h, len(messages)))
        messages += encode_message(m)
    hashes = bytearray()
    for h, off in sorted(pairs):
        hashes += struct.pack(">II", h, off)
    out = bytearray(MAGIC)
    out += struct.pack(">BI", SEC_HASHES, len(hashes)) + hashes
    out += struct.pack(">BI", SEC_MESSAGES, len(messages)) + messages
    if numerus:
        out += struct.pack(">BI", SEC_NUMERUS, len(numerus)) + numerus
    open(path, "wb").write(out)


if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] not in ("dump", "roundtrip"):
        print("usage: qm.py dump <file.qm> | qm.py roundtrip <in.qm> <out.qm>"); sys.exit(1)
    msgs, numerus = read_qm(sys.argv[2])
    if sys.argv[1] == "dump":
        json.dump(msgs, sys.stdout, ensure_ascii=False, indent=1)
    else:
        write_qm(sys.argv[3], msgs, numerus)
        a, b = open(sys.argv[2], "rb").read(), open(sys.argv[3], "rb").read()
        print("identical" if a == b else f"DIFFER (len {len(a)} vs {len(b)})")
