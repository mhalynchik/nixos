"""Original timer sounds and bounded, cancellable playback without master-volume changes."""
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import wave

MELODIES = ('signal', 'orbit', 'chime')
SOUND_DEFAULTS = {'timerVolume': 85, 'timerMelody': 'signal', 'timerRepeats': 3}


def valid_sound_setting(key, value):
    if key == 'timerVolume':
        return type(value) is int and 0 <= value <= 100
    if key == 'timerMelody':
        return isinstance(value, str) and value in MELODIES
    if key == 'timerRepeats':
        return type(value) is int and value in (1, 3, 5)
    return False


def sound_settings(values):
    """Repair only sound preferences; keep existing agenda/timer/history intact."""
    return {key: values.get(key) if valid_sound_setting(key, values.get(key)) else default
            for key, default in SOUND_DEFAULTS.items()}


def write_chime(path, melody='chime'):
    if melody not in MELODIES:
        raise ValueError('invalid_timer_melody')
    rate, duration = 24000, 3.2
    if melody == 'signal':
        notes = [(start, frequency) for start, frequency in
                 [(0, 880), (.28, 1174.66), (.56, 880), (1.25, 880), (1.53, 1174.66), (1.81, 880)]]
    elif melody == 'orbit':
        notes = [(i * .3, frequency) for i, frequency in enumerate([440, 659.25, 880, 1174.66, 880, 659.25])]
    else:
        notes = [(0, 523.25), (.28, 659.25), (.56, 783.99), (1.25, 1046.5)]
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        value = 0.0
        for start, frequency in notes:
            age = t - start
            if age < 0:
                continue
            if melody == 'signal':
                envelope = min(1, age / .012) * min(1, max(0, (.22 - age) / .035))
            else:
                envelope = min(1, age / .015) * math.exp(-3.3 * age)
            value += envelope * (math.sin(math.tau * frequency * age) + .15 * math.sin(math.tau * frequency * 2 * age))
        samples.append(value * min(1, (duration - t) / .1))
    gain = .78 / max(abs(sample) for sample in samples)
    frames = b''.join(struct.pack('<h', round(sample * gain * 32767)) for sample in samples)
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(frames)


def write_sounds(directory):
    for melody in MELODIES:
        write_chime(Path(directory) / ('timer-' + melody + '.wav'), melody)


class TimerSoundPlayer:
    """One paplay process at a time. Repeated clicks replace rather than layer audio."""
    def __init__(self, directory, clock=time.monotonic, spawn=subprocess.Popen):
        self.directory = Path(directory)
        self.clock = clock
        self.spawn = spawn
        self.process = None
        self.log = None
        self.remaining = 0
        self.next_at = 0
        self.started_at = 0
        self.arguments = []

    @property
    def active(self):
        return self.process is not None or self.remaining > 0

    def stop(self):
        self.remaining = 0
        if self.process is not None:
            if self.process.poll() is None:
                self.process.terminate()
                try:
                    self.process.wait(timeout=.2)
                except subprocess.TimeoutExpired:
                    self.process.kill()
                    self.process.wait(timeout=.2)
            self.process = None
        if self.log is not None:
            self.log.close()
            self.log = None

    def start(self, preferences, preview=False):
        self.stop()
        settings = sound_settings(preferences)
        if settings['timerVolume'] == 0:
            return
        self.arguments = ['paplay', '--client-name=Event Horizon', '--stream-name=Timer',
                          '--volume=' + str(round(settings['timerVolume'] * 65536 / 100)),
                          str(self.directory / ('timer-' + settings['timerMelody'] + '.wav'))]
        self.remaining = 1 if preview else settings['timerRepeats']
        self.next_at = self.clock()
        self.poll()

    def poll(self):
        now = self.clock()
        if self.process is not None:
            code = self.process.poll()
            if code is None:
                if now - self.started_at > 10:
                    self.stop()
                    raise RuntimeError('timer_sound_timeout')
                return
            self.process = None
            self.log.seek(0)
            error = self.log.read(350).strip()
            self.log.close()
            self.log = None
            if code:
                self.remaining = 0
                raise RuntimeError(error or 'timer_sound_failed')
            self.next_at = now + .8
        if self.remaining and now >= self.next_at:
            self.log = tempfile.TemporaryFile(mode='w+t')
            try:
                self.process = self.spawn(self.arguments, stdin=subprocess.DEVNULL,
                                          stdout=subprocess.DEVNULL, stderr=self.log)
            except OSError:
                self.log.close()
                self.log = None
                self.remaining = 0
                raise
            self.remaining -= 1
            self.started_at = now


if __name__ == '__main__':
    write_sounds(sys.argv[1])
