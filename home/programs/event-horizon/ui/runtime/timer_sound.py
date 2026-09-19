"""Generate the short, original timer chime at package build time."""
import math
from pathlib import Path
import struct
import sys
import wave


def write_chime(path):
    rate, duration = 24000, 3.2
    notes = [(0.0, 523.25), (0.28, 659.25), (0.56, 783.99), (1.25, 1046.5)]
    frames = bytearray()
    for i in range(int(rate * duration)):
        t = i / rate
        value = 0.0
        for start, frequency in notes:
            age = t - start
            if age < 0:
                continue
            envelope = min(1.0, age / .015) * math.exp(-3.3 * age)
            value += .23 * envelope * (math.sin(math.tau * frequency * age) + .15 * math.sin(math.tau * frequency * 2 * age))
        value *= min(1.0, (duration - t) / .1)
        frames.extend(struct.pack('<h', round(max(-1, min(1, value)) * 32767)))
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(frames)


if __name__ == '__main__':
    write_chime(sys.argv[1])
