import csv
import os
from datetime import datetime

# Obtenir le chemin absolu du dossier data
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(PROJECT_DIR, "data")
CSV_FILE = os.path.join(DATA_DIR, "kilometers.csv")
CSV_HEADERS = ["date", "kilometrage", "litres", "prix"]


def ensure_csv_exists():
    """Crée le fichier CSV et le répertoire data s'ils n'existent pas"""
    os.makedirs(DATA_DIR, exist_ok=True)
    if not os.path.exists(CSV_FILE):
        with open(CSV_FILE, 'w', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=CSV_HEADERS)
            writer.writeheader()


def load_entries():
    """Charge toutes les entrées du fichier CSV"""
    ensure_csv_exists()
    entries = []
    try:
        with open(CSV_FILE, 'r', newline='') as f:
            reader = csv.DictReader(f)
            for row in reader:
                entries.append(row)
    except Exception as e:
        print(f"Erreur de lecture CSV: {e}")
    return entries


def save_entry(kilometrage, litres, prix):
    """Ajoute une nouvelle entrée dans le fichier CSV"""
    ensure_csv_exists()
    try:
        with open(CSV_FILE, 'a', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=CSV_HEADERS)
            writer.writerow({
                'date': datetime.now().strftime("%Y-%m-%d %H:%M"),
                'kilometrage': kilometrage,
                'litres': litres,
                'prix': prix
            })
        return True
    except Exception as e:
        print(f"Erreur d'écriture CSV: {e}")
        return False


def calculate_consumption_stats(entries):
    """Calcule les statistiques de consommation à partir des entrées"""
    if len(entries) < 2:
        return None

    consumptions = []

    # Calculer la consommation entre chaque entrée
    for i in range(1, len(entries)):
        prev_entry = entries[i-1]
        curr_entry = entries[i]

        try:
            prev_km = float(prev_entry['kilometrage'])
            curr_km = float(curr_entry['kilometrage'])
            litres = float(curr_entry['litres'])

            km_parcourus = curr_km - prev_km
            if km_parcourus > 0:
                # Consommation en L/100km
                consumption = (litres / km_parcourus) * 100
                consumptions.append({
                    'date': curr_entry['date'],
                    'km_start': prev_km,
                    'km_end': curr_km,
                    'km_parcourus': km_parcourus,
                    'litres': litres,
                    'consumption': consumption,
                    'prix': float(curr_entry['prix'])
                })
        except (ValueError, KeyError) as e:
            print(f"Erreur de calcul: {e}")
            continue

    if not consumptions:
        return None

    # Calculer la moyenne globale
    avg_consumption = sum(c['consumption'] for c in consumptions) / len(consumptions)

    # Consommation entre les deux dernières entrées
    last_consumption = consumptions[-1]['consumption'] if consumptions else 0

    return {
        'consumptions': consumptions,
        'avg_consumption': avg_consumption,
        'last_consumption': last_consumption,
        'total_litres': sum(c['litres'] for c in consumptions),
        'total_km': sum(c['km_parcourus'] for c in consumptions),
        'total_prix': sum(c['prix'] for c in consumptions)
    }


class NumericKeyboard:
    """Clavier numérique virtuel pour saisie tactile"""

    def __init__(self, position, size=(350, 280)):
        self.position = position
        self.size = size
        self.keys = [
            ['7', '8', '9'],
            ['4', '5', '6'],
            ['1', '2', '3'],
            ['.', '0', '<']
        ]
        self.key_rects = []
        self.setup_keys()

    def setup_keys(self):
        """Calcule les rectangles pour chaque touche"""
        self.key_rects = []
        key_width = self.size[0] // 3 - 10
        key_height = self.size[1] // 4 - 10

        for row_idx, row in enumerate(self.keys):
            row_rects = []
            for col_idx, key in enumerate(row):
                x = self.position[0] + col_idx * (key_width + 10) + 5
                y = self.position[1] + row_idx * (key_height + 10) + 5
                rect = pygame.Rect(x, y, key_width, key_height)
                row_rects.append((key, rect))
            self.key_rects.append(row_rects)

    def draw(self, screen, bg_color=(0, 0, 0, 0), key_color=(0, 0, 0, 0), text_color=(0, 162, 255)):
        """Dessine le clavier sur l'écran avec style épuré"""
        # Pas de fond pour le clavier (transparent)

        # Dessiner chaque touche
        font = pygame.font.Font(None, 40)
        for row in self.key_rects:
            for key, rect in row:
                # Fond transparent, contour bleu fin
                pygame.draw.rect(screen, text_color, rect, width=1, border_radius=5)

                # Texte bleu
                text = font.render(key, True, text_color)
                text_rect = text.get_rect(center=rect.center)
                screen.blit(text, text_rect)

    def handle_click(self, pos):
        """Retourne la touche cliquée ou None"""
        for row in self.key_rects:
            for key, rect in row:
                if rect.collidepoint(pos):
                    return key
        return None


