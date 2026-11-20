#!/usr/bin/env bash
# Package a real Flutter Linux release bundle into the v0.28 channels.
# Only formats whose tools exist are produced; each missing tool is reported
# as NOT_RUN, never faked. Usage:
#   tools/linux/package.sh <bundle-dir> <out-dir> <version> <source-revision>
# Optional env: APPIMAGETOOL=<path> APPIMAGE_RUNTIME=<path>
#   FLAVOR=development (default) | encrypted. "encrypted" packages a bundle
#   built with APP_ENV=staging (encrypted vault, D-049) as its own app
#   "Human OS (encrypted)": package human-health-os-encrypted, command
#   human-health-os-encrypted, desktop id org.humanhealthos.HumanHealthOS.Encrypted,
#   so it installs beside the development package and never replaces it.
#   The flavour only names the package; the bundle decides the storage.
set -euo pipefail

BUNDLE=$(readlink -f "$1"); OUT=$(readlink -f -m "$2"); VERSION=$3; REV=$4
REPO=$(cd "$(dirname "$0")/../.." && pwd)
P="$REPO/packaging/linux"
ID=org.humanhealthos.HumanHealthOS
case "${FLAVOR:-development}" in
  development) PKG=human-health-os; AID=$ID; APPNAME="Human OS"; BASE=HumanHealthOS ;;
  encrypted) PKG=human-health-os-encrypted; AID=$ID.Encrypted; APPNAME="Human OS (encrypted)"; BASE=HumanHealthOS-Encrypted ;;
  *) echo "FLAVOR must be development or encrypted" >&2; exit 2 ;;
esac
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OUT"
EPOCH=$(git -C "$REPO" log -1 --format=%ct "$REV" 2>/dev/null || date +%s)
export SOURCE_DATE_EPOCH=$EPOCH
STATUS="$OUT/package-status.txt"; : > "$STATUS"
note() { echo "$1" | tee -a "$STATUS"; }

[ -x "$BUNDLE/human_health_os" ] || { echo "no release bundle at $BUNDLE" >&2; exit 1; }

# Desktop entry and metainfo of this flavour (identical bytes for development).
sed -e "s|^Name=Human OS\$|Name=$APPNAME|" -e "s|^Exec=human-health-os\$|Exec=$PKG|" \
  -e "s|^Icon=$ID\$|Icon=$AID|" "$P/$ID.desktop" > "$WORK/$AID.desktop"
sed -e "s|<id>$ID</id>|<id>$AID</id>|" -e "s|<name>Human OS</name>|<name>$APPNAME</name>|" \
  -e "s|\"desktop-id\">$ID.desktop<|\"desktop-id\">$AID.desktop<|" \
  "$P/$ID.metainfo.xml" > "$WORK/$AID.metainfo.xml"

# Shared desktop integration files, installed under a given prefix.
install_desktop_files() { # <root> <prefix>
  install -Dm644 "$WORK/$AID.desktop" "$1$2/share/applications/$AID.desktop"
  install -Dm644 "$WORK/$AID.metainfo.xml" "$1$2/share/metainfo/$AID.metainfo.xml"
  install -Dm644 "$P/icons/$ID.svg" "$1$2/share/icons/hicolor/scalable/apps/$AID.svg"
  mkdir -p "$1$2/share/icons/hicolor/256x256/apps"
  rsvg-convert -w 256 -h 256 "$P/icons/$ID.svg" -o "$1$2/share/icons/hicolor/256x256/apps/$AID.png"
}

# C. Portable tar.zst (portable_mode.json => encrypted-only storage; F004).
if command -v zstd >/dev/null; then
  D="$WORK/$BASE-Linux-x86_64-Portable"
  mkdir -p "$D"; cp -a "$BUNDLE/." "$D/"
  install -m644 "$P/portable/portable_mode.json" "$P/portable/README.txt" "$D/"
  install -m644 "$P/icons/$ID.svg" "$D/"
  tar --sort=name --mtime="@$EPOCH" --owner=0 --group=0 --numeric-owner \
    -C "$WORK" -cf - "$BASE-Linux-x86_64-Portable" \
    | zstd -q -19 -T0 -o "$OUT/$BASE-Linux-x86_64-Portable.tar.zst" -f
  note "tar.zst PRODUCED"
else note "tar.zst NOT_RUN (zstd missing)"; fi

