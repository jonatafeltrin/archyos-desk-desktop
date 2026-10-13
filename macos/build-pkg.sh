#!/usr/bin/env bash
# Monta o instalador ArchyOs.pkg para Mac.
#   ./build-pkg.sh <ArchyOs.app> <archyos-agent> [saida.pkg]
# O .pkg instala o app em /Applications e o programa que cuida da senha em
# /Library/Application Support/ArchyOs; no fim pede a conta ArchyOs (setup).
# Assinatura: defina SIGN_APP="Developer ID Application: ..." e
# SIGN_PKG="Developer ID Installer: ..." (sem elas sai sem assinatura, para teste).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$1"; AGENT="$2"; OUT="${3:-ArchyOs.pkg}"
VERSION="${VERSION:-1.4.9}"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/root/Applications" "$WORK/root/Library/Application Support/ArchyOs" "$WORK/scripts"
ditto "$APP" "$WORK/root/Applications/ArchyOs.app"
install -m 0755 "$AGENT" "$WORK/root/Library/Application Support/ArchyOs/archyos-agent"

if [ -n "${SIGN_APP:-}" ]; then
  codesign --force --options runtime --deep --timestamp -s "$SIGN_APP" "$WORK/root/Applications/ArchyOs.app"
  codesign --force --options runtime --timestamp -s "$SIGN_APP" "$WORK/root/Library/Application Support/ArchyOs/archyos-agent"
else
  codesign --force --deep -s - "$WORK/root/Applications/ArchyOs.app"
  codesign --force -s - "$WORK/root/Library/Application Support/ArchyOs/archyos-agent"
fi

cat > "$WORK/scripts/preinstall" <<'SH'
#!/bin/sh
# Atualização: para os serviços antes de trocar os arquivos.
for l in br.com.archyos.agent com.carriez.ArchyOs_service; do launchctl bootout system/$l 2>/dev/null; done
uid=$(stat -f %u /dev/console)
launchctl bootout gui/$uid/com.carriez.ArchyOs_server 2>/dev/null
pkill -f /Applications/ArchyOs.app 2>/dev/null
exit 0
SH
cat > "$WORK/scripts/postinstall" <<'SH'
#!/bin/sh
"/Library/Application Support/ArchyOs/archyos-agent" setup
exit 0
SH
chmod +x "$WORK/scripts/preinstall" "$WORK/scripts/postinstall"

# O app não pode ir parar em outra pasta (o instalador do Mac "realoca" se achar outra cópia).
pkgbuild --analyze --root "$WORK/root" "$WORK/component.plist" >/dev/null
i=0
while /usr/libexec/PlistBuddy -c "Print :$i" "$WORK/component.plist" >/dev/null 2>&1; do
  /usr/libexec/PlistBuddy -c "Set :$i:BundleIsRelocatable false" "$WORK/component.plist"
  i=$((i + 1))
done

pkgbuild --root "$WORK/root" --component-plist "$WORK/component.plist" --scripts "$WORK/scripts" \
  --identifier br.com.archyos.desk.pkg --version "$VERSION" --install-location / "$WORK/archyos.pkg"

cp "$HERE/distribution.xml" "$WORK/distribution.xml"
sed -i '' "s/__VERSION__/$VERSION/" "$WORK/distribution.xml"
SIGN_ARGS=()
[ -n "${SIGN_PKG:-}" ] && SIGN_ARGS=(--sign "$SIGN_PKG" --timestamp)
productbuild --distribution "$WORK/distribution.xml" --resources "$HERE/resources" --package-path "$WORK" ${SIGN_ARGS[@]+"${SIGN_ARGS[@]}"} "$OUT"
echo "ok $OUT"
