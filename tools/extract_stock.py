#!/usr/bin/env python3
"""Extracts the reference files this project needs out of a stock Anycubic SWU.

Anycubic's own translation files are not redistributed with this repository, so the
build inputs are produced locally from a firmware package you supply yourself.

Writes:
  stock/LanguageEnglish.qm      source strings + contexts (build input, git-ignored)
  stock/LanguageItaly.qm        the file we replace; also supplies the plural rules
  translations/en_full.json     the string list build_qm.py validates against

Usage:
  python3 tools/extract_stock.py /path/to/stock_2.7.2.7.swu
"""
import argparse, hashlib, json, os, shutil, subprocess, sys, tarfile, tempfile, zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qm

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# SWU archive passwords, per printer family (from the Rinkhals project)
SWU_PASSWORDS = {
    "KS1/KS1M": "U2FsdGVkX1+lG6cHmshPLI/LaQr9cZCjA8HZt6Y8qmbB7riY",
    "K2P/K3/K3V2": "U2FsdGVkX19deTfqpXHZnB5GeyQ/dtlbHjkUnwgCi+w=",
    "K3M": "4DKXtEGStWHpPgZm8Xna9qluzAI8VJzpOsEIgd8brTLiXs8fLSu3vRx8o7fMf4h6",
}
WANTED = ["LanguageEnglish.qm", "LanguageItaly.qm"]


def unzip(swu, dest):
    """SWU files are ZIPs with a per-model password. Try each known one."""
    last = None
    for family, password in SWU_PASSWORDS.items():
        try:
            with zipfile.ZipFile(swu) as z:
                z.extractall(dest, pwd=password.encode())
            return family
        except Exception as e:  # wrong password, or AES-encrypted entries
            last = e
    # Python's zipfile only handles legacy ZipCrypto; fall back to the unzip binary
    for family, password in SWU_PASSWORDS.items():
        r = subprocess.run(["unzip", "-o", "-q", "-P", password, swu, "-d", dest],
                           capture_output=True)
        if r.returncode == 0:
            return family
    raise SystemExit(f"Could not open {swu} with any known SWU password ({last})")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("swu", help="stock Anycubic firmware .swu (downloaded by you)")
    args = ap.parse_args()

    if not os.path.isfile(args.swu):
        raise SystemExit(f"No such file: {args.swu}")

    work = tempfile.mkdtemp(prefix="stock-swu-")
    try:
        family = unzip(args.swu, work)
        print(f"Opened SWU ({family} password)")

        setup = os.path.join(work, "update_swu", "setup.tar.gz")
        if not os.path.isfile(setup):
            setup = os.path.join(work, "update_swu", "setup.tar")
        if not os.path.isfile(setup):
            raise SystemExit("setup.tar(.gz) not found inside the SWU")

        payload = os.path.join(work, "setup")
        os.makedirs(payload, exist_ok=True)
        with tarfile.open(setup) as t:
            t.extractall(payload)

        stock_dir = os.path.join(ROOT, "stock")
        os.makedirs(stock_dir, exist_ok=True)

        found = {}
        for root, _dirs, files in os.walk(payload):
            for f in files:
                if f in WANTED and f not in found:
                    found[f] = os.path.join(root, f)
        missing = [w for w in WANTED if w not in found]
        if missing:
            raise SystemExit(f"Not found inside the SWU: {', '.join(missing)}")

        for name, src in found.items():
            dst = os.path.join(stock_dir, name)
            shutil.copyfile(src, dst)
            digest = hashlib.md5(open(dst, "rb").read()).hexdigest()
            print(f"  stock/{name}  md5 {digest}")

        # The English file carries the authoritative source strings and contexts
        msgs, _ = qm.read_qm(os.path.join(stock_dir, "LanguageEnglish.qm"))
        out = [{"context": m.get("context", ""), "source": m.get("source", ""),
                "comment": m.get("comment", ""), "translations": m.get("translations", [])}
               for m in msgs]
        target = os.path.join(ROOT, "translations", "en_full.json")
        os.makedirs(os.path.dirname(target), exist_ok=True)
        json.dump(out, open(target, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(f"  translations/en_full.json  {len(out)} strings")
        print("\nDone. Next: python3 tools/build_qm.py")
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
