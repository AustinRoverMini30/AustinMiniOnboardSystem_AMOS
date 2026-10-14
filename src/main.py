import sys
from pathlib import Path
from PySide6.QtCore import QObject, QTimer, Property, Signal, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlApplicationEngine

from gpiozero import OutputDevice
from gpiozero.exc import BadPinFactory

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

    def __init__(self):
        super().__init__()
        self._temp = 0.0
        self._speed = 0
        self._tick = 0
        timer = QTimer(self)
        timer.timeout.connect(self._update)
        timer.start(500)

    def _read_temp(self):
        try:
            return int(Path("/sys/class/thermal/thermal_zone0/temp").read_text()) / 1000
        except OSError:
            return 42.0  # valeur bidon sur PC

    def _update(self):
        self._tick += 1
        self._temp = self._read_temp()
        self._speed = abs(int(60 * __import__("math").sin(self._tick / 8)))
        self.cpuTempChanged.emit()
        self.speedChanged.emit()

    @Property(float, notify=cpuTempChanged)
    def cpuTemp(self):
        return self._temp

    @Property(int, notify=speedChanged)
    def speed(self):
        return self._speed

    @Slot(bool)
    def setFan(self, state):
        if fan:
            fan.on() if state else fan.off()

app = QGuiApplication(sys.argv)
engine = QQmlApplicationEngine()
backend = Backend()
engine.rootContext().setContextProperty("backend", backend)
engine.load(Path(__file__).parent / "Main.qml")
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())