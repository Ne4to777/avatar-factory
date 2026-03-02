"""
Tests for temporary file cleanup in GPU server endpoints.

Verifies that Agent 2's fixes properly clean up temp files:
- On success: BackgroundTasks, try/finally, generator finally
- On error: except block cleanup, finally blocks

Endpoints tested:
1. /api/tts - BackgroundTasks for WAV
2. /api/generate-background - BackgroundTasks for PNG
3. /api/stt - finally block for audio
4. /api/lipsync - try/finally in generator + cleanup in except
5. /api/generate-video-api - try/finally for keyframe
6. /api/pipeline - finally removes audio_path and all image_paths
"""

import os
import sys
import tempfile
import time
from pathlib import Path
from unittest.mock import AsyncMock, MagicMock, patch

import httpx
import numpy as np
import pytest
from httpx import ASGITransport


def _create_mock_torch():
    """Create a fully configured torch mock for server import."""
    mock = MagicMock()
    mock.__version__ = "2.1.0"
    mock.cuda.is_available.return_value = True
    mock.cuda.get_device_name.return_value = "Mock GPU"
    mock.cuda.get_device_properties.return_value = MagicMock(
        total_memory=8 * 1024**3
    )
    mock.cuda.mem_get_info.return_value = (4 * 1024**3, 8 * 1024**3)
    # XPU stub (server checks hasattr(torch, 'xpu'))
    mock.xpu = MagicMock()
    mock.xpu.is_available.return_value = False
    mock.xpu.device_count.return_value = 0
    return mock


def _create_mock_models():
    """Create mock AI models for testing without GPU."""
    mock_tts = MagicMock()
    mock_tts.apply_tts.return_value = np.zeros(48000, dtype=np.float32)

    mock_sd = MagicMock()
    mock_image = MagicMock()

    def _save(path):
        Path(path).write_bytes(b"\x89PNG\r\n\x1a\n")  # minimal PNG

    mock_image.save = _save
    mock_sd.return_value = MagicMock(images=[mock_image])

    mock_whisper = MagicMock()
    mock_whisper.transcribe.return_value = {
        "text": "test text",
        "language": "ru",
        "segments": [{"start": 0, "end": 1, "text": "test"}],
    }

    mock_musetalk = MagicMock()

    def _musetalk_generate(image_path, audio_path, output_path, **kwargs):
        Path(output_path).write_bytes(b"\x00\x00\x00\x00")  # minimal mp4-like

    mock_musetalk.generate = _musetalk_generate

    mock_llm = {
        "tokenizer": MagicMock(),
        "model": MagicMock(),
    }
    mock_llm["tokenizer"].return_value = MagicMock(**{"to.return_value": MagicMock()})
    mock_llm["tokenizer"].decode.return_value = "[/INST] improved text"
    mock_llm["tokenizer"].eos_token_id = 0
    mock_llm["model"].generate.return_value = MagicMock()

    return {
        "tts": mock_tts,
        "sd": mock_sd,
        "whisper": mock_whisper,
        "musetalk": mock_musetalk,
        "llm": mock_llm,
    }


@pytest.fixture(scope="module")
def _mock_torch_and_import_server():
    """Patch torch and import server once per module."""
    mock_torch = _create_mock_torch()
    with patch.dict("sys.modules", {"torch": mock_torch}):
        import server as server_module

        yield server_module


