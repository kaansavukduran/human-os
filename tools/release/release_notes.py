#!/usr/bin/env python3
"""Write SHA256SUMS and a plain EN/TR release note for one development build.

Reads only the files that are really in <dir>: a platform whose file is not
there is listed as missing, never claimed. Used by the `release` job of
.github/workflows/downloads.yml; it can be dry-run locally on empty files:

  mkdir -p /tmp/r && touch /tmp/r/Human-OS-0.1.0-dev.7-android.apk
  python3 tools/release/release_notes.py --dir /tmp/r --version 0.1.0-dev.7 \
      --revision 0123abc --out /tmp/r-notes.md

Exit 0 = notes written; 1 = no release files at all (nothing to publish);
2 = a file matches no known platform (the catalogue below needs updating).
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import sys
from pathlib import Path

# (key, glob, short label, English "who is it for", Turkish "kimin için").
# Order is the order of the "Which file is mine?" list. Every entry is
# expected in a full build; an entry without a file is listed as missing.
CATALOGUE = [
    ("windows-setup", "*-windows-x64-Setup.exe", "Windows installer (.exe)",
     "Windows PC: download this and double-click it to install",
     "Windows bilgisayar: indir, çift tıkla, kur"),
    ("windows-portable", "*-windows-x64-portable.zip", "Windows portable (.zip)",
     "Windows PC without installing: unzip, double-click human_health_os.exe",
     "Windows, kurmadan: ZIP'i aç, human_health_os.exe'ye çift tıkla"),
    ("macos", "*-macos.zip", "Mac (.zip)",
     "Mac: unzip, move the app to Applications, right-click it and choose Open",
     "Mac: ZIP'i aç, uygulamayı Uygulamalar'a taşı, sağ tıkla > Aç"),
    ("android-apk", "*-android.apk", "Android phone (.apk)",
     "Android phone: open this page on the phone and tap this file",
     "Android telefon: bu sayfayı telefonda aç ve bu dosyaya dokun"),
    ("android-aab", "*-android.aab", "Android App Bundle (.aab)",
     "Not for phones: Android App Bundle for store testing only",
     "Telefon için değil: yalnızca mağaza testi için Android App Bundle"),
    ("deb", "*.deb", "Ubuntu/Debian (.deb)",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: double-click to install",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: çift tıkla, kur"),
    ("rpm", "*.rpm", "Fedora (.rpm)",
     "Fedora, Nobara, openSUSE: double-click to install",
     "Fedora, Nobara, openSUSE: çift tıkla, kur"),
    ("appimage", "*.AppImage", "other Linux (.AppImage)",
     "Any other Linux: make it executable, then double-click it",
     "Diğer Linux dağıtımları: çalıştırılabilir yap, çift tıkla"),
    ("linux-portable", "*.tar.zst", "Linux portable (.tar.zst)",
     "Linux without installing (portable, keeps data in an encrypted vault)",
     "Linux, kurmadan (taşınabilir, veriyi şifreli kasada tutar)"),
    ("web", "*-web.zip", "browser (web .zip)",
     "Any computer, in the browser: unzip, double-click Human-OS-baslat.bat "
     "(Windows) or run ./Human-OS-baslat.sh (needs python3)",
     "Her bilgisayar, tarayıcıda: ZIP'i aç, Human-OS-baslat.bat'a çift tıkla "
     "(Windows) ya da ./Human-OS-baslat.sh çalıştır (python3 gerekir)"),
]

NOT_BUILT = [
    ("iPhone/iPad (iOS)", "iPhone/iPad (iOS)",
     "not built: installing on an iPhone needs an Apple signing identity",
     "üretilmedi: iPhone'a kurmak için Apple imza kimliği gerekir"),
]


def classify(name: str) -> str | None:
    for key, pattern, *_ in CATALOGUE:
        if fnmatch.fnmatchcase(name, pattern):
            return key
    return None


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def parse_results(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for item in filter(None, (p.strip() for p in text.split(","))):
        name, _, result = item.partition("=")
        out[name.strip()] = result.strip() or "unknown"
    return out


def build(files: list[Path], version: str, revision: str,
          results: dict[str, str], run_url: str) -> str:
    by_key: dict[str, list[str]] = {}
    for f in files:
        by_key.setdefault(classify(f.name) or "", []).append(f.name)
    present = [c for c in CATALOGUE if c[0] in by_key]
    missing = [label for key, _, label, _, _ in CATALOGUE
               if key not in by_key]

    L: list[str] = []
    L.append(f"Human OS {version}, development build from `{revision}`.")
    if run_url:
        L.append(f"Build log: {run_url}")
    L += ["",
          "> **Warning: development build for testing.** Most of these builds "
          "keep your entries unencrypted on this device, none is signed for an "
          "app store, and nothing here is for clinical decisions. "
          "**Do not enter real health data.**",
          ">",
          "> **Uyarı: test amaçlı geliştirme sürümü.** Bu sürümlerin çoğu "
          "girdiğin verileri bu cihazda şifrelemeden saklar, hiçbiri mağaza "
          "için imzalı değildir ve klinik karar için değildir. "
          "**Gerçek sağlık verisi girme.**",
          "", "## Which file is mine?", ""]
    for key, _, _, en, _ in present:
        for name in sorted(by_key[key]):
            L.append(f"- **{en}:** `{name}`")
    for en, _, why_en, _ in NOT_BUILT:
        L.append(f"- {en}: {why_en}.")
    L += ["", "## Hangi dosya benim?", ""]
    for key, _, _, _, tr in present:
        for name in sorted(by_key[key]):
            L.append(f"- **{tr}:** `{name}`")
    for _, tr, _, why_tr in NOT_BUILT:
        L.append(f"- {tr}: {why_tr}.")

    L += ["", "## Missing from this build / Bu sürümde eksik olanlar", ""]
    if missing:
        L.append("No file in this release for (its build failed or was "
                 "skipped; see the build log) / Bu sürümde dosyası olmayanlar "
                 "(derleme başarısız oldu ya da atlandı; derleme kaydına bak):")
        L.append("")
        for label in missing:
            L.append(f"- {label}")
    else:
        L.append("- Nothing: every file a full build makes is here. "
                 "/ Hiçbiri: tam bir derlemenin ürettiği her dosya burada.")
    failed = sorted(j for j, r in results.items() if r != "success")
    if failed:
        L.append("")
        L.append("Build jobs that did not succeed / başarısız işler: "
                 + ", ".join(f"{j} ({results[j]})" for j in failed) + ".")

    L += ["", "## Checksums / Sağlama toplamları", "",
          "`SHA256SUMS` on this page lists the SHA-256 of every file. "
          "Check a download with `sha256sum -c SHA256SUMS --ignore-missing` "
          "(Linux), `shasum -a 256 <file>` (Mac) or "
          "`Get-FileHash <file>` (Windows PowerShell).", ""]
    for f in files:
        L.append(f"- `{sha256(f)}`  {f.name}")
    L += ["", "Android: the signing key changes with every build; remove the "
          "old app first to install a newer one (its data goes with it). / "
          "Android: imza anahtarı her sürümde değişir; yenisini kurmadan önce "
          "eskisini kaldır (verisi de silinir).",
          "Windows and Mac may warn that the publisher is unknown (not signed). "
          "/ Windows ve Mac yayıncının bilinmediğini söyleyebilir (imzasız).",
          ""]
    return "\n".join(L)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--dir", required=True, type=Path)
    ap.add_argument("--version", required=True)
    ap.add_argument("--revision", required=True)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--results", default="",
                    help="job=result pairs, comma separated (from needs.*)")
    ap.add_argument("--run-url", default="")
    a = ap.parse_args()

    files = sorted(p for p in a.dir.iterdir()
                   if p.is_file() and p.name != "SHA256SUMS")
    if not files:
        print("no release files in", a.dir, file=sys.stderr)
        return 1
    unknown = [f.name for f in files if classify(f.name) is None]
    if unknown:
        print("files that match no platform:", ", ".join(unknown),
              file=sys.stderr)
        return 2
    (a.dir / "SHA256SUMS").write_text(
        "".join(f"{sha256(f)}  {f.name}\n" for f in files), encoding="utf-8")
    a.out.write_text(build(files, a.version, a.revision,
                           parse_results(a.results), a.run_url),
                     encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
