"""Short-lived inference process. Heavy libraries stay out of the HTTP server."""
import json
import os
import sys


def main():
    from faster_whisper import WhisperModel
    device = os.environ.get('WHISPER_DEVICE', 'cpu')
    options = dict(download_root=os.environ.get('WHISPER_DOWNLOAD_ROOT', '/var/lib/whisper/models'))
    try:
        model = WhisperModel(os.environ.get('WHISPER_MODEL', 'medium'), device=device,
            compute_type=os.environ.get('WHISPER_COMPUTE_TYPE', 'int8' if device == 'cpu' else 'float16'), **options)
    except Exception:
        if device == 'cpu':
            raise
        model = WhisperModel(os.environ.get('WHISPER_MODEL', 'medium'), device='cpu', compute_type='int8', **options)
    for line in sys.stdin:
        request = json.loads(line)
        try:
            segments, _ = model.transcribe(request['path'], language=request['language'] or None)
            print(json.dumps({'text': ''.join(segment.text for segment in segments).strip()}), flush=True)
        except Exception as error:
            print(json.dumps({'error': str(error)}), flush=True)


if __name__ == '__main__':
    main()
