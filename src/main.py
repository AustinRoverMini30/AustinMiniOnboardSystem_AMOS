import math
import subprocess
import sys
import threading
from pathlib import Path

import psutil
from PySide6.QtCore import (
    QObject,
    QCoreApplication,
    QTimer,
    Property,
    Signal,
    Slot,
)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from gpiozero import OutputDevice
from gpiozero.exc import BadPinFactory

from UpdateUtility import (
    check_for_updates,
    download_latest_release,
    get_current_version,
    restart_application,
)
from KilometerManager import calculate_consumption_stats, load_entries, save_entry


pc_dev = False
FAN_PIN = 18

try:
    fan = OutputDevice(FAN_PIN, active_high=False, initial_value=False)
except BadPinFactory:
    fan = None
    pc_dev = True


class Backend(QObject):
    cpuTempChanged = Signal()
    speedChanged = Signal()
    gaugesChanged = Signal()
    updateStateChanged = Signal()
    updateCheckResult = Signal(str, str)
    updateDownloadResult = Signal(bool, str)
    updateProgressResult = Signal(float)
    updateStatusResult = Signal(str)
    journalChanged = Signal()

    def __init__(self):
        super().__init__()
        self._temp = 0.0
        self._speed = 0
        self._ram = 0.0
        self._tick = 0
        self._current_version = get_current_version()
        self._latest_version = ""
        self._update_available = False
        self._update_in_progress = False
        self._update_progress = 0.0
        self._update_status = "En attente..."
        self._journal_rows = []
        self._journal_average = 0.0
        self._journal_last = 0.0
        self._journal_total_km = 0.0
        self._journal_total_litres = 0.0
        self._journal_total_price = 0.0
        self._load_journal()

        self.updateCheckResult.connect(self._handle_update_check)
        self.updateDownloadResult.connect(self._handle_update_result)
        self.updateProgressResult.connect(
            lambda progress: self._set_update_state(update_progress=progress)
        )
        self.updateStatusResult.connect(
            lambda status: self._set_update_state(update_status=status)
        )

        self._timer = QTimer(self)
        self._timer.timeout.connect(self._update)
        self._timer.start(300)

    def _read_temp(self):
        try:
            return int(Path("/sys/class/thermal/thermal_zone0/temp").read_text()) / 1000
        except OSError:
            return 42.0

    def _update(self):
        self._tick += 1
        self._temp = self._read_temp()
        self._speed = abs(int(60 * math.sin(self._tick / 8)))
        self._ram = psutil.virtual_memory().percent
        self.cpuTempChanged.emit()
        self.speedChanged.emit()
        self.gaugesChanged.emit()

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

    @Property(str, notify=updateStateChanged)
    def currentVersion(self):
        return self._current_version

    @Property(str, notify=updateStateChanged)
    def latestVersion(self):
        return self._latest_version

    @Property(bool, notify=updateStateChanged)
    def updateAvailable(self):
        return self._update_available

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

    def _load_journal(self):
        stats = calculate_consumption_stats(load_entries())
        if not stats:
            self._journal_rows = []
            self._journal_average = 0.0
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
        available = bool(latest)
        self._set_update_state(
            latest_version=latest,
            update_available=available,
            update_status=error or (
                f"Version {latest} disponible." if available else "Votre version est à jour."
            ),
        )

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
engine = QQmlApplicationEngine()
backend = Backend()
engine.rootContext().setContextProperty("backend", backend)
engine.load(Path(__file__).parent / "Main.qml")
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
