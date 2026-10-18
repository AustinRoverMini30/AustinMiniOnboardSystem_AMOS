#!/usr/bin/env bash
# =============================================================================
# install.sh : installe Mini Dash / AMOS au démarrage (Raspberry Pi OS, EGLFS)
#
# Usage (depuis la racine du projet) :
#   sudo ./install.sh                      installation (choix du mode proposé)
#   sudo ./install.sh --mode apt|pip       choix du mode sans question
#   sudo ./install.sh --rollback           annule la DERNIÈRE exécution d'install.sh
#   sudo ./install.sh --uninstall          retire simplement le service et la règle sudo
#
# Modes de dépendances :
#   apt  venv + paquets Debian (PySide6, gpiozero, lgpio) : rendu EGLFS/GPU  (recommandé)
#   pip  venv isolé, tout via pip (PySide6 compris) : EGLFS seulement si les
#        roues pip le fournissent, sinon rendu linuxfb (sans accélération GPU)
#
# Options : --user NOM  --dir CHEMIN  --entry src/main.py  --no-deps
#           --qt-platform eglfs|linuxfb|xcb   --quiet-boot  --console-boot
#           --keep-on-failure   (désactive l'annulation automatique en cas d'échec)
#           --drm-device /dev/dri/cardN   (force la carte graphique pour EGLFS)
#           --debug             (logs Qt détaillés dans journalctl)
# =============================================================================
set -euo pipefail

SERVICE_NAME="minidash"
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_USER="${SUDO_USER:-}"
ENTRY="src/main.py"
MODE=""
QT_PLATFORM=""
QUIET_BOOT=0
CONSOLE_BOOT=0
UNINSTALL=0
ROLLBACK=0
INSTALL_DEPS=1
AUTO_ROLLBACK=1
DRM_DEVICE=""
DEBUG_QT=0
SERVICE_OK=1

UNIT_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
SUDOERS_FILE="/etc/sudoers.d/${SERVICE_NAME}"
STATE_DIR="/var/lib/${SERVICE_NAME}"
STATE_FILE="${STATE_DIR}/state"
BACKUP_DIR="${STATE_DIR}/backup"

INSTALL_STARTED=0
INSTALL_DONE=0

log()  { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

usage() { sed -n '2,/^# =====/p' "${BASH_SOURCE[0]}" | sed '/^# =====/d; s/^# \{0,1\}//'; }

# --- Arguments ---------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --user)            APP_USER="${2:?valeur manquante}"; shift 2 ;;
        --dir)             APP_DIR="$(cd "${2:?valeur manquante}" && pwd)"; shift 2 ;;
        --entry)           ENTRY="${2:?valeur manquante}"; shift 2 ;;
        --mode)            MODE="${2:?valeur manquante}"; shift 2 ;;
        --qt-platform)     QT_PLATFORM="${2:?valeur manquante}"; shift 2 ;;
        --quiet-boot)      QUIET_BOOT=1; shift ;;
        --console-boot)    CONSOLE_BOOT=1; shift ;;
        --no-deps)         INSTALL_DEPS=0; shift ;;
        --keep-on-failure) AUTO_ROLLBACK=0; shift ;;
        --drm-device)      DRM_DEVICE="${2:?valeur manquante}"; shift 2 ;;
        --debug)           DEBUG_QT=1; shift ;;
        --rollback)        ROLLBACK=1; shift ;;
        --uninstall)       UNINSTALL=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *)                 die "Option inconnue : $1" ;;
    esac
done

[[ $EUID -eq 0 ]] || die "Lancez ce script avec sudo."
[[ -z "$MODE" || "$MODE" == "apt" || "$MODE" == "pip" ]] || die "--mode doit valoir apt ou pip."

# --- Journal d'état et annulation --------------------------------------------
# Chaque exécution écrit dans $STATE_FILE ce qu'elle modifie ; --rollback le relit.
record() { printf '%s|%s|%s|%s\n' "$1" "${2:-}" "${3:-}" "${4:-}" >> "$STATE_FILE"; }

