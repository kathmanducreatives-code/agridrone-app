# AgriDrone Guardian Project Status

Last reviewed: 2026-06-19

## Canonical Runtime

- Active frontend URL: `http://localhost:51655/`
- Active frontend source tree: `/Users/prasidha/Downloads/agri-drone-datatrain/AgriDrone-Guardian`
- Active backend-style integration: `/Users/prasidha/Downloads/app.py`
- Active frontend framework: Flutter Web
- Active inference flow: Flutter calls FastAPI `POST /predict` with JSON containing `image_url` and either flight capture IDs or a test upload ID.
- Phase 2 AI explanation flow: FastAPI server-side endpoints under `/ai/*` use Claude/Anthropic only after YOLO/Supabase detection context exists. Flutter must never receive or store an Anthropic API key.

## Current End-To-End Flow

1. ESP32/ESP32-S3 captures a field image.
2. Image is uploaded to Supabase Storage bucket `drone-images`.
3. A Supabase row is written or updated for the image.
4. Flutter listens through Supabase Realtime for `flight_captures` and `detections` changes.
5. Operator reviews/selects an image in the Flutter Lab or Test AI screen.
6. Flutter calls the FastAPI/Hugging Face `/predict` endpoint.
7. FastAPI downloads the Supabase image URL, runs YOLO, writes detections back to Supabase, and marks the image processed.
8. Flutter refreshes the result view from Supabase.
9. Optional Phase 2 flow: backend `POST /ai/explain-analysis`, `/ai/recommendation`, `/ai/judge-summary`, or `/ai/report` turns trusted YOLO detection context into farmer-friendly guidance.

## Tables And Views Expected By The Active App

- `flight_captures`
- `detections`
- `flight_summary`
- `latest_detections`
- `flight_paths`
- `test_uploads`
- `test_detections`
- `test_upload_summary`
- `ai_explanations` (optional Phase 2 table; backend-generated Claude/Anthropic explanations)
- `ai_reports` (optional Phase 2 table; backend-generated Markdown reports)

## RPCs Expected By The Active App

- `mark_capture_reviewed(capture_id, is_rejected)`
- `request_capture_analysis(capture_id)`
- `create_test_upload(p_upload_uuid, p_source_filename, p_image_url, p_image_size, p_notes)`
- `request_test_analysis(upload_id)`
- `delete_test_upload(upload_id)`

## Secret Rotation Notice

The current demo still has prototype fallback values in Flutter config, the FastAPI worker default secret, and firmware config. Before real deployment, rotate all exposed Supabase service-role keys and backend/API secrets, then move runtime values to environment variables or build-time `--dart-define` values.

Claude/Anthropic Phase 2 variables are backend-only:

- `ANTHROPIC_API_KEY`
- `ANTHROPIC_MODEL` (defaults to `claude-sonnet-4-6`)
- `ANTHROPIC_TIMEOUT_SECONDS`
- `ANTHROPIC_MAX_RETRIES`
- `AGRIDRONE_AI_LANGUAGE_DEFAULT`

Do not add `ANTHROPIC_API_KEY` to Flutter, firmware, screenshots, logs, or client-visible build config.
