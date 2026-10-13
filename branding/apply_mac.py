#!/usr/bin/env python3
"""Marca ArchyOs no RustDesk para macOS (rodar na pasta do RustDesk, depois do apply.py).

- app ArchyOs.app (nome e identificador próprios); o RustDesk usa o nome do app
  para criar os serviços do sistema (com.carriez.ArchyOs_service etc.);
- ícone do app no formato do Mac e ícone da barra de menus;
- link "archyos://" no lugar de "rustdesk://".
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
BUNDLE_ID = "br.com.archyos.desk"


def edit(path, pairs):
    with open(path, encoding="utf-8") as f:
        s = f.read()
    for old, new in pairs:
        if old not in s:
            sys.exit(f"marca mac: não encontrei {old!r} em {path}")
        s = s.replace(old, new)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("ok", path)


edit("flutter/macos/Runner/Configs/AppInfo.xcconfig", [
    ("PRODUCT_NAME = RustDesk", "PRODUCT_NAME = ArchyOs"),
    ("PRODUCT_BUNDLE_IDENTIFIER = com.carriez.flutterHbb", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}"),
    ("Copyright © 2026 Purslane Tech Pte. Ltd. All rights reserved.", "ArchyOs"),
])

# O projeto do Xcode também fixa o identificador (é por ele que o Mac guarda as permissões).
with open("flutter/macos/Runner.xcodeproj/project.pbxproj", encoding="utf-8") as f:
    pbx = f.read()
if "PRODUCT_BUNDLE_IDENTIFIER = com.carriez.rustdesk;" not in pbx:
    sys.exit("marca mac: identificador não encontrado no project.pbxproj")
with open("flutter/macos/Runner.xcodeproj/project.pbxproj", "w", encoding="utf-8", newline="") as f:
    f.write(pbx.replace("PRODUCT_BUNDLE_IDENTIFIER = com.carriez.rustdesk;", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID};"))
print("ok flutter/macos/Runner.xcodeproj/project.pbxproj")

edit("flutter/macos/Runner/Info.plist", [
    ("<string>com.carriez.rustdesk</string>", f"<string>{BUNDLE_ID}</string>"),
    ("<string>rustdesk</string>", "<string>archyos</string>"),
])

# O build copia o "service" para dentro do .app pelo nome.
edit("build.py", [
    ("./build/macos/Build/Products/Release/RustDesk.app/Contents/MacOS/')",
     "./build/macos/Build/Products/Release/ArchyOs.app/Contents/MacOS/')"),
])

icon = Image.open(os.path.join(HERE, "icon.png")).convert("RGBA").resize((1024, 1024), Image.LANCZOS)

# Ícone do app: quadrado arredondado com a margem padrão do macOS (824 de 1024).
inner = 824
tile = icon.resize((inner, inner), Image.LANCZOS)
mask = Image.new("L", (inner, inner), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, inner - 1, inner - 1), radius=185, fill=255)
mac = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
mac.paste(tile, ((1024 - inner) // 2, (1024 - inner) // 2), mask)
mac.save("res/mac-icon.png")
print("ok res/mac-icon.png")

with tempfile.TemporaryDirectory() as tmp:
    iconset = os.path.join(tmp, "AppIcon.iconset")
    os.mkdir(iconset)
    for size in (16, 32, 128, 256, 512):
        mac.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}.png"))
        mac.resize((size * 2, size * 2), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}@2x.png"))
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", "flutter/macos/Runner/AppIcon.icns"], check=True)
print("ok flutter/macos/Runner/AppIcon.icns")

# Barra de menus: o Mac usa só o desenho (transparência); pega a parte branca do símbolo.
glyph = Image.new("RGBA", icon.size, (0, 0, 0, 0))
px, gp = icon.load(), glyph.load()
for y in range(icon.size[1]):
    for x in range(icon.size[0]):
        r, g, b, a = px[x, y]
        if a > 0 and min(r, g, b) > 200:
            gp[x, y] = (0, 0, 0, 255)
box = glyph.getbbox()
glyph = glyph.crop(box)
side = max(glyph.size)
square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
square.paste(glyph, ((side - glyph.size[0]) // 2, (side - glyph.size[1]) // 2))
for name, size in [("res/mac-tray-dark-x2.png", 60), ("res/mac-tray-light-x2.png", 48)]:
    pad = round(size * 0.08)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(square.resize((size - 2 * pad, size - 2 * pad), Image.LANCZOS), (pad, pad))
    out.save(name)
    print("ok", name)

print("marca ArchyOs (Mac) aplicada")
