import os
import tempfile
import asyncio
import importlib.util
import sys
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, PlainTextResponse

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


worker_module = importlib.util.spec_from_file_location('whisper_idle', os.environ.get(
    'WHISPER_IDLE_PATH', str(Path(__file__).with_name('whisper-idle.py'))))
worker_module_object = importlib.util.module_from_spec(worker_module)
worker_module.loader.exec_module(worker_module_object)
worker = worker_module_object.IdleWorker(
    [sys.executable, os.environ.get('WHISPER_WORKER_PATH', str(Path(__file__).with_name('whisper-worker.py')))],
    idle_seconds=max(1, int(os.environ.get('WHISPER_IDLE_SECONDS', '300'))))


@asynccontextmanager
async def lifespan(app):
    yield
    await asyncio.to_thread(worker.close)


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    process = worker.process
    return {"status": "ok", "model": WHISPER_MODEL, "device": WHISPER_DEVICE,
            "model_loaded": process is not None and process.poll() is None}


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
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=True) as tmp:
        while chunk := await file.read(1024 * 1024):
            tmp.write(chunk)
        tmp.flush()
        return await asyncio.to_thread(worker.transcribe, tmp.name, language)


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
    try:
        text = await _text_from_upload(file, language or WHISPER_LANGUAGE)
    except (RuntimeError, OSError, ValueError, TimeoutError) as error:
        raise HTTPException(status_code=503, detail=str(error)) from error
    return _transcription_response(text, response_format)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=WHISPER_HOST, port=WHISPER_PORT)
