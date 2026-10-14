#!/usr/bin/env bash
# =============================================================================
# install.sh : installe Mini Dash au démarrage (Raspberry Pi OS Lite, EGLFS)
#
# Usage (depuis le dossier du projet) :
#   sudo ./install.sh                  installation complète
#   sudo ./install.sh --quiet-boot     + masque les messages de démarrage
#   sudo ./install.sh --console-boot   + force le boot en mode console
#   sudo ./install.sh --uninstall      retire le service et la règle sudo
#
# Options : --user NOM  --dir CHEMIN  --entry src/main.py  --no-deps
# =============================================================================
set -euo pipefail

SERVICE_NAME="minidash"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_USER="${SUDO_USER:-}"
ENTRY="src/main.py"
QUIET_BOOT=0
CONSOLE_BOOT=0
UNINSTALL=0
INSTALL_DEPS=1

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SUDOERS_FILE="/etc/sudoers.d/${SERVICE_NAME}"

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

# --- Arguments ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)         APP_USER="${2:?valeur manquante}"; shift 2 ;;
        --dir)          APP_DIR="$(cd "${2:?valeur manquante}" && pwd)"; shift 2 ;;
        --entry)        ENTRY="${2:?valeur manquante}"; shift 2 ;;
        --quiet-boot)   QUIET_BOOT=1; shift ;;
        --console-boot) CONSOLE_BOOT=1; shift ;;
        --no-deps)      INSTALL_DEPS=0; shift ;;
        --uninstall)    UNINSTALL=1; shift ;;
        -h|--help)      sed -n '2,13p' "$0"; exit 0 ;;
        *)              die "Option inconnue : $1" ;;
    esac
done

[[ $EUID -eq 0 ]] || die "Lancez ce script avec sudo."

# --- Désinstallation ---------------------------------------------------------
if [[ $UNINSTALL -eq 1 ]]; then
    log "Arrêt et suppression du service"
    systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null || true
    rm -f "$UNIT_FILE" "$SUDOERS_FILE"
    systemctl daemon-reload
    log "Terminé. Les paquets, le venv et les groupes ne sont pas modifiés."
    exit 0
fi

# --- Vérifications -----------------------------------------------------------
[[ -n "$APP_USER" && "$APP_USER" != "root" ]] \
    || die "Utilisateur introuvable : relancez avec --user NOM (pas root)."
id "$APP_USER" >/dev/null 2>&1 || die "L'utilisateur '$APP_USER' n'existe pas."
[[ -f "$APP_DIR/$ENTRY" ]] || die "Fichier $APP_DIR/$ENTRY introuvable."
# Dossier de travail = dossier du script (comme l'ancien launcher.sh : cd src)
WORK_DIR="$(dirname "$APP_DIR/$ENTRY")"

log "Utilisateur : $APP_USER"
log "Dossier     : $APP_DIR"
log "Programme   : $ENTRY"
log "Travail     : $WORK_DIR"

# --- 1. Dépendances système --------------------------------------------------
if [[ $INSTALL_DEPS -eq 1 ]]; then
    log "Installation des paquets système"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y \
        python3-venv python3-pip python3-gpiozero python3-lgpio \
        libegl1 libgles2 libgbm1 libdrm2 libinput10 libxkbcommon0 \
        libfontconfig1 libdbus-1-3 fonts-dejavu-core

    # PySide6 packagé par Debian (inclut EGLFS) : facultatif, on essaie sans bloquer
    for pkg in python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml \
               python3-pyside6.qtquick python3-pyside6.qtsvg; do
        apt-get install -y "$pkg" 2>/dev/null || warn "Paquet $pkg indisponible (ignoré)"
    done
fi

# --- 2. Environnement Python -------------------------------------------------
VENV="$APP_DIR/venv"
if [[ ! -x "$VENV/bin/python" ]]; then
    log "Création du venv (avec accès aux paquets système)"
    sudo -u "$APP_USER" python3 -m venv --system-site-packages "$VENV"
fi

REQ_FILE="$APP_DIR/requirements.txt"
if [[ -f "$REQ_FILE" ]]; then
    REQ_TMP="$(mktemp)"
    if sudo -u "$APP_USER" "$VENV/bin/python" -c "import PySide6" 2>/dev/null; then
        # PySide6 Debian déjà présent (avec EGLFS) : on évite de le masquer par la version pip
        log "PySide6 système détecté : ignoré dans requirements.txt"
        grep -viE '^\s*pyside6' "$REQ_FILE" > "$REQ_TMP" || true
    else
        cp "$REQ_FILE" "$REQ_TMP"
    fi
    chmod 644 "$REQ_TMP"
    log "Installation de requirements.txt"
    sudo -u "$APP_USER" "$VENV/bin/pip" install -r "$REQ_TMP" \
        || warn "Certaines dépendances de requirements.txt ont échoué (voir ci-dessus)"
    rm -f "$REQ_TMP"
fi

