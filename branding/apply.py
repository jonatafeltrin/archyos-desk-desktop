#!/usr/bin/env python3
"""Aplica a marca ArchyOs no código do RustDesk (rodar na pasta do RustDesk).

- nome do programa: ArchyOs (o RustDesk troca "RustDesk" pelo nome em toda a interface);
- servidor e chave já gravados (o programa só funciona com o servidor ArchyOs);
- ícones (programa, bandeja, logo interna) e dados do .exe;
- links do site apontam para o ArchyOs.
"""
import os
import re
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.environ.get("ARCHYOS_SERVER", "desk.archyos.com.br")
KEY = os.environ.get("ARCHYOS_KEY", "gdGMaMshMyjKKbe2mn7cdKtLc1VHGsnlJ0DF4pTGvBU=")
SITE = "https://gestao.archyos.com.br"


def edit(path, pairs, regex=False):
    with open(path, encoding="utf-8") as f:
        s = f.read()
    for old, new in pairs:
        n = s
        s = re.sub(old, new, s) if regex else s.replace(old, new)
        if n == s:
            sys.exit(f"marca: não encontrei {old!r} em {path}")
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(s)
    print("ok", path)


edit("libs/hbb_common/src/config.rs", [
    ('RwLock::new("RustDesk".to_owned())', 'RwLock::new("ArchyOs".to_owned())'),
    ('&["rs-ny.rustdesk.com"]', f'&["{SERVER}"]'),
    ('"OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw="', f'"{KEY}"'),
])

with open("Cargo.toml", encoding="utf-8") as f:
    cargo = f.read()
cargo = re.sub(r'(\[package\.metadata\.winres\][^\[]*?)LegalCopyright = "[^"]*"', r'\1LegalCopyright = "ArchyOs"', cargo, flags=re.S)
cargo = cargo.replace('ProductName = "RustDesk"', 'ProductName = "ArchyOs"').replace('FileDescription = "RustDesk Remote Desktop"', 'FileDescription = "ArchyOs"')
with open("Cargo.toml", "w", encoding="utf-8", newline="") as f:
    f.write(cargo)
print("ok Cargo.toml")

edit("libs/portable/Cargo.toml", [
    ('description = "RustDesk Remote Desktop"', 'description = "ArchyOs"'),
    ('ProductName = "RustDesk"', 'ProductName = "ArchyOs"'),
    ('FileDescription = "RustDesk Remote Desktop"', 'FileDescription = "ArchyOs"'),
])

edit("flutter/windows/runner/Runner.rc", [
    (r'VALUE "CompanyName", "[^"]*"', 'VALUE "CompanyName", "ArchyOs"'),
    (r'VALUE "FileDescription", "[^"]*"', 'VALUE "FileDescription", "ArchyOs"'),
    (r'VALUE "LegalCopyright", "[^"]*"', 'VALUE "LegalCopyright", "ArchyOs"'),
    (r'VALUE "ProductName", "[^"]*"', 'VALUE "ProductName", "ArchyOs"'),
], regex=True)

# Ícones: .ico (programa, bandeja, runner), .png e a logo interna (svg).
icon = Image.open(os.path.join(HERE, "icon.png")).convert("RGBA")
sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
for ico in ["res/icon.ico", "res/tray-icon.ico", "flutter/windows/runner/resources/app_icon.ico"]:
    icon.save(ico, sizes=sizes)
    print("ok", ico)
for png, size in [("res/icon.png", 1024), ("res/32x32.png", 32), ("res/64x64.png", 64), ("res/128x128.png", 128), ("res/128x128@2x.png", 256)]:
    if os.path.exists(png):
        icon.resize((size, size), Image.LANCZOS).save(png)
        print("ok", png)
with open(os.path.join(HERE, "icon.svg"), encoding="utf-8") as f:
    svg = f.read()
with open("flutter/assets/icon.svg", "w", encoding="utf-8") as f:
    f.write(svg)
print("ok flutter/assets/icon.svg")

# Links do site.
for root, _, files in os.walk("flutter/lib"):
    for name in files:
        if not name.endswith(".dart"):
            continue
        p = os.path.join(root, name)
        with open(p, encoding="utf-8") as f:
            s = f.read()
        n = re.sub(r"https://rustdesk\.com[^'\"\s)]*", SITE, s)
        if n != s:
            with open(p, "w", encoding="utf-8", newline="") as f:
                f.write(n)
            print("ok", p)

print("marca ArchyOs aplicada")