# Sauvegarde un fichier AVANT sa première modification dans cette exécution
snapshot() {
    local f="$1" b
    grep -qF "FILE|${f}|" "$STATE_FILE" 2>/dev/null && return 0
    mkdir -p "$BACKUP_DIR"
    if [[ -e "$f" ]]; then
        b="$(printf '%s' "$f" | tr '/' '_')"
        cp -p "$f" "${BACKUP_DIR}/${b}"
        record FILE "$f" existed "$b"
    else
        record FILE "$f" absent
    fi
}

do_rollback() {
    set +e
    [[ -f "$STATE_FILE" ]] || { warn "Aucune installation à annuler."; return 0; }
    log "Annulation de la dernière installation"
    systemctl disable --now "${SERVICE_NAME}.service" 2>/dev/null

    local kind a b c was_enabled=0 was_active=0
    while IFS='|' read -r kind a b c; do
        case "$kind" in
            FILE)       if [[ "$b" == "existed" ]]; then cp -p "${BACKUP_DIR}/${c}" "$a"; else rm -f "$a"; fi ;;
            TARGET)     systemctl set-default "$a" ;;
            GROUP)      gpasswd -d "$a" "$b" >/dev/null ;;
            VENV_NEW)   rm -rf "$a" ;;
            WAS_ENABLED) was_enabled=1 ;;
            WAS_ACTIVE)  was_active=1 ;;
        esac
    done < "$STATE_FILE"
    # Venv sauvegardé : à remettre une fois le nouveau supprimé
    while IFS='|' read -r kind a b c; do
        [[ "$kind" == "VENV_OLD" ]] && mv "$a" "$b"
    done < "$STATE_FILE"

    systemctl daemon-reload
    [[ $was_enabled -eq 1 ]] && systemctl enable "${SERVICE_NAME}.service" 2>/dev/null
    [[ $was_active  -eq 1 ]] && systemctl start  "${SERVICE_NAME}.service" 2>/dev/null
    rm -rf "$STATE_FILE" "$BACKUP_DIR"
    log "Annulation terminée (config.txt, cmdline.txt, service, sudoers, venv, groupes, cible de démarrage)."
    warn "Non annulés : paquets apt installés, paquets pip d'un venv réutilisé, dossier data/."
    return 0
}

on_exit() {
    local rc=$?
    if [[ $rc -ne 0 && $INSTALL_STARTED -eq 1 && $INSTALL_DONE -eq 0 && $AUTO_ROLLBACK -eq 1 ]]; then
        trap - EXIT
        warn "Échec de l'installation : annulation automatique des modifications."
        do_rollback || true
    fi
    exit $rc
}
trap on_exit EXIT

# --- Actions autonomes --------------------------------------------------------
if [[ $ROLLBACK -eq 1 ]]; then
    do_rollback
    exit 0
fi

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
WORK_DIR="$(dirname "$APP_DIR/$ENTRY")"
VENV="$APP_DIR/venv"

# --- Choix du mode -----------------------------------------------------------
if [[ -z "$MODE" ]]; then
    if [[ -t 0 && -t 1 ]]; then
        cat <<'MENU'

Mode d'installation des dépendances :
  1) apt + venv  (recommandé)  PySide6, gpiozero et lgpio viennent de Debian ;
                               rendu EGLFS avec accélération GPU
  2) pip seul                  venv isolé, tout via pip (PySide6 compris) ;
                               EGLFS seulement si les roues pip le fournissent,
                               sinon rendu linuxfb (sans accélération GPU)

MENU
        read -r -p "Votre choix [1] : " ans
        case "${ans:-1}" in
            1) MODE="apt" ;;
            2) MODE="pip" ;;
            *) die "Choix invalide." ;;
        esac
    else
        MODE="apt"
        warn "Pas de terminal interactif : mode apt par défaut (utilisez --mode pour changer)."
    fi
fi

log "Mode        : $MODE"
log "Utilisateur : $APP_USER"
log "Dossier     : $APP_DIR"
log "Programme   : $ENTRY (travail : $WORK_DIR)"

# --- Initialisation du journal d'état (conserve l'exécution précédente) ------
mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"
if [[ -f "$STATE_FILE" ]]; then
    rm -rf "${STATE_DIR}/prev"
    mkdir -p "${STATE_DIR}/prev"
    mv "$STATE_FILE" "${STATE_DIR}/prev/state"
    [[ -d "$BACKUP_DIR" ]] && mv "$BACKUP_DIR" "${STATE_DIR}/prev/backup"
