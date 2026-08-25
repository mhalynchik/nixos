import os
import tempfile
import threading

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse
from faster_whisper import WhisperModel

WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "medium")
WHISPER_LANGUAGE = os.environ.get("WHISPER_LANGUAGE", "ru")
WHISPER_DEVICE = os.environ.get("WHISPER_DEVICE", "cpu")
WHISPER_COMPUTE_TYPE = os.environ.get(
    "WHISPER_COMPUTE_TYPE",
    "int8" if WHISPER_DEVICE == "cpu" else "float16",
)
WHISPER_HOST = os.environ.get("WHISPER_HOST", "127.0.0.1")
WHISPER_PORT = int(os.environ.get("WHISPER_PORT", "8178"))
WHISPER_DOWNLOAD_ROOT = os.environ.get("WHISPER_DOWNLOAD_ROOT", "/var/lib/whisper/models")


def _whisper_model_from_env():
    try:
        return WhisperModel(
            WHISPER_MODEL,
            device=WHISPER_DEVICE,
            compute_type=WHISPER_COMPUTE_TYPE,
            download_root=WHISPER_DOWNLOAD_ROOT,
        )
    except Exception:
        if WHISPER_DEVICE == "cpu":
            raise
        return WhisperModel(
            WHISPER_MODEL,
            device="cpu",
            compute_type="int8",
            download_root=WHISPER_DOWNLOAD_ROOT,
        )


def _text_from_audio_path(model, path, language):
    segments, _info = model.transcribe(path, language=language or None)
    return "".join(segment.text for segment in segments).strip()


whisper_model = None
whisper_error = None
whisper_ready = threading.Event()


def _load_whisper_model():
    global whisper_model, whisper_error
    print(
        f"loading whisper model {WHISPER_MODEL} device={WHISPER_DEVICE}",
        flush=True,
    )
    try:
        whisper_model = _whisper_model_from_env()
        whisper_ready.set()
        print("whisper model ready", flush=True)
    except Exception as exc:
        whisper_error = str(exc)
        print(f"whisper model failed: {exc}", flush=True)
        raise


app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    if whisper_ready.is_set():
        return {"status": "ok", "model": WHISPER_MODEL, "device": WHISPER_DEVICE}
    if whisper_error:
        return JSONResponse(
            {"status": "error", "error": whisper_error, "model": WHISPER_MODEL},
            status_code=503,
        )
    return JSONResponse(
        {"status": "loading", "model": WHISPER_MODEL, "device": WHISPER_DEVICE},
        status_code=503,
    )


@app.get("/v1/models")
def models():
    return {
        "object": "list",
        "data": [
            {"id": "whisper-1", "object": "model", "owned_by": "local"},
            {"id": WHISPER_MODEL, "object": "model", "owned_by": "local"},
        ],
    }


async def _text_from_upload(file, language):
    suffix = os.path.splitext(file.filename or "")[1] or ".audio"
    data = await file.read()
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        tmp.write(data)
        tmp.flush()
        return _text_from_audio_path(whisper_model, tmp.name, language)


def _transcription_response(text, response_format):
    if response_format == "text":
        return PlainTextResponse(text)
    return JSONResponse({"text": text})


@app.post("/v1/audio/transcriptions")
@app.post("/audio/transcriptions")
async def transcribe_audio(
    file: UploadFile = File(...),
    model: str = Form("whisper-1"),
    language: str | None = Form(None),
    response_format: str = Form("json"),
):
    _ = model
    if not whisper_ready.is_set():
        raise HTTPException(status_code=503, detail=whisper_error or "model still loading")
    text = await _text_from_upload(file, language or WHISPER_LANGUAGE)
    return _transcription_response(text, response_format)


if __name__ == "__main__":
    import uvicorn

    threading.Thread(target=_load_whisper_model, daemon=True, name="whisper-load").start()
    uvicorn.run(app, host=WHISPER_HOST, port=WHISPER_PORT)
