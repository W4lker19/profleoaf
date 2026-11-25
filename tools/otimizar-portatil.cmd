<# : -------- parte em linha de comandos (cmd): pede administrador e passa o resto ao PowerShell --------
@echo off
chcp 65001 >nul
set "OTIMIZAR_F=%~f0"
fltmc >nul 2>&1
if %errorlevel% neq 0 (
  if "%~1"=="elevado" ( echo Sem permissoes de administrador. & pause & exit /b )
  echo A pedir permissoes de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath $env:OTIMIZAR_F -ArgumentList 'elevado' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:OTIMIZAR_F; iex ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8))"
exit /b
#>

# =============================================================================
#  Otimizar portátil — profleoaf.pt/tools
#  Limpeza e otimização automática dos portáteis Windows da escola.
#
#  Duplo clique no ficheiro. O Windows pede permissão de administrador.
#  A única pergunta é a confirmação no início.
#
#  O que faz:
#   1. Limpa os ficheiros dos alunos: transferências antigas, instaladores e
#      jogos descarregados, ficheiros temporários, cache dos browsers e reciclagem
#   2. Limpa o sistema: temporários, cache do Windows Update, relatórios de erros
#   3. Remove aplicações pré-instaladas desnecessárias (Xbox, Solitaire, notícias…)
#   4. Desliga telemetria, sugestões, anúncios, widgets e aplicações em segundo plano
#   5. Desliga efeitos visuais (animações, transparências) em todas as contas
#   6. Ativa o Sensor de Armazenamento, que limpa sozinho daqui para a frente
#   7. Instala as aplicações das aulas de TIC e CEA (Scratch, GIMP, Audacity,
#      VLC, 7-Zip) e põe atalhos para o MakeCode (micro:bit) e o Microsoft 365
#
#  NÃO mexe em: Windows Update, Windows Defender, Microsoft Store, Office,
#  Teams, OneDrive, nem nas pastas Documentos/Imagens dos alunos.
#  Pode ser corrido mais do que uma vez: só instala o que faltar.
#  Registo de tudo o que foi feito em C:\ProgramData\OtimizarPortatil\
# =============================================================================

# ----------------------------- DEFINIÇÕES ------------------------------------

$PedirConfirmacao       = $true   # pergunta antes de começar
$DiasTransferencias     = 7       # apaga das Transferências o que tiver mais de 7 dias
$DiasLimpezaAutomatica  = 14      # depois, o Windows limpa sozinho as Transferências com mais de 14 dias
$LimpezaProfunda        = $true   # limpeza de componentes do Windows (DISM): liberta espaço, demora 10-30 min
$ContasExcluidas        = @()     # contas cujos ficheiros NÃO são apagados, ex.: @('professor')

# Ficheiros apagados das Transferências seja qual for a data (instaladores, jogos, arquivos)
$ExtensoesTransferencias = @('.exe', '.msi', '.msix', '.appx', '.iso', '.img', '.rar', '.7z', '.zip', '.apk', '.jar', '.torrent')
# Ficheiros apagados da Área de Trabalho (só instaladores e imagens de disco)
$ExtensoesAreaTrabalho   = @('.exe', '.msi', '.iso', '.torrent')

# Jogos e programas que os alunos instalam na sua própria conta (pastas dentro do perfil)
$PastasJogos = @(
  'AppData\Local\Roblox',
  'AppData\Local\Discord',
  'AppData\Roaming\.minecraft',
  'AppData\Roaming\.tlauncher',
  'AppData\Roaming\uTorrent',
  'AppData\Roaming\BitTorrent',
  'AppData\Local\Programs\Opera GX',
  'AppData\Local\Programs\Opera'
)

# Aplicações pré-instaladas a remover (para todas as contas e para contas novas)
$AppsRemover = @(
  'Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingSports', 'Microsoft.BingFinance',
  'Microsoft.GetHelp', 'Microsoft.Getstarted', 'Microsoft.MicrosoftSolitaireCollection',
  'Microsoft.MicrosoftOfficeHub', 'Microsoft.People', 'Microsoft.SkypeApp',
  'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps', 'Microsoft.MixedReality.Portal',
  'Microsoft.Microsoft3DViewer', 'Microsoft.3DBuilder', 'Microsoft.Wallet',
  'Microsoft.Xbox.TCUI', 'Microsoft.XboxApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay',
  'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.XboxIdentityProvider', 'Microsoft.GamingApp',
  'Microsoft.YourPhone', 'Microsoft.ZuneVideo',
  'Microsoft.549981C3F5F10', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Todos',
  'Microsoft.Windows.DevHome', 'Microsoft.Copilot', 'Microsoft.BingSearch',
  'MicrosoftCorporationII.MicrosoftFamily',
  '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*', '*Disney*', '*Spotify*', '*TikTok*',
  '*Instagram*', '*Facebook*', '*Netflix*', '*Twitter*', '*ROBLOX*', '*Hulu*', '*PrimeVideo*',
  '*king.com*', '*Asphalt*', '*McAfee*', '*Norton*'
)
# Mantidas de propósito: Leitor Multimédia (ZuneMusic), Clipchamp (M365 Educação),
# Dolby (som dos altifalantes) e Obter Ajuda (resolução de problemas do Windows 11).