fi
: > "$STATE_FILE"
INSTALL_STARTED=1
record MODE "$MODE"
systemctl is-enabled --quiet "${SERVICE_NAME}.service" 2>/dev/null && record WAS_ENABLED 1 || true
systemctl is-active  --quiet "${SERVICE_NAME}.service" 2>/dev/null && record WAS_ACTIVE 1 || true

# --- 1. Paquets système ------------------------------------------------------
if [[ $INSTALL_DEPS -eq 1 ]]; then
    log "Installation des paquets système"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    BASE_PKGS=(python3-venv python3-pip libegl1 libgles2 libgbm1 libdrm2 libinput10
               libxkbcommon0 libfontconfig1 libdbus-1-3 fonts-dejavu-core)

    if [[ "$MODE" == "apt" ]]; then
        apt-get install -y "${BASE_PKGS[@]}" python3-gpiozero python3-lgpio
        for pkg in python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml \
                   python3-pyside6.qtquick python3-pyside6.qtsvg; do
            apt-get install -y "$pkg" 2>/dev/null || warn "Paquet $pkg indisponible (ignoré)"
        done
        apt-get install -y qt6-qpa-plugins 2>/dev/null || warn "qt6-qpa-plugins indisponible (ignoré)"
        # Modules QML (import QtQuick, Controls, Layouts...) : paquets Debian séparés de PySide6
        for pkg in qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
                   qml6-module-qtquick-window qml6-module-qtquick-templates \
                   qml6-module-qtqml-workerscript qml6-module-qtmultimedia; do
            apt-get install -y "$pkg" 2>/dev/null || warn "Paquet $pkg indisponible (ignoré)"
        done
    else
        apt-get install -y "${BASE_PKGS[@]}" libgl1
        # Outils pour compiler lgpio par pip (facultatif)
        apt-get install -y build-essential swig python3-dev liblgpio-dev 2>/dev/null \
            || warn "Outils de compilation indisponibles : lgpio pip risque d'échouer"
    fi
    # Pilotes Mesa (EGL + GPU vc4/v3d) : indispensables à EGLFS, noms variables selon la version
    apt-get install -y libegl-mesa0 libgl1-mesa-dri 2>/dev/null \
        || warn "Paquets Mesa (libegl-mesa0, libgl1-mesa-dri) indisponibles : vérifiez le rendu EGL"
fi

# --- 2. Environnement Python -------------------------------------------------
WANT_SYSTEM_SITE="false"
[[ "$MODE" == "apt" ]] && WANT_SYSTEM_SITE="true"

create_venv() {
    log "Création du venv ($MODE)"
    if [[ "$MODE" == "apt" ]]; then
        sudo -u "$APP_USER" python3 -m venv --system-site-packages "$VENV"
    else
        sudo -u "$APP_USER" python3 -m venv "$VENV"
    fi
    record VENV_NEW "$VENV"
}

if [[ -x "$VENV/bin/python" ]]; then
    CURRENT_SITE="$(grep -i '^include-system-site-packages' "$VENV/pyvenv.cfg" 2>/dev/null \
                    | cut -d= -f2 | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
    if [[ "$CURRENT_SITE" != "$WANT_SYSTEM_SITE" ]]; then
        OLD="${VENV}.old-${SERVICE_NAME}"
        [[ ! -e "$OLD" ]] || die "$OLD existe déjà : supprimez-le ou déplacez-le, puis relancez."
        warn "Le venv existant ne correspond pas au mode $MODE : il est mis de côté (${OLD})"
        mv "$VENV" "$OLD"
        record VENV_OLD "$OLD" "$VENV"
        create_venv
    else
        log "Venv existant réutilisé"
    fi
else
    create_venv
fi

PIP="sudo -u $APP_USER $VENV/bin/pip"
PY="sudo -u $APP_USER $VENV/bin/python"
REQ_FILE="$APP_DIR/requirements.txt"

