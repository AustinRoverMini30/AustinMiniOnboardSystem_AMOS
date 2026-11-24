import hashlib
import logging
import math
import mimetypes
import re
import subprocess
import sys
import threading
import time
import zipfile
from pathlib import Path
from tokenize import String

from smbus2 import SMBus

import psutil
from PySide6.QtCore import (
    QObject,
    QCoreApplication,
    QTimer,
    Property,
    Signal,
    Slot,
    QSettings,
    QStandardPaths,
    QUrl,
    Qt
)
from PySide6.QtGui import QColor, QGuiApplication, QCursor
from PySide6.QtQml import QQmlApplicationEngine

from gpiozero import OutputDevice
from gpiozero.exc import BadPinFactory
from mutagen import File as MutagenFile
from mutagen import MutagenError

from UpdateUtility import (
    check_for_updates,
    download_latest_release,
    find_usb_update_archive,
    get_current_version,
    install_update_archive,
    restart_application,
)
from KilometerManager import calculate_consumption_stats, load_entries, save_entry
from LedAnimations import ANIMATION_MODES, build_animation_frame

logger = logging.getLogger(__name__)

pc_dev = False
FAN_PIN = 18

BOOT_DIR = Path(__file__).resolve().parent.parent / "assets" / "boot"
THUMBNAIL_DIR = Path(__file__).resolve().parent.parent / "assets" / "boot" / "thumbnails"
MUSIC_DIR = Path(__file__).resolve().parent.parent / "music"
MUSIC_ART_DIR = Path(QStandardPaths.writableLocation(
    QStandardPaths.StandardLocation.GenericCacheLocation
)) / "amos" / "album-art"
settings = QSettings("AMOS", "AustinMiniOnboardSystem_AMOS")

LED_COUNT = 30
LED_PIN = 18
LED_BRIGHTNESS = 80
strip = None
Color = None
led_available = False

try:
    fan = OutputDevice(FAN_PIN, active_high=False, initial_value=False)
    bus = SMBus(1)
except BadPinFactory:
    fan = None
    pc_dev = True
    bus = None

if (pc_dev):
    bus= None
else:
    bus = SMBus(1)

    try:
        from rpi_ws281x import PixelStrip, Color, ws

        LED_COUNT = 144
        LED_PIN = 12
        LED_BRIGHTNESS = 80

        strip = PixelStrip(LED_COUNT, LED_PIN, 800000, 10, False, LED_BRIGHTNESS, 0,
                           ws.WS2811_STRIP_GRB)
        strip.begin()
        for index in range(LED_COUNT):
            strip.setPixelColor(index, Color(0, 0, 0))
        strip.show()
        led_available = True
    except Exception:
        logger.exception("Initialisation de la bande LED impossible.")
        strip = None


def set_led_color(color):
    global led_available
    color = QColor(color)
    if not color.isValid():
        logger.error("Couleur de LED invalide : %s", color)
        return

    if not led_available:
        return

    try:
        led_color = Color(color.red(), color.green(), color.blue())
        for index in range(LED_COUNT):
            strip.setPixelColor(index, led_color)
        strip.show()
    except Exception:
        led_available = False
        logger.exception("Échec lors du réglage de la couleur des LED.")


def set_led_brightness(brightness):
    global led_available
    if not led_available:
        return

    try:
        strip.setBrightness(max(0, min(255, int(brightness))))
        strip.show()
    except Exception:
        led_available = False
        logger.exception("Échec lors du réglage de la luminosité des LED.")


def set_led_animation(mode, phase):
    global led_available
    if not led_available:
        return

    try:
        base_color = QColor(settings.value("dashboardLightColor", "#ffc400", type=str))
        if not base_color.isValid():
            logger.error("Couleur mémorisée des LED invalide.")
            return

        frame = build_animation_frame(
            mode,
            phase,
            LED_COUNT,
            (base_color.red(), base_color.green(), base_color.blue()),
        )
        for index, rgb in enumerate(frame):
            strip.setPixelColor(index, Color(*rgb))
        strip.show()
    except Exception:
        led_available = False
        logger.exception("Échec lors de l'animation des LED.")


