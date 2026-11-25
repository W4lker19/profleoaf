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
#  A única pergunta é a confirmação no início (com a lista do que vai ser apagado).
#
#  O que faz:
#   1. Remove aplicações e programas que não fazem falta (Xbox, Solitaire, notícias,
#      Paint, Câmara, Teams, OneDrive, LibreOffice, paint.net, Lenovo Vantage, .NET antigo…)
#      e impede que as atualizações do Windows reinstalem as aplicações
#   2. Deixa só as contas Administrador e Aluno: apaga as outras contas, as pastas
#      delas e as pastas de contas abandonadas (mostra a lista antes de apagar)
#   3. Limpa os ficheiros dos alunos: transferências antigas, instaladores e
#      jogos descarregados, ficheiros temporários, cache dos browsers e reciclagem
#   4. Limpa o sistema: temporários, cache do Windows Update, relatórios de erros
#   5. Desliga telemetria, sugestões, anúncios e widgets; ativa o Sensor de Armazenamento
#   6. Desliga efeitos visuais (animações, transparências) em todas as contas
#   7. Instala (ou atualiza) o que os alunos precisam: Office (português), Chrome, Edge, Scratch,
#      GIMP, Audacity, VLC e 7-Zip, e atalhos para o MakeCode e o Microsoft 365;
#      desinstala versões antigas (p. ex. GIMP 2) quando a nova já está instalada
#   8. Resumo, com os programas que ocupam mais espaço
#
#  NÃO mexe em: Windows Update, Windows Defender, Microsoft Store, Fotografias, Calculadora,
#  nem nos Documentos, Imagens e ficheiros da pasta OneDrive das contas que ficam.
#  Pode ser corrido mais do que uma vez: só instala o que faltar.
#  Registo de tudo o que foi feito em C:\ProgramData\OtimizarPortatil\
# =============================================================================

# ----------------------------- DEFINIÇÕES ------------------------------------

# Versão deste script (mostrada no site profleoaf.pt/tools, no arranque e no resumo).
# Muda a cada alteração publicada: ano.mês.dia-número
$VersaoScript = '2026.11.25-2'

$PedirConfirmacao       = $true   # pergunta antes de começar
$DiasTransferencias     = 7       # apaga das Transferências o que tiver mais de 7 dias
$DiasLimpezaAutomatica  = 14      # depois, o Windows limpa sozinho as Transferências com mais de 14 dias
$LimpezaProfunda        = $true   # limpeza de componentes do Windows (DISM): liberta espaço, demora 10-30 min
$ContasExcluidas        = @()     # contas cujos ficheiros NÃO são apagados, ex.: @('professor')

# Contas: ficam SÓ estas. As outras contas, as pastas delas e as pastas abandonadas em C:\Users
# são apagadas depois da confirmação. Por segurança, se alguma destas contas não existir no
# portátil, não se apaga nenhuma conta. A conta com que o script está a correr nunca é apagada.
$ContasManter           = @('Administrador', 'Aluno')
$ApagarOutrasContas     = $true

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
  'AppData\Local\Programs\Opera',
  'AppData\Local\Microsoft\Teams'          # Teams clássico instalado na conta
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
  'Microsoft.MSPaint',                       # Paint 3D
  'Microsoft.Office.OneNote',                # OneNote antigo do Windows 10 (o do Office fica)
  'Microsoft.WindowsCommunicationsApps',     # Correio e Calendário antigos
  'Microsoft.OutlookForWindows',             # Outlook novo (os alunos usam o Outlook na web)
  'Microsoft.WindowsAlarms', 'Microsoft.Messaging', 'Microsoft.OneConnect', 'Microsoft.Print3D',
  'Microsoft.MicrosoftJournal', 'MicrosoftWindows.CrossDevice', 'Microsoft.Windows.Ai.Copilot.Provider',
  'MicrosoftTeams',                          # chat pessoal do Windows 11
  'Microsoft.MicrosoftStickyNotes', 'Microsoft.Edge.GameAssist',
  'E046963F.LenovoCompanion',                # Lenovo Vantage (o Lenovo Hotkeys fica)
  'MSTeams',                                 # Teams (os alunos usam o Teams na web, em office.com)
  'Microsoft.Paint', 'Microsoft.WindowsCamera',
  '*LinkedIn*', '*WhatsApp*', '*Amazon*', '*Booking*',
  '*CandyCrush*', '*BubbleWitch*', '*MarchofEmpires*', '*Disney*', '*Spotify*', '*TikTok*',
  '*Instagram*', '*Facebook*', '*Netflix*', '*Twitter*', '*ROBLOX*', '*Hulu*', '*PrimeVideo*',
  '*king.com*', '*Asphalt*', '*McAfee*', '*Norton*'
)
# Mantidas de propósito: Fotografias, Calculadora, Microsoft Store, Gravador de Som, Ferramenta de Recorte,
# Bloco de Notas, Leitor Multimédia (ZuneMusic), Clipchamp (M365 Educação), Whiteboard,
# Assistência Rápida, Dolby (som dos altifalantes) e Obter Ajuda (resolução de problemas).
# As aplicações removidas ficam marcadas como "retiradas" no Windows, para as atualizações
# não as voltarem a instalar.

# Aplicações para as aulas (identificadores do winget). Só instala as que faltarem.
$AppsInstalar = @(
  @('Google.Chrome',         'Google Chrome'),
  @('Microsoft.Edge',        'Microsoft Edge'),
  @('MITMediaLab.Scratch.3', 'Scratch 3'),
  @('GIMP.GIMP.3',           'GIMP'),
  @('Audacity.Audacity',     'Audacity'),
  @('VideoLAN.VLC',          'VLC'),
  @('7zip.7zip',             '7-Zip')
)

# Microsoft Office (Word, Excel, PowerPoint e OneNote) em português de Portugal.
# Só é instalado se ainda não existir e se houver espaço livre suficiente (descarrega cerca de 3 GB).
# Os alunos ativam-no ao entrar com a conta da escola.
$InstalarOffice     = $true

