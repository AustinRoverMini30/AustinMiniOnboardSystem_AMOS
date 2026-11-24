import math


LEFT_TO_RIGHT = 0
CENTER_TO_EDGES = 1
EDGES_TO_CENTER = 2
FUTURISTIC_FLASH = 3
GAUGE_FILL = 4
ANIMATION_MODES = (
    LEFT_TO_RIGHT,
    CENTER_TO_EDGES,
    EDGES_TO_CENTER,
    FUTURISTIC_FLASH,
    GAUGE_FILL,
)
SWEEP_OVERRUN = 0.2
GAUGE_FILL_BEAM_WIDTH = 1 / 14
GAUGE_FILL_CYCLES = round(1 / GAUGE_FILL_BEAM_WIDTH)
GAUGE_FILL_BEAM_SIGMA = GAUGE_FILL_BEAM_WIDTH / 1.75
GAUGE_FILL_DURATION_MS = 6000
GAUGE_FILL_TIMER_INTERVAL_MS = 25


def _light_distance(mode, position, phase):
    if mode == LEFT_TO_RIGHT:
        sweep_position = -SWEEP_OVERRUN + phase * (1 + 2 * SWEEP_OVERRUN)
        return abs(position - sweep_position)
    if mode == CENTER_TO_EDGES:
        sweep_distance = -SWEEP_OVERRUN + phase * (1 + 2 * SWEEP_OVERRUN)
        return abs(abs(position - 0.5) * 2 - sweep_distance)
    if mode == EDGES_TO_CENTER:
        sweep_distance = 1 + SWEEP_OVERRUN - phase * (1 + 2 * SWEEP_OVERRUN)
        return abs(abs(position - 0.5) * 2 - sweep_distance)
    if mode == FUTURISTIC_FLASH:
        progress = phase ** 3
        return max(0.0, position - progress)
    raise ValueError(f"Mode d'animation LED invalide : {mode}")


def _smooth_step(edge0, edge1, value):
    amount = min(1.0, max(0.0, (value - edge0) / (edge1 - edge0)))
    return amount * amount * (3 - 2 * amount)


def _gauge_fill_state(phase):
    progress = min(1.0, max(0.0, phase)) * GAUGE_FILL_CYCLES
    completed_cycles = min(GAUGE_FILL_CYCLES, int(progress + 1e-9))
    sweep_progress = progress - completed_cycles
    return completed_cycles, sweep_progress


def build_animation_frame(mode, phase, led_count, base_color):
    if mode not in ANIMATION_MODES:
        raise ValueError(f"Mode d'animation LED invalide : {mode}")
    if led_count < 1:
        raise ValueError("Le nombre de LED doit être supérieur à zéro.")
    if len(base_color) != 3:
        raise ValueError("La couleur doit contenir les composantes rouge, vert et bleu.")

    frame = []
    for index in range(led_count):
        position = index / max(led_count - 1, 1)
        if mode == FUTURISTIC_FLASH:
            progress = phase ** 3
            if phase >= 1:
                intensity = 1.0
            elif position <= progress:
                flash_phase = phase + 8 * phase ** 2
                intensity = 1.0 if math.sin(2 * math.pi * flash_phase) > 0 else 0.0
            else:
                intensity = 0.0
        elif mode == GAUGE_FILL:
            completed_cycles, sweep_progress = _gauge_fill_state(phase)
            fill_progress = completed_cycles / GAUGE_FILL_CYCLES
            if completed_cycles == 0:
                filled_from_right = 0.0
            elif completed_cycles == GAUGE_FILL_CYCLES:
                filled_from_right = 1.0
            else:
                fill_boundary = 1 - fill_progress
                filled_from_right = _smooth_step(
                    fill_boundary - 0.015, fill_boundary + 0.015, position
                )
            beam = math.exp(
                -((position - sweep_progress) / GAUGE_FILL_BEAM_SIGMA) ** 2 * 3
            )
            if phase >= 1:
                beam = 0.0
            intensity = max(filled_from_right, 0.88 * beam)
        else:
            distance = _light_distance(mode, position, phase)
            intensity = 0.88 * math.exp(-((distance / 0.12) ** 2) * 3)
        frame.append(tuple(round(channel * intensity) for channel in base_color))
    return frame
