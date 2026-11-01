# Installation de The Crea Lab sur PC, en une commande (dans PowerShell) :
#   irm https://raw.githubusercontent.com/Lacreacom/the-crea-lab-installation/main/install.ps1 | iex
# Le kit n'est pas en ligne : la cliente télécharge d'abord the-crea-lab.zip dans son espace payant,
# et ce script le trouve tout seul dans Téléchargements (le zip, ou le dossier déjà extrait).
# Tout va dans le dossier « The Crea Lab » du Bureau (Claude Code dans %USERPROFILE%\.local\bin).
# La relancer met le kit à jour sans toucher à ses vidéos, sa marque, ses scripts ni ses clés.

& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Telechargements = if ($env:CREALAB_TELECHARGEMENTS) { $env:CREALAB_TELECHARGEMENTS } else {
  try { (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path } catch { Join-Path $env:USERPROFILE 'Downloads' }
}
$Dossier = if ($env:CREALAB_DOSSIER) { $env:CREALAB_DOSSIER } else { Join-Path ([Environment]::GetFolderPath('Desktop')) 'The Crea Lab' }
$Outils = Join-Path $Dossier 'outils'
$Bin = Join-Path $Outils 'bin'
$LocalBin = Join-Path $env:USERPROFILE '.local\bin'
$Claude = Join-Path $LocalBin 'claude.exe'
$Tmp = Join-Path $env:TEMP "crealab-$(Get-Random)"
New-Item -ItemType Directory -Force $Tmp | Out-Null

function Dire($t) { Write-Host "`n> $t" -ForegroundColor Magenta }
function Ok($t) { Write-Host "  OK  $t" }
function Arreter($t) { Write-Host "`nX  $t`n" -ForegroundColor Red; throw $t }
function Telecharger($url, $vers) {
  try { Invoke-WebRequest -UseBasicParsing $url -OutFile $vers }
  catch { Arreter "Le téléchargement a échoué ($url). Vérifie ta connexion internet et relance la commande." }
}
function Connectee { try { (& $Claude auth status 2>$null | Out-String) -match '"loggedIn":\s*true' } catch { $false } }

try {
  Write-Host "`n The Crea Lab · installation (5 à 10 minutes)"
  $Arm = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'

  # ---------- 1. le kit ----------
  Dire '1/5 · Le kit'
  # le plus récent : un the-crea-lab*.zip, ou un dossier the-crea-lab* déjà extrait
  $Zip = Get-ChildItem $Telechargements -Filter 'the-crea-lab*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  $Ouvert = Get-ChildItem $Telechargements -Filter 'montage.mjs' -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'the-crea-lab[^\\]*\\(.*\\)?moteur\\montage\.mjs$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($env:CREALAB_ZIP) { Telecharger $env:CREALAB_ZIP "$Tmp\kit.zip"; $Zip = Get-Item "$Tmp\kit.zip"; $Ouvert = $null }
  if ($Zip -and (-not $Ouvert -or $Zip.LastWriteTime -ge $Ouvert.LastWriteTime)) {
    try { Expand-Archive $Zip.FullName "$Tmp\kit" -Force } catch { Arreter 'Le fichier the-crea-lab.zip est abîmé. Retélécharge-le dans ton espace The Crea Lab.' }
    $Src = (Get-ChildItem "$Tmp\kit" -Filter 'montage.mjs' -Recurse -File | Select-Object -First 1).Directory.Parent.FullName
  } elseif ($Ouvert) {
    $Src = $Ouvert.Directory.Parent.FullName
  } else {
    Arreter 'Je ne trouve pas le kit. Télécharge d''abord the-crea-lab.zip dans ton espace The Crea Lab (leçon « Installation »), puis relance la commande.'
  }
  if (-not $Src -or -not (Test-Path "$Src\CLAUDE.md")) { Arreter 'Le kit téléchargé est incomplet. Retélécharge-le dans ton espace The Crea Lab.' }
  if (Test-Path $Dossier) {
    # mise à jour : on remplace le programme, jamais ses fichiers à elle
    # le studio tourne peut-être encore avec l'ancienne version : on l'arrête, Claude le relancera
    try {
      Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*serveur.mjs*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch { }
    foreach ($x in 'moteur', 'studio', 'polices', 'CLAUDE.md', 'README.md', 'LICENCE.md', 'MENTIONS-TIERCES.md', 'package.json', 'produit.json', 'install.sh', 'install.ps1', 'codex.sh', 'codex.ps1') {
      if (Test-Path "$Src\$x") {
        Remove-Item -Recurse -Force "$Dossier\$x" -ErrorAction SilentlyContinue
        Copy-Item -Recurse "$Src\$x" "$Dossier\$x"
      }
    }
    New-Item -ItemType Directory -Force "$Dossier\.claude" | Out-Null
    Remove-Item -Recurse -Force "$Dossier\.claude\skills" -ErrorAction SilentlyContinue
    Copy-Item -Recurse "$Src\.claude\skills" "$Dossier\.claude\skills"
    if (Test-Path "$Src\.claude\settings.json") { Copy-Item -Force "$Src\.claude\settings.json" "$Dossier\.claude\settings.json" }
    Ok "kit mis à jour (tes vidéos, ta marque et tes clés n'ont pas bougé)"
  } else {
    Copy-Item -Recurse $Src $Dossier
    Ok "kit installé dans $Dossier"
  }
  foreach ($d in 'A-roll', 'projets', 'scripts', 'marques', 'reglages', 'B-roll', 'Musiques', 'Memes', 'Sons', 'outils\bin') {
    New-Item -ItemType Directory -Force (Join-Path $Dossier $d) | Out-Null
  }

  # ---------- 2. Node (fait tourner le studio et le moteur) ----------
  Dire '2/5 · Node'
  $Node = Get-Command node -ErrorAction SilentlyContinue
  if ($Node -and [int]((& node -v).TrimStart('v').Split('.')[0]) -ge 20) {
    Ok "déjà installé ($(& node -v))"
  } else {
    $Base = 'https://nodejs.org/dist/latest-v24.x'
    Telecharger "$Base/SHASUMS256.txt" "$Tmp\sommes.txt"
    $Arch = if ($Arm) { 'win-arm64' } else { 'win-x64' }
    $Ligne = Get-Content "$Tmp\sommes.txt" | Where-Object { $_ -match "$Arch\.zip$" } | Select-Object -First 1
    if (-not $Ligne) { Arreter 'Je ne trouve pas Node pour ce PC.' }
    $Somme, $Nom = $Ligne -split '\s+'
    Telecharger "$Base/$Nom" "$Tmp\node.zip"
    if ((Get-FileHash "$Tmp\node.zip" -Algorithm SHA256).Hash -ne $Somme.ToUpper()) { Arreter 'Le fichier Node est abîmé. Relance la commande.' }
    Expand-Archive "$Tmp\node.zip" "$Tmp\node" -Force
    Remove-Item -Recurse -Force "$Outils\node" -ErrorAction SilentlyContinue
    Move-Item (Get-ChildItem "$Tmp\node" -Directory | Select-Object -First 1).FullName "$Outils\node"
    Ok "installé dans le kit ($(& "$Outils\node\node.exe" -v))"
  }

  # ---------- 3. ffmpeg (le montage) et yt-dlp (les vidéos d'inspiration) ----------
  Dire '3/5 · Les outils de montage'
  $SousTitres = { (Test-Path "$Bin\ffmpeg.exe") -and ((& "$Bin\ffmpeg.exe" -hide_banner -filters 2>$null | Out-String) -match 'libass') }
  if ((& $SousTitres) -and (Test-Path "$Bin\ffprobe.exe")) {
    Ok 'ffmpeg déjà là'
  } else {
    Telecharger 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' "$Tmp\ffmpeg.zip"
    Expand-Archive "$Tmp\ffmpeg.zip" "$Tmp\ffmpeg" -Force
    foreach ($x in 'ffmpeg.exe', 'ffprobe.exe') {
      Copy-Item (Get-ChildItem "$Tmp\ffmpeg" -Recurse -Filter $x | Select-Object -First 1).FullName "$Bin\$x" -Force
    }
    if (-not (& $SousTitres)) { Arreter "ffmpeg est installé mais sans les sous-titres. Écris à Laura avec une capture de cet écran." }
    Ok 'ffmpeg installé'
  }
  if (-not (Test-Path "$Bin\yt-dlp.exe")) { Telecharger 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' "$Bin\yt-dlp.exe" }
  Ok 'yt-dlp prêt'

  # pour que Claude trouve node, ffmpeg et claude dans chaque nouvelle fenêtre
  $Chemins = @($Bin, "$Outils\node", $LocalBin)
  $Actuel = [Environment]::GetEnvironmentVariable('Path', 'User')
  $Manque = $Chemins | Where-Object { ($Actuel -split ';') -notcontains $_ }
  if ($Manque) { [Environment]::SetEnvironmentVariable('Path', (@($Manque) + @($Actuel -split ';' | Where-Object { $_ })) -join ';', 'User') }
  $env:Path = ($Chemins -join ';') + ';' + $env:Path

  # ---------- 4. Claude Code (LOU écrit tes hooks et ta légende toute seule) ----------
  Dire '4/5 · Claude Code'
  # sur PC, Claude Code a besoin de Git (gratuit)
  if (-not (Get-Command git -ErrorAction SilentlyContinue) -and -not (Test-Path "$env:ProgramFiles\Git\bin\bash.exe")) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { Arreter "Il manque Git. Installe-le depuis https://git-scm.com/download/win puis relance la commande." }
    Write-Host '  Installation de Git (si Windows te demande l''autorisation, clique sur Oui)…'
    winget install --id Git.Git -e --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Null
    Ok 'Git installé'
  }
  if (Test-Path $Claude) {
    Ok 'déjà installé'
  } else {
    try { Invoke-RestMethod https://claude.ai/install.ps1 | Invoke-Expression | Out-Null } catch { Arreter "L'installation de Claude Code a échoué. Relance la commande." }
    if (-not (Test-Path $Claude)) { Arreter 'Claude Code ne s''est pas installé. Relance la commande.' }
    Ok 'installé'
  }

  # ---------- 5. la connexion à son compte Claude ----------
  Dire '5/5 · Ton compte Claude'
  if (Connectee) {
    Ok 'déjà connectée'
  } else {
    Write-Host "  Une page va s'ouvrir dans ton navigateur."
    Write-Host '  Connecte-toi avec le compte de ton abonnement Claude, puis clique sur « Autoriser ».'
    Write-Host "  Si on te donne un code, copie-le et colle-le ici, puis appuie sur Entrée.`n"
    & $Claude auth login
    if (-not (Connectee)) { Arreter 'La connexion n''a pas abouti. Relance la commande : tout ce qui est déjà installé sera gardé.' }
    Ok 'connectée'
  }

  Write-Host "`nC'est installé !`n" -ForegroundColor Green
  Write-Host '  Ouvre l''application Claude, onglet « Code », choisis le dossier « The Crea Lab »'
  Write-Host "  et écris : « Ouvre mon studio ».`n"
  Start-Process explorer.exe $Dossier
} finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}
}
