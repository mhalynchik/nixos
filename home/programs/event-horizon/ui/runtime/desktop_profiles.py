"""User-editable desktop modes; external controls supplied by the session adapter."""
import copy
import json
import math
from pathlib import Path
from idle_settings import atomic_write

DEFAULTS = {
    'work': {'dnd': True, 'volume': 30, 'brightness': 70, 'widgets': {'clock': True, 'calendar': True, 'media': False}},
    'music': {'dnd': False, 'volume': 60, 'brightness': 60, 'widgets': {'clock': True, 'calendar': False, 'media': True}},
    'evening': {'dnd': True, 'volume': 25, 'brightness': 30, 'widgets': {'clock': True, 'calendar': True, 'media': True}},
}


def validate(value):
    if not isinstance(value, dict) or type(value.get('dnd')) is not bool:
        raise ValueError('invalid_profile')
    for field in ['volume', 'brightness']:
        number = value.get(field)
        if number is not None and (type(number) is not int or not 0 <= number <= 100):
            raise ValueError('invalid_profile')
    widgets = value.get('widgets')
    if not isinstance(widgets, dict) or set(widgets) != {'clock', 'calendar', 'media'} or any(type(v) is not bool for v in widgets.values()):
        raise ValueError('invalid_profile')
    return {key: copy.deepcopy(value[key]) for key in ['dnd', 'volume', 'brightness', 'widgets']}


def snapshot(value):
    # A saved real system level may exceed the preset's nominal 100% ceiling.
    result=validate(dict(value, volume=None))
    level=value.get('volume')
    if level is not None and (type(level) not in (int,float) or not math.isfinite(level) or not 0<=level<=1000):
        raise ValueError('invalid_profile')
    result['volume']=level
    for key in ['outputName','brightnessDevice']:
        if key in value:
            if not isinstance(value[key],str) or len(value[key])>512:raise ValueError('invalid_profile')
            result[key]=value[key]
    return result


class DesktopProfiles:
    def __init__(self, path):
        self.path = Path(path)
        self.presets = copy.deepcopy(DEFAULTS)
        self.active = ''
        self.active_widgets = {}
        self.previous = None
        try:
            stored = json.loads(self.path.read_text())
            for name in DEFAULTS:
                if name in stored.get('presets', {}):
                    try: self.presets[name] = validate(stored['presets'][name])
                    except (ValueError, KeyError, TypeError): pass
            if stored.get('active') in DEFAULTS:
                self.active=stored['active'];self.active_widgets=dict(self.presets[self.active]['widgets'])
            if stored.get('previous') is not None:
                try:self.previous=snapshot(stored['previous'])
                except (ValueError,KeyError,TypeError):pass
        except (OSError, ValueError, TypeError, AttributeError):
            pass

    def snapshot(self):
        return {'presets': copy.deepcopy(self.presets), 'active': self.active,
                'activeWidgets': dict(self.active_widgets), 'canRestore': self.previous is not None}

    def persist(self, presets=None):
        atomic_write(self.path, json.dumps({'version':1,'presets':presets or self.presets,'active':self.active,'previous':self.previous})+'\n')

    def save(self, name, values):
        if name not in DEFAULTS: raise ValueError('invalid_profile')
        candidate = validate(values)
        presets = dict(self.presets, **{name: candidate})
        self.persist(presets)
        self.presets = presets

    def apply(self, name, capture, apply):
        if name not in self.presets: raise ValueError('invalid_profile')
        before = capture()
        old=(self.active, self.active_widgets, self.previous)
        try:
            apply(self.presets[name])
            if self.previous is None:
                self.previous = dict(before, widgets={key:self.active_widgets.get(key,True) for key in ['clock','calendar','media']})
            self.active = name
            self.active_widgets = dict(self.presets[name]['widgets'])
            self.persist()
        except Exception:
            self.active,self.active_widgets,self.previous=old
            apply(before)
            raise

    def restore(self, apply, capture=None):
        if self.previous is None: return
        old=(self.active, self.active_widgets, self.previous)
        before=capture() if capture else self.presets.get(self.active)
        try:
            apply(self.previous)
            self.active_widgets = self.previous['widgets']
            self.active = ''
            self.previous = None
            self.persist()
        except Exception:
            self.active,self.active_widgets,self.previous=old
            if before is not None:apply(before)
            raise