if [[ "$MODE" == "apt" ]]; then
    # PySide6 doit venir de Debian : les roues pip n'embarquent pas toujours eglfs/KMS
    $PY -c "import PySide6.QtQuick" 2>/dev/null \
        || die "PySide6 (apt) introuvable : les paquets python3-pyside6.* existent sur Debian 13 (Trixie), pas sur Bookworm. Relancez avec --mode pip, ou passez sur Trixie."
    find /usr/lib -name 'libqeglfs*' 2>/dev/null | grep -q . \
        || warn "Plugin Qt eglfs introuvable sous /usr/lib : le rendu EGLFS risque d'échouer."
    ls /usr/lib/*/qt6/qml/QtQuick/Controls/qmldir >/dev/null 2>&1 \
        || warn "Modules QML Qt Quick Controls introuvables : Main.qml ne se chargera pas (paquets qml6-module-*)."
    if [[ -f "$REQ_FILE" ]]; then
        REQ_TMP="$(mktemp)"
        grep -viE '^\s*pyside6' "$REQ_FILE" > "$REQ_TMP" || true
        chmod 644 "$REQ_TMP"
        log "Installation de requirements.txt (sans PySide6)"
        $PIP install -r "$REQ_TMP" || warn "Certaines dépendances ont échoué (voir ci-dessus)"
        rm -f "$REQ_TMP"
    fi
    $PY -c "import gpiozero" 2>/dev/null || $PIP install gpiozero
else
    if [[ -f "$REQ_FILE" ]]; then
        log "Installation de requirements.txt"
        $PIP install -r "$REQ_FILE"
    fi
    $PY -c "import PySide6" 2>/dev/null || { log "Installation de PySide6 (pip)"; $PIP install PySide6; }
    $PY -c "import gpiozero" 2>/dev/null || $PIP install gpiozero
    $PIP install lgpio 2>/dev/null \
        || warn "lgpio (pip) a échoué : gpiozero utilisera un autre backend GPIO (plus limité)."
fi

# --- Plateforme Qt à utiliser ------------------------------------------------
detect_qt_pip() {
    $PY - <<'PY'
import importlib.util, pathlib
spec = importlib.util.find_spec("PySide6")
if not spec or not spec.submodule_search_locations:
    print("none"); raise SystemExit
root = pathlib.Path(list(spec.submodule_search_locations)[0])
has = lambda n: any(root.rglob(n))
if has("libqeglfs-kms-integration.so") and has("libqeglfs.so"):
    print("eglfs")
elif has("libqlinuxfb.so"):
    print("linuxfb")
else:
    print("none")
PY
}

if [[ -z "$QT_PLATFORM" ]]; then
    if [[ "$MODE" == "apt" ]]; then
        QT_PLATFORM="eglfs"
    else
        QT_PLATFORM="$(detect_qt_pip)"
        [[ "$QT_PLATFORM" != "none" ]] \
            || die "Les roues PySide6 pip ne contiennent ni eglfs/KMS ni linuxfb. Utilisez --mode apt (Trixie)."
        if [[ "$QT_PLATFORM" == "linuxfb" ]]; then
            warn "Roues pip sans eglfs/KMS : rendu linuxfb (sans accélération GPU)."
        fi
    fi
fi
record QT_PLATFORM "$QT_PLATFORM"
log "Plateforme Qt : $QT_PLATFORM"

# Le dossier data doit rester inscriptible (kilometers.csv)
mkdir -p "$APP_DIR/data"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR/data"

# --- 3. Accès matériel -------------------------------------------------------
log "Groupes video, render, input, gpio pour $APP_USER"
for grp in video render input gpio; do
    if ! getent group "$grp" >/dev/null; then
        warn "Groupe $grp absent (ignoré)"
    elif id -nG "$APP_USER" | tr ' ' '\n' | grep -qx "$grp"; then
        :   # déjà membre : rien à annuler
    else
        usermod -aG "$grp" "$APP_USER"
        record GROUP "$APP_USER" "$grp"
    fi
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
snapshot "$SUDOERS_FILE"
install -m 0440 -o root -g root "$TMP_SUDOERS" "$SUDOERS_FILE"
rm -f "$TMP_SUDOERS"

# --- 5. Configuration de démarrage (KMS) -------------------------------------
CONFIG_TXT="/boot/firmware/config.txt"
[[ -f "$CONFIG_TXT" ]] || CONFIG_TXT="/boot/config.txt"
if [[ -f "$CONFIG_TXT" ]]; then
    if ! grep -Eq '^\s*dtoverlay=vc4-(f)?kms-v3d' "$CONFIG_TXT"; then
        log "Activation du driver graphique KMS dans $CONFIG_TXT"
        snapshot "$CONFIG_TXT"
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
        snapshot "$CMDLINE"
        for flag in quiet loglevel=3 logo.nologo vt.global_cursor_default=0; do
            grep -qw -- "$flag" "$CMDLINE" || sed -i "1 s|\$| ${flag}|" "$CMDLINE"
        done
    fi
fi

if [[ $CONSOLE_BOOT -eq 1 ]]; then
    log "Démarrage en mode console"
    record TARGET "$(systemctl get-default)"
    systemctl set-default multi-user.target
fi

# --- 6. Service systemd ------------------------------------------------------
log "Création du service $SERVICE_NAME"
EXTRA_ENV=""
if [[ -n "$DRM_DEVICE" ]]; then
    KMS_CONF="/etc/${SERVICE_NAME}-kms.json"
    snapshot "$KMS_CONF"
    printf '{\n  "device": "%s"\n}\n' "$DRM_DEVICE" > "$KMS_CONF"
    EXTRA_ENV+="Environment=QT_QPA_EGLFS_KMS_CONFIG=${KMS_CONF}"$'\n'
fi
if [[ $DEBUG_QT -eq 1 ]]; then
    EXTRA_ENV+="Environment=QT_DEBUG_PLUGINS=1"$'\n'
    EXTRA_ENV+="Environment=QT_LOGGING_RULES=qt.qpa.*=true"$'\n'
fi
snapshot "$UNIT_FILE"
cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Mini Dash
After=local-fs.target systemd-user-sessions.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=${APP_USER}
SupplementaryGroups=video render input gpio
WorkingDirectory=${WORK_DIR}
Environment=QT_QPA_PLATFORM=${QT_PLATFORM}
Environment=QT_QPA_EGLFS_ALWAYS_SET_MODE=1
${EXTRA_ENV}# Attend que le GPU expose /dev/dri (max 30 s)
ExecStartPre=/usr/bin/timeout 30 /bin/sh -c 'until ls /dev/dri/card* >/dev/null 2>&1; do sleep 1; done'
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

log "Vérification du démarrage (10 s)"
sleep 10
RESTARTS="$(systemctl show -p NRestarts --value "${SERVICE_NAME}.service" 2>/dev/null || echo 0)"
if ! systemctl is-active --quiet "${SERVICE_NAME}.service" || [[ "${RESTARTS:-0}" != "0" ]]; then
    SERVICE_OK=0
    warn "Le service ne tourne pas correctement (redémarrages automatiques : ${RESTARTS:-?})."
    warn "Dernières lignes du journal :"
    journalctl -u "${SERVICE_NAME}" -n 25 --no-pager >&2 || true
else
    log "Le service tourne."
fi

INSTALL_DONE=1
log "Installation terminée (mode ${MODE}, Qt ${QT_PLATFORM})."
if [[ $SERVICE_OK -eq 0 ]]; then
    warn "L'installation est faite, mais l'application ne démarre pas. Pour diagnostiquer :"
    warn "  sudo ./install.sh --mode ${MODE} --debug   puis   journalctl -u ${SERVICE_NAME} -b --no-pager"
    warn "  Si /dev/dri contient plusieurs cartes : ajoutez --drm-device /dev/dri/card1 (ou card0)"
fi
cat <<EOF

  Logs        : journalctl -u ${SERVICE_NAME} -f
  Redémarrer  : sudo systemctl restart ${SERVICE_NAME}
  Annuler     : sudo ./install.sh --rollback   (défait cette installation)
  Désinstaller: sudo ./install.sh --uninstall

  Un redémarrage est conseillé pour prendre en compte les nouveaux groupes
  et la configuration graphique :  sudo reboot
EOF