# Demo Readiness Checklist

## Start Frontend

```bash
cd /Users/prasidha/Downloads/agri-drone-datatrain/AgriDrone-Guardian
flutter pub get
flutter run -d chrome
```

Expected active URL: `http://localhost:51655/` when Flutter chooses that port.

## Start Backend

For the active JSON `/predict` worker:

```bash
cd /Users/prasidha/Downloads
uvicorn app:app --host 0.0.0.0 --port 8000
```

For Hugging Face Spaces, verify the deployed Space uses the same request shape as `/Users/prasidha/Downloads/app.py`.

Optional Phase 2 AI explanation variables are backend-only:

```bash
export ANTHROPIC_API_KEY="PASTE_ANTHROPIC_API_KEY_HERE"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-4-6}"
export ANTHROPIC_TIMEOUT_SECONDS="${ANTHROPIC_TIMEOUT_SECONDS:-30}"
export ANTHROPIC_MAX_RETRIES="${ANTHROPIC_MAX_RETRIES:-2}"
export AGRIDRONE_AI_LANGUAGE_DEFAULT="${AGRIDRONE_AI_LANGUAGE_DEFAULT:-en}"
```

Never put `ANTHROPIC_API_KEY` in Flutter or firmware.

## Verify Supabase Connection

In the app, open Settings and use `TEST SUPABASE`.

Manual smoke check:

```bash
curl -I "$SUPABASE_URL/rest/v1/flight_captures?select=id&limit=1"
```

Use the correct anon/service key only in a local shell environment. Do not paste keys into logs or screenshots.

## Verify Realtime

Open Dashboard or Lab and confirm the status reads `CONNECTED`. If disconnected, use Settings -> Re-subscribe Realtime and refresh the app.

## Verify FastAPI / Hugging Face

```bash
curl --max-time 20 https://prasidhaaaa-aimodel.hf.space/health
```

The response should include service status, model readiness, Supabase writeback status, and a timestamp.

For a local Phase 2 backend smoke test:

```bash
curl --max-time 20 http://127.0.0.1:8001/health
```

The response should include `ai_provider`, `anthropic_configured`, `anthropic_model`, `anthropic_timeout_seconds`, and `ai_endpoints_available`.

## Verify Claude Explanation Layer

Use fallback context only when Supabase env vars are missing locally:

```bash
curl --max-time 45 http://127.0.0.1:8001/ai/explain-analysis \
  -H "Authorization: Bearer $API_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "language": "en",
    "farmer_level": "simple",
    "detection_context": {
      "disease_name": "Brown Spot Disease",
      "confidence": 0.78,
      "severity": "moderate",
      "crop_type": "rice",
      "moisture_pct": 42
    }
  }'
```

If `ANTHROPIC_API_KEY` is missing, the endpoint should return a structured `anthropic_not_configured` error without crashing the backend.

## Test One Image Analysis

1. Open Lab or Test AI.
2. Pick one known image with a valid public Supabase Storage URL.
3. Run analysis.
4. Confirm a success, no-detection, or clear failure message appears.
5. Confirm `detections` or `test_detections` changes in Supabase if detections are found.

## Fallback Plan If Hugging Face Is Slow

- Run the health check before judges arrive; cold starts can be slow.
- Keep one already-analyzed image in the database.
- Show Dashboard, Lab detail, and existing detection overlays if live inference is delayed.
- If Claude is slow or unavailable, explain from the saved YOLO detection and show the existing detection overlay; the visual AI flow still works without the explanation layer.
- Keep the backend logs visible privately so the operator can tell whether the delay is image download, model load, inference, or Supabase writeback.
