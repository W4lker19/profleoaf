<# : -------- parte em linha de comandos (cmd): pede administrador e passa o resto ao PowerShell --------
@echo off
chcp 65001 >nul
net session >nul 2>&1
if errorlevel 1 (
  echo A pedir permissoes de administrador...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f='%~f0'; iex ([IO.File]::ReadAllText($f, [Text.Encoding]::UTF8))"
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
#
#  NÃO mexe em: Windows Update, Windows Defender, Microsoft Store, Office,
#  Teams, OneDrive, nem nas pastas Documentos/Imagens dos alunos.
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
  'Microsoft.YourPhone', 'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo',
  'Microsoft.549981C3F5F10', 'Microsoft.PowerAutomateDesktop', 'Microsoft.Todos',
  'Microsoft.Windows.DevHome', 'Microsoft.Copilot', 'Microsoft.BingSearch',
  'Clipchamp.Clipchamp', 'MicrosoftCorporationII.MicrosoftFamily',
  '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*', '*Disney*', '*Spotify*', '*TikTok*',
  '*Instagram*', '*Facebook*', '*Netflix*', '*Twitter*', '*ROBLOX*', '*Hulu*', '*PrimeVideo*',
  '*king.com*', '*Dolby*', '*Asphalt*', '*McAfee*', '*Norton*'
)

# Serviços a desligar
$ServicosDesligar = @(
  'DiagTrack',            # telemetria
  'dmwappushservice',     # telemetria (mensagens WAP)
  'WSearch',              # indexação de ficheiros: pesa muito em discos lentos
  'MapsBroker',           # mapas offline
  'RetailDemo',           # modo de demonstração de loja
  'XblAuthManager', 'XblGameSave', 'XboxNetApiSvc', 'XboxGipSvc',  # Xbox
  'WMPNetworkSvc',        # partilha do Windows Media Player
  'Fax'
)

# Tarefas agendadas de telemetria
$TarefasDesligar = @(
  @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
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

# Apaga o conteúdo de uma pasta (mas não a pasta) e devolve os bytes apagados
function Limpar-Pasta([string]$pasta) {
  if (-not (Test-Path -LiteralPath $pasta)) { return 0 }
  $bytes = (Get-ChildItem -LiteralPath $pasta -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
  Get-ChildItem -LiteralPath $pasta -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
  if ($bytes) { return $bytes } else { return 0 }
}

# Apaga uma pasta inteira e devolve os bytes apagados
function Apagar-Pasta([string]$pasta) {
  if (-not (Test-Path -LiteralPath $pasta)) { return 0 }
  $bytes = (Get-ChildItem -LiteralPath $pasta -Recurse -Force -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
  Remove-Item -LiteralPath $pasta -Recurse -Force -ErrorAction SilentlyContinue
  if ($bytes) { return $bytes } else { return 0 }
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
Write-Host ''
Write-Host 'Os Documentos, Imagens e o OneDrive dos alunos NÃO são tocados.' -ForegroundColor Green
if ($ContasExcluidas.Count -gt 0) { Write-Host ('Contas excluídas: ' + ($ContasExcluidas -join ', ')) -ForegroundColor Green }
Write-Host ''
Write-Host 'Os browsers vão ser fechados. Pode demorar entre 5 e 40 minutos.'
Write-Host ''

if ($PedirConfirmacao) {
  $r = Read-Host 'Continuar? (S/N)'
  if ($r -notmatch '^[sS]') { Write-Host 'Cancelado. Nada foi alterado.'; Stop-Transcript | Out-Null; Start-Sleep 3; exit }
}

$Inicio = Get-Date
$LivreAntes = EspacoLivre

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

Passo '1/6 A limpar os ficheiros das contas'

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
  if (Test-Path -LiteralPath $dl) {
    $ficheiros = Get-ChildItem -LiteralPath $dl -Recurse -Force -File -ErrorAction SilentlyContinue |
      Where-Object { $_.LastWriteTime -lt $Limite -or $ExtensoesTransferencias -contains $_.Extension.ToLower() }
    foreach ($f in $ficheiros) {
      $t = $f.Length
      Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
      if (-not (Test-Path -LiteralPath $f.FullName)) { $apagado += $t }
    }
    # Pastas que ficaram vazias
    Get-ChildItem -LiteralPath $dl -Recurse -Force -Directory -ErrorAction SilentlyContinue |
      Sort-Object { $_.FullName.Length } -Descending |
      Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue) } |
      Remove-Item -Force -ErrorAction SilentlyContinue
  }

  # Área de Trabalho: só instaladores e imagens de disco
  $ad = Join-Path $casa 'Desktop'
  if (Test-Path -LiteralPath $ad) {
    Get-ChildItem -LiteralPath $ad -Force -File -ErrorAction SilentlyContinue |
      Where-Object { $ExtensoesAreaTrabalho -contains $_.Extension.ToLower() } |
      ForEach-Object { $apagado += $_.Length; Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue }
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

# ----------------------------- 2. SISTEMA ------------------------------------

Passo '2/6 A limpar o sistema'

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
  Start-Process -FilePath dism.exe -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup' -Wait -NoNewWindow
  Ok 'Componentes antigos do Windows removidos'
}

# ----------------------------- 3. APLICAÇÕES ---------------------------------

Passo '3/6 A remover aplicações desnecessárias'

$Provisionadas = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
foreach ($a in $AppsRemover) {
  $removida = $false
  Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction Stop; $removida = $true } catch {}
  }
  $Provisionadas | Where-Object { $_.DisplayName -like $a } | ForEach-Object {
    try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null; $removida = $true } catch {}
  }
  if ($removida) { Ok "Removida: $a" }
}

