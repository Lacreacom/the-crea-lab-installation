#!/bin/bash
# Installation de The Crea Lab sur Mac, en une commande (dans le Terminal) :
#   curl -fsSL https://raw.githubusercontent.com/Lacreacom/the-crea-lab-installation/main/install.sh | bash
# Le kit n'est pas en ligne : la cliente télécharge d'abord the-crea-lab.zip dans son espace payant,
# et ce script le trouve tout seul dans Téléchargements (le zip, ou le dossier que Safari a déjà ouvert).
# Aucun mot de passe : tout va dans le dossier « The Crea Lab » (Claude Code dans ~/.local/bin).
# La relancer met le kit à jour sans toucher à ses vidéos, sa marque, ses scripts ni ses clés.
set -euo pipefail

# tout est dans une fonction : avec « curl | bash », le script est lu en entier avant de démarrer
main() {

TELECHARGEMENTS="${CREALAB_TELECHARGEMENTS:-$HOME/Downloads}"
DOSSIER="${CREALAB_DOSSIER:-$HOME/Desktop/The Crea Lab}"
PROFILS="${CREALAB_PROFILS:-$HOME/.zshrc $HOME/.zprofile $HOME/.bash_profile}"
OUTILS="$DOSSIER/outils"
CLAUDE="$HOME/.local/bin/claude"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

dire() { printf '\n\033[1;35m✦ %s\033[0m\n' "$1"; }
ok() { printf '  ✓ %s\n' "$1"; }
stop() { printf '\n\033[1;31m✗ %s\033[0m\n\n' "$1"; exit 1; }
telecharger() { curl -fsSL --retry 3 "$1" -o "$2" || stop "Le téléchargement a échoué ($1). Vérifie ta connexion internet et relance la commande."; }

[ "$(uname)" = Darwin ] || stop "Cette commande est pour Mac. Sur PC, utilise celle du tuto pour Windows."
case "$(uname -m)" in arm64) PUCE=arm64; NODE_ARCH=arm64 ;; *) PUCE=amd64; NODE_ARCH=x64 ;; esac

printf '\n\033[1m The Crea Lab · installation\033[0m (5 à 10 minutes)\n'

# ---------- 1. le kit ----------
dire "1/5 · Le kit"
# le plus récent des the-crea-lab*.zip, ou des dossiers the-crea-lab* déjà ouverts
plus_recent() { local m=0 r="" f t; while IFS= read -r -d '' f; do t=$(stat -f %m "$f"); if [ "$t" -gt "$m" ]; then m=$t; r=$f; fi; done; printf '%s\t%s' "$m" "$r"; }
Z="$(find "$TELECHARGEMENTS" -maxdepth 1 -iname 'the-crea-lab*.zip' -print0 2>/dev/null | plus_recent)"
O="$(find "$TELECHARGEMENTS" -maxdepth 3 -ipath '*the-crea-lab*/moteur/montage.mjs' -print0 2>/dev/null | plus_recent)"
if [ -n "${CREALAB_ZIP:-}" ]; then
  telecharger "$CREALAB_ZIP" "$TMP/kit.zip"; Z="1	$TMP/kit.zip"; O="0	"
fi
if [ -n "${Z#*	}" ] && [ "${Z%%	*}" -ge "${O%%	*}" ]; then
  ditto -x -k "${Z#*	}" "$TMP/kit" || stop "Le fichier the-crea-lab.zip est abîmé. Retélécharge-le dans ton espace The Crea Lab."
  SRC="$(dirname "$(find "$TMP/kit" -maxdepth 3 -path '*/moteur/montage.mjs' | head -1)")"; SRC="$(dirname "$SRC")"
elif [ -n "${O#*	}" ]; then
  SRC="$(dirname "$(dirname "${O#*	}")")"
else
  stop "Je ne trouve pas le kit. Télécharge d'abord the-crea-lab.zip dans ton espace The Crea Lab (leçon « Installation »), puis relance la commande."
fi
[ -f "$SRC/CLAUDE.md" ] || stop "Le kit téléchargé est incomplet. Retélécharge-le dans ton espace The Crea Lab."
if [ -d "$DOSSIER" ]; then
  # mise à jour : on remplace le programme, jamais ses fichiers à elle
  for x in moteur studio polices CLAUDE.md README.md LICENCE.md MENTIONS-TIERCES.md package.json produit.json install.sh install.ps1; do
    if [ -e "$SRC/$x" ]; then rm -rf "${DOSSIER:?}/$x"; cp -R "$SRC/$x" "$DOSSIER/$x"; fi
  done
  mkdir -p "$DOSSIER/.claude"; rm -rf "$DOSSIER/.claude/skills"; cp -R "$SRC/.claude/skills" "$DOSSIER/.claude/skills"
  [ -f "$SRC/.claude/settings.json" ] && cp "$SRC/.claude/settings.json" "$DOSSIER/.claude/settings.json"
  ok "kit mis à jour (tes vidéos, ta marque et tes clés n'ont pas bougé)"
else
  mkdir -p "$(dirname "$DOSSIER")"
  cp -R "$SRC" "$DOSSIER"
  ok "kit installé dans $DOSSIER"