# D. .deb (Debian/Ubuntu family).
if command -v dpkg-deb >/dev/null; then
  R="$WORK/deb"
  mkdir -p "$R/usr/lib/$PKG" "$R/usr/bin" "$R/DEBIAN" "$R/usr/share/doc/$PKG"
  cp -a "$BUNDLE/." "$R/usr/lib/$PKG/"
  ln -s "../lib/$PKG/human_health_os" "$R/usr/bin/$PKG"
  install_desktop_files "$R" /usr
  install -m644 "$P/deb/copyright" "$R/usr/share/doc/$PKG/copyright"
  # Native package: the changelog is changelog.gz (lintian).
  printf '%s (%s) unstable; urgency=low\n\n  * Build from %s.\n\n -- Human OS project <noreply@humanhealthos.invalid>  %s\n' \
    "$PKG" "$VERSION" "${REV:0:12}" "$(date -u -R -d "@$EPOCH")" | gzip -9n > "$R/usr/share/doc/$PKG/changelog.gz"
  SIZE=$(du -sk --exclude=DEBIAN "$R" | cut -f1)
  sed -e "s/@PACKAGE@/$PKG/" -e "s/@VERSION@/$VERSION/" -e "s/@INSTALLED_SIZE@/$SIZE/" "$P/deb/control.in" > "$R/DEBIAN/control"
  find "$R" -type d -exec chmod 755 {} +
  find "$R" -exec touch -h -d "@$EPOCH" {} +
  fakeroot dpkg-deb --root-owner-group -Zxz --build "$R" "$OUT/${PKG}_${VERSION}_amd64.deb" >/dev/null
  note "deb PRODUCED"
else note "deb NOT_RUN (dpkg-deb missing)"; fi

# E. .rpm (Fedora/Nobara family). Built from a staged tree, nothing compiled.
if command -v rpmbuild >/dev/null; then
  S="$WORK/rpmstage"
  mkdir -p "$S/usr/lib64/$PKG" "$S/usr/bin"
  cp -a "$BUNDLE/." "$S/usr/lib64/$PKG/"
  ln -s "../lib64/$PKG/human_health_os" "$S/usr/bin/$PKG"
  install_desktop_files "$S" /usr
  sed -e "s/@PACKAGE@/$PKG/g" -e "s/@APPID@/$AID/g" -e "s/@VERSION@/$VERSION/g" -e "s|@STAGE@|$S|" \
    "$P/rpm/human-health-os.spec.in" > "$WORK/$PKG.spec"
  rpmbuild -bb --quiet --define "_topdir $WORK/rpmbuild" --define "_build_id_links none" \
    --define "use_source_date_epoch_as_buildtime 1" --define "clamp_mtime_to_source_date_epoch 1" \
    --target x86_64 "$WORK/$PKG.spec" >/dev/null
  cp "$WORK"/rpmbuild/RPMS/x86_64/*.rpm "$OUT/"
  note "rpm PRODUCED"
else note "rpm NOT_RUN (rpmbuild missing)"; fi

# B. AppImage (type 2). Needs appimagetool + runtime; FUSE only to *run* it.
if [ -n "${APPIMAGETOOL:-}" ] && [ -x "$APPIMAGETOOL" ]; then
  A="$WORK/AppDir"
  mkdir -p "$A/usr/lib/human-health-os"
  cp -a "$BUNDLE/." "$A/usr/lib/human-health-os/"
  install -m755 "$P/appimage/AppRun" "$A/AppRun"
  install_desktop_files "$A" /usr
  install -m644 "$WORK/$AID.desktop" "$A/$AID.desktop"
  install -m644 "$P/icons/$ID.svg" "$A/$AID.svg"
  ln -s "$AID.svg" "$A/.DirIcon"
  RT=(); [ -n "${APPIMAGE_RUNTIME:-}" ] && RT=(--runtime-file "$APPIMAGE_RUNTIME")
  # mksquashfs refuses SOURCE_DATE_EPOCH together with appimagetool's own flags.
  env -u SOURCE_DATE_EPOCH ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" --no-appstream "${RT[@]}" "$A" \
    "$OUT/$BASE-${VERSION//\~/-}-x86_64.AppImage" > "$WORK/appimagetool.log" 2>&1 \
    || { cat "$WORK/appimagetool.log" >&2; exit 1; }
  note "AppImage PRODUCED"
else note "AppImage NOT_RUN (APPIMAGETOOL not provided)"; fi

# A. Flatpak: only with flatpak-builder and the Freedesktop runtime installed.
if command -v flatpak-builder >/dev/null && flatpak info org.freedesktop.Platform//24.08 >/dev/null 2>&1; then
  note "Flatpak: builder present, build it with the manifest in packaging/linux/flatpak"
else note "Flatpak NOT_RUN (flatpak-builder or org.freedesktop.Platform//24.08 unavailable)"; fi

( cd "$OUT" && sha256sum -- *.tar.zst *.deb *.rpm *.AppImage 2>/dev/null > SHA256SUMS || true )
cat "$OUT/SHA256SUMS"
