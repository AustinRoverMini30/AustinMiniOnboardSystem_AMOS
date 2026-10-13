#!/bin/bash
# Attendre que Wayland/X11 soit initialisé
while [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; do
  sleep 1
done

# Aller dans le dossier du projet
cd /home/nicolas/Téléchargements/AustinMiniOnboardSystem_AMOS/src
# Lancer l'app
/usr/bin/python3 main.py