# Desinstalar a aplicação OneDrive do computador (os alunos usam o OneDrive na web).
# Os ficheiros que já estão na pasta OneDrive de cada conta NÃO são apagados.
$RemoverOneDrive    = $true
$EspacoMinimoOffice = 10GB
$ConfigOffice = @'
<Configuration>
  <Add OfficeClientEdition="64" Channel="Current">
    <Product ID="O365ProPlusRetail">
      <Language ID="pt-pt" />
      <ExcludeApp ID="Access" />
      <ExcludeApp ID="Bing" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
      <ExcludeApp ID="OneDrive" />
      <ExcludeApp ID="Outlook" />
      <ExcludeApp ID="Publisher" />
      <ExcludeApp ID="Teams" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
</Configuration>
'@

# Programas do computador a desinstalar (nome como aparece em Definições > Aplicações).
# Só com desinstaladores silenciosos conhecidos; os outros ficam com um aviso.
# Ficam de propósito: Lenovo Vantage Service, Lenovo Hotkeys, drivers Intel e Realtek, Visual C++.
$ProgramasRemover = @(
  'LibreOffice*',
  'paint.net*',
  'Microsoft Windows Desktop Runtime - 5.*',   # .NET 5, 6 e 7: sem suporte da Microsoft
  'Microsoft Windows Desktop Runtime - 6.*',
  'Microsoft Windows Desktop Runtime - 7.*',
  'Lenovo System Update*',
  'Ligação ao ambiente de trabalho remoto*', 'Remote Desktop Connection*'
)