# Filet de sécurité si requirements.txt est incomplet
if ! sudo -u "$APP_USER" "$VENV/bin/python" -c "import PySide6" 2>/dev/null; then
    log "Installation de PySide6 via pip"
    sudo -u "$APP_USER" "$VENV/bin/pip" install PySide6
fi
if ! sudo -u "$APP_USER" "$VENV/bin/python" -c "import gpiozero" 2>/dev/null; then
    log "Installation de gpiozero via pip"
    sudo -u "$APP_USER" "$VENV/bin/pip" install gpiozero
fi

# Le dossier data doit rester inscriptible (kilometers.csv)
mkdir -p "$APP_DIR/data"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR/data"

# --- 3. Accès matériel -------------------------------------------------------
log "Ajout de $APP_USER aux groupes video, render, input, gpio"
for grp in video render input gpio; do
    getent group "$grp" >/dev/null && usermod -aG "$grp" "$APP_USER" \
        || warn "Groupe $grp absent (ignoré)"
done

# --- 4. Droits sudo pour shutdown / reboot -----------------------------------
log "Configuration de sudo (extinction et redémarrage uniquement)"
PATH="$PATH:/usr/sbin:/sbin"
cmd_path() { command -v "$1" 2>/dev/null || true; }
POWEROFF="$(cmd_path poweroff)"
REBOOT="$(cmd_path reboot)"
SHUTDOWN="$(cmd_path shutdown)"
[[ -n "$POWEROFF" && -n "$REBOOT" && -n "$SHUTDOWN" ]] \
    || die "Commandes poweroff/reboot/shutdown introuvables."

TMP_SUDOERS="$(mktemp)"
cat > "$TMP_SUDOERS" <<EOF
# Généré par install.sh : Mini Dash peut éteindre / redémarrer le système
Cmnd_Alias MINIDASH_POWER = ${POWEROFF}, ${REBOOT}, ${SHUTDOWN} -h now, ${SHUTDOWN} -r now
${APP_USER} ALL=(root) NOPASSWD: MINIDASH_POWER
EOF
visudo -cf "$TMP_SUDOERS" >/dev/null || { rm -f "$TMP_SUDOERS"; die "Règle sudoers invalide."; }
install -m 0440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"

# --- 5. Configuration de démarrage (KMS) -------------------------------------
CONFIG_TXT="/boot/firmware/config.txt"
[[ -f "$CONFIG_TXT" ]] || CONFIG_TXT="/boot/config.txt"
if [[ -f "$CONFIG_TXT" ]]; then
    if ! grep -Eq '^\s*dtoverlay=vc4-(f)?kms-v3d' "$CONFIG_TXT"; then
        log "Activation du driver graphique KMS dans $CONFIG_TXT"
        cp -n "$CONFIG_TXT" "${CONFIG_TXT}.bak-${SERVICE_NAME}"
        printf '\n[all]\ndtoverlay=vc4-kms-v3d\n' >> "$CONFIG_TXT"
    fi
else
    warn "config.txt introuvable : vérifiez le driver KMS à la main."
fi

if [[ $QUIET_BOOT -eq 1 ]]; then
    CMDLINE="/boot/firmware/cmdline.txt"
    [[ -f "$CMDLINE" ]] || CMDLINE="/boot/cmdline.txt"
    if [[ -f "$CMDLINE" ]]; then
        log "Masquage des messages de démarrage"
        cp -n "$CMDLINE" "${CMDLINE}.bak-${SERVICE_NAME}"
        for flag in quiet loglevel=3 logo.nologo vt.global_cursor_default=0; do
            grep -qw -- "$flag" "$CMDLINE" || sed -i "1 s|\$| ${flag}|" "$CMDLINE"
        done
    fi
fi

if [[ $CONSOLE_BOOT -eq 1 ]]; then
    log "Démarrage en mode console"
    systemctl set-default multi-user.target
fi

# --- 6. Service systemd ------------------------------------------------------
log "Création du service $SERVICE_NAME"
cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Mini Dash
After=local-fs.target systemd-user-sessions.service

[Service]
Type=simple
User=${APP_USER}
SupplementaryGroups=video render input gpio
WorkingDirectory=${WORK_DIR}
Environment=QT_QPA_PLATFORM=eglfs
Environment=QT_QPA_EGLFS_ALWAYS_SET_MODE=1
ExecStart=${VENV}/bin/python ${APP_DIR}/${ENTRY}
Restart=on-failure
RestartSec=3
# Pas de NoNewPrivileges : l'app doit pouvoir appeler sudo (extinction)

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service"
systemctl restart "${SERVICE_NAME}.service" || warn "Démarrage immédiat échoué : voir journalctl -u ${SERVICE_NAME}"

log "Installation terminée."
cat <<EOF

  Logs        : journalctl -u ${SERVICE_NAME} -f
  Redémarrer  : sudo systemctl restart ${SERVICE_NAME}
  Arrêter     : sudo systemctl stop ${SERVICE_NAME}
  Désinstaller: sudo ./install.sh --uninstall

  Un redémarrage est conseillé pour prendre en compte les nouveaux groupes
  et la configuration graphique :  sudo reboot
EOF