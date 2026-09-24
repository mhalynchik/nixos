"""Small, versioned placement profiles for desktop widgets.

Coordinates are fractions of the output's logical size; scale is relative to the
2560×1440 design. No output resolution or compositor identifier is persisted.
"""
import copy
import json
import math
from pathlib import Path

from idle_settings import atomic_write, state_root

DEFAULTS = {
    'clock': {'x': 105 / 2560, 'y': 142 / 1440, 'scale': 1.0, 'visible': True},
    'calendar': {'x': 106 / 2560, 'y': 400 / 1440, 'scale': 1.0, 'visible': True},
    'media': {'x': 93 / 2560, 'y': 848 / 1440, 'scale': 1.0, 'visible': True},
}
MAX_PROFILES = 128


def profile_key(monitor, wallpaper):
    if not isinstance(monitor, str) or not monitor or len(monitor) > 256:
        raise ValueError('Не удалось определить монитор.')
    if not isinstance(wallpaper, str) or len(wallpaper) > 4096:
        raise ValueError('Не удалось определить обои.')
    return json.dumps([monitor, wallpaper], ensure_ascii=False, separators=(',', ':'))


def validate(widgets):
    if not isinstance(widgets, dict) or set(widgets) != set(DEFAULTS):
        raise ValueError('В профиле должны быть часы, календарь и плеер.')
    clean = {}
    for name, widget in widgets.items():
        if not isinstance(widget, dict) or set(widget) != {'x', 'y', 'scale', 'visible'}:
            raise ValueError('Некорректное размещение виджета.')
        for field, minimum, maximum in [('x', 0, 1), ('y', 0, 1), ('scale', .55, 1.6)]:
            number = widget[field]
            if type(number) not in (int, float) or not math.isfinite(number) or not minimum <= number <= maximum:
                raise ValueError('Размер или положение виджета вне допустимого диапазона.')
        if type(widget['visible']) is not bool:
            raise ValueError('Некорректная видимость виджета.')
        clean[name] = dict(widget)
    return clean


class WidgetLayouts:
    def __init__(self, path=None):
        self.path = Path(path) if path is not None else state_root() / 'widget-layouts.json'
        self.profiles = {}
        self.error = ''
        try:
            data = json.loads(self.path.read_text())
            if not isinstance(data, dict) or data.get('version') != 1 or not isinstance(data.get('profiles'), dict):
                raise ValueError('неизвестный формат')
            if len(data['profiles']) > MAX_PROFILES:
                raise ValueError('слишком много профилей')
            for key, widgets in data['profiles'].items():
                context = json.loads(key)
                if not isinstance(context, list) or len(context) != 2 or key != profile_key(*context):
                    raise ValueError('некорректный профиль')
                self.profiles[key] = validate(widgets)
        except FileNotFoundError:
            pass
        except (OSError, ValueError, TypeError) as error:
            self.profiles = {}
            self.error = 'Не удалось прочитать размещение виджетов: ' + str(error)

    def snapshot(self, wallpaper=''):
        return {'profiles': copy.deepcopy(self.profiles), 'wallpaper': wallpaper, 'defaults': copy.deepcopy(DEFAULTS)}

    def resolve(self, monitor, wallpaper=''):
        return copy.deepcopy(self.profiles.get(profile_key(monitor, wallpaper),
            self.profiles.get(profile_key(monitor, ''), DEFAULTS)))

    def _write(self, profiles):
        atomic_write(self.path, json.dumps({'version': 1, 'profiles': profiles}, ensure_ascii=False) + '\n')
        self.profiles = profiles
        self.error = ''

    def save(self, monitor, wallpaper, widgets):
        key = profile_key(monitor, wallpaper)
        candidate = dict(self.profiles)
        candidate.pop(key, None)
        candidate[key] = validate(widgets)
        while len(candidate) > MAX_PROFILES:
            del candidate[next(iter(candidate))]
        self._write(candidate)

    def reset(self, monitor, wallpaper):
        key = profile_key(monitor, wallpaper)
        candidate = dict(self.profiles)
        candidate.pop(key, None)
        self._write(candidate)