# ----------------------------- 4. DEFINIÇÕES DO SISTEMA ----------------------

Passo '4/6 A desligar telemetria, sugestões e programas em segundo plano'

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
# Aplicações da Store em segundo plano
Definir-Registo "$Pol\Windows\AppPrivacy" 'LetAppsRunInBackground' 2
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

foreach ($t in $TarefasDesligar) {
  if (Get-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue) {
    Disable-ScheduledTask -TaskPath $t[0] -TaskName $t[1] -ErrorAction SilentlyContinue | Out-Null
    Ok "Tarefa desligada: $($t[1])"
  }
}

# ----------------------------- 5. CONTAS (efeitos visuais e sugestões) ------

Passo '5/6 A aplicar definições de desempenho em todas as contas'

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
  @('Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications', 'GlobalUserDisabled', 'REG_DWORD', '1'),
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
    & reg.exe load 'HKU\OtimizarTmp' $h.Ficheiro 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
      Aplicar-Conta 'HKU\OtimizarTmp'
      [gc]::Collect(); Start-Sleep -Milliseconds 500
      & reg.exe unload 'HKU\OtimizarTmp' 2>&1 | Out-Null
      Ok "Conta $($h.Nome)"
    } else { Aviso "Não foi possível abrir a conta $($h.Nome)" }
  }
}

# ----------------------------- 6. RESUMO -------------------------------------

Passo '6/6 Resumo'
$LivreDepois = EspacoLivre
$Ganho = $LivreDepois - $LivreAntes
$Duracao = [int]((Get-Date) - $Inicio).TotalMinutes

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host "  Concluído em $Duracao min — $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "  Espaço livre antes:  $(Tamanho $LivreAntes)" -ForegroundColor Green
Write-Host "  Espaço livre depois: $(Tamanho $LivreDepois)  (+$(Tamanho ([math]::Max($Ganho, 0))))" -ForegroundColor Green
Write-Host "  Registo: $Registo" -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'É preciso reiniciar para as alterações ficarem todas ativas.'
Stop-Transcript | Out-Null

$r = Read-Host 'Reiniciar agora? (S/N)'
if ($r -match '^[sS]') { Restart-Computer -Force }
