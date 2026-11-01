# Bonus The Crea Lab sur PC : installe Codex (tes images et tes mèmes), en une commande (dans PowerShell) :
#   irm https://raw.githubusercontent.com/Lacreacom/the-crea-lab-installation/main/codex.ps1 | iex
# Il faut un abonnement ChatGPT payant. Codex va dans le dossier « The Crea Lab » (outils\codex).

& {
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Dossier = if ($env:CREALAB_DOSSIER) { $env:CREALAB_DOSSIER } else { Join-Path ([Environment]::GetFolderPath('Desktop')) 'The Crea Lab' }
$Outils = Join-Path $Dossier 'outils'
$Codex = Join-Path $Outils 'codex\codex.cmd'

function Dire($t) { Write-Host "`n> $t" -ForegroundColor Magenta }
function Ok($t) { Write-Host "  OK  $t" }
function Arreter($t) { Write-Host "`nX  $t`n" -ForegroundColor Red; throw $t }
function Connectee { try { (& $Codex login status 2>&1 | Out-String) -match '(?m)^\s*Logged in' } catch { $false } }

if (-not (Test-Path (Join-Path $Dossier 'moteur'))) { Arreter 'Je ne trouve pas ton dossier « The Crea Lab » sur le Bureau. Installe d''abord le kit (étapes 1 et 2 du tuto).' }
$env:Path = "$Outils\node;$Outils\bin;" + $env:Path
if (-not (Get-Command npm.cmd -ErrorAction SilentlyContinue)) { Arreter 'Il manque un outil du kit. Relance d''abord la commande d''installation du kit, puis celle-ci.' }

Write-Host "`n The Crea Lab · bonus Codex (2 minutes)"

# ---------- 1. Codex ----------
Dire '1/2 · Codex'
if (Test-Path $Codex) {
  Ok 'déjà installé'
} else {
  try { & npm.cmd install -g '@openai/codex' --prefix "$Outils\codex" --no-fund --no-audit --loglevel=error 2>&1 | Out-Null } catch { }
  if (-not (Test-Path $Codex)) { Arreter 'L''installation de Codex a échoué. Vérifie ta connexion internet et relance la commande.' }
  Ok 'installé'
}

# ---------- 2. la connexion à son compte ChatGPT ----------
Dire '2/2 · Ton compte ChatGPT'
if (Connectee) {
  Ok 'déjà connectée'
} else {
  Write-Host "  Une page va s'ouvrir dans ton navigateur."
  Write-Host "  Connecte-toi avec le compte de ton abonnement ChatGPT, puis autorise Codex.`n"
  & $Codex login
  if (-not (Connectee)) { Arreter 'La connexion n''a pas abouti. Relance la commande : Codex est déjà installé, il ne reste que la connexion.' }
  Ok 'connectée'
}

Write-Host "`nC'est prêt !`n" -ForegroundColor Green
Write-Host '  Dans Claude, dis par exemple : « Ajoute une image de ma tasse de café sur la phrase 6 »'
Write-Host "  ou « Mets un mème de chat surpris, en petit ».`n"
}
