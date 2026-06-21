# Active Schema Expectations

This document reflects what the active Flutter app expects today. It is intentionally more current than the older handover schema files.

## `flight_captures`

One row per drone image.

Expected fields:

- `id`
- `flight_id`
- `image_index`
- `device_id`
- `image_path`
- `image_url`
- `moisture_raw`
- `moisture_pct`
- `captured_at_ms`
- `uploaded_at`
- `ai_processed`
- `reviewed`
- `rejected`
- `analysis_requested_at`
- `gps_lat`
- `gps_lon`
- `gps_altitude_m`
- `gps_fix_quality`
- `gps_satellites`
- `gps_hdop`

Compatibility note: keep `ai_processed` for the current demo. A richer `analysis_status` lifecycle can be added later without removing the boolean.

## `detections`

One row per YOLO detection box.

Expected fields:

- `id`
- `flight_capture_id`
- `flight_id`
- `image_index`
- `label`
- `confidence`
- `bbox_x1`
- `bbox_y1`
- `bbox_x2`
- `bbox_y2`
- `inference_time_ms`
- `detected_at`

## Views

- `flight_summary`: aggregate flight counts, pending review counts, rejected counts, analyzed counts, moisture, detections, and last upload timestamp.
- `latest_detections`: recent detection rows joined with the image URL.
- `flight_paths`: GPS-enabled captures for map display.
- `test_upload_summary`: test upload history joined/aggregated with detection count, labels, and max confidence.

## Phase 2 AI Explanation Tables

These tables are optional until the Phase 2 migration is reviewed and applied. They are written by the backend service role, not directly by Flutter.

`ai_explanations` expected fields:

- `id`
- `capture_id`
- `detection_id`
- `provider`
- `language`
- `disease_name`
- `confidence`
- `severity`
- `summary`
- `likely_causes`
- `farmer_friendly_explanation`
- `immediate_actions`
- `organic_treatment`
- `chemical_treatment`
- `prevention_tips`
- `confidence_disclaimer`
- `expert_escalation`
- `raw_ai_json`
- `prompt_version`
- `model_name`
- `created_at`

`ai_reports` expected fields:

- `id`
- `capture_id`
- `detection_id`
- `explanation_id`
- `provider`
- `title`
- `report_markdown`
- `report_json`
- `language`
- `created_at`

## Test Upload Tables

`test_uploads` expected fields:

- `id`
- `upload_uuid`
- `source_filename`
- `image_url`
- `image_size_bytes`
- `uploaded_by`
- `uploaded_at`
- `analysis_requested_at`
- `ai_processed`
- `notes`

`test_detections` expected fields:

- `id`
- `test_upload_id`
- `label`
- `confidence`
- `bbox_x1`
- `bbox_y1`
- `bbox_x2`
- `bbox_y2`
- `inference_time_ms`
- `detected_at`

## RPCs

- `mark_capture_reviewed(capture_id, is_rejected)`: marks a capture reviewed and optionally rejected.
- `request_capture_analysis(capture_id)`: marks a capture reviewed, not rejected, and sets `analysis_requested_at`.
- `create_test_upload(p_upload_uuid, p_source_filename, p_image_url, p_image_size, p_notes)`: creates a test upload and returns its ID.
- `request_test_analysis(upload_id)`: sets `analysis_requested_at` for a test upload.
- `delete_test_upload(upload_id)`: deletes a test upload and cascades/removes its detections.

## Future Analysis Status Lifecycle

Recommended statuses for Phase 2+:

- `uploaded`
- `review_pending`
- `analysis_requested`
- `queued`
- `processing`
- `detected`
- `no_detection`
- `failed`
- `explained`

These should be introduced alongside `ai_processed`, not as a breaking replacement.