# Versões antigas a desinstalar, só se a versão nova já estiver instalada:
# nome antigo (como aparece em Definições > Aplicações), nome da versão nova, identificador
# do winget da versão nova (reinstalada por cima no fim, para repor atalhos e associações)
$VersoesAntigas = @(
  @('GIMP 2*',          'GIMP 3*',     'GIMP.GIMP.3'),
  @('Scratch Desktop*', 'Scratch 3*',  'MITMediaLab.Scratch.3'),
  @('Scratch 2*',       'Scratch 3*',  'MITMediaLab.Scratch.3'),
  @('Audacity 2*',      'Audacity 3*', 'Audacity.Audacity')
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

function EspacoLivre { return [long](Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free }

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

# Marca uma aplicação da Store como "retirada": as atualizações do Windows deixam de a reinstalar
function Marcar-Retirada([string]$familia) {
  if (-not $familia -or $familia -eq '_') { return }
  $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\$familia"
  if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
}

# Programas instalados no computador (chaves de desinstalação do Windows)
$ChavesDesinstalar = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                     'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
function Programas-Instalados {
  foreach ($k in $ChavesDesinstalar) {
    Get-ItemProperty -Path $k -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName }
  }
}

# Separa um comando em programa + argumentos
function Separar-Comando([string]$cmd) {
  $cmd = $cmd.Trim()
  $c = if ($cmd -match '^"([^"]+)"') { $Matches[1] } elseif ($cmd -match '^(.+?\.exe)') { $Matches[1] } else { $null }
  if (-not $c) { return $null }
  $resto = $cmd.Substring($cmd.IndexOf($c) + $c.Length).Trim('"', ' ')
  return @{ Exe = $c; Args = @($resto -split '\s+' | Where-Object { $_ }) }
}

# Desinstala um programa SÓ com desinstaladores silenciosos conhecidos (MSI, Inno Setup, NSIS,
# pacotes .NET) ou com o comando silencioso que o próprio programa indica. Nunca abre uma janela
# que fique à espera de alguém. Devolve $true se o programa desapareceu da lista.
function Desinstalar-Programa($entrada) {
  $nome = $entrada.DisplayName
  $exe = $null; $argumentos = @()
  $guid = if ($entrada.PSChildName -match '^\{[0-9A-Fa-f-]+\}$') { $entrada.PSChildName } else { $null }
  if ($entrada.UninstallString -match '(?i)msiexec' -and $guid) {
    $exe = 'msiexec.exe'; $argumentos = @('/x', $guid, '/qn', '/norestart')
  } elseif ($entrada.QuietUninstallString) {
    $sc = Separar-Comando $entrada.QuietUninstallString
    if ($sc -and (Test-Path -LiteralPath $sc.Exe)) {
      $exe = $sc.Exe
      # Inno Setup: o comando "silencioso" do próprio programa (/SILENT) ainda pode abrir mensagens
      if ((Split-Path $sc.Exe -Leaf) -match '(?i)^unins\d*\.exe$') { $argumentos = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') }
      else { $argumentos = $sc.Args }
    }
  }
  if (-not $exe -and $entrada.UninstallString) {
    $sc = Separar-Comando $entrada.UninstallString
    if ($sc -and (Test-Path -LiteralPath $sc.Exe)) {
      $leaf = Split-Path $sc.Exe -Leaf
      $silencio = $null
      if ($leaf -match '(?i)^unins\d*\.exe$') { $silencio = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') }      # Inno Setup
      elseif ($leaf -match '(?i)^uninst(all)?.*\.exe$') { $silencio = @('/S') }                                      # NSIS
      elseif ($sc.Exe -match '(?i)\\Package Cache\\' -and $sc.Args -contains '/uninstall') { $silencio = @('/quiet', '/norestart') }   # pacotes .NET
      if ($silencio) { $exe = $sc.Exe; $argumentos = @($sc.Args) + $silencio }
    }
  }
  if (-not $exe) { Aviso "$($nome): sem desinstalação automática segura. Desinstale-o em Definições > Aplicações."; return $false }
  Write-Host "    A desinstalar: $nome..."
  try {
    $pr = Start-Process -FilePath $exe -ArgumentList $argumentos -PassThru -ErrorAction Stop
    $null = $pr.Handle
    [void]$pr.WaitForExit(600000)   # no máximo 10 minutos
  } catch { Aviso "$($nome): não foi possível desinstalar ($(($_.Exception.Message -split "`n")[0]))"; return $false }
  # Alguns desinstaladores continuam em segundo plano: espera até 2 minutos que o programa desapareça
  $saiu = $false
  for ($i = 0; $i -lt 24 -and -not $saiu; $i++) {
    $saiu = @(Programas-Instalados | Where-Object { $_.DisplayName -eq $nome }).Count -eq 0
    if (-not $saiu) { Start-Sleep -Seconds 5 }
  }
  if ($saiu) { Ok "Removido: $nome" } else { Aviso "$($nome): a desinstalação não terminou. Confirme em Definições > Aplicações." }
  return $saiu
}

# ----------------------------- INÍCIO ----------------------------------------

Clear-Host

# ----- Plano das contas: calculado antes da confirmação, para ser mostrado -----
# SEGURANÇA: se alguma coisa não bater certo (conta que fica não encontrada, lista de perfis
# ilegível ou incoerente), não se apaga NENHUMA conta.
$PlanoContas = @()
$AvisoContas = $null
$ContasEmUso = @()
$ContasFicam = @()
$MesmoNomeMantidas = @()
if ($ApagarOutrasContas) {
  Write-Host 'A verificar as contas deste portátil (pode demorar um minuto)...'
  $Locais = @(Get-LocalUser -ErrorAction SilentlyContinue)
  $Faltam = @($ContasManter | Where-Object { $n = $_; -not ($Locais | Where-Object { $_.Name -eq $n }) })

  # Perfis segundo o WMI e segundo o registo do Windows (ProfileList)
  try { $PerfisTodos = @(Get-CimInstance Win32_UserProfile -ErrorAction Stop | Where-Object { $_.LocalPath }) }
  catch { $PerfisTodos = $null }
  $ListaPerfis = @(Get-ChildItem -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue |
    ForEach-Object {
      $img = (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).ProfileImagePath
      if ($img) {
        [pscustomobject]@{ Sid = ($_.PSChildName -replace '\.bak$', '')
          Caminho = ([Environment]::ExpandEnvironmentVariables($img)).TrimEnd('\').ToLower() }
      }
    })
  # Pastas cujo registo de utilizador (NTUSER.DAT) está aberto agora (conta com sessão aberta)
  $HivesCarregadas = @()
  $hl = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\hivelist' -ErrorAction SilentlyContinue
  if ($hl) {
    $HivesCarregadas = @($hl.PSObject.Properties |
      Where-Object { $_.Name -like '\REGISTRY\USER\*' -and $_.Value -is [string] -and $_.Value -match '\\NTUSER\.DAT$' } |
      ForEach-Object { (($_.Value -replace '^\\Device\\HarddiskVolume\d+', $env:SystemDrive) -replace '\\NTUSER\.DAT$', '').ToLower() })
  }

  if ($Locais.Count -eq 0 -or $Faltam.Count -gt 0) {
    $AvisoContas = "Não encontrei a(s) conta(s) $($Faltam -join ', ') neste portátil. Por segurança, nenhuma conta vai ser apagada."
  } elseif ($null -eq $PerfisTodos -or $PerfisTodos.Count -eq 0 -or $ListaPerfis.Count -eq 0) {
    $AvisoContas = 'Não foi possível ler a lista de perfis do Windows. Por segurança, nenhuma conta vai ser apagada.'
  } else {
    $SidAtual = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $SidsManter = @($Locais | Where-Object { $ContasManter -contains $_.Name } | ForEach-Object { $_.SID.Value }) + @($SidAtual)
    # Coerência: uma conta que fica e tem perfil no registo tem de aparecer também no WMI
    $Incoerentes = @($SidsManter | Where-Object {
      $s = $_
      @($ListaPerfis | Where-Object { $_.Sid -eq $s }).Count -gt 0 -and @($PerfisTodos | Where-Object { $_.SID -eq $s }).Count -eq 0
    })
    if ($Incoerentes.Count -gt 0) {
      $AvisoContas = 'A lista de perfis do Windows está incoerente. Por segurança, nenhuma conta vai ser apagada.'
    } else {
      $CaminhosManter = @($PerfisTodos | Where-Object { $SidsManter -contains $_.SID } | ForEach-Object { $_.LocalPath.TrimEnd('\').ToLower() }) +
                        @($ListaPerfis | Where-Object { $SidsManter -contains $_.Sid } | ForEach-Object { $_.Caminho }) +
                        @($env:USERPROFILE.TrimEnd('\').ToLower())
      $PerfisNormais = @($PerfisTodos | Where-Object { -not $_.Special -and $_.LocalPath -like "$env:SystemDrive\Users\*" })

      # Contas que ficam e a pasta de cada uma (mostrado na confirmação)
      foreach ($n in $ContasManter) {
        $u = $Locais | Where-Object { $_.Name -eq $n } | Select-Object -First 1
        $pf = $ListaPerfis | Where-Object { $_.Sid -eq $u.SID.Value } | Select-Object -First 1
        $ContasFicam += "$($u.Name) -> $(if ($pf) { $pf.Caminho } else { '(ainda sem pasta)' })"
      }

      # a) Contas locais a mais (nunca as contas internas do Windows: 500 a 504)
      foreach ($u in $Locais) {
        $sid = $u.SID.Value
        if ($SidsManter -contains $sid -or $sid -match '-50[0-4]$') { continue }
        $perfil = @($PerfisNormais | Where-Object { $_.SID -eq $sid }) | Select-Object -First 1
        $PlanoContas += [pscustomobject]@{ Tipo = 'conta'; Nome = $u.Name; Sid = $sid; Perfil = $perfil
          Caminho = $(if ($perfil) { $perfil.LocalPath } else { $null }) }
      }
      # b) Pastas de contas que não são locais (contas Microsoft ou da escola) ou cuja conta já não existe
      foreach ($p in $PerfisNormais) {
        if ($SidsManter -contains $p.SID) { continue }
        if (@($PlanoContas | Where-Object { $_.Sid -eq $p.SID }).Count -gt 0) { continue }
        $PlanoContas += [pscustomobject]@{ Tipo = 'perfil'; Nome = (Split-Path $p.LocalPath -Leaf); Sid = $p.SID; Perfil = $p; Caminho = $p.LocalPath }
      }
      # c) Pastas abandonadas: têm NTUSER.DAT mas não pertencem a nenhuma conta
      #    (p. ex. "ALUNO.PC" quando o Windows criou um "Aluno.PC.000" novo)
      $Ignorar = @('Public', 'Default', 'Default User', 'All Users', 'defaultuser0', 'defaultuser100000')
      $Registados = @($PerfisTodos | ForEach-Object { $_.LocalPath.TrimEnd('\').ToLower() }) + @($ListaPerfis | ForEach-Object { $_.Caminho })
      Get-ChildItem -LiteralPath (Join-Path $env:SystemDrive 'Users') -Force -Directory -ErrorAction SilentlyContinue |
        Where-Object {
          -not (E-Ligacao $_) -and $Ignorar -notcontains $_.Name -and
          $Registados -notcontains $_.FullName.TrimEnd('\').ToLower() -and
          (Test-Path -LiteralPath (Join-Path $_.FullName 'NTUSER.DAT'))
        } | ForEach-Object {
          $PlanoContas += [pscustomobject]@{ Tipo = 'pasta'; Nome = $_.Name; Sid = $null; Perfil = $null; Caminho = $_.FullName }
        }

      # Salvaguardas finais: nunca as pastas das contas que ficam, nunca uma conta ou pasta com
      # sessão aberta, e uma pasta com o nome exato de uma conta que fica (p. ex. C:\Users\Aluno
      # quando a Aluno atual usa Aluno.PC.000) só entra se for de uma conta LOCAL que já não existe
      $PlanoContas = @($PlanoContas | Where-Object { -not $_.Caminho -or $CaminhosManter -notcontains $_.Caminho.TrimEnd('\').ToLower() })
      $PrefixoMaquina = ($Locais[0].SID.Value -replace '-\d+$', '') + '-'
      $SidsLocais = @($Locais | ForEach-Object { $_.SID.Value })
      $MesmoNomeMantidas = @()
      $PlanoContas = @($PlanoContas | Where-Object {
        if (-not $_.Caminho) { return $true }
        if ($ContasManter -notcontains (Split-Path $_.Caminho.TrimEnd('\') -Leaf)) { return $true }
        $contaApagada = $_.Sid -and $_.Sid.StartsWith($PrefixoMaquina) -and $SidsLocais -notcontains $_.Sid
        if ($contaApagada) {
          $_.Tipo = 'apagada'
          return $true
        }
        $dono = 'desconhecida'
        if ($_.Sid) { try { $dono = ([Security.Principal.SecurityIdentifier]$_.Sid).Translate([Security.Principal.NTAccount]).Value } catch {} }
        $MesmoNomeMantidas += "$($_.Caminho) (conta: $dono)"
        return $false
      })
      foreach ($c in $PlanoContas) {
        $c | Add-Member -NotePropertyName EmUso -NotePropertyValue ([bool](
          ($c.Perfil -and $c.Perfil.Loaded) -or
          ($c.Caminho -and $HivesCarregadas -contains $c.Caminho.TrimEnd('\').ToLower())))
      }
      $ContasEmUso = @($PlanoContas | Where-Object { $_.EmUso })
      $PlanoContas = @($PlanoContas | Where-Object { -not $_.EmUso })

      # Tamanho e data da última utilização de cada pasta, para a confirmação
      foreach ($c in $PlanoContas) {
        $c | Add-Member -NotePropertyName Bytes -NotePropertyValue ([long]0)
        $c | Add-Member -NotePropertyName Data -NotePropertyValue ''
        if ($c.Caminho -and (Test-Path -LiteralPath $c.Caminho)) {
          $soma = (Listar-Ficheiros $c.Caminho | Measure-Object -Property Length -Sum).Sum
          if ($soma) { $c.Bytes = [long]$soma }
          $nt = Get-Item -LiteralPath (Join-Path $c.Caminho 'NTUSER.DAT') -Force -ErrorAction SilentlyContinue
          if (-not $nt) { $nt = Get-Item -LiteralPath $c.Caminho -Force }
          $c.Data = $nt.LastWriteTime.ToString('dd/MM/yyyy')
        }
      }
    }
  }
}

# Contas que ficam e têm uma pasta OneDrive com ficheiros (para avisar antes da confirmação)
$ContasComOneDrive = @()
if ($RemoverOneDrive) {
  $caminhosApagar = @($PlanoContas | Where-Object { $_.Caminho } | ForEach-Object { $_.Caminho.TrimEnd('\').ToLower() })
  foreach ($p in @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                   Where-Object { -not $_.Special -and $_.LocalPath -like "$env:SystemDrive\Users\*" })) {
    if ($caminhosApagar -contains $p.LocalPath.TrimEnd('\').ToLower()) { continue }
    $comFicheiros = @(Get-ChildItem -LiteralPath $p.LocalPath -Directory -Force -Filter 'OneDrive*' -ErrorAction SilentlyContinue |
      Where-Object { Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -ne 'desktop.ini' } | Select-Object -First 1 })
    if ($comFicheiros.Count -gt 0) { $ContasComOneDrive += (Split-Path $p.LocalPath -Leaf) }
  }
}

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '  OTIMIZAR PORTÁTIL — limpeza e otimização do Windows' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host "Versão do script: $VersaoScript"
Write-Host "Computador: $env:COMPUTERNAME"
Write-Host ''
Write-Host 'Vai ser apagado, em TODAS as contas deste computador:' -ForegroundColor Yellow
Write-Host "  - Transferências com mais de $DiasTransferencias dias"
Write-Host '  - Instaladores, jogos e arquivos (.exe, .zip, .rar, .iso…) nas Transferências'
Write-Host '  - Instaladores (.exe, .msi, .iso) na Área de Trabalho'
Write-Host '  - Jogos instalados pelos alunos (Roblox, Minecraft/TLauncher, Discord…)'
Write-Host '  - Ficheiros temporários, cache dos browsers e Reciclagem'
Write-Host '  Os ficheiros são apagados de vez (não vão para a Reciclagem).' -ForegroundColor Yellow
Write-Host ''
Write-Host "Daqui para a frente, o Windows apaga sozinho, em todas as contas, o que estiver"
Write-Host "nas Transferências há mais de $DiasLimpezaAutomatica dias."
Write-Host ''
Write-Host 'Nas contas que ficam, os Documentos, Imagens e os ficheiros da pasta OneDrive NÃO são tocados.' -ForegroundColor Green
if ($RemoverOneDrive) {
  Write-Host 'A aplicação OneDrive é desinstalada (os alunos usam o OneDrive na web, em office.com).'
  if ($ContasComOneDrive.Count -gt 0) {
    Write-Host ('ATENÇÃO: ' + ($ContasComOneDrive -join ', ') + ' tem/têm ficheiros na pasta OneDrive.') -ForegroundColor Yellow
    Write-Host '  Os ficheiros que estiverem só na nuvem (ícone de nuvem) deixam de abrir neste portátil;' -ForegroundColor Yellow
    Write-Host '  continuam disponíveis no OneDrive na web. Alterações ainda não sincronizadas ficam só no portátil.' -ForegroundColor Yellow
  }
}
Write-Host ''
if ($AvisoContas) { Write-Host $AvisoContas -ForegroundColor Yellow }
elseif ($ApagarOutrasContas -and $PlanoContas.Count -eq 0) { Write-Host ("Contas: só existem " + ($ContasManter -join ' e ') + '. Nenhuma conta vai ser apagada.') -ForegroundColor Green }
elseif ($PlanoContas.Count -gt 0) {
  Write-Host 'CONTAS QUE FICAM:' -ForegroundColor Green
  foreach ($cf in $ContasFicam) { Write-Host "  + $cf" -ForegroundColor Green }
  Write-Host 'CONTAS E PASTAS QUE VÃO SER APAGADAS:' -ForegroundColor Red
  foreach ($c in $PlanoContas) {
    $tipo = switch ($c.Tipo) { 'conta' { 'conta do Windows' } 'perfil' { 'pasta de outra conta' } 'apagada' { 'pasta de uma conta que já não existe' } default { 'pasta abandonada' } }
    $info = if ($c.Data) { "$(Tamanho ([double]$c.Bytes)), último uso $($c.Data)" } else { 'sem pasta' }
    Write-Host "  - $($c.Nome)  ($tipo; $info)" -ForegroundColor Red
    if ($c.Caminho) { Write-Host "      $($c.Caminho)" -ForegroundColor Red }
  }
  Write-Host '  TUDO o que estas contas têm é apagado, incluindo Documentos e Imagens.' -ForegroundColor Red
}
foreach ($mn in $MesmoNomeMantidas) {
  Write-Host "Mantida por ter o nome de uma conta que fica (não é apagada): $mn" -ForegroundColor Yellow
}
foreach ($c in $ContasEmUso) { Write-Host "A conta $($c.Nome) tem uma sessão aberta e não vai ser apagada (termine a sessão e volte a correr)." -ForegroundColor Yellow }
if ($ContasExcluidas.Count -gt 0) { Write-Host ('Contas excluídas: ' + ($ContasExcluidas -join ', ')) -ForegroundColor Green }
Write-Host ''
Write-Host ('Também instala ' + $(if ($InstalarOffice) { 'Microsoft Office, ' } else { '' }) + (($AppsInstalar | ForEach-Object { $_[1] }) -join ', ') + ' (precisa de internet).')
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

# ----------------------------- 1. APLICAÇÕES ---------------------------------

Passo '1/8 A remover aplicações desnecessárias'

$Provisionadas = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
$AppsPorRemover = @()
foreach ($a in $AppsRemover) {
  $removida = $false
  # Aplicações em "pacote" (bundle) têm de ser removidas pelo pacote, não pela parte principal
  $pacotes = @(Get-AppxPackage -AllUsers -PackageTypeFilter Bundle -Name $a -ErrorAction SilentlyContinue)
  if ($pacotes.Count -eq 0) { $pacotes = @(Get-AppxPackage -AllUsers -Name $a -ErrorAction SilentlyContinue) }
  foreach ($pk in $pacotes) {
    Marcar-Retirada $pk.PackageFamilyName
    try { Remove-AppxPackage -Package $pk.PackageFullName -AllUsers -ErrorAction Stop; $removida = $true }
    catch {
      # Falha típica logo a seguir a apagar contas ("um utilizador terminou sessão"): o Windows
      # ainda guarda a conta apagada. Remove-se então conta a conta, só nas contas que existem.
      $falhou = $false
      $tentativas = 0
      $infos = @($pk.PackageUserInformation)
      if ($infos.Count -eq 0) {
        # Nos pacotes "bundle" a lista de contas pode vir vazia: usa a do pacote principal
        $infos = @(Get-AppxPackage -AllUsers -Name $pk.Name -ErrorAction SilentlyContinue | ForEach-Object { $_.PackageUserInformation })
      }
      foreach ($ui in $infos) {
        $sidUi = $ui.UserSecurityId.Sid
        if (-not $sidUi) { continue }
        if (-not (Test-Path -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sidUi")) { continue }
        if ("$($ui.InstallState)" -ne 'Installed') { continue }
        $tentativas++
        try { Remove-AppxPackage -Package $pk.PackageFullName -User $sidUi -ErrorAction Stop } catch { $falhou = $true }
      }
      if ($falhou -or $tentativas -eq 0) { if ($AppsPorRemover -notcontains $pk.Name) { $AppsPorRemover += $pk.Name } }
      else { $removida = $true }
    }
  }
  $Provisionadas | Where-Object { $_.DisplayName -like $a } | ForEach-Object {
    Marcar-Retirada "$($_.DisplayName)_$($_.PublisherId)"
    try { Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName -AllUsers -ErrorAction Stop | Out-Null; $removida = $true } catch {}
  }
  if ($removida) { Ok "Removida: $a" }
}

# Programas do computador que não fazem falta (LibreOffice, paint.net, Lenovo…).
# O .NET fica para o fim: só sai depois de confirmar que nenhum programa que fica precisa dele.
$PadroesNet = @($ProgramasRemover | Where-Object { $_ -like 'Microsoft Windows Desktop Runtime*' })
foreach ($padrao in @($ProgramasRemover | Where-Object { $PadroesNet -notcontains $_ })) {
  foreach ($prog in @(Programas-Instalados | Where-Object { $_.DisplayName -like $padrao -and -not $_.SystemComponent })) {
    [void](Desinstalar-Programa $prog)
  }
}

# Que versões do .NET são usadas pelos programas que ficam? Cada programa que depende do .NET
# instalado no Windows tem um ficheiro *.runtimeconfig.json com a versão de que precisa.
# Os que trazem o seu próprio .NET ("includedFrameworks") não contam.
if ($PadroesNet.Count -gt 0) {
  Write-Host '    A verificar se algum programa precisa do .NET 5, 6 ou 7 (pode demorar um minuto)...'
  $PastasProgramas = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) +
    @(Get-ChildItem -LiteralPath (Join-Path $env:SystemDrive 'Users') -Directory -Force -ErrorAction SilentlyContinue |
      ForEach-Object { Join-Path $_.FullName 'AppData\Local\Programs' })
  $NetUsado = @{}   # versão principal -> programas que a usam
  foreach ($pasta in $PastasProgramas) {
    if (-not $pasta -or -not (Test-Path -LiteralPath $pasta)) { continue }
    foreach ($rc in @(Get-ChildItem -LiteralPath $pasta -Filter '*.runtimeconfig.json' -Recurse -File -Force -ErrorAction SilentlyContinue)) {
      if ($rc.FullName -like (Join-Path $pasta 'dotnet\*')) { continue }   # a própria pasta do .NET não conta
      try { $j = Get-Content -LiteralPath $rc.FullName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { continue }
      if (-not $j.runtimeOptions -or $j.runtimeOptions.includedFrameworks) { continue }
      $fws = @($j.runtimeOptions.framework) + @($j.runtimeOptions.frameworks) | Where-Object { $_ -and $_.version }
      # Com rollForward Major/LatestMajor o programa pode estar a usar uma versão mais recente
      $rf = "$($j.runtimeOptions.rollForward)"
      $prog = ($rc.FullName.Substring($pasta.Length).TrimStart('\') -split '\\')[0]
      foreach ($fw in $fws) {
        if ($fw.name -notmatch '^Microsoft\.(NETCore|WindowsDesktop)\.App$') { continue }
        $alvo = 0
        if (-not [int]::TryParse((($fw.version -split '\.')[0]), [ref]$alvo)) { continue }
        $majores = if ($rf -match '^(Major|LatestMajor)$' -and $alvo -lt 7) { $alvo..7 } else { @($alvo) }
        foreach ($m in $majores) {
          $k = "$m"
          if (-not $NetUsado.ContainsKey($k)) { $NetUsado[$k] = @() }
          if ($NetUsado[$k] -notcontains $prog) { $NetUsado[$k] += $prog }
        }
      }
    }
  }
  foreach ($padrao in $PadroesNet) {
    $maior = if ($padrao -match '- (\d+)\.') { $Matches[1] } else { $null }
    $entradas = @(Programas-Instalados | Where-Object { $_.DisplayName -like $padrao -and -not $_.SystemComponent })
    if ($entradas.Count -eq 0) { continue }
    if ($maior -and $NetUsado.ContainsKey($maior)) {
      Ok ".NET $maior mantido: é usado por $($NetUsado[$maior] -join ', ')"
      continue
    }
    foreach ($prog in $entradas) { [void](Desinstalar-Programa $prog) }
  }
}

if ($AppsPorRemover.Count -gt 0) {
  Aviso ('Ficaram por remover (reinicie e volte a correr o script): ' + ($AppsPorRemover -join ', '))
}

# Paint, Câmara e Teams: marcados como retirados mesmo que já não existam,
# para as atualizações do Windows não os voltarem a instalar
foreach ($nomePk in 'Microsoft.Paint', 'Microsoft.WindowsCamera', 'MSTeams', 'MicrosoftTeams') {
  Marcar-Retirada "$($nomePk)_8wekyb3d8bbwe"
}
# As Fotografias ficam: desfaz a marcação de uma versão anterior deste script, se existir
Remove-Item -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.Windows.Photos_8wekyb3d8bbwe' -Force -ErrorAction SilentlyContinue

# Teams clássico: o "Teams Machine-Wide Installer" volta a instalar o Teams em cada conta ao entrar
foreach ($chave in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                   'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
  Get-ItemProperty -Path $chave -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -eq 'Teams Machine-Wide Installer' -and $_.PSChildName -match '^\{[0-9A-Fa-f-]+\}$' } |
    ForEach-Object {
      $pr = Start-Process -FilePath msiexec.exe -ArgumentList '/x', $_.PSChildName, '/qn', '/norestart' -Wait -PassThru
      if ($pr.ExitCode -eq 0 -or $pr.ExitCode -eq 3010) { Ok 'Removido: Teams Machine-Wide Installer' }
      else { Aviso "Teams Machine-Wide Installer: a desinstalação terminou com o código $($pr.ExitCode)" }
    }
}

# Paint clássico (componente opcional em algumas versões do Windows)
try {
  Get-WindowsCapability -Online -ErrorAction Stop |
    Where-Object { $_.Name -like 'Microsoft.Windows.MSPaint*' -and $_.State -eq 'Installed' } |
    ForEach-Object { Remove-WindowsCapability -Online -Name $_.Name -ErrorAction Stop | Out-Null; Ok 'Removido: Paint clássico' }
} catch {}

# OneDrive: desinstala a aplicação (os ficheiros da pasta OneDrive de cada conta ficam)
if ($RemoverOneDrive) {
  Stop-Process -Name OneDrive, OneDriveSetup -Force -ErrorAction SilentlyContinue
  function Correr-Desinstalador([string]$exe, [string[]]$argumentos) {
    try {
      $pr = Start-Process -FilePath $exe -ArgumentList $argumentos -PassThru -ErrorAction Stop
      $null = $pr.Handle
      [void]$pr.WaitForExit(300000)   # no máximo 5 minutos
    } catch {}
  }
  # Instalação para todo o computador (Programas)
  $odMaquina = Get-ChildItem -Path "$env:ProgramFiles\Microsoft OneDrive", "${env:ProgramFiles(x86)}\Microsoft OneDrive" `
                 -Filter 'OneDriveSetup.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($odMaquina) { Correr-Desinstalador $odMaquina.FullName @('/uninstall', '/allusers') }
  # Instalação na conta que está a correr o script
  foreach ($odSetup in "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    if (Test-Path -LiteralPath $odSetup) { Correr-Desinstalador $odSetup @('/uninstall'); break }
  }
  # Nas outras contas: só a pasta do PROGRAMA (AppData\Local\Microsoft\OneDrive), nunca a dos ficheiros
  $bOd = [long]0
  foreach ($p in @(Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
                   Where-Object { -not $_.Special -and $_.LocalPath -like "$env:SystemDrive\Users\*" -and -not $_.Loaded })) {
    $bOd += Apagar-Pasta (Join-Path $p.LocalPath 'AppData\Local\Microsoft\OneDrive')
  }
  # Impede que o OneDrive volte a ser usado e tira-o do painel do Explorador de Ficheiros
  Definir-Registo 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
  foreach ($clsid in 'Registry::HKEY_CLASSES_ROOT\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}',
                     'Registry::HKEY_CLASSES_ROOT\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}') {
    if (Test-Path -LiteralPath $clsid) { Set-ItemProperty -LiteralPath $clsid -Name 'System.IsPinnedToNameSpaceTree' -Value 0 -ErrorAction SilentlyContinue }
  }
  Ok "Aplicação OneDrive desinstalada e desligada ($(Tamanho $bOd) libertados nas outras contas; nas contas com sessão aberta termina no próximo início de sessão)"
}

# ----------------------------- 2. CONTAS --------------------------------------

Passo '2/8 A apagar as contas e pastas que não são precisas'
[long]$ContasLibertado = 0
if ($AvisoContas) { Aviso $AvisoContas }
elseif (-not $ApagarOutrasContas) { Ok 'Apagar contas está desligado nas definições' }
elseif ($PlanoContas.Count -eq 0) { Ok ('Só existem as contas ' + ($ContasManter -join ' e ')) }
else {
  foreach ($c in $PlanoContas) {
    $antes = EspacoLivre
    if ($c.Perfil) {
      # Remove o perfil pelo Windows (apaga a pasta e o registo da conta)
      try { $c.Perfil | Remove-CimInstance -ErrorAction Stop }
      catch { Aviso "$($c.Nome): o Windows não removeu o perfil; a apagar a pasta diretamente" }
    }
    if ($c.Caminho -and (Test-Path -LiteralPath $c.Caminho)) { [void](Apagar-Pasta $c.Caminho) }
    if ($c.Tipo -eq 'conta') {
      try { Remove-LocalUser -SID $c.Sid -ErrorAction Stop }
      catch { Aviso "Não foi possível apagar a conta $($c.Nome): $(($_.Exception.Message -split "`n")[0])" }
    }
    [long]$libertado = [long](EspacoLivre) - [long]$antes
    if ($libertado -lt 0) { $libertado = 0 }
    $ContasLibertado += $libertado
    if ($c.Caminho -and (Test-Path -LiteralPath $c.Caminho)) {
      Aviso "$($c.Nome): ficaram ficheiros por apagar (em uso). Reinicie e volte a correr o script."
    } else { Ok "$($c.Nome) apagada ($(Tamanho $libertado) libertados)" }
  }
}

# ----------------------------- 3. FICHEIROS DOS ALUNOS -----------------------

Passo '3/8 A limpar os ficheiros das contas'

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

# ----------------------------- 4. SISTEMA ------------------------------------

Passo '4/8 A limpar o sistema'

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

# ----------------------------- 5. DEFINIÇÕES DO SISTEMA ----------------------

Passo '5/8 A desligar telemetria, sugestões e programas em segundo plano'

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
# Ícone do Chat/Teams na barra de tarefas do Windows 11 (3 = escondido)
Definir-Registo "$Pol\Windows\Windows Chat" 'ChatIcon' 3
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

# ----------------------------- 6. CONTAS (efeitos visuais e sugestões) ------

Passo '6/8 A aplicar definições de desempenho em todas as contas'

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

# Desinstalador do OneDrive por conta (System32 no Windows 11; SysWOW64 no Windows 10 de 64 bits)
$odSetupConta = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") |
  Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
function Aplicar-Conta([string]$raiz, [bool]$modelo = $false) {
  foreach ($d in $DefConta) { Definir-RegistoConta $raiz $d[0] $d[1] $d[2] $d[3] }
  # Desfaz uma alteração da primeira versão deste script
  & reg.exe delete "$raiz\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /f 2>&1 | Out-Null
  if ($RemoverOneDrive) {
    # OneDrive: tira o arranque automático e a instalação automática em contas novas
    & reg.exe delete "$raiz\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f 2>&1 | Out-Null
    & reg.exe delete "$raiz\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDriveSetup /f 2>&1 | Out-Null
    & reg.exe delete "$raiz\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" /f 2>&1 | Out-Null
    if (-not $modelo -and $odSetupConta) {
      # Desinstala o OneDrive desta conta no próximo início de sessão (o desinstalador só
      # consegue retirar a cópia da conta que o corre)
      & reg.exe add "$raiz\Software\Microsoft\Windows\CurrentVersion\RunOnce" /v DesinstalarOneDrive /t REG_SZ `
          /d "$odSetupConta /uninstall" /f 2>&1 | Out-Null
    }
  }
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
      Aplicar-Conta $tmp ($null -eq $h.Sid)
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

# ----------------------------- 7. APLICAÇÕES DAS AULAS -----------------------

Passo '7/8 A instalar as aplicações das aulas (TIC e CEA)'

$AppsFalharam = @()
$InstSoAdmin = @()
# Códigos do winget: sucesso, "já instalado" e "instalado, falta reiniciar"
$CodigosOk = @(0, -1978335189, -1978335135, -1978334967)
$SemInstaladorMaquina = -1978335216   # o pacote não tem instalação "para todos"
$WingetNaoArranca = -1073741515       # falta uma biblioteca do Windows ao winget

function Versao-Pasta($pasta) { try { return [version](($pasta.Name -split '_')[1]) } catch { return [version]'0.0' } }

$Winget = $null
$catalogo = $false
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
    if ($codigo -eq 0) {
      if ($id -eq 'Microsoft.Edge') { Ok "$nomeApp já estava instalado (atualiza-se sozinho)"; continue }
      # Já instalado: atualiza para a versão mais recente (as versões antigas têm falhas de segurança)
      & $Winget upgrade --id $id --exact --source winget --silent --accept-package-agreements --accept-source-agreements
      $cu = $LASTEXITCODE
      if ($cu -eq 0) { Ok "$nomeApp atualizado" }
      elseif ($CodigosOk -contains $cu -or $cu -eq -1978335212) { Ok "$nomeApp já estava atualizado" }
      else { Aviso "$($nomeApp): não foi possível atualizar (código $cu)" }
      continue
    }

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

# Microsoft Office
if ($InstalarOffice) {
  $c2r = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration' -ErrorAction SilentlyContinue
  $wordExe = @("$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE",
               "${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\WINWORD.EXE",
               "$env:ProgramFiles\Microsoft Office\Office16\WINWORD.EXE",
               "${env:ProgramFiles(x86)}\Microsoft Office\Office16\WINWORD.EXE") |
             Where-Object { Test-Path -LiteralPath $_ }
  if (($c2r -and $c2r.ProductReleaseIds) -or @($wordExe).Count -gt 0) {
    Ok 'Microsoft Office já estava instalado'
  } elseif (-not $Winget -or -not $catalogo) {
    $AppsFalharam += 'Microsoft Office'
  } elseif ((EspacoLivre) -lt $EspacoMinimoOffice) {
    $AppsFalharam += 'Microsoft Office'
    Aviso "Microsoft Office NÃO foi instalado: precisa de pelo menos $(Tamanho $EspacoMinimoOffice) livres e há $(Tamanho (EspacoLivre))."
    Aviso 'Desinstale programas grandes que não se usam (ver a lista no resumo) e volte a correr o script.'
  } else {
    $xmlOffice = Join-Path $PastaRegisto 'office-ptpt.xml'
    [IO.File]::WriteAllText($xmlOffice, $ConfigOffice, (New-Object Text.UTF8Encoding($false)))
    Write-Host '    A instalar o Microsoft Office em português (descarrega cerca de 3 GB; pode demorar 20-60 min)...'
    & $Winget install --id Microsoft.Office --exact --source winget --silent `
        --accept-package-agreements --accept-source-agreements --override "/configure $xmlOffice"
    $codigo = $LASTEXITCODE
    if ($CodigosOk -notcontains $codigo) {
      # Recurso: instalador oficial do Office (o do winget às vezes falha a verificação do ficheiro)
      Write-Host '    A tentar com o instalador oficial da Microsoft...'
      $setupOffice = Join-Path $PastaRegisto 'setup-office.exe'
      try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile $setupOffice -UseBasicParsing -ErrorAction Stop
        $pr = Start-Process -FilePath $setupOffice -ArgumentList '/configure', $xmlOffice -PassThru
        $null = $pr.Handle   # sem isto, o PowerShell 5.1 às vezes não devolve o código de saída
        $pr.WaitForExit()
        $codigo = $pr.ExitCode
      } catch { Aviso "Não foi possível descarregar o instalador oficial do Office: $(($_.Exception.Message -split "`n")[0])" }
    }
    if ($CodigosOk -contains $codigo) { Ok 'Microsoft Office instalado' }
    else { $AppsFalharam += 'Microsoft Office'; Aviso "Microsoft Office NÃO foi instalado (código $codigo; verifique a internet)" }
  }
}

# Versões antigas: só se desinstalam se a versão nova estiver instalada
$Reparar = @()
foreach ($va in $VersoesAntigas) {
  $instalados = @(Programas-Instalados)
  if (@($instalados | Where-Object { $_.DisplayName -like $va[1] }).Count -eq 0) { continue }   # a versão nova não está: não se toca na antiga
  foreach ($antigo in @($instalados | Where-Object { $_.DisplayName -like $va[0] })) {
    if (Desinstalar-Programa $antigo) { if ($Reparar -notcontains $va[2]) { $Reparar += $va[2] } }
  }
}
# A desinstalação da versão antiga pode levar atalhos ou associações de ficheiros que a nova
# também usava: reinstala a versão nova por cima para os repor
foreach ($idRep in $Reparar) {
  if (-not $Winget -or -not $catalogo) { Aviso "Não foi possível reparar $idRep (winget indisponível)"; continue }
  Write-Host "    A repor os atalhos de $idRep..."
  & $Winget install --id $idRep --exact --source winget --silent --force --scope machine `
      --accept-package-agreements --accept-source-agreements
  $codigo = $LASTEXITCODE
  if ($codigo -eq $SemInstaladorMaquina) {
    & $Winget install --id $idRep --exact --source winget --silent --force --accept-package-agreements --accept-source-agreements
    $codigo = $LASTEXITCODE
  }
  if ($CodigosOk -contains $codigo) { Ok "Reposto: $idRep" } else { Aviso "Não foi possível repor $idRep (código $codigo)" }
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

# ----------------------------- 8. RESUMO -------------------------------------

Passo '8/8 Resumo'
$LivreDepois = EspacoLivre
[long]$Ganho = [long]$LivreDepois - [long]$LivreAntes
if ($Ganho -lt 0) { $Ganho = 0 }
$Duracao = [int]((Get-Date) - $Inicio).TotalMinutes

Write-Host ''
Write-Host '============================================================' -ForegroundColor Green
Write-Host "  Concluído em $Duracao min — $env:COMPUTERNAME" -ForegroundColor Green
Write-Host "  Espaço livre antes:  $(Tamanho $LivreAntes)" -ForegroundColor Green
Write-Host "  Espaço livre depois: $(Tamanho $LivreDepois)  (+$(Tamanho $Ganho))" -ForegroundColor Green
Write-Host "  Contas e pastas apagadas: $(Tamanho $ContasLibertado)" -ForegroundColor Green
Write-Host "  Ficheiros das contas apagados: $(Tamanho $TotalContas)" -ForegroundColor Green
Write-Host "  Versão do script: $VersaoScript" -ForegroundColor Green
Write-Host "  Registo: $Registo" -ForegroundColor Green
Write-Host '============================================================' -ForegroundColor Green
if ($AppsFalharam.Count -gt 0) {
  Write-Host ''
  Write-Host ('Aplicações por instalar: ' + ($AppsFalharam -join ', ')) -ForegroundColor Yellow
  Write-Host 'Volte a correr o script com internet: só instala o que faltar.' -ForegroundColor Yellow
}
# Programas instalados que ocupam mais espaço (para decidir o que desinstalar)
$Programas = foreach ($chave in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                             'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*') {
  Get-ItemProperty -Path $chave -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -and $_.EstimatedSize -and -not $_.SystemComponent } |
    ForEach-Object { [pscustomobject]@{ Nome = $_.DisplayName; Bytes = [double]$_.EstimatedSize * 1KB } }
}
$Maiores = @($Programas | Sort-Object Bytes -Descending | Select-Object -First 10)
if ($Maiores.Count -gt 0) {
  Write-Host ''
  Write-Host 'Programas que ocupam mais espaço (Definições > Aplicações para desinstalar):'
  foreach ($m in $Maiores) { Write-Host ('  {0,9}  {1}' -f (Tamanho $m.Bytes), $m.Nome) }
}
if ($LivreDepois -lt 10GB) {
  Write-Host ''
  Write-Host "ATENÇÃO: só há $(Tamanho $LivreDepois) livres. Abaixo de 10 GB o Windows fica lento e não instala atualizações." -ForegroundColor Yellow
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
