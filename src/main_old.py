import io
import os
import sys
import shutil
import zipfile
from json.encoder import py_encode_basestring_ascii

import pygame
import subprocess
import threading
from datetime import datetime
import psutil
import requests

from UpdateUtility import *
from Gauge import *
from Indicator import *
from Tile import Tile, ToggleTile
from ProgressBar import *
from KilometerManager import *

pc_dev = False

FAN_PIN = 18

try:
    import RPi.GPIO as GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(FAN_PIN, GPIO.OUT)
    GPIO.output(FAN_PIN, GPIO.HIGH)
except RuntimeError:
    pc_dev = True

pygame.init()
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 480
FPS = 30

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
BLUE_UI = (0, 162, 255)
RED = (255, 30, 30)
GRAY_DARK = (40, 40, 40)

screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.FULLSCREEN | pygame.NOFRAME)
clock = pygame.time.Clock()


current_view = "main"

# Variables pour la gestion de la mise à jour
update_available = False
update_version = None
update_in_progress = False
update_progress = 0.0
update_status = "En attente..."
progress_bar = None

GAUGE_SIZE = 200
ARROW_SIZE = 25
PADDING = 50
GAUGE_Y = 50

jaugeTemp = GaugeTemperature(GAUGE_SIZE, "../assets/Compteur.png", "../assets/Aiguille.png",
                             (50, GAUGE_Y), (GAUGE_SIZE, GAUGE_SIZE), ARROW_SIZE, title="TEMPÉRATURE")
jaugeCpu = GaugeCPU(GAUGE_SIZE, "../assets/CompteurCpu.png", "../assets/Aiguille.png",
                    (50 + GAUGE_SIZE + PADDING, GAUGE_Y), (GAUGE_SIZE, GAUGE_SIZE), ARROW_SIZE, title="CPU")
jaugeRam = GaugeCPU(GAUGE_SIZE, "../assets/CompteurRam.png", "../assets/Aiguille.png",
                    (50 + (GAUGE_SIZE + PADDING) * 2, GAUGE_Y), (GAUGE_SIZE, GAUGE_SIZE), ARROW_SIZE, title="RAM")

wifiIndic = Indicator((100, 30), (255, 100, 0), GRAY_DARK, "../assets/wifi.png")
fanIndic = Indicator((100, 30), (50, 0, 255), GRAY_DARK, "../assets/fan.png")
updateIndic = Indicator((100, 30), (0, 255, 0), GRAY_DARK, "../assets/update.png", methode=check_for_updates)

indicatorsBox = IndicatorBox((20, 20), (SCREEN_WIDTH-40, 70), BLUE_UI, 1)
indicatorsBox.add_indicator(wifiIndic)

wallpaper = pygame.image.load("../assets/wallpaper.jpg")

wallpaper = pygame.transform.smoothscale(wallpaper, (SCREEN_WIDTH, SCREEN_HEIGHT))

# Créer le filtre assombrissant
wallpaper_overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
wallpaper_overlay.set_alpha(120)  # 0 = transparent, 255 = opaque
wallpaper_overlay.fill(BLACK)

version = "null"
version_checked = False

# Variables pour la gestion des kilomètres
kilometer_keyboard = None
kilometer_fields = []
kilometer_active_field = None
kilometer_entries = []
kilometer_scroll_offset = 0
kilometer_mode = "input"  # "input" ou "history"
kilometer_history_graph = None
kilometer_stats = None

def shutdown(desktop=False):
    if not desktop:
        os.system("sudo shutdown -h now")
    pygame.quit()
    if not pc_dev:
        GPIO.cleanup()
    sys.exit()