class InputField:
    """Champ de saisie pour un formulaire"""

    def __init__(self, position, size, label, unit="", max_length=10, integer_only=False):
        self.position = position
        self.size = size
        self.label = label
        self.unit = unit
        self.value = ""
        self.max_length = max_length
        self.rect = pygame.Rect(*position, *size)
        self.is_active = False
        self.integer_only = integer_only  # True pour accepter seulement des entiers

    def draw(self, screen, active_color=(0, 162, 255), inactive_color=(0, 162, 255),
             text_color=(255, 255, 255), bg_color=(0, 0, 0, 0)):
        """Dessine le champ de saisie avec style épuré"""
        # Couleur selon l'état actif (même couleur, juste l'épaisseur change)
        border_color = active_color
        border_width = 2 if self.is_active else 1

        # Fond transparent, contour bleu
        pygame.draw.rect(screen, border_color, self.rect, width=border_width, border_radius=5)

        # Label
        font_label = pygame.font.Font(None, 28)
        label_text = font_label.render(self.label, True, active_color)
        screen.blit(label_text, (self.position[0], self.position[1] - 30))

        # Valeur
        font_value = pygame.font.Font(None, 36)
        display_text = f"{self.value} {self.unit}".strip()
        if not self.value:
            display_text = "---"
        value_text = font_value.render(display_text, True, text_color)
        value_rect = value_text.get_rect(center=self.rect.center)
        screen.blit(value_text, value_rect)

    def handle_click(self, pos):
        """Retourne True si le champ est cliqué"""
        return self.rect.collidepoint(pos)

    def add_char(self, char):
        """Ajoute un caractère à la valeur"""
        if char == '⌫' or char == '<':
            # Backspace : effacer le dernier caractère
            self.value = self.value[:-1]
        elif char == '.':
            # Si integer_only, ignorer le point décimal
            if self.integer_only:
                return
            # Empêcher plusieurs points
            if '.' in self.value:
                return
            if len(self.value) < self.max_length:
                self.value += char
        elif len(self.value) < self.max_length:
            self.value += char

    def clear(self):
        """Vide le champ"""
        self.value = ""

    def get_value(self):
        """Retourne la valeur en float"""
        try:
            return float(self.value) if self.value else 0.0
        except ValueError:
            return 0.0


