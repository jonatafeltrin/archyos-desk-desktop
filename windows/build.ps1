# Compila o programa ArchyOs para Windows (RustDesk 1.4.9 com a marca ArchyOs)
# NESTA máquina. Não usa GitHub Actions.
#
# Uso: clique com o botão direito em COMPILAR.bat -> "Executar como administrador".
# Na primeira vez instala as ferramentas (demora; pode passar de 1 hora).
# Resultado: C:\ArchyOs-build\saida\ArchyOs-motor-1.4.9-x64.exe
# Log completo: C:\ArchyOs-build\log.txt

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RUSTDESK_TAG   = '1.4.9'
$RUST_VERSION   = '1.75'
$LLVM_VERSION   = '15.0.6'
$FLUTTER_VERSION = '3.24.5'
$VCPKG_COMMIT   = '120deac3062162151622ca4860575a33844ba10b'

$Repo = Split-Path -Parent $PSScriptRoot          # pasta archyos-desktop
$Work = 'C:\ArchyOs-build'                       # sem espaço no caminho
New-Item -ItemType Directory -Force -Path $Work | Out-Null
Start-Transcript -Path "$Work\log.txt" -Force | Out-Null

function Passo($t) { Write-Host ""; Write-Host "=== $t" -ForegroundColor Cyan }
function Run {
    param([string]$Exe, [Parameter(ValueFromRemainingArguments)]$Rest)
    & $Exe @Rest
    if ($LASTEXITCODE -ne 0) { throw "Falhou ($LASTEXITCODE): $Exe $Rest" }
}
function AtualizaPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Tem($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function Winget($id, $extra = @()) {
    Run winget install --id $id -e --accept-source-agreements --accept-package-agreements --silent @extra
    AtualizaPath
}

try {
    # ---------------------------------------------------------------- ferramentas
    Passo 'Ferramentas'
    if (-not (Tem winget)) { throw 'Falta o winget (App Installer da Microsoft Store). Instale e rode de novo.' }

    if (-not (Tem git)) { Winget 'Git.Git' @('--scope', 'machine') }
    git config --global core.longpaths true

    $Python = 'C:\Program Files\Python311\python.exe'
    if (-not (Test-Path $Python)) { Winget 'Python.Python.3.11' @('--scope', 'machine') }

    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $temVC = (Test-Path $vswhere) -and (& $vswhere -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    if (-not $temVC) {
        Write-Host 'Instalando Visual Studio Build Tools (C++)... demora.'
        Winget 'Microsoft.VisualStudio.2022.BuildTools' @('--override',
            '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended')
    }

    $LLVM = 'C:\Program Files\LLVM'
    if (-not (Test-Path "$LLVM\bin\libclang.dll")) {
        Write-Host "Instalando LLVM $LLVM_VERSION..."
        $f = "$Work\LLVM-$LLVM_VERSION-win64.exe"
        Invoke-WebRequest "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/LLVM-$LLVM_VERSION-win64.exe" -OutFile $f
        Start-Process $f -ArgumentList '/S' -Wait
    }
    $env:LIBCLANG_PATH = "$LLVM\bin"
    $env:Path = "$LLVM\bin;$env:Path"

    if (-not (Tem rustup)) {
        $f = "$Work\rustup-init.exe"
        Invoke-WebRequest 'https://win.rustup.rs/x86_64' -OutFile $f
        Run $f -y --default-toolchain none
        $env:Path = "$env:USERPROFILE\.cargo\bin;$env:Path"
    }
    Run rustup toolchain install $RUST_VERSION --profile minimal -c rustfmt
    $env:RUSTUP_TOOLCHAIN = $RUST_VERSION

    $Flutter = "$Work\flutter"
    if (-not (Test-Path "$Flutter\bin\flutter.bat")) {
        Run git clone --depth 1 --branch $FLUTTER_VERSION https://github.com/flutter/flutter.git $Flutter
    }
    $env:Path = "$Flutter\bin;$env:Path"
    Run flutter config --no-analytics
    Run flutter precache --windows

    $env:VCPKG_ROOT = "$Work\vcpkg"
    if (-not (Test-Path "$env:VCPKG_ROOT\vcpkg.exe")) {
        if (-not (Test-Path $env:VCPKG_ROOT)) { Run git clone https://github.com/microsoft/vcpkg.git $env:VCPKG_ROOT }
        Push-Location $env:VCPKG_ROOT
        Run git checkout $VCPKG_COMMIT
        Run .\bootstrap-vcpkg.bat -disableMetrics
        Pop-Location
    }

    Run $Python -m pip install --quiet --upgrade pip pillow

    # ---------------------------------------------------------------- RustDesk limpo
    Passo "RustDesk $RUSTDESK_TAG"
    $RD = "$Work\rustdesk"
    if (-not (Test-Path "$RD\Cargo.toml")) {
        Run git clone --depth 1 --branch $RUSTDESK_TAG --recurse-submodules --shallow-submodules https://github.com/rustdesk/rustdesk.git $RD
    }
    Set-Location $RD
    # volta ao código original (a marca só pode ser aplicada uma vez)
    Run git checkout -q -- .
    Run git clean -qfd -e target -e flutter/build -e flutter/.dart_tool
    Run git submodule foreach -q --recursive 'git checkout -q -- .'

    # ponte Flutter <-> Rust (gerada uma vez, mesma versão)
    Copy-Item -Recurse -Force "$PSScriptRoot\bridge\*" $RD

    # ---------------------------------------------------------------- marca
    Passo 'Marca ArchyOs'
    Run $Python "$Repo\branding\apply.py"

    # ---------------------------------------------------------------- Flutter do RustDesk
    Passo 'Motor Flutter do RustDesk'
    $engine = "$Flutter\bin\cache\artifacts\engine\windows-x64-release"
    $zip = "$Work\windows-x64-release.zip"
    if (-not (Test-Path "$Work\engine-ok")) {
        Invoke-WebRequest 'https://github.com/rustdesk/engine/releases/download/main/windows-x64-release.zip' -OutFile $zip
        Expand-Archive -Force $zip "$Work\engine"
        Copy-Item -Recurse -Force "$Work\engine\*" $engine
        New-Item "$Work\engine-ok" -ItemType File | Out-Null
    }
    $patch = "$RD\.github\patches\flutter_3.24.4_dropdown_menu_enableFilter.diff"
    Push-Location $Flutter
    $ErrorActionPreference = 'Continue'
    git apply --check $patch 2>&1 | Out-Null
    $ok = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if ($ok) { Run git apply $patch }   # se falhar o check, já está aplicado
    Pop-Location

    # ---------------------------------------------------------------- dependências
    Passo 'Dependências (vcpkg) - na primeira vez demora'
    $env:VCPKG_DEFAULT_HOST_TRIPLET = 'x64-windows-static'
    Run "$env:VCPKG_ROOT\vcpkg.exe" install --triplet x64-windows-static "--x-install-root=$env:VCPKG_ROOT\installed"

    # ---------------------------------------------------------------- compilar
    Passo 'Compilando'
    Run $Python .\build.py --portable --flutter --skip-portable-pack --hwcodec --vram

    if (Test-Path .\rustdesk) { Remove-Item -Recurse -Force .\rustdesk }
    Move-Item .\flutter\build\windows\x64\runner\Release .\rustdesk
    # o serviço instalado procura "<nome do app>.exe"
    Move-Item .\rustdesk\rustdesk.exe .\rustdesk\ArchyOs.exe

    $res = Get-ChildItem -Recurse -Filter Runner.res -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($res) { Copy-Item $res.FullName .\libs\portable\Runner.res -Force }

    # ---------------------------------------------------------------- instalador
    Passo 'Montando o instalador'
    (Get-Content res\manifest.xml) | Where-Object { $_ -notmatch 'dpiAware' } | Set-Content res\manifest.xml
    Push-Location .\libs\portable
    Run $Python -m pip install --quiet -r requirements.txt
    Run $Python .\generate.py -f ..\..\rustdesk\ -o . -e ..\..\rustdesk\ArchyOs.exe
    Pop-Location

    $Saida = "$Work\saida"
    New-Item -ItemType Directory -Force -Path $Saida | Out-Null
    $Exe = "$Saida\ArchyOs-motor-$RUSTDESK_TAG-x64.exe"
    Move-Item -Force .\target\release\rustdesk-portable-packer.exe $Exe

    Passo 'PRONTO'
    Write-Host "Instalador: $Exe" -ForegroundColor Green
    Write-Host 'Agora suba esse arquivo no painel (Central de arquivos).' -ForegroundColor Green
    Start-Process explorer.exe $Saida
}
catch {
    Write-Host ""
    Write-Host "DEU ERRO: $_" -ForegroundColor Red
    Write-Host "Mande o arquivo $Work\log.txt para o suporte." -ForegroundColor Red
    exit 1
}
finally {
    Stop-Transcript | Out-Null
}
