import hashlib
import math
import mimetypes
import re
import subprocess
import sys
import threading
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

pc_dev = False
FAN_PIN = 18

BOOT_DIR = Path(__file__).resolve().parent.parent / "assets" / "boot"
THUMBNAIL_DIR = Path(__file__).resolve().parent.parent / "assets" / "boot" / "thumbnails"
MUSIC_DIR = Path(__file__).resolve().parent.parent / "music"
MUSIC_ART_DIR = Path(QStandardPaths.writableLocation(
    QStandardPaths.StandardLocation.GenericCacheLocation
)) / "amos" / "album-art"
settings = QSettings("AMOS", "AustinMiniOnboardSystem_AMOS")

try:
    fan = OutputDevice(FAN_PIN, active_high=False, initial_value=False)
    bus = SMBus(1)
except BadPinFactory:
    fan = None
    pc_dev = True
    bus = None

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
    kioskAtStartupChanged = Signal()
    primaryColorChanged = Signal()

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
        self._load_journal()

        self.updateCheckResult.connect(self._handle_update_check)
        self.updateDownloadResult.connect(self._handle_update_result)
        self.updateProgressResult.connect(self._handle_update_progress)
        self.updateStatusResult.connect(
            lambda status: self._set_update_state(update_status=status)
        )

        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update)
        self._timer.start(300)

        self._usb_update_timer = QTimer(self)
        self._usb_update_timer.timeout.connect(self._check_usb_update)
        self._usb_update_timer.start(3000)
        self._check_usb_update()

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
        self.voltageChanged.emit()
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
        if (pc_dev):
            return 12.0
        try:
            voltage = bus.read_word_data(0x40, 0x02)
            voltage = ((voltage & 0xFF) << 8) | (voltage >> 8)
            voltage = voltage * 0.00125
            return round(voltage, 2)
        except Exception:
            return 0.0

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
        progress = max(0.0, min(1.0, float(progress)))
        if progress < self._update_progress:
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
            update_progress=0.0,
            update_status="Démarrage...",
        )

        def progress(downloaded, total):
            if total:
                self.updateProgressResult.emit(downloaded / total)

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
        if pc_dev:
            QCoreApplication.quit()
            return
        subprocess.Popen(["sudo", "shutdown", "-h", "now"])

    @Slot()
    def restart(self):
        if pc_dev:
            QCoreApplication.quit()
            return
        subprocess.Popen(["sudo", "reboot"])


app = QGuiApplication(sys.argv)

if app.platformName() in ("eglfs", "linuxfb"):
    app.setOverrideCursor(QCursor(Qt.BlankCursor))

engine = QQmlApplicationEngine()
backend = Backend()
engine.rootContext().setContextProperty("backend", backend)

engine.load(Path(__file__).parent / "Main.qml")
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
