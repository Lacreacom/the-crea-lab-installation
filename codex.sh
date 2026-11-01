#!/bin/bash
# Bonus The Crea Lab sur Mac : installe Codex (tes images et tes mèmes), en une commande (dans le Terminal) :
#   curl -fsSL https://raw.githubusercontent.com/Lacreacom/the-crea-lab-installation/main/codex.sh | bash
# Il faut un abonnement ChatGPT payant. Codex va dans le dossier « The Crea Lab » (outils/codex), sans mot de passe.
set -euo pipefail

# tout est dans une fonction : avec « curl | bash », le script est lu en entier avant de démarrer
main() {

DOSSIER="${CREALAB_DOSSIER:-$HOME/Desktop/The Crea Lab}"
OUTILS="$DOSSIER/outils"
CODEX="$OUTILS/codex/bin/codex"

dire() { printf '\n\033[1;35m✦ %s\033[0m\n' "$1"; }
ok() { printf '  ✓ %s\n' "$1"; }
stop() { printf '\n\033[1;31m✗ %s\033[0m\n\n' "$1"; exit 1; }
connectee() { "$CODEX" login status </dev/null 2>&1 | grep -i '^logged in' >/dev/null; }

[ "$(uname)" = Darwin ] || stop "Cette commande est pour Mac. Sur PC, utilise celle du tuto pour Windows."
[ -d "$DOSSIER/moteur" ] || stop "Je ne trouve pas ton dossier « The Crea Lab » sur le Bureau. Installe d'abord le kit (étapes 1 et 2 du tuto)."
export PATH="$OUTILS/node/bin:$OUTILS/bin:$PATH"
command -v npm >/dev/null || stop "Il manque un outil du kit. Relance d'abord la commande d'installation du kit, puis celle-ci."

printf '\n\033[1m The Crea Lab · bonus Codex\033[0m (2 minutes)\n'

# ---------- 1. Codex ----------
dire "1/2 · Codex"
if [ -x "$CODEX" ]; then
  ok "déjà installé"
else
  npm install -g @openai/codex --prefix "$OUTILS/codex" --no-fund --no-audit --loglevel=error >/dev/null 2>&1 \
    || stop "L'installation de Codex a échoué. Vérifie ta connexion internet et relance la commande."
  [ -x "$CODEX" ] || stop "Codex ne s'est pas installé. Relance la commande."
  ok "installé"
fi

# ---------- 2. la connexion à son compte ChatGPT ----------
dire "2/2 · Ton compte ChatGPT"
if connectee; then
  ok "déjà connectée"
else
  printf '  Une page va s'"'"'ouvrir dans ton navigateur.\n  Connecte-toi avec le compte de ton abonnement ChatGPT, puis autorise Codex.\n\n'
  "$CODEX" login < /dev/tty || stop "La connexion n'a pas abouti. Relance la commande : Codex est déjà installé, il ne reste que la connexion."
  connectee || stop "La connexion n'a pas abouti. Relance la commande."
  ok "connectée"
fi

printf '\n\033[1;32m✓ C'"'"'est prêt !\033[0m\n\n'
printf '  Dans Claude, dis par exemple : « Ajoute une image de ma tasse de café sur la phrase 6 »\n'
printf '  ou « Mets un mème de chat surpris, en petit ».\n\n'
}

main "$@"
