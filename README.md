# AgriDrone Guardian

Flutter control panel for AgriDrone mission control, Firebase telemetry, and backend/ESP32 developer tooling.

## Active Demo Status

The canonical active frontend for the current demo is this directory:

```text
/Users/prasidha/Downloads/agri-drone-datatrain/AgriDrone-Guardian
```

The active JSON FastAPI worker shape is documented against:

```text
/Users/prasidha/Downloads/app.py
```

See `PROJECT_STATUS.md`, `docs/ACTIVE_SCHEMA_EXPECTATIONS.md`, and `docs/DEMO_READINESS.md` before changing the Supabase schema, FastAPI integration, or demo startup flow.

Phase 2 adds backend-only Claude/Anthropic explanation endpoints under `/ai/*` in `/Users/prasidha/Downloads/app.py`. YOLO/Hugging Face remains the detector; Claude only turns trusted detection context into explanations, recommendations, judge summaries, and reports.

## Developer Tools

The app now includes a dedicated Developer Tools section with:
- ESP32 local controls using a persisted configurable IP address
- Backend multipart upload testing against `/predict_form`
- Latest backend debug image viewer for `/debug/latest.jpg`
- Firebase status and diagnostics panels

## Deployment Safety

Vercel routing is kept stable by:
- keeping `vercel.json` in the project root
- copying `vercel.json` into `build/web/vercel.json` during web builds
- deploying `build/web` instead of the repository root
- using a rewrite that sends all routes to `index.html`

## Local Run

```bash
flutter pub get
flutter run -d macos
```

## Web Build

```bash
./build_web.sh
```