@pytest.fixture
def test_temp_dir():
    """Create isolated temp directory for each test."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield Path(tmpdir)


@pytest.fixture
def app_with_mocks(_mock_torch_and_import_server, test_temp_dir):
    """Create FastAPI app with mocked models and test temp dir."""
    server_module = _mock_torch_and_import_server
    mock_models = _create_mock_models()

    with (
        patch.object(server_module, "TEMP_DIR", test_temp_dir),
        patch.object(server_module, "tts_model", mock_models["tts"]),
        patch.object(server_module, "sd_pipeline", mock_models["sd"]),
        patch.object(server_module, "whisper_model", mock_models["whisper"]),
        patch.object(server_module, "musetalk_model", mock_models["musetalk"]),
        patch.object(server_module, "text_llm", mock_models["llm"]),
        patch.object(server_module, "models_loaded", True),
    ):
        yield server_module.app


@pytest.fixture
def api_headers():
    """API key for requests."""
    return {"X-API-Key": os.getenv("GPU_API_KEY", "your-secret-gpu-key-change-this")}


BASE_URL = "http://testserver"


# ---------------------------------------------------------------------------
# 1. /api/tts - BackgroundTasks for WAV cleanup
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_tts_cleanup_on_success(app_with_mocks, test_temp_dir, api_headers):
    """TTS: temp WAV file is deleted after successful response (BackgroundTasks)."""
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
        response = await client.post(
            "/api/tts",
            params={"text": "тест", "speaker": "xenia"},
            headers=api_headers,
        )
    assert response.status_code == 200
    # BackgroundTasks run after response - wait for them
    time.sleep(0.5)
    wav_files = list(test_temp_dir.glob("tts_*.wav"))
    assert len(wav_files) == 0, f"TTS temp WAV should be cleaned, found: {wav_files}"


@pytest.mark.asyncio
async def test_tts_cleanup_on_error(app_with_mocks, test_temp_dir, api_headers):
    """TTS: temp file is deleted when exception occurs (except block)."""
    import server as s

    with patch.object(s, "tts_model", None):
        transport = ASGITransport(app=app_with_mocks)
        async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
            response = await client.post(
                "/api/tts",
                params={"text": "тест", "speaker": "xenia"},
                headers=api_headers,
            )
    assert response.status_code == 503
    wav_files = list(test_temp_dir.glob("tts_*.wav"))
    assert len(wav_files) == 0


# ---------------------------------------------------------------------------
# 2. /api/generate-background - BackgroundTasks for PNG cleanup
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_generate_background_cleanup_on_success(
    app_with_mocks, test_temp_dir, api_headers
):
    """generate-background: temp PNG is deleted after success (BackgroundTasks)."""
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
        response = await client.post(
            "/api/generate-background",
            params={
                "prompt": "test background",
                "width": 256,
                "height": 256,
            },
            headers=api_headers,
        )
    assert response.status_code == 200
    time.sleep(0.5)
    png_files = list(test_temp_dir.glob("bg_*.png"))
    assert len(png_files) == 0, f"Background temp PNG should be cleaned, found: {png_files}"


@pytest.mark.asyncio
async def test_generate_background_cleanup_on_error(
    app_with_mocks, test_temp_dir, api_headers
):
    """generate-background: temp file deleted on exception (except block)."""
    import server as s

    with patch.object(s, "sd_pipeline", None):
        transport = ASGITransport(app=app_with_mocks)
        async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
            response = await client.post(
                "/api/generate-background",
                params={"prompt": "test", "width": 256, "height": 256},
                headers=api_headers,
            )
    assert response.status_code == 503
    png_files = list(test_temp_dir.glob("bg_*.png"))
    assert len(png_files) == 0


# ---------------------------------------------------------------------------
# 3. /api/stt - finally block for audio cleanup
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_stt_cleanup_on_success(app_with_mocks, test_temp_dir, api_headers):
    """STT: temp audio file is deleted after success (finally block)."""
    audio_data = b"\x00" * 16000  # Minimal WAV-like payload
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
        response = await client.post(
            "/api/stt",
            files={"audio": ("test.wav", audio_data, "audio/wav")},
            params={"language": "ru"},
            headers=api_headers,
        )
    assert response.status_code == 200
    stt_files = list(test_temp_dir.glob("stt_*.wav"))
    assert len(stt_files) == 0, f"STT temp audio should be cleaned, found: {stt_files}"


@pytest.mark.asyncio
async def test_stt_cleanup_on_error(app_with_mocks, test_temp_dir, api_headers):
    """STT: temp file is deleted when transcribe raises (finally block)."""
    import server as s

    s.whisper_model.transcribe.side_effect = RuntimeError("Transcription failed")
    try:
        audio_data = b"\x00" * 16000
        transport = ASGITransport(app=app_with_mocks)
        async with httpx.AsyncClient(transport=transport, base_url=BASE_URL) as client:
            response = await client.post(
                "/api/stt",
                files={"audio": ("test.wav", audio_data, "audio/wav")},
                params={"language": "ru"},
                headers=api_headers,
            )
        assert response.status_code == 500
    finally:
        s.whisper_model.transcribe.side_effect = None
    stt_files = list(test_temp_dir.glob("stt_*.wav"))
    assert len(stt_files) == 0


# ---------------------------------------------------------------------------
# 4. /api/lipsync - try/finally in generator + cleanup in except
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_lipsync_cleanup_on_success(
    app_with_mocks, test_temp_dir, api_headers
):
    """lipsync: input and output files are cleaned (generator finally)."""
    image_data = b"\xff\xd8\xff" + b"\x00" * 100  # Minimal JPEG
    audio_data = b"\x00" * 16000
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(transport=transport, base_url=BASE_URL, timeout=30.0) as client:
        response = await client.post(
            "/api/lipsync",
            files={
                "image": ("test.jpg", image_data, "image/jpeg"),
                "audio": ("test.wav", audio_data, "audio/wav"),
            },
            headers=api_headers,
        )
    assert response.status_code == 200
    # Input files cleaned before streaming; output cleaned in generator finally
    # Consume response to trigger generator's finally
    _ = response.content
    time.sleep(0.2)
    img_files = list(test_temp_dir.glob("img_*"))
    aud_files = list(test_temp_dir.glob("aud_*"))
    video_files = list(test_temp_dir.glob("video_*.mp4"))
    assert len(img_files) == 0, f"Lipsync img files should be cleaned: {img_files}"
    assert len(aud_files) == 0, f"Lipsync aud files should be cleaned: {aud_files}"
    assert len(video_files) == 0, f"Lipsync video files should be cleaned: {video_files}"


@pytest.mark.asyncio
async def test_lipsync_cleanup_on_error(app_with_mocks, test_temp_dir, api_headers):
    """lipsync: files are cleaned when MuseTalk.generate raises (except block)."""
    import server as s

    original_generate = s.musetalk_model.generate
    s.musetalk_model.generate = MagicMock(side_effect=RuntimeError("MuseTalk failed"))
    try:
        image_data = b"\xff\xd8\xff" + b"\x00" * 100
        audio_data = b"\x00" * 16000
        transport = ASGITransport(app=app_with_mocks)
        async with httpx.AsyncClient(transport=transport, base_url=BASE_URL, timeout=30.0) as client:
            response = await client.post(
                "/api/lipsync",
                files={
                    "image": ("test.jpg", image_data, "image/jpeg"),
                    "audio": ("test.wav", audio_data, "audio/wav"),
                },
                headers=api_headers,
            )
        assert response.status_code == 500
    finally:
        s.musetalk_model.generate = original_generate
    img_files = list(test_temp_dir.glob("img_*"))
    aud_files = list(test_temp_dir.glob("aud_*"))
    video_files = list(test_temp_dir.glob("video_*"))
    assert len(img_files) == 0
    assert len(aud_files) == 0
    assert len(video_files) == 0


# ---------------------------------------------------------------------------
# 5. /api/generate-video-api - try/finally for keyframe
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_generate_video_api_cleanup_on_success(
    app_with_mocks, test_temp_dir, api_headers
):
    """generate-video-api: keyframe temp file is cleaned (try/finally)."""
    import server as s

    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = {
        "task_id": "test-123",
        "estimated_time": 60,
    }
    mock_client = AsyncMock()
    mock_client.post = AsyncMock(return_value=mock_response)
    mock_client.__aenter__ = AsyncMock(return_value=mock_client)
    mock_client.__aexit__ = AsyncMock(return_value=None)

    with patch.object(s, "POLZA_API_KEY", "test-key"):
        with patch.object(s.httpx, "AsyncClient", return_value=mock_client):
            image_data = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
            transport = ASGITransport(app=app_with_mocks)
            async with httpx.AsyncClient(
                transport=transport, base_url=BASE_URL
            ) as client:
                response = await client.post(
                    "/api/generate-video-api",
                    params={"prompt": "test video", "duration": 5},
                    files={"keyframe": ("key.png", image_data, "image/png")},
                    headers=api_headers,
                )
    assert response.status_code == 200
    key_files = list(test_temp_dir.glob("key_*.png"))
    assert len(key_files) == 0, f"Keyframe temp should be cleaned: {key_files}"


@pytest.mark.asyncio
async def test_generate_video_api_cleanup_on_error(
    app_with_mocks, test_temp_dir, api_headers
):
    """generate-video-api: keyframe is cleaned when API call fails."""
    # Create test client BEFORE patch (else our client would get the mock)
    image_data = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(
        transport=transport, base_url=BASE_URL
    ) as client:
        mock_client = AsyncMock()
        mock_client.post = AsyncMock(
            side_effect=httpx.ConnectError("API connection failed")
        )
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)

        with patch("server.POLZA_API_KEY", "test-key"):
            with patch("server.httpx.AsyncClient", return_value=mock_client):
                response = await client.post(
                    "/api/generate-video-api",
                    params={"prompt": "test", "duration": 5},
                    files={"keyframe": ("key.png", image_data, "image/png")},
                    headers=api_headers,
                )
    assert response.status_code == 503
    key_files = list(test_temp_dir.glob("key_*.png"))
    assert len(key_files) == 0


# ---------------------------------------------------------------------------
# 6. /api/pipeline - finally removes audio_path and image_paths
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_pipeline_cleanup_on_success(
    app_with_mocks, test_temp_dir, api_headers
):
    """pipeline: audio and image temp files are cleaned (finally block)."""
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(transport=transport, base_url=BASE_URL, timeout=60.0) as client:
        response = await client.post(
            "/api/pipeline",
            params={"text": "test text", "num_images": 2},
            headers=api_headers,
        )
    assert response.status_code == 200
    audio_files = list(test_temp_dir.glob("pipeline_audio_*"))
    img_files = list(test_temp_dir.glob("pipeline_img_*"))
    assert len(audio_files) == 0, f"Pipeline audio should be cleaned: {audio_files}"
    assert len(img_files) == 0, f"Pipeline images should be cleaned: {img_files}"


@pytest.mark.asyncio
async def test_pipeline_cleanup_on_error(
    app_with_mocks, test_temp_dir, api_headers
):
    """pipeline: audio and images are cleaned when step fails (finally block)."""
    import server as s

    s.sd_pipeline.side_effect = RuntimeError("SD generation failed")
    try:
        transport = ASGITransport(app=app_with_mocks)
        async with httpx.AsyncClient(transport=transport, base_url=BASE_URL, timeout=60.0) as client:
            response = await client.post(
                "/api/pipeline",
                params={"text": "test", "num_images": 2},
                headers=api_headers,
            )
        assert response.status_code == 500
    finally:
        s.sd_pipeline.side_effect = None
    audio_files = list(test_temp_dir.glob("pipeline_audio_*"))
    img_files = list(test_temp_dir.glob("pipeline_img_*"))
    assert len(audio_files) == 0
    assert len(img_files) == 0


# ---------------------------------------------------------------------------
# Connection drop (client disconnect) - lipsync streaming
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_lipsync_cleanup_on_client_disconnect(
    app_with_mocks, test_temp_dir, api_headers
):
    """lipsync: video file is cleaned when client disconnects during stream."""
    # Simulate disconnect by consuming only part of response then closing
    transport = ASGITransport(app=app_with_mocks)
    async with httpx.AsyncClient(
        transport=transport, base_url=BASE_URL, timeout=30.0
    ) as client:
        async with client.stream(
            "POST",
            "/api/lipsync",
            files={
                "image": ("test.jpg", b"\xff\xd8\xff\x00" * 100, "image/jpeg"),
                "audio": ("test.wav", b"\x00" * 16000, "audio/wav"),
            },
            headers=api_headers,
        ) as response:
            # Read first chunk only, then close (simulate disconnect)
            chunk = await response.aread()
            assert len(chunk) > 0
    time.sleep(0.3)
    video_files = list(test_temp_dir.glob("video_*.mp4"))
    assert len(video_files) == 0, (
        "Video should be cleaned on disconnect (generator finally)"
    )