def switch_view(view):
    global current_view
    global tiles
    global version
    global update_available
    global update_version
    global progress_bar
    global update_in_progress
    global update_progress
    global update_status
    global version_checked
    global kilometer_keyboard
    global kilometer_fields
    global kilometer_active_field
    global kilometer_entries
    global kilometer_history_graph

    current_view = view

    if (current_view == "main"):
        if fanTile not in tiles:
            tiles.append(fanTile)

    elif (current_view == "stats"):
        if fanTile in tiles:
            tiles.remove(fanTile)

    elif (current_view == "settings"):
        if fanTile in tiles:
            tiles.remove(fanTile)

        if updateDownloadTile in tiles:
            tiles.remove(updateDownloadTile)

        # Retirer le bouton de téléchargement de la barre de navigation (il sera affiché à côté de la progressbar)
        if updateDownloadTile in tiles:
            tiles.remove(updateDownloadTile)

        try:
            current = get_current_version().strip()
            if not version_checked:
                latest = check_for_updates()
                version_checked = True

                if latest and latest != current:
                    update_available = True
                    update_version = latest
                    version = f"{current} -> {latest}"
                else:
                    update_available = False
                    update_version = None
                    version = f"{current} : Aucune mise à jour"
        except Exception as e:
            print(e)
            update_available = False
            update_version = None
            version = "Erreur de connexion"

        # Réinitialiser les variables de mise à jour si on revient sur la page
        if not update_in_progress:
            update_progress = 0.0
            update_status = "En attente..."

        # Créer la barre de progression si nécessaire
        if progress_bar is None:
            progress_bar = ProgressBar((150, 260), (400, 40),
                                      bg_color=GRAY_DARK,
                                      fill_color=BLUE_UI,
                                      border_color=WHITE)
    elif (current_view == "kilometers"):
        # Initialiser les composants pour la vue kilomètres (une seule fois)
        if kilometer_keyboard is None:
            kilometer_keyboard = NumericKeyboard((425, 100))

        if not kilometer_fields:
            # Créer les champs de saisie
            kilometer_fields = [
                InputField((50, 100), (300, 60), "Kilométrage", "km", max_length=8, integer_only=True),
                InputField((50, 190), (300, 60), "Litres", "L", max_length=6),
                InputField((50, 280), (300, 60), "Prix", "€", max_length=7)
            ]
            # Charger les entrées du CSV (seulement lors de l'initialisation)
            kilometer_entries = load_entries()

        # Initialiser le graphique d'historique
        if kilometer_history_graph is None:
            from KilometerManager import HistoryGraph
            kilometer_history_graph = HistoryGraph((50, 110), (700, 350))

# Configuration des 4 boutons en ligne
BUTTON_WIDTH = 170
BUTTON_HEIGHT = 100
BUTTON_Y = 350
BUTTON_SPACING = (SCREEN_WIDTH - 4 * BUTTON_WIDTH) / 5  # Espacement uniforme

offTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
               (BUTTON_SPACING, BUTTON_Y),
               BLUE_UI,
               icon="../assets/on-off-button.png",
               methode=shutdown,
               pressed_color=(0, 100, 180),
               text_color=BLUE_UI)

desktopTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
                   (BUTTON_SPACING * 4 + BUTTON_WIDTH * 3, BUTTON_Y),
                   BLUE_UI,
                   icon="../assets/desktop-monitor.png",
                   methode=lambda: shutdown(desktop=True),
                   pressed_color=(0, 100, 180),
                   text_color=BLUE_UI)

settingsTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
                   (BUTTON_SPACING * 3 + BUTTON_WIDTH *2, BUTTON_Y),
                   BLUE_UI,
                   icon="../assets/update.png",
                   methode=lambda: switch_view("settings"),
                   pressed_color=(0, 100, 180),
                    text_color=BLUE_UI)

statsTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
                 (BUTTON_SPACING * 4 + BUTTON_WIDTH * 3, BUTTON_Y),
                 BLUE_UI,
                 icon="../assets/stats.png",
                 methode=lambda: switch_view("stats"),
                 pressed_color=(0, 100, 180),
                 text_color=BLUE_UI)

clockTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
                 (BUTTON_SPACING * 4 + BUTTON_WIDTH * 3, BUTTON_Y),
                 BLUE_UI,
                 icon="../assets/clock.png",
                 methode=lambda: switch_view("main"),
                 pressed_color=(0, 100, 180),
                 text_color=BLUE_UI)

def toggle_fan(state):

    if (pc_dev):
        print(f"Fan toggled: {'ON' if state else 'OFF'}")
        return
    GPIO.output(FAN_PIN, GPIO.LOW if state else GPIO.HIGH)

fanTile = ToggleTile((BUTTON_WIDTH*2, BUTTON_HEIGHT),
                     (SCREEN_WIDTH/2 - BUTTON_WIDTH, BUTTON_Y),
                     BLUE_UI,
                     icon="../assets/fan_motor.png",
                     methode=toggle_fan,
                     pressed_color=(0, 100, 180),
                     text_color=BLUE_UI)

def start_update():
    """Démarre le téléchargement et l'installation de la mise à jour"""
    global update_in_progress, update_version, update_progress, update_status

    if update_in_progress or not update_version:
        return

    update_in_progress = True
    update_progress = 0.0
    update_status = "Démarrage..."

    # Lancer le téléchargement dans un thread séparé
    def update_thread():
        global update_progress, update_status

        def progress_callback(downloaded, total):
            global update_progress
            if total > 0:
                update_progress = downloaded / total

        def status_callback(status):
            global update_status
            update_status = status

        # Extraire le numéro de version (enlever le 'v' si présent)
        version_number = update_version.strip().lstrip('v')
        download_latest_release(version_number, progress_callback, status_callback)

    thread = threading.Thread(target=update_thread, daemon=True)
    thread.start()

updateDownloadTile = Tile((BUTTON_WIDTH, BUTTON_HEIGHT),
                          (BUTTON_SPACING * 4 + BUTTON_WIDTH * 3, BUTTON_Y),
                          (0, 200, 100),  # Vert pour indiquer le téléchargement
                          icon="../assets/update.png",
                          text="Télécharger",
                          font_size=26,
                          methode=start_update,
                          pressed_color=(0, 150, 70),
                          text_color=WHITE,
                          pressed_text_color=(200, 200, 200))

tiles = [offTile, desktopTile, fanTile]

switch_view("main")

def draw_bottom_nav():
    for tile in tiles:
        tile.show(screen)

def show_main():
    screen.fill(BLACK)

    screen.blit(wallpaper, (0, 0))
    screen.blit(wallpaper_overlay, (0, 0))

    now = datetime.now().strftime("%H : %M")
    font_time = pygame.font.Font(None, 240)
    text = font_time.render(now, True, WHITE)
    screen.blit(text, text.get_rect(center=(400, 200)))
    draw_bottom_nav()


def get_cpu_temp():
    try:
        with open('/sys/class/thermal/thermal_zone0/temp', 'r') as f:
            return float(f.read()) / 1000.0
    except: return 0.0

def get_cpu_usage():
    return psutil.cpu_percent(interval=0.1)

def show_stats():
    screen.fill(BLACK)

    screen.blit(wallpaper, (0, 0))
    screen.blit(wallpaper_overlay, (0, 0))

    temp = get_cpu_temp()
    cpu = get_cpu_usage()
    ram = psutil.virtual_memory().percent

    wifiIndic.state = psutil.net_if_stats().get('wlan0', None) and psutil.net_if_stats()['wlan0'].isup
    fanIndic.state = False

    jaugeTemp.show(screen, temp)
    jaugeCpu.show(screen, cpu)
    jaugeRam.show(screen, ram)

    draw_bottom_nav()