class HistoryGraph:
    """Affiche l'historique des consommations sous forme de graphique scrollable"""

    def __init__(self, position, size):
        self.position = position
        self.size = size
        self.rect = pygame.Rect(*position, *size)
        self.scroll_offset = 0
        self.max_scroll = 0
        self.bar_height = 60
        self.bar_spacing = 10

    def draw(self, screen, stats, bg_color=(0, 0, 0, 0), text_color=(255, 255, 255)):
        """Dessine l'historique et les statistiques avec style épuré"""
        if not stats or not stats['consumptions']:
            # Afficher un message si pas de données
            font = pygame.font.Font(None, 28)
            text = font.render("Pas assez de données (min. 2 entrées)", True, text_color)
            screen.blit(text, (self.position[0] + 10, self.position[1] + 20))
            return

        # Plus d'encadré - statistiques sur toute la largeur
        blue_ui = (0, 162, 255)

        # Statistiques globales - toute la largeur
        y_stats = self.position[1]
        font_stats = pygame.font.Font(None, 24)

        avg_consumption = stats['avg_consumption']
        last_consumption = stats['last_consumption']

        # Moyenne globale (blanc)
        avg_text = f"Moyenne: {avg_consumption:.2f} L/100km"
        avg_surface = font_stats.render(avg_text, True, text_color)
        screen.blit(avg_surface, (self.position[0], y_stats))

        # Dernière consommation (blanc)
        last_text = f"Dernière: {last_consumption:.2f} L/100km"
        last_surface = font_stats.render(last_text, True, text_color)
        screen.blit(last_surface, (self.position[0] + 300, y_stats))

        # Totaux (blanc)
        total_text = f"Total: {stats['total_km']:.0f} km | {stats['total_litres']:.1f} L | {stats['total_prix']:.2f} €"
        total_surface = font_stats.render(total_text, True, text_color)
        screen.blit(total_surface, (self.position[0], y_stats + 30))

        # Zone de graphique
        graph_y = y_stats + 70
        graph_height = self.size[1] - 70

        # Créer une surface pour le contenu scrollable
        content_height = len(stats['consumptions']) * (self.bar_height + self.bar_spacing)
        self.max_scroll = max(0, content_height - graph_height)

        # Limiter le scroll
        self.scroll_offset = max(0, min(self.scroll_offset, self.max_scroll))

        # Clip pour le scrolling - sur toute la largeur
        clip_rect = pygame.Rect(self.position[0], graph_y, self.size[0], graph_height)
        screen.set_clip(clip_rect)

        # Trouver la consommation max pour normaliser les barres
        max_consumption = max(c['consumption'] for c in stats['consumptions'])
        max_bar_width = self.size[0] - 150

        # Dessiner les barres
        consumptions = stats['consumptions']
        font_bar = pygame.font.Font(None, 20)

        for i, consumption_data in enumerate(consumptions):
            y = graph_y + i * (self.bar_height + self.bar_spacing) - self.scroll_offset

            # Sauter si hors de la zone visible
            if y + self.bar_height < graph_y or y > graph_y + graph_height:
                continue

            consumption = consumption_data['consumption']
            date_str = consumption_data['date'][:10]  # YYYY-MM-DD

            # Style épuré : toutes les barres en bleu avec contour fin
            bar_width = (consumption / max_consumption) * max_bar_width
            bar_rect = pygame.Rect(self.position[0] + 100, y, bar_width, self.bar_height - 5)

            # Contour bleu fin uniquement
            pygame.draw.rect(screen, blue_ui, bar_rect, width=1, border_radius=5)

            # Date (blanc)
            date_surface = font_bar.render(date_str, True, text_color)
            screen.blit(date_surface, (self.position[0], y + 2))

            # Valeur de consommation (blanc)
            cons_text = f"{consumption:.2f}"
            cons_surface = font_bar.render(cons_text, True, text_color)
            screen.blit(cons_surface, (self.position[0] + 120, y + 10))

            # Distance (blanc)
            km_text = f"{consumption_data['km_parcourus']:.0f}km"
            km_surface = font_bar.render(km_text, True, text_color)
            screen.blit(km_surface, (self.position[0] + 120, y + 30))

        # Réinitialiser le clip
        screen.set_clip(None)

        # Indicateur de scroll si nécessaire
        if self.max_scroll > 0:
            # Barre de scroll (bleu)
            scroll_height = max(20, (graph_height / content_height) * graph_height)
            scroll_y = graph_y + (self.scroll_offset / self.max_scroll) * (graph_height - scroll_height)
            scroll_rect = pygame.Rect(self.position[0] + self.size[0] - 15, scroll_y, 10, scroll_height)
            pygame.draw.rect(screen, blue_ui, scroll_rect, border_radius=5)

    def handle_scroll(self, direction):
        """Gère le scroll avec la molette ou les gestes"""
        scroll_speed = 30
        self.scroll_offset += direction * scroll_speed
        self.scroll_offset = max(0, min(self.scroll_offset, self.max_scroll))

    def handle_drag(self, dy):
        """Gère le scroll par drag"""
        self.scroll_offset -= dy
        self.scroll_offset = max(0, min(self.scroll_offset, self.max_scroll))