fi
for d in A-roll "A-roll/Vidéo 1" "A-roll/Vidéo 2" "A-roll/Vidéo 3" "A-roll/Vidéo 4" projets scripts marques reglages B-roll Musiques Memes Sons "outils/bin"; do mkdir -p "$DOSSIER/$d"; done

# ---------- 2. Node (fait tourner le studio et le moteur) ----------
dire "2/5 · Node"
if command -v node >/dev/null && node -e 'process.exit(+process.versions.node.split(".")[0] >= 20 ? 0 : 1)'; then
  ok "déjà installé ($(node -v))"
else
  BASE="https://nodejs.org/dist/latest-v24.x"
  telecharger "$BASE/SHASUMS256.txt" "$TMP/sommes.txt"
  LIGNE="$(grep "darwin-$NODE_ARCH.tar.gz$" "$TMP/sommes.txt" | head -1)"
  [ -n "$LIGNE" ] || stop "Je ne trouve pas Node pour ce Mac."
  telecharger "$BASE/${LIGNE##* }" "$TMP/node.tgz"
  (cd "$TMP" && echo "${LIGNE%% *}  node.tgz" | shasum -a 256 -c - >/dev/null) || stop "Le fichier Node est abîmé. Relance la commande."
  rm -rf "$OUTILS/node"; mkdir -p "$OUTILS/node"
  tar -xzf "$TMP/node.tgz" -C "$OUTILS/node" --strip-components 1
  ok "installé dans le kit ($("$OUTILS/node/bin/node" -v))"
fi

# ---------- 3. ffmpeg (le montage) et yt-dlp (les vidéos d'inspiration) ----------
dire "3/5 · Les outils de montage"
sous_titres() { [ -x "$OUTILS/bin/ffmpeg" ] && "$OUTILS/bin/ffmpeg" -hide_banner -filters 2>/dev/null | grep libass >/dev/null; }
if sous_titres && [ -x "$OUTILS/bin/ffprobe" ]; then
  ok "ffmpeg déjà là"
else
  for x in ffmpeg ffprobe; do
    telecharger "https://ffmpeg.martin-riedl.de/redirect/latest/macos/$PUCE/release/$x.zip" "$TMP/$x.zip"
    ditto -x -k "$TMP/$x.zip" "$OUTILS/bin"
  done
  chmod +x "$OUTILS/bin/ffmpeg" "$OUTILS/bin/ffprobe"
  xattr -dr com.apple.quarantine "$OUTILS/bin" 2>/dev/null || true
  sous_titres || stop "ffmpeg est installé mais sans les sous-titres. Écris à Laura avec une capture de cet écran."
  ok "ffmpeg installé"
fi
if [ ! -x "$OUTILS/bin/yt-dlp" ]; then
  telecharger "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos" "$OUTILS/bin/yt-dlp"
  chmod +x "$OUTILS/bin/yt-dlp"; xattr -d com.apple.quarantine "$OUTILS/bin/yt-dlp" 2>/dev/null || true
fi
ok "yt-dlp prêt"

# pour que Claude trouve node, ffmpeg et claude dans chaque nouvelle fenêtre
for f in $PROFILS; do
  touch "$f"
  grep -q '# The Crea Lab' "$f" || printf '\n# The Crea Lab\nexport PATH="%s/bin:%s/node/bin:$HOME/.local/bin:$PATH"\n' "$OUTILS" "$OUTILS" >> "$f"
done
export PATH="$OUTILS/bin:$OUTILS/node/bin:$HOME/.local/bin:$PATH"

# ---------- 4. Claude Code (LOU écrit tes hooks et ta légende toute seule) ----------
dire "4/5 · Claude Code"
if [ -x "$CLAUDE" ]; then
  ok "déjà installé"
else
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || stop "L'installation de Claude Code a échoué. Relance la commande."
  [ -x "$CLAUDE" ] || stop "Claude Code ne s'est pas installé. Relance la commande."
  ok "installé"
fi

# ---------- 5. la connexion à son compte Claude ----------
dire "5/5 · Ton compte Claude"
if "$CLAUDE" auth status </dev/null 2>/dev/null | grep -Eq '"loggedIn": *true'; then
  ok "déjà connectée"
else
  printf '  Une page va s'"'"'ouvrir dans ton navigateur.\n  Connecte-toi avec le compte de ton abonnement Claude, puis clique sur « Autoriser ».\n  Si on te donne un code, copie-le et colle-le ici, puis appuie sur Entrée.\n\n'
  "$CLAUDE" auth login < /dev/tty || stop "La connexion n'a pas abouti. Relance la commande : tout ce qui est déjà installé sera gardé."
  "$CLAUDE" auth status </dev/null 2>/dev/null | grep -Eq '"loggedIn": *true' || stop "La connexion n'a pas abouti. Relance la commande."
  ok "connectée"
fi

printf '\n\033[1;32m✓ C'"'"'est installé !\033[0m\n\n'
printf '  Ouvre l'"'"'application Claude, onglet « Code », choisis le dossier « The Crea Lab »\n'
printf '  et écris : « Ouvre mon studio ».\n\n'
open "$DOSSIER" 2>/dev/null || true
}

main "$@"