class Backend(QObject):
    cpuTempChanged = Signal()
    speedChanged = Signal()
    gaugesChanged = Signal()
    voltageChanged = Signal()
    updateStateChanged = Signal()
    updateCheckResult = Signal(str, str)
    updateDownloadResult = Signal(bool, str)
    updateProgressResult = Signal(float)
    updateStatusResult = Signal(str)
    journalChanged = Signal()
    bootVideoChanged = Signal()
    musicLibraryChanged = Signal()
    bluetoothStateChanged = Signal()
    bluetoothOperationResult = Signal(object, str, str)
    kioskAtStartupChanged = Signal()
    primaryColorChanged = Signal()
    ledAvailabilityChanged = Signal()
    ledAnimationModeChanged = Signal()
    dashboardLightColorChanged = Signal()
    dashboardLightBrightnessChanged = Signal()

    def __init__(self):
        super().__init__()
        self._temp = 0.0
        self._speed = 0
        self._ram = 0.0
        self._tick = 0
        self._current_version = get_current_version()
        self._latest_version = ""
        self._update_available = False
        self._update_source = ""
        self._usb_update_archive = None
        self._usb_scan_error = ""
        self._update_in_progress = False
        self._update_progress = 0.0
        self._update_status = "En attente..."
        self._journal_rows = []
        self._journal_average = 0.0
        self._journal_average_ready = False
        self._journal_last = 0.0
        self._journal_total_km = 0.0
        self._journal_total_litres = 0.0
        self._journal_total_price = 0.0
        self._music_albums = self._load_music_library()
        self._bluetooth_devices = []
        self._bluetooth_busy = False
        self._bluetooth_status = "Appuyez sur Rechercher pour détecter les appareils."
        self._bluetooth_connected_address = ""
        self._voltage = 0.0
        self._voltmeter_available = False
        try:
            self._led_animation_mode = settings.value(
                "dashboardLightAnimationMode", 0, type=int
            )
        except (TypeError, ValueError):
            self._led_animation_mode = 0
        if self._led_animation_mode not in ANIMATION_MODES:
            self._led_animation_mode = 0
        self._led_brightness = settings.value(
            "dashboardLightBrightness", LED_BRIGHTNESS, type=int
        )
        self._led_brightness = max(0, min(255, self._led_brightness))
        self._led_preview_brightness = self._led_brightness
        set_led_brightness(self._led_brightness)
        self._load_journal()

        self.updateCheckResult.connect(self._handle_update_check)
        self.updateDownloadResult.connect(self._handle_update_result)
        self.updateProgressResult.connect(self._handle_update_progress)
        self.updateStatusResult.connect(
            lambda status: self._set_update_state(update_status=status)
        )
        self.bluetoothOperationResult.connect(self._finish_bluetooth_operation)

        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update)
        self._timer.start(300)

        self._led_animation_phase = 0.0
        self._led_output_enabled = False
        self._led_animation_active = False
        self._led_startup_animation_active = False
        self._led_preview_active = False
        self._led_animation_timer = QTimer(self)
        self._led_animation_timer.timeout.connect(self._update_led_animation)

        self._usb_update_timer = QTimer(self)
        self._usb_update_timer.timeout.connect(self._check_usb_update)
        self._usb_update_timer.start(3000)
        self._check_usb_update()

        # La lecture I2C tourne hors du thread graphique Qt.
        self._voltage_thread = threading.Thread(
            target=self._voltage_loop,
            name="INA226Reader",
            daemon=True,
        )
        self._voltage_thread.start()

    def _read_temp(self):
        try:
            return int(Path("/sys/class/thermal/thermal_zone0/temp").read_text()) / 1000
        except OSError:
            return 0

    def _update(self):
        self._tick += 1
        self._temp = self._read_temp()
        self._speed = abs(int(60 * math.sin(self._tick / 8)))
        self._ram = psutil.virtual_memory().percent
        self.cpuTempChanged.emit()
        self.speedChanged.emit()
        self.gaugesChanged.emit()

    def _update_led_animation(self):
        if not led_available:
            self._led_animation_timer.stop()
            return
        if not self._led_animation_active:
            return
        if self._led_animation_mode in (3, 4):
            self._led_animation_phase = min(1.0, self._led_animation_phase + 0.02)
        else:
            self._led_animation_phase = (self._led_animation_phase + 0.02) % 1.0
        was_available = led_available
        set_led_animation(self._led_animation_mode, self._led_animation_phase)
        if self._led_animation_mode in (3, 4) and self._led_animation_phase >= 1:
            self._led_animation_timer.stop()
        if was_available and not led_available:
            self.ledAvailabilityChanged.emit()

    def _voltage_loop(self):
        """Lit l'INA226 en arrière-plan sans bloquer l'interface Qt."""
        while True:
            was_available = self._voltmeter_available

            try:
                if bus is None:
                    raise OSError("Bus I2C indisponible")

                raw = bus.read_word_data(0x40, 0x02)
                raw = ((raw & 0xFF) << 8) | (raw >> 8)

                self._voltage = round(raw * 0.00125, 2)
                self._voltmeter_available = True
                self.voltageChanged.emit()

            except Exception:
                self._voltmeter_available = False
                # Notifie QML uniquement lors du passage disponible -> indisponible.
                if was_available:
                    self.voltageChanged.emit()

            # Fréquence de mesure : 2 Hz.
            time.sleep(0.5)

    @Property(float, notify=cpuTempChanged)
    def cpuTemp(self):
        return self._temp

    @Property(int, notify=speedChanged)
    def speed(self):
        return self._speed

    @Property(float, notify=gaugesChanged)
    def ramUsage(self):
        return self._ram

    @Property(float, notify=gaugesChanged)
    def temperature(self):
        return self._temp

    @Property(float, notify=gaugesChanged)
    def cpuUsage(self):
        return psutil.cpu_percent(interval=None)

    @Property(float, notify=voltageChanged)
    def voltage(self):
        # Cette propriété ne fait qu'exposer la dernière valeur mise en cache.
        return self._voltage if self._voltmeter_available else 0.0

    @Property(bool, notify=voltageChanged)
    def voltmeterAvailable(self):
        return self._voltmeter_available

    @Property(str, notify=updateStateChanged)
    def currentVersion(self):
        return self._current_version

    @Property(str, notify=updateStateChanged)
    def latestVersion(self):
        return self._latest_version

    @Property(bool, notify=updateStateChanged)
    def updateAvailable(self):
        return self._update_available

    @Property(str, notify=updateStateChanged)
    def updateSource(self):
        return self._update_source

    @Property(bool, notify=updateStateChanged)
    def updateInProgress(self):
        return self._update_in_progress

    @Property(float, notify=updateStateChanged)
    def updateProgress(self):
        return self._update_progress

    @Property(str, notify=updateStateChanged)
    def updateStatus(self):
        return self._update_status

    @Property("QVariantList", notify=journalChanged)
    def journalRows(self):
        return self._journal_rows

    @Property(float, notify=journalChanged)
    def journalAverage(self):
        return self._journal_average

    @Property(bool, notify=journalChanged)
    def journalAverageReady(self):
        return self._journal_average_ready

    @Property(float, notify=journalChanged)
    def journalLast(self):
        return self._journal_last

    @Property(float, notify=journalChanged)
    def journalTotalKm(self):
        return self._journal_total_km

    @Property(float, notify=journalChanged)
    def journalTotalLitres(self):
        return self._journal_total_litres

    @Property(float, notify=journalChanged)
    def journalTotalPrice(self):
        return self._journal_total_price

    def _boot_files(self):
        return sorted(BOOT_DIR.glob("*.mp4"))

    def _current_boot_file(self):
        files = self._boot_files()
        wanted = settings.value("bootVideo", "")
        for f in files:
            if f.name == wanted:
                return f
        return files[0] if files else None   # par défaut : la première

    def _thumbnail_file(self, video_file):
        matches = sorted(THUMBNAIL_DIR.glob(f"{video_file.stem}.*"))
        return matches[0] if matches else None

    @Property("QVariantList", notify=bootVideoChanged)
    def bootVideos(self):
        return [
            {
                "name": f.stem.replace("_", " "),
                "file": f.name,
                "thumbnail": (
                    QUrl.fromLocalFile(str(thumbnail))
                    if (thumbnail := self._thumbnail_file(f))
                    else QUrl()
                ),
            }
            for f in self._boot_files()
        ]

    @Property(str, notify=bootVideoChanged)
    def bootVideoFile(self):
        f = self._current_boot_file()
        return f.name if f else ""

    @Property(QUrl, notify=bootVideoChanged)
    def bootVideoUrl(self):
        f = self._current_boot_file()
        return QUrl.fromLocalFile(str(f)) if f else QUrl()

    def _load_music_library(self):
        supported_formats = {".aac", ".flac", ".m4a", ".mp3", ".ogg", ".wav", ".wma"}
        if not MUSIC_DIR.is_dir():
            return []

        albums = []
        album_directories = sorted(
            (path for path in MUSIC_DIR.rglob("*") if path.is_dir()),
            key=lambda path: path.relative_to(MUSIC_DIR).as_posix().casefold(),
        )
        for album_dir in album_directories:
            tracks = []
            track_files = sorted(
                (path for path in album_dir.iterdir()
                 if path.is_file() and path.suffix.casefold() in supported_formats),
                key=lambda path: (
                    int(match.group(1)) if (match := re.match(r"^\s*(\d+)", path.stem)) else float("inf"),
                    path.name.casefold(),
                ),
            )
            for index, track_file in enumerate(track_files, start=1):
                title = re.sub(r"^\s*\d+\s*[-._ ]+\s*", "", track_file.stem).strip()
                tracks.append({
                    "number": index,
                    "title": title or track_file.stem,
                    "file": track_file.name,
                    "url": QUrl.fromLocalFile(str(track_file)),
                })
            if tracks:
                albums.append({
                    "name": album_dir.relative_to(MUSIC_DIR).as_posix(),
                    "trackCount": len(tracks),
                    "tracks": tracks,
                    "cover": self._album_cover(album_dir, track_files),
                })
        return albums

    @staticmethod
    def _album_cover(album_dir, track_files):
        image_extensions = {".bmp", ".gif", ".jpeg", ".jpg", ".png", ".webp"}
        cover_names = {"cover", "folder", "front"}
        for image in sorted(album_dir.iterdir(), key=lambda path: path.name.casefold()):
            if image.is_file() and image.suffix.casefold() in image_extensions:
                if image.stem.casefold() in cover_names:
                    return QUrl.fromLocalFile(str(image))

        for track_file in track_files:
            try:
                audio = MutagenFile(track_file)
            except MutagenError as error:
                print(f"Impossible de lire les métadonnées de {track_file}: {error}")
                continue
            if audio is None or audio.tags is None:
                continue

            artwork = next(
                (picture.data for picture in getattr(audio, "pictures", []) if picture.data),
                None,
            )
            mime_type = next(
                (picture.mime for picture in getattr(audio, "pictures", []) if picture.data),
                "",
            )
            if artwork is None:
                tags = audio.tags
                apic_frames = tags.getall("APIC") if hasattr(tags, "getall") else []
                if apic_frames:
                    artwork = apic_frames[0].data
                    mime_type = apic_frames[0].mime
                elif tags.get("covr"):
                    artwork = bytes(tags["covr"][0])
                    mime_type = "image/png" if getattr(tags["covr"][0], "imageformat", 0) == 14 else "image/jpeg"
            if artwork:
                extension = mimetypes.guess_extension(mime_type) or ".jpg"
                if extension == ".jpe":
                    extension = ".jpg"
                MUSIC_ART_DIR.mkdir(parents=True, exist_ok=True)
                album_key = hashlib.sha256(str(album_dir.resolve()).encode()).hexdigest()
                cover_path = MUSIC_ART_DIR / f"{album_key}{extension}"
                cover_path.write_bytes(artwork)
                return QUrl.fromLocalFile(str(cover_path))
        return QUrl()

    @Property("QVariantList", notify=musicLibraryChanged)
    def musicAlbums(self):
        return self._music_albums

    @Property("QVariantList", notify=bluetoothStateChanged)
    def bluetoothDevices(self):
        return self._bluetooth_devices

    @Property(bool, notify=bluetoothStateChanged)
    def bluetoothBusy(self):
        return self._bluetooth_busy

    @Property(str, notify=bluetoothStateChanged)
    def bluetoothStatus(self):
        return self._bluetooth_status

    @Property(str, notify=bluetoothStateChanged)
    def bluetoothConnectedAddress(self):
        return self._bluetooth_connected_address

    @staticmethod
    def _run_bluetoothctl(*arguments, timeout=12):
        result = subprocess.run(
            ["bluetoothctl", *arguments],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        output = "\n".join(part for part in (result.stdout, result.stderr) if part).strip()
        if result.returncode != 0:
            raise RuntimeError(output or f"bluetoothctl s'est terminé avec le code {result.returncode}.")
        return output

    @staticmethod
    def _parse_bluetooth_devices(output):
        devices = {}
        for line in output.splitlines():
            match = re.search(
                r"(?:^|\[NEW\]\s+)Device\s+([0-9A-Fa-f:]{17})\s+(.+?)\s*$",
                line.strip(),
            )
            if match:
                address, name = match.groups()
                devices[address.upper()] = {
                    "address": address.upper(),
                    "name": name,
                    "connected": False,
                }
        return devices

    @staticmethod
    def _connected_bluetooth_addresses(output):
        return {
            match.group(1).upper()
            for line in output.splitlines()
            if (match := re.search(r"Device\s+([0-9A-Fa-f:]{17})", line))
        }

    @Slot()
    def scanBluetoothDevices(self):
        if self._bluetooth_busy:
            return
        self._bluetooth_busy = True
        self._bluetooth_status = "Recherche des appareils Bluetooth..."
        connected_address_before_scan = self._bluetooth_connected_address
        self.bluetoothStateChanged.emit()

        def worker():
            try:
                self._run_bluetoothctl("--timeout", "8", "scan", "on", timeout=15)
                device_output = self._run_bluetoothctl("devices")
                connected_output = self._run_bluetoothctl("devices", "Connected")
                devices = self._parse_bluetooth_devices(device_output)
                connected = self._connected_bluetooth_addresses(connected_output)
                for address in connected:
                    if address in devices:
                        devices[address]["connected"] = True
                status = (
                    f"{len(devices)} appareil(s) détecté(s)."
                    if devices else "Aucun appareil détecté. Vérifiez que l'enceinte est allumée."
                )
                connected_address = next(iter(connected), "")
                self.bluetoothOperationResult.emit(
                    {"devices": sorted(devices.values(), key=lambda device: device["name"].casefold())},
                    connected_address,
                    status,
                )
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                self.bluetoothOperationResult.emit(
                    None,
                    connected_address_before_scan,
                    f"Recherche Bluetooth impossible : {error}",
                )

        threading.Thread(target=worker, daemon=True).start()

    @Slot(str)
    def connectBluetoothDevice(self, address):
        address = address.strip().upper()
        if self._bluetooth_busy:
            return
        if not re.fullmatch(r"[0-9A-F]{2}(?::[0-9A-F]{2}){5}", address):
            self._bluetooth_status = "Adresse Bluetooth invalide."
            self.bluetoothStateChanged.emit()
            return

        self._bluetooth_busy = True
        self._bluetooth_status = "Connexion à l'enceinte..."
        devices_before_connect = [dict(device) for device in self._bluetooth_devices]
        connected_address_before_connect = self._bluetooth_connected_address
        self.bluetoothStateChanged.emit()

        def worker():
            try:
                info = self._run_bluetoothctl("info", address)
                if not re.search(r"^\s*Paired:\s*yes\s*$", info, re.MULTILINE | re.IGNORECASE):
                    self._run_bluetoothctl(
                        "--agent", "NoInputNoOutput", "pair", address, timeout=30
                    )
                    info = self._run_bluetoothctl("info", address)
                    if not re.search(r"^\s*Paired:\s*yes\s*$", info, re.MULTILINE | re.IGNORECASE):
                        raise RuntimeError("L'appairage a échoué. Vérifiez que l'enceinte est en mode appairage.")

                self._run_bluetoothctl("trust", address)
                self._run_bluetoothctl("connect", address, timeout=20)
                info = self._run_bluetoothctl("info", address)
                if not re.search(r"^\s*Connected:\s*yes\s*$", info, re.MULTILINE | re.IGNORECASE):
                    raise RuntimeError("L'enceinte n'a pas confirmé la connexion.")

                devices = devices_before_connect
                for device in devices:
                    device["connected"] = device["address"] == address
                self.bluetoothOperationResult.emit(
                    {"devices": devices},
                    address,
                    "Enceinte connectée.",
                )
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                self.bluetoothOperationResult.emit(
                    None,
                    connected_address_before_connect,
                    f"Connexion Bluetooth impossible : {error}",
                )

        threading.Thread(target=worker, daemon=True).start()

    @Slot()
    def disconnectBluetoothDevice(self):
        address = self._bluetooth_connected_address
        if not address or self._bluetooth_busy:
            return
        self._bluetooth_busy = True
        self._bluetooth_status = "Déconnexion de l'enceinte..."
        devices_before_disconnect = [dict(device) for device in self._bluetooth_devices]
        self.bluetoothStateChanged.emit()

        def worker():
            try:
                self._run_bluetoothctl("disconnect", address)
                devices = devices_before_disconnect
                for device in devices:
                    device["connected"] = False
                self.bluetoothOperationResult.emit(
                    {"devices": devices},
                    "",
                    "Enceinte déconnectée.",
                )
            except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
                self.bluetoothOperationResult.emit(
                    None,
                    address,
                    f"Déconnexion Bluetooth impossible : {error}",
                )

        threading.Thread(target=worker, daemon=True).start()

    @Slot(object, str, str)
    def _finish_bluetooth_operation(self, result, connected_address, status):
        if result is not None:
            self._bluetooth_devices = result["devices"]
        self._bluetooth_connected_address = connected_address
        self._bluetooth_status = status
        self._bluetooth_busy = False
        self.bluetoothStateChanged.emit()

    @Property(bool, notify=kioskAtStartupChanged)
    def kioskAtStartup(self):
        return settings.value("kioskAtStartup", False, type=bool)

    @Slot(bool)
    def setKioskAtStartup(self, enabled):
        enabled = bool(enabled)
        if enabled == self.kioskAtStartup:
            return
        settings.setValue("kioskAtStartup", enabled)
        settings.sync()
        self.kioskAtStartupChanged.emit()

    @Slot(str)
    def setBootVideo(self, file):
        name = Path(file).name
        if (BOOT_DIR / name).is_file():
            settings.setValue("bootVideo", name)
            settings.sync()
            self.bootVideoChanged.emit()

    @Property(str, notify=primaryColorChanged)
    def primaryColor(self):
        return settings.value("primaryColor", "#2d5fff", type=str)

    @Slot(str)
    def setPrimaryColor(self, color):
        color = QColor(color)
        if not color.isValid():
            return
        color = color.name()
        if color == self.primaryColor:
            return
        settings.setValue("primaryColor", color)
        settings.sync()
        self.primaryColorChanged.emit()

    @Slot(str)
    def setDashboardLightColor(self, color):
        was_available = led_available
        parsed_color = QColor(color)
        if not parsed_color.isValid():
            logger.error("Couleur de LED invalide : %s", color)
            return
        color = parsed_color.name()
        color_changed = color != self.dashboardLightColor
        settings.setValue("dashboardLightColor", color)
        settings.sync()
        if color_changed:
            self.dashboardLightColorChanged.emit()
        if self._led_output_enabled and not self._led_animation_active:
            set_led_color(color)
        if was_available and not led_available:
            self.ledAvailabilityChanged.emit()

    @Property(bool, notify=ledAvailabilityChanged)
    def ledsAvailable(self):
        return led_available

    @Property(str, notify=dashboardLightColorChanged)
    def dashboardLightColor(self):
        return settings.value("dashboardLightColor", "#ffc400", type=str)

    @Property(int, notify=dashboardLightBrightnessChanged)
    def dashboardLightBrightness(self):
        return self._led_brightness

    @Property(int, notify=ledAnimationModeChanged)
    def dashboardLightAnimationMode(self):
        return self._led_animation_mode

    @Slot(int)
    def setDashboardLightAnimation(self, mode):
        mode = int(mode)
        if mode not in ANIMATION_MODES or mode == self._led_animation_mode:
            return
        self._led_animation_mode = mode
        settings.setValue("dashboardLightAnimationMode", mode)
        settings.sync()
        self.ledAnimationModeChanged.emit()
        if self._led_animation_active:
            self._led_animation_phase = 0.0
            self._led_animation_timer.start(100)
            self._update_led_animation()

    @Slot(bool)
    def setLedStartupAnimation(self, active):
        self._set_led_animation_source("startup", active)

    @Slot(bool)
    def setLedAnimationPreview(self, active):
        self._set_led_animation_source("preview", active)

    def _set_led_animation_source(self, source, active):
        active = bool(active)
        if source == "startup":
            self._led_startup_animation_active = active
        else:
            self._led_preview_active = active

        was_active = self._led_animation_active
        self._led_animation_active = (
            self._led_startup_animation_active or self._led_preview_active
        )

        if self._led_animation_active and not was_active and led_available:
            self._led_output_enabled = True
            brightness = (
                self._led_preview_brightness
                if self._led_preview_active
                else self._led_brightness
            )
            self._apply_led_brightness(brightness)
            self._led_animation_phase = 0.0
            self._update_led_animation()
            if led_available:
                self._led_animation_timer.start(100)
        elif was_active and not self._led_animation_active:
            self._led_animation_timer.stop()
            self._apply_led_brightness(self._led_brightness)
            set_led_color(settings.value("dashboardLightColor", "#ffc400", type=str))
        elif self._led_animation_active:
            self._led_output_enabled = True
            brightness = (
                self._led_preview_brightness
                if self._led_preview_active
                else self._led_brightness
            )
            self._apply_led_brightness(brightness)

    @Slot(int)
    def setDashboardLightBrightness(self, brightness):
        brightness = max(0, min(255, int(brightness)))
        if brightness == self._led_brightness:
            return
        self._led_brightness = brightness
        settings.setValue("dashboardLightBrightness", brightness)
        settings.sync()
        self.dashboardLightBrightnessChanged.emit()
        if not self._led_animation_active:
            self._apply_led_brightness(brightness)

    @Slot(int)
    def setDashboardLightPreviewBrightness(self, brightness):
        self._led_preview_brightness = max(0, min(255, int(brightness)))
        if self._led_preview_active:
            self._apply_led_brightness(self._led_preview_brightness)

    def _apply_led_brightness(self, brightness):
        was_available = led_available
        set_led_brightness(brightness)
        if was_available and not led_available:
            self.ledAvailabilityChanged.emit()

    @Slot()
    def turnOffLeds(self):
        self._led_animation_timer.stop()
        self._led_animation_active = False
        self._led_startup_animation_active = False
        self._led_preview_active = False
        self._led_output_enabled = False
        set_led_color("#000000")

    def _load_journal(self):
        stats = calculate_consumption_stats(load_entries())
        if not stats:
            self._journal_rows = []
            self._journal_average = 0.0
            self._journal_average_ready = False
            self._journal_last = 0.0
            self._journal_total_km = 0.0
            self._journal_total_litres = 0.0
            self._journal_total_price = 0.0
        else:
            self._journal_rows = [
                {
                    "date": row["date"],
                    "consumption": row["consumption"],
                    "distance": row["km_parcourus"],
                    "litres": row["litres"],
                    "price": row["prix"],
                }
                for row in stats["consumptions"]
            ]
            self._journal_average = stats["avg_consumption"]
            self._journal_average_ready = stats["average_ready"]
            self._journal_last = stats["last_consumption"]
            self._journal_total_km = stats["total_km"]
            self._journal_total_litres = stats["total_litres"]
            self._journal_total_price = stats["total_prix"]
        self.journalChanged.emit()

    @Slot()
    def refreshJournal(self):
        self._load_journal()

    @Slot(str, str, str, result=bool)
    def saveJournalEntry(self, kilometrage, litres, prix):
        values = (kilometrage.strip(), litres.strip(), prix.strip())
        try:
            if not all(values) or any(float(value) < 0 for value in values):
                raise ValueError("Tous les champs doivent contenir une valeur positive.")
            if not save_entry(*values):
                raise OSError("Impossible d'enregistrer l'entrée.")
        except (ValueError, OSError) as error:
            self._set_update_state(update_status=f"Erreur carnet de bord : {error}")
            return False
        self._load_journal()
        return True

    def _set_update_state(self, **values):
        for name, value in values.items():
            setattr(self, f"_{name}", value)
        self.updateStateChanged.emit()

    @Slot(float)
    def _handle_update_progress(self, progress):
        progress = float(progress)
        if progress < 0:
            self._set_update_state(update_progress=-1.0)
            return
        progress = max(0.0, min(1.0, float(progress)))
        if self._update_progress >= 0 and progress < self._update_progress:
            return
        self._set_update_state(update_progress=progress)

    @Slot()
    def checkForUpdates(self):
        if self._update_in_progress:
            return
        self._set_update_state(update_status="Recherche de mises à jour...")

        def worker():
            try:
                latest = check_for_updates() or ""
                self.updateCheckResult.emit(latest, "")
            except Exception as error:
                self.updateCheckResult.emit("", f"Erreur de connexion : {error}")

        threading.Thread(target=worker, daemon=True).start()

    @Slot(str, str)
    def _handle_update_check(self, latest, error):
        if self._update_source == "usb":
            return
        available = bool(latest)
        self._set_update_state(
            latest_version=latest,
            update_available=available,
            update_source="online" if available else "",
            update_status=error or (
                f"Version {latest} disponible." if available else "Votre version est à jour."
            ),
        )

    def _check_usb_update(self):
        if self._update_in_progress:
            return
        try:
            candidate = find_usb_update_archive()
        except (OSError, UnicodeDecodeError, ValueError, zipfile.BadZipFile) as error:
            message = f"Archive USB invalide : {error}"
            if message != self._usb_scan_error:
                self._usb_scan_error = message
                self._usb_update_archive = None
                if self._update_source == "usb":
                    self._set_update_state(
                        latest_version="",
                        update_available=False,
                        update_source="",
                        update_status=message,
                    )
                else:
                    self._set_update_state(update_status=message)
            return

        had_scan_error = bool(self._usb_scan_error)
        self._usb_scan_error = ""
        if candidate:
            archive_path, version = candidate
            archive_path = str(archive_path)
            self._usb_update_archive = archive_path

            if version.removeprefix("v") == self._current_version.removeprefix("v"):
                if self._update_source == "online" and self._update_available:
                    return
                if self._update_source == "usb" or self._update_status != "La version USB est déjà installée.":
                    self._set_update_state(
                        latest_version="",
                        update_available=False,
                        update_source="",
                        update_status="La version USB est déjà installée.",
                    )
                return

            if (
                self._update_source != "usb"
                or self._latest_version != version
                or self._update_status != "Archive USB prête à installer."
            ):
                self._set_update_state(
                    latest_version=version,
                    update_available=True,
                    update_source="usb",
                    update_status="Archive USB prête à installer.",
                )
            return

        if self._usb_update_archive:
            self._usb_update_archive = None
            if self._update_source == "usb":
                self._set_update_state(
                    latest_version="",
                    update_available=False,
                    update_source="",
                    update_status="Archive USB retirée.",
                )
            elif self._update_source != "online":
                self._set_update_state(update_status="Archive USB retirée.")
        elif had_scan_error:
            if self._update_source == "online" and self._update_available:
                status = f"Version {self._latest_version} disponible."
            else:
                status = "Archive USB retirée."
            self._set_update_state(update_status=status)

    @Slot()
    def startUpdate(self):
        if self._update_in_progress or not self._latest_version:
            return
        self._set_update_state(
            update_in_progress=True,
            update_progress=0.0 if self._update_source == "online" else -1.0,
            update_status="Démarrage...",
        )

        def progress(value):
            self.updateProgressResult.emit(value)

        def status(message):
            self.updateStatusResult.emit(message)

        def worker():
            status_messages = []

            def tracked_status(message):
                status_messages.append(message)
                status(message)

            if self._update_source == "usb":
                success = install_update_archive(
                    self._usb_update_archive,
                    self._latest_version,
                    progress_callback=progress,
                    status_callback=tracked_status,
                )
            else:
                success = download_latest_release(
                    self._latest_version,
                    progress_callback=progress,
                    status_callback=tracked_status,
                )
            self.updateDownloadResult.emit(
                success,
                "" if success else (status_messages[-1] if status_messages else ""),
            )

        threading.Thread(target=worker, daemon=True).start()

    @Slot(bool, str)
    def _handle_update_result(self, success, error):
        if not success:
            self._set_update_state(
                update_in_progress=False,
                update_status=error or "La mise à jour a échoué.",
            )
            return
        self._set_update_state(update_progress=1.0, update_status="Redémarrage...")
        try:
            restart_application()
            QCoreApplication.quit()
        except OSError as restart_error:
            self._set_update_state(
                update_in_progress=False,
                update_status=f"Mise à jour installée, redémarrage impossible : {restart_error}",
            )

    @Slot(bool)
    def setFan(self, state):
        if fan:
            fan.on() if state else fan.off()

    @Slot()
    def shutdown(self):
        self.turnOffLeds()
        if pc_dev:
            QCoreApplication.quit()
            return
        subprocess.Popen(["sudo", "shutdown", "-h", "now"])

    @Slot()
    def restart(self):
        self.turnOffLeds()
        if pc_dev:
            QCoreApplication.quit()
            return
        subprocess.Popen(["sudo", "reboot"])


app = QGuiApplication(sys.argv)

if app.platformName() in ("eglfs", "linuxfb"):
    app.setOverrideCursor(QCursor(Qt.BlankCursor))

engine = QQmlApplicationEngine()
backend = Backend()
app.aboutToQuit.connect(backend.turnOffLeds)
engine.rootContext().setContextProperty("backend", backend)

engine.load(Path(__file__).parent / "Main.qml")
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())