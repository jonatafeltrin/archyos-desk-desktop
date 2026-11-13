# ArchyOs — programa para computador

O motor de acesso remoto (RustDesk 1.4.9, licença AGPL-3.0) compilado com a marca
ArchyOs: nome, ícones, servidor e chave já gravados. O código do RustDesk não fica
aqui: a compilação baixa a versão oficial e aplica `branding/apply.py`.

## Windows (compila numa máquina Windows nossa, não no GitHub)

1. Copie esta pasta (`archyos-desktop`) para a máquina Windows (Windows 10/11, 64 bits,
   uns 60 GB livres, internet).
2. Abra a pasta `windows`, clique com o botão direito em **COMPILAR.bat** →
   **Executar como administrador**.
3. Espere. Na primeira vez ele instala tudo sozinho (Visual Studio Build Tools, Git,
   Python, LLVM, Rust, Flutter, vcpkg) e pode passar de 1 hora. Das próximas vezes é bem
   mais rápido.
4. No fim abre a pasta com o instalador:
   `C:\ArchyOs-build\saida\ArchyOs-motor-1.4.9-x64.exe`
5. Suba esse arquivo no painel (Central de arquivos).

Se der erro, a janela mostra a mensagem e o log completo fica em `C:\ArchyOs-build\log.txt`.

## Mac

`archyos-mac/build-engine.sh` (neste Mac) monta o `ArchyOs.app`; `macos/build-pkg.sh`
monta o instalador `.pkg`.

Código-fonte do RustDesk: https://github.com/rustdesk/rustdesk (tag 1.4.9).
