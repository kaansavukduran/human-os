#!/usr/bin/env python3
"""Write SHA256SUMS and a plain EN/TR release note for one preview build.

Two flavours of the same app (D-049): the development build, for trying the
app (entries kept unencrypted), and the encrypted build (APP_ENV=staging,
entries kept only in the encrypted vault), whose file names carry
"-encrypted-". Reads only the files that are really in <dir>: a file that is
not there is listed as missing, never claimed. Used by the `release` job of
.github/workflows/downloads.yml; it can be dry-run locally on empty files:

  mkdir -p /tmp/r && touch /tmp/r/Human-OS-0.1.1-dev.7-android.apk \\
      /tmp/r/Human-OS-0.1.1-dev.7-encrypted-android.apk
  python3 tools/release/release_notes.py --dir /tmp/r --version 0.1.1-dev.7 \\
      --revision 0123abc --out /tmp/r-notes.md

Exit 0 = notes written; 1 = no release files at all (nothing to publish);
2 = a file matches no known file (the catalogue below needs updating).
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import sys
from pathlib import Path

DEV, ENC = "development", "encrypted"

# (key, flavour, glob, short label, English "who is it for", Turkish "kimin
# için"). Order is the order of the lists. Every entry is expected in a full
# build; an entry without a file is listed as missing. A name with
# "-encrypted-" is matched only against encrypted entries and any other name
# only against development ones, so "*.deb" never claims an encrypted .deb.
CATALOGUE = [
    ("enc-windows-setup", ENC, "*-encrypted-windows-x64-Setup.exe",
     "Windows installer (.exe)",
     "Windows PC: download, double-click, install. It installs as "
     "\"Human OS (encrypted)\", beside the development app",
     "Windows bilgisayar: indir, çift tıkla, kur. \"Human OS (encrypted)\" "
     "adıyla, geliştirme sürümünün yanına kurulur"),
    ("enc-windows-portable", ENC, "*-encrypted-windows-x64-portable.zip",
     "Windows portable (.zip)",
     "Windows PC without installing: unzip, double-click "
     "human_health_os.exe. The vault stays in UserData beside the app, so the "
     "folder can move (e.g. to a USB stick)",
     "Windows, kurmadan: ZIP'i aç, human_health_os.exe'ye çift tıkla. Kasa "
     "uygulamanın yanındaki UserData klasöründe durur, klasör taşınabilir "
     "(örneğin USB belleğe)"),
    ("enc-macos", ENC, "*-encrypted-macos.zip", "Mac (.zip)",
     "Mac: unzip, move \"Human OS encrypted\" to Applications, right-click "
     "it and choose Open",
     "Mac: ZIP'i aç, \"Human OS encrypted\" uygulamasını Uygulamalar'a taşı, "
     "sağ tıkla > Aç"),
    ("enc-android-apk", ENC, "*-encrypted-android.apk",
     "Android phone (.apk)",
     "Android phone: open this page on the phone and tap this file",
     "Android telefon: bu sayfayı telefonda aç ve bu dosyaya dokun"),
    ("enc-deb", ENC, "*-encrypted-*.deb", "Ubuntu/Debian (.deb)",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: double-click to install "
     "(\"Human OS (encrypted)\", beside the development app)",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: çift tıkla, kur "
     "(\"Human OS (encrypted)\", geliştirme sürümünün yanına)"),
    ("enc-rpm", ENC, "*-encrypted-*.rpm", "Fedora (.rpm)",
     "Fedora, Nobara, openSUSE: double-click to install "
     "(\"Human OS (encrypted)\", beside the development app)",
     "Fedora, Nobara, openSUSE: çift tıkla, kur "
     "(\"Human OS (encrypted)\", geliştirme sürümünün yanına)"),
    ("enc-appimage", ENC, "*-encrypted-*.AppImage",
     "other Linux (.AppImage)",
     "Any other Linux: make it executable, then double-click it",
     "Diğer Linux dağıtımları: çalıştırılabilir yap, çift tıkla"),
    ("enc-linux-portable", ENC, "*-encrypted-*.tar.zst",
     "Linux portable (.tar.zst)",
     "Linux without installing: unpack, run ./human_health_os. The vault "
     "stays in UserData beside the app",
     "Linux, kurmadan: aç, ./human_health_os çalıştır. Kasa uygulamanın "
     "yanındaki UserData klasöründe durur"),
    ("windows-setup", DEV, "*-windows-x64-Setup.exe",
     "Windows installer (.exe)",
     "Windows PC: download this and double-click it to install",
     "Windows bilgisayar: indir, çift tıkla, kur"),
    ("windows-portable", DEV, "*-windows-x64-portable.zip",
     "Windows portable (.zip)",
     "Windows PC without installing: unzip, double-click human_health_os.exe",
     "Windows, kurmadan: ZIP'i aç, human_health_os.exe'ye çift tıkla"),
    ("macos", DEV, "*-macos.zip", "Mac (.zip)",
     "Mac: unzip, move the app to Applications, right-click it and choose Open",
     "Mac: ZIP'i aç, uygulamayı Uygulamalar'a taşı, sağ tıkla > Aç"),
    ("android-apk", DEV, "*-android.apk", "Android phone (.apk)",
     "Android phone: open this page on the phone and tap this file",
     "Android telefon: bu sayfayı telefonda aç ve bu dosyaya dokun"),
    ("android-aab", DEV, "*-android.aab", "Android App Bundle (.aab)",
     "Not for phones: Android App Bundle for store testing only",
     "Telefon için değil: yalnızca mağaza testi için Android App Bundle"),
    ("deb", DEV, "*.deb", "Ubuntu/Debian (.deb)",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: double-click to install",
     "Ubuntu, Debian, Linux Mint, Pop!_OS: çift tıkla, kur"),
    ("rpm", DEV, "*.rpm", "Fedora (.rpm)",
     "Fedora, Nobara, openSUSE: double-click to install",
     "Fedora, Nobara, openSUSE: çift tıkla, kur"),
    ("appimage", DEV, "*.AppImage", "other Linux (.AppImage)",
     "Any other Linux: make it executable, then double-click it",
     "Diğer Linux dağıtımları: çalıştırılabilir yap, çift tıkla"),
    ("web", DEV, "*-web.zip", "browser (web .zip)",
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

ENC_MARK = "-encrypted-"


def classify(name: str) -> str | None:
    flavour = ENC if ENC_MARK in name else DEV
    for key, fl, pattern, *_ in CATALOGUE:
        if fl == flavour and fnmatch.fnmatchcase(name, pattern):
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


CHOOSE_EN = [
    "## Which file should I choose?",
    "",
    "There are two builds of the same app. Pick by what you want to do:",
    "",
    "- **To try the app: the development build** (file names *without* "
    "\"encrypted\"). What you enter is kept on this device **without "
    "encryption**, and the app shows that it is a development build. Use it "
    "to look around, not for your real records.",
    "- **To keep your own records: the encrypted build** (file names *with* "
    "\"encrypted\"). On first start you create a passphrase and get a "
    "recovery key: write the key down and keep it somewhere safe. Your "
    "records are saved only in an encrypted vault, and nothing is saved "
    "before you create or unlock it. **If you lose both the passphrase and "
    "the recovery key, nobody can recover your data.**",
    "- The encrypted build does not open what you entered in the development "
    "build by itself. To move your records: make a backup or an export in "
    "the development build (\"Your data\" on Today), then, in the encrypted "
    "vault, choose \"Bring in records from the development build\". Records "
    "already in the vault are skipped; a record that differs from the one in "
    "the vault stops the whole import, and nothing is changed. That file is "
    "not encrypted: delete it yourself once your records are in the vault.",
    "- In the browser (web .zip) there is only the development build: a "
    "browser build that is not a development build keeps nothing after the "
    "tab closes, so it could not keep your records.",
    "- On Android both builds are the same app: a phone holds one of them. "
    "Remove the other first (its data goes with it).",
]

CHOOSE_TR = [
    "## Hangi dosyayı seçmeliyim?",
    "",
    "Aynı uygulamanın iki sürümü var. Ne yapmak istediğine göre seç:",
    "",
    "- **Uygulamayı denemek için: geliştirme sürümü** (adında \"encrypted\" "
    "*olmayan* dosyalar). Girdiklerin bu cihazda **şifrelenmeden** saklanır "
    "ve uygulama bunun bir geliştirme sürümü olduğunu gösterir. Göz atmak "
    "için kullan, gerçek kayıtların için değil.",
    "- **Kendi kayıtlarını tutmak için: şifreli sürüm** (adında "
    "\"encrypted\" *olan* dosyalar). İlk açılışta bir parola belirlersin ve "
    "bir kurtarma anahtarı alırsın: anahtarı yaz ve güvenli bir yerde sakla. "
    "Kayıtların yalnızca şifreli bir kasada saklanır; kasayı oluşturmadan ya "
    "da açmadan hiçbir şey kaydedilmez. **Parolayı da kurtarma anahtarını da "
    "kaybedersen verilerini kimse geri getiremez.**",
    "- Şifreli sürüm, geliştirme sürümünde girdiklerini kendiliğinden açmaz. "
    "Kayıtlarını taşımak için geliştirme sürümünde yedek al ya da dışa aktar "
    "(Bugün'deki \"Verilerin\"); sonra şifreli kasada \"Geliştirme "
    "sürümündeki kayıtları buraya getir\"i seç. Kasada zaten olan kayıtlar "
    "atlanır; kasadakinden farklı bir kayıt bütün aktarımı durdurur ve hiçbir "
    "şey değişmez. O dosya şifreli değildir: kayıtların kasaya geçince onu "
    "kendin sil.",
    "- Tarayıcıda (web .zip) yalnızca geliştirme sürümü var: geliştirme "
    "sürümü olmayan bir tarayıcı sürümü sekme kapanınca hiçbir şey tutmaz, "
    "yani kayıtlarını saklayamaz.",
    "- Android'de iki sürüm aynı uygulamadır: bir telefonda biri durur. "
    "Önce diğerini kaldır (verisi de silinir).",
]


def build(files: list[Path], version: str, revision: str,
          results: dict[str, str], run_url: str) -> str:
    by_key: dict[str, list[str]] = {}
    for f in files:
        by_key.setdefault(classify(f.name) or "", []).append(f.name)
    flavour_label = {DEV: "development / geliştirme",
                     ENC: "encrypted / şifreli"}
    missing = [f"{label}, {flavour_label[fl]}"
               for key, fl, _, label, _, _ in CATALOGUE if key not in by_key]

    def listing(flavour: str, lang: int) -> list[str]:
        out = []
        for key, fl, _, _, en, tr in CATALOGUE:
            if fl != flavour or key not in by_key:
                continue
            for name in sorted(by_key[key]):
                out.append(f"- **{(en, tr)[lang]}:** `{name}`")
        return out or [("- No file of this build is attached; see "
                        "\"Missing\" below.",
                        "- Bu sürümün hiçbir dosyası ekli değil; aşağıdaki "
                        "\"eksik\" bölümüne bak.")[lang]]

    L: list[str] = []
    L.append(f"Human OS {version}, preview builds from `{revision}`.")
    if run_url:
        L.append(f"Build log: {run_url}")
    L += ["",
          "> **Unsigned previews, not for clinical decisions.** No file here "
          "is signed, so Windows (SmartScreen) and macOS (Gatekeeper) will "
          "warn that the publisher is unknown. Nothing here is for clinical "
          "decisions.",
          ">",
          "> **İmzasız ön sürümler, klinik karar için değildir.** Buradaki "
          "hiçbir dosya imzalı değildir; bu yüzden Windows (SmartScreen) ve "
          "macOS (Gatekeeper) yayıncının bilinmediği uyarısını gösterir. "
          "Buradaki hiçbir şey klinik karar için değildir.",
          ""]
    L += CHOOSE_EN
    L += ["", "### Encrypted build: for your own records", ""]
    L += listing(ENC, 0)
    L += ["", "### Development build: for trying out (not encrypted)", ""]
    L += listing(DEV, 0)
    for en, _, why_en, _ in NOT_BUILT:
        L.append(f"- {en}: {why_en}.")
    L += [""]
    L += CHOOSE_TR
    L += ["", "### Şifreli sürüm: kendi kayıtların için", ""]
    L += listing(ENC, 1)
    L += ["", "### Geliştirme sürümü: denemek için (şifresiz)", ""]
    L += listing(DEV, 1)
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
        print("files that match no known file:", ", ".join(unknown),
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
