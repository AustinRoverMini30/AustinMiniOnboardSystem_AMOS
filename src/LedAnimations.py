import math


LEFT_TO_RIGHT = 0
CENTER_TO_EDGES = 1
EDGES_TO_CENTER = 2
ANIMATION_MODES = (LEFT_TO_RIGHT, CENTER_TO_EDGES, EDGES_TO_CENTER)
SWEEP_OVERRUN = 0.2


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
    raise ValueError(f"Mode d'animation LED invalide : {mode}")


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
        distance = _light_distance(mode, position, phase)
        intensity = 0.88 * math.exp(-((distance / 0.12) ** 2) * 3)
        frame.append(tuple(round(channel * intensity) for channel in base_color))
    return frame