def show_kilometers():
    global kilometer_scroll_offset
    global kilometer_mode
    global kilometer_stats

    screen.fill(BLACK)
    screen.blit(wallpaper, (0, 0))
    screen.blit(wallpaper_overlay, (0, 0))

    # Titre
    font_title = pygame.font.Font(None, 48)
    title_text = "CARNET DE BORD" if kilometer_mode == "input" else "HISTORIQUE"
    title_surface = font_title.render(title_text, True, WHITE)
    screen.blit(title_surface, (SCREEN_WIDTH // 2 - title_surface.get_width() // 2, 10))


    if kilometer_mode == "input":
        # Mode saisie - afficher les champs et le clavier
        # Dessiner les champs de saisie
        for field in kilometer_fields:
            field.draw(screen)

        # Dessiner le clavier numérique
        if kilometer_keyboard:
            kilometer_keyboard.draw(screen)

        # Bouton Valider - style épuré avec contour bleu fin
        validate_button_rect = pygame.Rect(425, 390, 160, 50)
        pygame.draw.rect(screen, BLUE_UI, validate_button_rect, width=1, border_radius=10)
        font_button = pygame.font.Font(None, 32)
        validate_text = font_button.render("VALIDER", True, BLUE_UI)
        screen.blit(validate_text, validate_text.get_rect(center=validate_button_rect.center))

        # Bouton Effacer - style épuré avec contour bleu fin
        clear_button_rect = pygame.Rect(600, 390, 160, 50)
        pygame.draw.rect(screen, BLUE_UI, clear_button_rect, width=1, border_radius=10)
        clear_text = font_button.render("EFFACER", True, BLUE_UI)
        screen.blit(clear_text, clear_text.get_rect(center=clear_button_rect.center))

        # Stocker les rectangles pour la détection de clic
        globals()['validate_button_rect'] = validate_button_rect
        globals()['clear_button_rect'] = clear_button_rect

        # Bouton HISTORIQUE sous les champs de saisie
        history_button_rect = pygame.Rect(50, 370, 300, 50)
        pygame.draw.rect(screen, BLUE_UI, history_button_rect, width=1, border_radius=10)
        font_button = pygame.font.Font(None, 32)
        history_text = font_button.render("HISTORIQUE", True, BLUE_UI)
        screen.blit(history_text, history_text.get_rect(center=history_button_rect.center))
        globals()['mode_button_rect'] = history_button_rect


    elif kilometer_mode == "history":
        # Mode historique - afficher le graphique des statistiques

        # Bouton SAISIE pour revenir au mode input
        mode_button_rect = pygame.Rect(50, 60, 150, 40)
        pygame.draw.rect(screen, BLUE_UI, mode_button_rect, width=1, border_radius=10)
        font_mode = pygame.font.Font(None, 28)
        mode_text = font_mode.render("SAISIE", True, BLUE_UI)
        screen.blit(mode_text, mode_text.get_rect(center=mode_button_rect.center))
        globals()['mode_button_rect'] = mode_button_rect

        if kilometer_stats is None:
            # Calculer les stats
            from KilometerManager import calculate_consumption_stats
            kilometer_stats = calculate_consumption_stats(kilometer_entries)

        # Afficher le graphique
        if kilometer_history_graph:
            kilometer_history_graph.draw(screen, kilometer_stats)



def show_settings():
    screen.fill(BLACK)

    screen.blit(wallpaper, (0, 0))
    screen.blit(wallpaper_overlay, (0, 0))

    # Afficher la version
    try:
        font = pygame.font.Font(None, 50)
        version_txt = font.render(version, True, WHITE)
    except Exception as e:
        print(e)
        font = pygame.font.Font(None, 50)
        version_txt = font.render("ERROR", True, WHITE)
    screen.blit(version_txt, version_txt.get_rect(center=(400, 180)))

    # Afficher la barre de progression et le bouton si une mise à jour est disponible
    if update_available and progress_bar:
        # Mettre à jour la barre de progression
        progress_bar.set_progress(update_progress)
        progress_bar.show(screen)

        # Afficher le statut de la mise à jour
        font_status = pygame.font.Font(None, 28)
        status_txt = font_status.render(update_status, True, WHITE)
        screen.blit(status_txt, status_txt.get_rect(center=(400, 320)))

        # Afficher le bouton de téléchargement à côté de la barre de progression
        # Repositionner temporairement le bouton pour l'afficher à côté de la progressbar
        download_button_x = 570  # À droite de la barre de progression
        download_button_y = 240  # Aligné avec la barre
        download_button_width = 120
        download_button_height = 60

        # Créer un rectangle pour le bouton de téléchargement
        download_rect = pygame.Rect(download_button_x, download_button_y, download_button_width, download_button_height)

        # Déterminer la couleur selon l'état
        if update_in_progress:
            button_color = (100, 100, 100)  # Gris si en cours
            text_color = (200, 200, 200)
        else:
            button_color = (0, 200, 100)  # Vert si disponible
            text_color = WHITE

        # Dessiner le bouton avec contour (fileté)
        pygame.draw.rect(screen, button_color, download_rect, width=1, border_radius=5)

        # Afficher l'icône du bouton (plus petite)
        try:
            icon = pygame.image.load("../assets/update.png").convert_alpha()
            icon = pygame.transform.scale(icon, (30, 30))
            # Colorer l'icône
            color_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
            color_surf.fill(text_color)
            icon.blit(color_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MULT)
            icon_rect = icon.get_rect(center=(download_button_x + download_button_width // 2, download_button_y + 20))
            screen.blit(icon, icon_rect)
        except Exception as e:
            print(f"Erreur icône: {e}")

        # Afficher le texte du bouton
        font_button = pygame.font.Font(None, 22)
        if update_in_progress:
            button_text = "En cours..."
        else:
            button_text = "Télécharger"
        button_txt = font_button.render(button_text, True, text_color)
        button_txt_rect = button_txt.get_rect(center=(download_button_x + download_button_width // 2, download_button_y + 45))
        screen.blit(button_txt, button_txt_rect)

        # Stocker le rectangle pour la détection de clic (on le fait dans la boucle principale)
        # Pour l'instant, on stocke les coordonnées dans des variables globales
        globals()['download_button_rect'] = download_rect

    indicatorsBox.show(screen)

    draw_bottom_nav()

def main():
    global current_view
    global kilometer_active_field
    global kilometer_fields
    global kilometer_keyboard
    global kilometer_entries
    global kilometer_mode
    global kilometer_stats
    global kilometer_history_graph

    running = True
    ondrag = False
    x_dep, y_dep = 0, 0
    previous_view = None  # Pour détecter les changements de vue

    while running:
        # Appeler switch_view uniquement si la vue a changé
        if current_view != previous_view:
            switch_view(current_view)
            previous_view = current_view

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # Clic gauche
                    x_dep, y_dep = event.pos
                    ondrag = True

                    # Gestion des clics dans la vue kilometers
                    if current_view == "kilometers":
                        # Vérifier le bouton de changement de mode
                        mode_rect = globals().get('mode_button_rect')
                        if mode_rect and mode_rect.collidepoint(event.pos):
                            # Basculer entre les modes
                            kilometer_mode = "history" if kilometer_mode == "input" else "input"
                            # Recalculer les stats si on passe en mode history
                            if kilometer_mode == "history":
                                from KilometerManager import calculate_consumption_stats
                                kilometer_stats = calculate_consumption_stats(kilometer_entries)
                            continue

                        # Mode saisie
                        if kilometer_mode == "input":
                            # Vérifier d'abord si on clique sur le clavier (priorité au clavier)
                            if kilometer_keyboard:
                                key = kilometer_keyboard.handle_click(event.pos)
                                if key and kilometer_active_field:
                                    kilometer_active_field.add_char(key)
                                    continue  # Ne pas propager le clic

                            # Vérifier si on clique sur le bouton Valider
                            validate_rect = globals().get('validate_button_rect')
                            if validate_rect and validate_rect.collidepoint(event.pos):
                                # Récupérer les valeurs des champs
                                km_value = kilometer_fields[0].value
                                litres_value = kilometer_fields[1].value
                                prix_value = kilometer_fields[2].value

                                # Sauvegarder si tous les champs sont remplis
                                if km_value and litres_value and prix_value:
                                    if save_entry(km_value, litres_value, prix_value):
                                        # Effacer les champs après sauvegarde
                                        for field in kilometer_fields:
                                            field.clear()
                                            field.is_active = False
                                        kilometer_active_field = None
                                        # Recharger les entrées et recalculer les stats
                                        kilometer_entries = load_entries()
                                        from KilometerManager import calculate_consumption_stats
                                        kilometer_stats = calculate_consumption_stats(kilometer_entries)
                                continue  # Ne pas propager le clic

                            # Vérifier si on clique sur le bouton Effacer
                            clear_rect = globals().get('clear_button_rect')
                            if clear_rect and clear_rect.collidepoint(event.pos):
                                for field in kilometer_fields:
                                    field.clear()
                                    field.is_active = False
                                kilometer_active_field = None
                                continue  # Ne pas propager le clic

                            # Vérifier si on clique sur un champ de saisie
                            field_clicked = False
                            for field in kilometer_fields:
                                if field.handle_click(event.pos):
                                    # Désactiver tous les champs
                                    for f in kilometer_fields:
                                        f.is_active = False
                                    # Activer le champ cliqué
                                    field.is_active = True
                                    kilometer_active_field = field
                                    field_clicked = True
                                    break

                            if field_clicked:
                                continue  # Ne pas propager le clic

                    # Vérifier d'abord si on clique sur le bouton de téléchargement dans la vue settings
                    if current_view == "settings" and update_available and not update_in_progress:
                        download_rect = globals().get('download_button_rect')
                        if download_rect and download_rect.collidepoint(event.pos):
                            start_update()
                            continue

                    # Gérer les clics sur les tiles de navigation

                    if current_view != "kilometers":
                        for tile in tiles:
                            if tile.check_click(event.pos):
                                tile.press()

            elif event.type == pygame.MOUSEBUTTONUP:

                if event.button == 1:  # Relâchement clic gauche

                    if ondrag:
                        ondrag = False

                        if (x_dep - event.pos[0]) > (SCREEN_WIDTH/4):
                            if current_view == "main":
                                current_view = "stats"
                            elif current_view == "kilometers":
                                current_view = "main"

                        if -(x_dep - event.pos[0]) > (SCREEN_WIDTH / 4):
                            if current_view == "stats":
                                current_view = "main"
                            elif current_view == "main":
                                current_view = "kilometers"

                        elif -(y_dep - event.pos[1]) > (SCREEN_HEIGHT/2):
                            if current_view == "main":
                                current_view = "settings"

                        elif (y_dep - event.pos[1]) > (SCREEN_HEIGHT/2):
                            if current_view == "settings":
                                current_view = "main"

                    # Gérer le relâchement sur les tiles de navigation
                    for tile in tiles:
                        if tile.is_pressed:
                            tile.release()
                            if tile.check_click(event.pos):
                                tile.on_click()

            elif event.type == pygame.MOUSEWHEEL:
                # Gestion du scroll avec la molette dans la vue historique
                if current_view == "kilometers" and kilometer_mode == "history":
                    if kilometer_history_graph:
                        kilometer_history_graph.handle_scroll(-event.y)

            elif event.type == pygame.MOUSEMOTION:
                # Gestion du drag pour le scroll dans la vue historique
                if current_view == "kilometers" and kilometer_mode == "history" and ondrag:
                    if kilometer_history_graph:
                        dy = event.pos[1] - y_dep
                        kilometer_history_graph.handle_drag(dy)
                        y_dep = event.pos[1]

        if current_view == "main":
            show_main()
        elif current_view == "stats":
            show_stats()
        elif current_view == "settings":
            show_settings()
        elif current_view == "kilometers":
            show_kilometers()

        pygame.display.flip()
        clock.tick(FPS)

    pygame.quit()

if __name__ == '__main__':
    main()