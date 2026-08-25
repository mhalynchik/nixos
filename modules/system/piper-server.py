import base64
import os
import subprocess
import tempfile

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, ConfigDict, Field

PIPER_BIN = os.environ.get("PIPER_BIN", "piper")
PIPER_VOICE = os.environ["PIPER_VOICE"]
PIPER_CONFIG = os.environ.get("PIPER_CONFIG", f"{PIPER_VOICE}.json")
PIPER_HOST = os.environ.get("PIPER_HOST", "127.0.0.1")
PIPER_PORT = int(os.environ.get("PIPER_PORT", "8179"))
FFMPEG_BIN = os.environ.get("FFMPEG_BIN", "ffmpeg")


class SpeechBody(BaseModel):
    model: str = "piper-tts"
    input: str | list[str]
    voice: str = ""
    response_format: str = "wav"


class Player2SpeakBody(BaseModel):
    model_config = ConfigDict(extra="ignore")

    text: str = ""
    play_in_app: bool = False
    speed: float = 1.0
    voice_ids: list[str] = Field(default_factory=list)
    audio_format: str = "mp3"


def _text_from_body(body: SpeechBody) -> str:
    if isinstance(body.input, list):
        return "\n".join(body.input).strip()
    return body.input.strip()


def _wav_from_text(text: str) -> bytes:
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp:
        proc = subprocess.run(
            [
                PIPER_BIN,
                "--model",
                PIPER_VOICE,
                "--config",
                PIPER_CONFIG,
                "--output_file",
                tmp.name,
                "--quiet",
            ],
            input=text.encode("utf-8"),
            capture_output=True,
            check=False,
        )
        if proc.returncode != 0:
            err = proc.stderr.decode("utf-8", errors="replace")[:400]
            raise RuntimeError(err or f"piper exit {proc.returncode}")
        tmp.seek(0)
        return tmp.read()


def _mp3_from_wav(wav: bytes) -> bytes:
    proc = subprocess.run(
        [
            FFMPEG_BIN,
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            "pipe:0",
            "-f",
            "mp3",
            "pipe:1",
        ],
        input=wav,
        capture_output=True,
        check=False,
    )
    if proc.returncode != 0:
        err = proc.stderr.decode("utf-8", errors="replace")[:400]
        raise RuntimeError(err or f"ffmpeg exit {proc.returncode}")
    return proc.stdout


app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
@app.get("/v1")
@app.get("/v1/")
@app.get("/health")
@app.get("/v1/health")
def health():
    return {"status": "ok", "engine": "piper", "voice": os.path.basename(PIPER_VOICE)}


@app.get("/v1/tts/voices")
@app.get("/tts/voices")
def player2_voices():
    return {
        "voices": [
            {
                "id": "irina",
                "name": "Irina (русский, Piper)",
                "gender": "female",
                "language": "american_english",
            }
        ]
    }


@app.post("/v1/tts/speak")
@app.post("/tts/speak")
def speak_player2_text(body: Player2SpeakBody):
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="text is empty")
    try:
        wav = _wav_from_text(text)
        fmt = (body.audio_format or "mp3").lower()
        audio = _mp3_from_wav(wav) if fmt in ("mp3", "mpeg") else wav
        return {"data": base64.b64encode(audio).decode("ascii")}
    except RuntimeError as exc:
        return JSONResponse({"error": str(exc)}, status_code=500)


@app.get("/v1/models")
def models():
    return {
        "object": "list",
        "data": [
            {"id": "piper-tts", "object": "model", "owned_by": "local"},
            {"id": "tts-1", "object": "model", "owned_by": "local"},
        ],
    }


@app.post("/v1/audio/speech")
@app.post("/audio/speech")
def speak_text(body: SpeechBody):
    text = _text_from_body(body)
    if not text:
        raise HTTPException(status_code=400, detail="input is empty")
    try:
        wav = _wav_from_text(text)
        fmt = (body.response_format or "wav").lower()
        if fmt in ("mp3", "mpeg"):
            return Response(content=_mp3_from_wav(wav), media_type="audio/mpeg")
        return Response(content=wav, media_type="audio/wav")
    except RuntimeError as exc:
        return JSONResponse({"error": str(exc)}, status_code=500)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=PIPER_HOST, port=PIPER_PORT)