# Aplicações para as aulas (identificadores do winget). Só instala as que faltarem.
$AppsInstalar = @(
  @('MITMediaLab.Scratch.3', 'Scratch 3'),
  @('GIMP.GIMP.3',           'GIMP'),
  @('Audacity.Audacity',     'Audacity'),
  @('VideoLAN.VLC',          'VLC'),
  @('7zip.7zip',             '7-Zip')
)

# Atalhos na Área de Trabalho de todas as contas: "Nome|Endereço"
$AtalhosWeb = @(
  'MakeCode micro:bit|https://makecode.microbit.org/',
  'Microsoft 365|https://www.office.com/'
)

# Serviços a desligar
$ServicosDesligar = @(
  'DiagTrack',            # telemetria
  'MapsBroker',           # mapas offline
  'RetailDemo',           # modo de demonstração de loja
  'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',  # Xbox
  'WMPNetworkSvc',        # partilha do Windows Media Player
  'Fax'
)

# Tarefas agendadas de telemetria
$TarefasDesligar = @(
  @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
  @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
  @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
  @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
  @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload'),
  @('\Microsoft\Windows\Windows Error Reporting\', 'QueueReporting'),
  @('\Microsoft\Windows\Maps\', 'MapsUpdateTask'),
  @('\Microsoft\Windows\DiskDiagnostic\', 'Microsoft-Windows-DiskDiagnosticDataCollector')
)

# ----------------------------- FUNÇÕES ---------------------------------------

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
$Host.UI.RawUI.WindowTitle = 'Otimizar portátil'

$PastaRegisto = Join-Path $env:ProgramData 'OtimizarPortatil'
New-Item -ItemType Directory -Path $PastaRegisto -Force | Out-Null
$Registo = Join-Path $PastaRegisto ('registo-' + (Get-Date -Format 'yyyy-MM-dd_HH-mm') + '.txt')
Start-Transcript -Path $Registo -Force | Out-Null

function Passo($t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Ok($t)    { Write-Host "    [OK] $t" -ForegroundColor Green }
function Aviso($t) { Write-Host "    [!]  $t" -ForegroundColor Yellow }

function Tamanho($bytes) {
  if ($bytes -ge 1GB) { return '{0:N1} GB' -f ($bytes / 1GB) }
  return '{0:N0} MB' -f ($bytes / 1MB)
}

function EspacoLivre { return (Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free }

# SEGURANÇA: nenhuma função abaixo entra em junções ou ligações simbólicas
# (pastas que "apontam" para outro sítio, p. ex. para os Documentos).
# Uma ligação é apagada como ligação; o destino nunca é tocado.
function E-Ligacao($item) { return [bool]($item.Attributes -band [IO.FileAttributes]::ReparsePoint) }

# Lista os ficheiros de uma pasta e subpastas, sem entrar em ligações
function Listar-Ficheiros([string]$pasta) {
  Get-ChildItem -LiteralPath $pasta -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if (E-Ligacao $_) { return }
    if ($_.PSIsContainer) { Listar-Ficheiros $_.FullName } else { $_ }
  }
}

# Apaga um ficheiro ou uma pasta (com tudo o que tem dentro) sem seguir ligações e
# devolve os bytes apagados. Ficheiros em uso são saltados (sem perguntas nem erros).
function Apagar-Item($i) {
  if (E-Ligacao $i) {
    try { if ($i.PSIsContainer) { [IO.Directory]::Delete($i.FullName, $false) } else { [IO.File]::Delete($i.FullName) } } catch {}
    return [long]0
  }
  if ($i.PSIsContainer) {
    [long]$s = 0
    foreach ($c in @(Get-ChildItem -LiteralPath $i.FullName -Force -ErrorAction SilentlyContinue)) { $s += Apagar-Item $c }
    try { $i.Attributes = 'Directory'; [IO.Directory]::Delete($i.FullName, $false) } catch {}   # só apaga se tiver ficado vazia
    return $s
  }
  try { $len = [long]$i.Length; $i.Attributes = 'Normal'; [IO.File]::Delete($i.FullName); return $len } catch { return [long]0 }
}

# Apaga as subpastas vazias (sem entrar em ligações)
function Apagar-PastasVazias([string]$pasta) {
  Get-ChildItem -LiteralPath $pasta -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    if (E-Ligacao $_) { return }
    Apagar-PastasVazias $_.FullName
    try { [IO.Directory]::Delete($_.FullName, $false) } catch {}
  }
}

# Apaga o conteúdo de uma pasta (mas não a pasta) e devolve os bytes apagados
function Limpar-Pasta([string]$pasta) {
  $r = Get-Item -LiteralPath $pasta -Force -ErrorAction SilentlyContinue
  if (-not $r -or (E-Ligacao $r)) { return [long]0 }
  [long]$s = 0
  foreach ($c in @(Get-ChildItem -LiteralPath $pasta -Force -ErrorAction SilentlyContinue)) { $s += Apagar-Item $c }
  return $s
}

# Apaga uma pasta inteira e devolve os bytes apagados
function Apagar-Pasta([string]$pasta) {
  $r = Get-Item -LiteralPath $pasta -Force -ErrorAction SilentlyContinue
  if (-not $r) { return [long]0 }
  return (Apagar-Item $r)
}

# Escreve um valor no registo (cria a chave se for preciso)
function Definir-Registo([string]$chave, [string]$nome, $valor, [string]$tipo = 'DWord') {
  try {
    if (-not (Test-Path $chave)) { New-Item -Path $chave -Force | Out-Null }
    New-ItemProperty -Path $chave -Name $nome -Value $valor -PropertyType $tipo -Force | Out-Null
  } catch { Aviso "Não foi possível definir $chave\$nome" }
}

# Escreve um valor numa conta de utilizador (raiz = HKU\...) com o reg.exe
function Definir-RegistoConta([string]$raiz, [string]$chave, [string]$nome, [string]$tipo, [string]$valor) {
  & reg.exe add "$raiz\$chave" /v $nome /t $tipo /d $valor /f 2>&1 | Out-Null
}

# Apaga atalhos da Área de Trabalho / Menu Iniciar que apontam para programas que já não existem
$Shell = New-Object -ComObject WScript.Shell
function Apagar-AtalhosPartidos([string]$pasta) {
  if (-not (Test-Path -LiteralPath $pasta)) { return 0 }
  $n = 0
  Get-ChildItem -LiteralPath $pasta -Filter '*.lnk' -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try {
      $alvo = $Shell.CreateShortcut($_.FullName).TargetPath
      if ($alvo -and $alvo -like "$env:SystemDrive\Users\*" -and -not (Test-Path -LiteralPath $alvo)) {
        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue
        $n++
      }
    } catch {}
  }
  return $n
}

# ----------------------------- INÍCIO ----------------------------------------

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OTIMIZAR PORTÁTIL — limpeza e otimização do Windows' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Computador: $env:COMPUTERNAME"
Write-Host ''
Write-Host 'Vai ser apagado, em TODAS as contas deste computador:' -ForegroundColor Yellow
Write-Host "  - Transferências com mais de $DiasTransferencias dias"
Write-Host '  - Instaladores, jogos e arquivos (.exe, .zip, .rar, .iso…) nas Transferências'
Write-Host '  - Instaladores (.exe, .msi, .iso) na Área de Trabalho'
Write-Host '  - Jogos instalados pelos alunos (Roblox, Minecraft/TLauncher, Discord…)'
Write-Host '  - Ficheiros temporários, cache dos browsers e Reciclagem'
Write-Host '  Os ficheiros são apagados de vez (não vão para a Reciclagem).' -ForegroundColor Yellow
Write-Host '  Se encontrar pastas de contas antigas que já não existem, pergunta antes de as apagar.'
Write-Host ''
Write-Host "Daqui para a frente, o Windows apaga sozinho, em todas as contas, o que estiver"
Write-Host "nas Transferências há mais de $DiasLimpezaAutomatica dias."
Write-Host ''
Write-Host 'Os Documentos, Imagens e o OneDrive dos alunos NÃO são tocados.' -ForegroundColor Green
if ($ContasExcluidas.Count -gt 0) { Write-Host ('Contas excluídas: ' + ($ContasExcluidas -join ', ')) -ForegroundColor Green }
Write-Host ''
Write-Host 'Também instala Scratch, GIMP, Audacity, VLC e 7-Zip (precisa de internet).'
Write-Host 'Os browsers vão ser fechados. Pode demorar entre 10 e 60 minutos.'
Write-Host ''

if ($PedirConfirmacao) {
  $r = Read-Host 'Continuar? (S/N)'
  if ($r -notmatch '^[sS]') { Write-Host 'Cancelado. Nada foi alterado.'; Stop-Transcript | Out-Null; Start-Sleep 3; exit }
}

$Inicio = Get-Date
$LivreAntes = EspacoLivre
$ReiniciarObrigatorio = $false

# Ponto de restauro (só se o Restauro do Sistema já estiver ligado)
Passo 'A criar ponto de restauro'
Definir-Registo 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore' 'SystemRestorePointCreationFrequency' 0
try {
  Checkpoint-Computer -Description 'Antes de Otimizar portatil' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
  Ok 'Ponto de restauro criado'
} catch {
  Aviso 'Restauro do Sistema desligado neste portátil (sem ponto de restauro)'
}

# ----------------------------- 1. FICHEIROS DOS ALUNOS -----------------------

Passo '1/7 A limpar os ficheiros das contas'

Stop-Process -Name chrome, msedge, firefox, opera, brave, Roblox*, Discord -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

$Perfis = Get-CimInstance Win32_UserProfile |
  Where-Object { -not $_.Special -and $_.LocalPath -like "$env:SystemDrive\Users\*" }

$CachesBrowsers = @(
  'AppData\Local\Google\Chrome\User Data\*\Cache',
  'AppData\Local\Google\Chrome\User Data\*\Code Cache',
  'AppData\Local\Google\Chrome\User Data\*\GPUCache',
  'AppData\Local\Google\Chrome\User Data\*\Service Worker\CacheStorage',
  'AppData\Local\Microsoft\Edge\User Data\*\Cache',
  'AppData\Local\Microsoft\Edge\User Data\*\Code Cache',
  'AppData\Local\Microsoft\Edge\User Data\*\GPUCache',
  'AppData\Local\Microsoft\Edge\User Data\*\Service Worker\CacheStorage',
  'AppData\Local\Mozilla\Firefox\Profiles\*\cache2',
  'AppData\Local\Microsoft\Windows\INetCache',
  'AppData\Local\CrashDumps',
  'AppData\Local\D3DSCache'
)

$Limite = (Get-Date).AddDays(-$DiasTransferencias)
$TotalContas = 0

foreach ($p in $Perfis) {
  $casa = $p.LocalPath
  $nome = Split-Path $casa -Leaf
  if ($ContasExcluidas -contains $nome) { Aviso "Conta '$nome' excluída"; continue }
  $apagado = 0

  # Transferências: antigas + instaladores/jogos/arquivos
  $dl = Join-Path $casa 'Downloads'
  if ((Test-Path -LiteralPath $dl) -and -not (E-Ligacao (Get-Item -LiteralPath $dl -Force))) {
    $ficheiros = Listar-Ficheiros $dl |
      Where-Object { $_.FullName -ne $f -and ($_.LastWriteTime -lt $Limite -or $ExtensoesTransferencias -contains $_.Extension.ToLower()) }
    foreach ($fi in $ficheiros) {
      $t = $fi.Length
      try { $fi.Attributes = 'Normal'; [IO.File]::Delete($fi.FullName); $apagado += $t } catch {}
    }
    Apagar-PastasVazias $dl
  }

  # Área de Trabalho: só instaladores e imagens de disco (nunca este próprio script)
  $ad = Join-Path $casa 'Desktop'
  if ((Test-Path -LiteralPath $ad) -and -not (E-Ligacao (Get-Item -LiteralPath $ad -Force))) {
    Get-ChildItem -LiteralPath $ad -Force -File -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -ne $f -and -not (E-Ligacao $_) -and $ExtensoesAreaTrabalho -contains $_.Extension.ToLower() } |
      ForEach-Object {
        $t = $_.Length
        try { $_.Attributes = 'Normal'; [IO.File]::Delete($_.FullName); $apagado += $t } catch {}
      }
  }

  # Jogos e programas instalados na conta
  foreach ($j in $PastasJogos) {
    $pasta = Join-Path $casa $j
    if (Test-Path -LiteralPath $pasta) {
      $apagado += Apagar-Pasta $pasta
      Ok "[$nome] removido: $(Split-Path $j -Leaf)"
    }
  }

  # Temporários e cache dos browsers
  $apagado += Limpar-Pasta (Join-Path $casa 'AppData\Local\Temp')
  foreach ($c in $CachesBrowsers) {
    Get-Item -Path (Join-Path $casa $c) -Force -ErrorAction SilentlyContinue |
      Where-Object { -not (E-Ligacao $_) } |
      ForEach-Object { $apagado += Limpar-Pasta $_.FullName }
  }

  # Atalhos para jogos que já não existem
  $atalhos = (Apagar-AtalhosPartidos $ad) + (Apagar-AtalhosPartidos (Join-Path $casa 'AppData\Roaming\Microsoft\Windows\Start Menu\Programs'))

  $TotalContas += $apagado
  Ok "[$nome] $(Tamanho $apagado) apagados$(if ($atalhos) { ", $atalhos atalhos partidos removidos" })"
}

# Reciclagem de todas as contas
$rb = Join-Path $env:SystemDrive '$Recycle.Bin'
$bytesRb = 0
Get-ChildItem -LiteralPath $rb -Force -Directory -ErrorAction SilentlyContinue |
  ForEach-Object { $bytesRb += Limpar-Pasta $_.FullName }
Ok "Reciclagem esvaziada ($(Tamanho $bytesRb))"

# Pastas de contas que já não existem (perfis antigos ou estragados, p. ex. "ALUNO.PC" quando
# o Windows criou um "Aluno.PC.000" novo). Ocupam espaço e não são usadas por ninguém.
# Só se consideram pastas com NTUSER.DAT que não pertencem a nenhuma conta do Windows.
# Pergunta sempre antes de apagar.
$Ignorar = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0', 'defaultuser100000')
$Registados = @(Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath } |
  ForEach-Object { $_.LocalPath.TrimEnd('\').ToLower() })
$Orfas = @(Get-ChildItem -LiteralPath (Join-Path $env:SystemDrive 'Users') -Force -Directory -ErrorAction SilentlyContinue |
  Where-Object {
    -not (E-Ligacao $_) -and $Ignorar -notcontains $_.Name -and
    $Registados -notcontains $_.FullName.TrimEnd('\').ToLower() -and
    (Test-Path -LiteralPath (Join-Path $_.FullName 'NTUSER.DAT'))
  })
foreach ($o in $Orfas) {
  Write-Host '    A medir uma pasta de conta antiga...'
  $t = (Listar-Ficheiros $o.FullName | Measure-Object -Property Length -Sum).Sum
  Aviso "Pasta de uma conta que já não existe: $($o.Name) ($(Tamanho ([double]$t)), última alteração $($o.LastWriteTime.ToString('dd/MM/yyyy')))"
  $r = Read-Host '    Apagar esta pasta e tudo o que tem dentro? (S/N)'
  if ($r -match '^[sS]') {
    $b = Apagar-Pasta $o.FullName
    $TotalContas += $b
    Ok "Pasta $($o.Name) apagada ($(Tamanho $b))"
  } else { Ok "Pasta $($o.Name) mantida" }
}

# ----------------------------- 2. SISTEMA ------------------------------------

Passo '2/7 A limpar o sistema'

$b = Limpar-Pasta (Join-Path $env:windir 'Temp')
Ok "Temporários do Windows ($(Tamanho $b))"

$b = (Limpar-Pasta (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive')) +
     (Limpar-Pasta (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'))
Ok "Relatórios de erros ($(Tamanho $b))"

Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
$b = Limpar-Pasta (Join-Path $env:windir 'SoftwareDistribution\Download')
Start-Service -Name bits, wuauserv -ErrorAction SilentlyContinue
Ok "Cache do Windows Update ($(Tamanho $b))"

if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
  Delete-DeliveryOptimizationCache -Force -ErrorAction SilentlyContinue | Out-Null
  Ok 'Cache da Otimização da Entrega'
}

if ($LimpezaProfunda) {
  Write-Host '    A limpar componentes antigos do Windows (pode demorar 10-30 min, não feche a janela)...'
  & dism.exe /Online /Cleanup-Image /StartComponentCleanup /NoRestart
  if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) { Ok 'Componentes antigos do Windows removidos' }
  else { Aviso "A limpeza de componentes não terminou (código $LASTEXITCODE). Normalmente é por haver uma atualização à espera de reinício; volte a correr depois de reiniciar." }
}

# ----------------------------- 3. APLICAÇÕES ---------------------------------

Passo '3/7 A remover aplicações desnecessárias'

$Provisionadas = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
foreach ($a in $AppsRemover) {
  $removida = $false
  # Aplicações em "pacote" (bundle) têm de ser removidas pelo pacote, não pela parte principal
  $pacotes = @(Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name $a -ErrorAction SilentlyContinue)
  if ($pacotes.Count -eq 0) { $pacotes = @(Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue) }
  foreach ($pk in $pacotes) {
    try { Remove-AppxPackage -Package $pk.PackageFullName -AllUsers -ErrorAction Stop; $removida = $true }
    catch { Aviso "Não foi possível remover $($pk.Name): $(($_.Exception.Message -split "`n")[0])" }
  }
  $Provisionadas | Where-Object { $_.DisplayName -like $a } | ForEach-Object {
    try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null; $removida = $true } catch {}
  }
  if ($removida) { Ok "Removida: $a" }
}

# ----------------------------- 4. DEFINIÇÕES DO SISTEMA ----------------------

Passo '4/7 A desligar telemetria, sugestões e programas em segundo plano'

$Pol = 'HKLM:\SOFTWARE\Policies\Microsoft'
# Telemetria
Definir-Registo "$Pol\Windows\DataCollection" 'AllowTelemetry' 0
# Anúncios, apps instaladas sozinhas e sugestões
Definir-Registo "$Pol\Windows\CloudContent" 'DisableWindowsConsumerFeatures' 1
Definir-Registo "$Pol\Windows\CloudContent" 'DisableSoftLanding' 1
Definir-Registo "$Pol\Windows\CloudContent" 'DisableCloudOptimizedContent' 1
Definir-Registo "$Pol\Windows\CloudContent" 'DisableConsumerAccountStateContent' 1
# Pesquisa: sem Bing/web nem Cortana
Definir-Registo "$Pol\Windows\Windows Search" 'AllowCortana' 0
Definir-Registo "$Pol\Windows\Windows Search" 'DisableWebSearch' 1
Definir-Registo "$Pol\Windows\Windows Search" 'ConnectedSearchUseWeb' 0
# Widgets / Notícias e interesses
Definir-Registo "$Pol\Dsh" 'AllowNewsAndInterests' 0
Definir-Registo "$Pol\Windows\Windows Feeds" 'EnableFeeds' 0
# Gravação de jogos
Definir-Registo "$Pol\Windows\GameDVR" 'AllowGameDVR' 0
# Copilot
Definir-Registo "$Pol\Windows\WindowsCopilot" 'TurnOffWindowsCopilot' 1
# Edge e Chrome não ficam a correr depois de fechados
Definir-Registo "$Pol\Edge" 'StartupBoostEnabled' 0
Definir-Registo "$Pol\Edge" 'BackgroundModeEnabled' 0
Definir-Registo "$Pol\Edge" 'HubsSidebarEnabled' 0
Definir-Registo 'HKLM:\SOFTWARE\Policies\Google\Chrome' 'BackgroundModeEnabled' 0
Ok 'Políticas aplicadas'

# Sensor de Armazenamento: limpeza automática a partir de agora
Definir-Registo "$Pol\Windows\StorageSense" 'AllowStorageSenseGlobal' 1
Definir-Registo "$Pol\Windows\StorageSense" 'ConfigStorageSenseGlobalCadence' 7
Definir-Registo "$Pol\Windows\StorageSense" 'AllowStorageSenseTemporaryFilesCleanup' 1
Definir-Registo "$Pol\Windows\StorageSense" 'ConfigStorageSenseRecycleBinCleanupThreshold' 7
Definir-Registo "$Pol\Windows\StorageSense" 'ConfigStorageSenseDownloadsCleanupThreshold' $DiasLimpezaAutomatica
Ok "Sensor de Armazenamento ligado (semanal; Transferências com mais de $DiasLimpezaAutomatica dias)"

foreach ($s in $ServicosDesligar) {
  $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
  if ($svc) {
    Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
    Ok "Serviço desligado: $s"
  }
}

# Desfaz alterações da primeira versão deste script (caso já tenha sido corrido neste portátil)
Remove-ItemProperty -Path "$Pol\Windows\AppPrivacy" -Name 'LetAppsRunInBackground' -ErrorAction SilentlyContinue
if (Get-Service -Name dmwappushservice -ErrorAction SilentlyContinue) { Set-Service -Name dmwappushservice -StartupType Manual -ErrorAction SilentlyContinue }
Enable-ScheduledTask -TaskPath '\Microsoft\Windows\Application Experience\' -TaskName 'Microsoft Compatibility Appraiser' -ErrorAction SilentlyContinue | Out-Null

# Indexação de pesquisa: em vez de desligar (estragaria a pesquisa no Iniciar e no
# Explorador), só arranca uns minutos depois de o portátil ligar, para não atrasar o arranque
if (Get-Service -Name WSearch -ErrorAction SilentlyContinue) {
  & sc.exe config WSearch start= delayed-auto 2>&1 | Out-Null
  Ok 'Indexação de pesquisa com arranque adiado'
}

foreach ($t in $TarefasDesligar) {
  if (Get-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue) {
    Disable-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue | Out-Null
    Ok "Tarefa desligada: $($t[1])"
  }
}

# ----------------------------- 5. CONTAS (efeitos visuais e sugestões) ------

Passo '5/7 A aplicar definições de desempenho em todas as contas'

# Definições por conta: chave, nome, tipo, valor
$DefConta = @(
  @('Control Panel\Desktop', 'UserPreferencesMask', 'REG_BINARY', '9012038010000000'),
  @('Control Panel\Desktop', 'MenuShowDelay', 'REG_SZ', '100'),
  @('Control Panel\Desktop', 'DragFullWindows', 'REG_SZ', '0'),
  @('Control Panel\Desktop\WindowMetrics', 'MinAnimate', 'REG_SZ', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects', 'VisualFXSetting', 'REG_DWORD', '3'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'TaskbarAnimations', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ListviewAlphaSelect', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ListviewShadow', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'TaskbarDa', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced', 'ShowCopilotButton', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize', 'EnableTransparency', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\DWM', 'EnableAeroPeek', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\Search', 'BingSearchEnabled', 'REG_DWORD', '0'),
  @('Software\Policies\Microsoft\Windows\Explorer', 'DisableSearchBoxSuggestions', 'REG_DWORD', '1'),
  @('Software\Policies\Microsoft\Windows\WindowsCopilot', 'TurnOffWindowsCopilot', 'REG_DWORD', '1'),
  @('System\GameConfigStore', 'GameDVR_Enabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'ContentDeliveryAllowed', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'OemPreInstalledAppsEnabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'PreInstalledAppsEnabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SilentInstalledAppsEnabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SystemPaneSuggestionsEnabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SoftLandingEnabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338388Enabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-338389Enabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353694Enabled', 'REG_DWORD', '0'),
  @('Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager', 'SubscribedContent-353696Enabled', 'REG_DWORD', '0')
)

function Aplicar-Conta([string]$raiz) {
  foreach ($d in $DefConta) { Definir-RegistoConta $raiz $d[0] $d[1] $d[2] $d[3] }
  # Desfaz uma alteração da primeira versão deste script
  & reg.exe delete "$raiz\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f 2>&1 | Out-Null
}

# Contas existentes (as que têm sessão aberta já estão carregadas; as outras carregam-se e descarregam-se)
$hives = @()
foreach ($p in $Perfis) { $hives += [pscustomobject]@{ Nome = (Split-Path $p.LocalPath -Leaf); Sid = $p.SID; Ficheiro = (Join-Path $p.LocalPath 'NTUSER.DAT') } }
# Conta "Default": modelo para as contas novas
$hives += [pscustomobject]@{ Nome = '(contas novas)'; Sid = $null; Ficheiro = (Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT') }

foreach ($h in $hives) {
  if ($h.Sid -and (Test-Path "Registry::HKEY_USERS\$($h.Sid)")) {
    Aplicar-Conta "HKU\$($h.Sid)"
    Ok "Conta $($h.Nome)"
  } elseif (Test-Path -LiteralPath $h.Ficheiro) {
    # Nome diferente para cada conta: se uma falhar a descarregar, as seguintes não ficam bloqueadas
    $tmp = 'HKU\OtimizarTmp' + [guid]::NewGuid().ToString('N').Substring(0, 8)
    & reg.exe load $tmp $h.Ficheiro 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Aplicar-Conta $tmp
      $descarregada = $false
      for ($i = 0; $i -lt 5 -and -not $descarregada; $i++) {
        [gc]::Collect(); [gc]::WaitForPendingFinalizers(); Start-Sleep -Seconds 1
        & reg.exe unload $tmp 2>&1 | Out-Null
        $descarregada = ($LASTEXITCODE -eq 0)
      }
      if ($descarregada) { Ok "Conta $($h.Nome)" }
      else { $ReiniciarObrigatorio = $true; Aviso "Conta $($h.Nome): definições aplicadas, mas é OBRIGATÓRIO reiniciar antes de alguém entrar" }
    } else { Aviso "Não foi possível abrir a conta $($h.Nome)" }
  }
}

# ----------------------------- 6. APLICAÇÕES DAS AULAS -----------------------

Passo '6/7 A instalar as aplicações das aulas (TIC e CEA)'

$AppsFalharam = @()
$InstSoAdmin = @()
# Códigos do winget: sucesso, "já instalado" e "instalado, falta reiniciar"
$CodigosOk = @(0, -1978335189, -1978335135, -1978334967)
$SemInstaladorMaquina = -1978335216   # o pacote não tem instalação "para todos"
$WingetNaoArranca = -1073741515       # falta uma biblioteca do Windows ao winget

function Versao-Pasta($pasta) { try { return [version](($pasta.Name -split '_')[1]) } catch { return [version]'0.0' } }

$Winget = $null
$cw = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($cw) { $Winget = $cw.Source }
else {
  # Conta de administrador sem o atalho do winget: usa a versão mais recente instalada no sistema
  $pastaApps = Join-Path $env:ProgramFiles 'WindowsApps'
  $ai = Get-ChildItem -LiteralPath $pastaApps -Filter 'Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe' -Directory -ErrorAction SilentlyContinue |
        Sort-Object { Versao-Pasta $_ } -Descending | Select-Object -First 1
  if ($ai -and (Test-Path -LiteralPath (Join-Path $ai.FullName 'winget.exe'))) {
    $Winget = Join-Path $ai.FullName 'winget.exe'
    $vc = Get-ChildItem -LiteralPath $pastaApps -Filter 'Microsoft.VCLibs.140.00.UWPDesktop_*_x64__8wekyb3d8bbwe' -Directory -ErrorAction SilentlyContinue |
          Sort-Object { Versao-Pasta $_ } -Descending | Select-Object -First 1
    if ($vc) { $env:PATH = "$($vc.FullName);$env:PATH" }
  }
}

if (-not $Winget) {
  Aviso 'O winget (Instalador de Aplicações) não está disponível neste portátil.'
  Aviso 'Atualize o "Instalador de Aplicações" na Microsoft Store e volte a correr o script.'
  $AppsFalharam = @($AppsInstalar | ForEach-Object { $_[1] })
} else {
  # Verifica se o catálogo do winget está disponível. Numa conta de administrador onde o
  # winget nunca foi usado, o catálogo pode não existir (erro 0x8a15000f); nesse caso repara-o.
  function Catalogo-Ok {
    & $Winget search --id 7zip.7zip --exact --source winget --accept-source-agreements 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
  }
  $catalogo = Catalogo-Ok
  if (-not $catalogo) {
    Write-Host '    A reparar o catálogo de aplicações do winget...'
    & $Winget source reset --force 2>&1 | Out-Null
    & $Winget source update --name winget 2>&1 | Out-Null
    $catalogo = Catalogo-Ok
  }
  if (-not $catalogo) {
    # Reinstala o catálogo a partir do endereço oficial da Microsoft
    try { Add-AppxPackage -Path 'https://cdn.winget.microsoft.com/cache/source.msix' -ErrorAction Stop } catch {}
    & $Winget source update --name winget 2>&1 | Out-Null
    $catalogo = Catalogo-Ok
  }
  if ($catalogo) { Ok 'Catálogo de aplicações disponível' }
  else {
    Aviso 'Não foi possível abrir o catálogo de aplicações do winget.'
    Aviso 'Confirme a internet. Se a rede da escola bloquear cdn.winget.microsoft.com, ligue o portátil a outra rede (por exemplo, a do telemóvel) e volte a correr o script.'
    $AppsFalharam = @($AppsInstalar | ForEach-Object { $_[1] })
  }

  foreach ($app in $AppsInstalar) {
    if (-not $catalogo) { break }
    $id = $app[0]; $nomeApp = $app[1]
    & $Winget list --id $id --exact --source winget --accept-source-agreements 2>&1 | Out-Null
    $codigo = $LASTEXITCODE
    if ($codigo -eq $WingetNaoArranca) {
      Aviso 'O winget não consegue arrancar neste portátil. Atualize o "Instalador de Aplicações" na Microsoft Store e volte a correr o script.'
      $AppsFalharam = @($AppsInstalar | ForEach-Object { $_[1] })
      break
    }
    if ($codigo -eq 0) { Ok "$nomeApp já estava instalado"; continue }

    Write-Host "    A instalar $nomeApp..."
    & $Winget install --id $id --exact --source winget --silent --scope machine `
        --accept-package-agreements --accept-source-agreements
    $codigo = $LASTEXITCODE
    if ($codigo -eq $SemInstaladorMaquina) {
      # Só para pacotes que não têm instalação "para todos": instala na conta atual
      & $Winget install --id $id --exact --source winget --silent `
          --accept-package-agreements --accept-source-agreements
      $codigo = $LASTEXITCODE
      if ($CodigosOk -contains $codigo) { $InstSoAdmin += $nomeApp }
    }
    if ($CodigosOk -contains $codigo) { Ok "$nomeApp instalado" }
    else { $AppsFalharam += $nomeApp; Aviso "$nomeApp NÃO foi instalado (código $codigo; verifique a internet)" }
  }
}

# Atalhos web na Área de Trabalho de todas as contas
$AreaPublica = [Environment]::GetFolderPath('CommonDesktopDirectory')
foreach ($a in $AtalhosWeb) {
  $partes = $a -split '\|', 2
  $ficheiroUrl = Join-Path $AreaPublica (($partes[0] -replace '[\\/:*?"<>|]', '') + '.url')
  try {
    [IO.File]::WriteAllText($ficheiroUrl, "[InternetShortcut]`r`nURL=$($partes[1])`r`n", [Text.Encoding]::ASCII)
    Ok "Atalho: $($partes[0])"
  } catch { Aviso "Não foi possível criar o atalho $($partes[0])" }
}

# ----------------------------- 7. RESUMO -------------------------------------

Passo '7/7 Resumo'
$LivreDepois = EspacoLivre
$Ganho = $LivreDepois - $LivreAntes
$Duracao = [int]((Get-Date) - $Inicio).TotalMinutes

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host "  Concluído em $Duracao min — $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "  Espaço livre antes:  $(Tamanho $LivreAntes)" -ForegroundColor Green
Write-Host "  Espaço livre depois: $(Tamanho $LivreDepois)  (+$(Tamanho ([math]::Max($Ganho, 0))))" -ForegroundColor Green
Write-Host "  Ficheiros das contas apagados: $(Tamanho $TotalContas)" -ForegroundColor Green
Write-Host "  Registo: $Registo" -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
if ($AppsFalharam.Count -gt 0) {
  Write-Host ''
  Write-Host ('Aplicações por instalar: ' + ($AppsFalharam -join ', ')) -ForegroundColor Yellow
  Write-Host 'Volte a correr o script com internet: só instala o que faltar.' -ForegroundColor Yellow
}
if ($InstSoAdmin.Count -gt 0) {
  Write-Host ('Instaladas só para a conta atual (não há versão para todos): ' + ($InstSoAdmin -join ', ')) -ForegroundColor Yellow
}
Write-Host ''
if ($ReiniciarObrigatorio) {
  Write-Host 'ATENÇÃO: reinicie ANTES de alguém entrar no portátil.' -ForegroundColor Red
} else {
  Write-Host 'É preciso reiniciar para as alterações ficarem todas ativas.'
}
Stop-Transcript | Out-Null

$r = Read-Host 'Reiniciar agora? (S/N)'
if ($r -match '^[sS]') { Restart-Computer -Force }
