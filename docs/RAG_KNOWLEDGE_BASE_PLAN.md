# AgriDrone Guardian Vetted Knowledge Base Plan

AgriDrone Guardian can later add a grounded advisory layer so the AI Advisor answers from verified agriculture material instead of general model knowledge alone.

## Goals

- Ground farmer advice in trusted crop disease guidance.
- Support local crops such as rice, wheat, and maize.
- Support English first, with Nepali and Hindi translations prepared.
- Keep chemical treatment guidance safe: no dosage instructions in AI output; refer to local agricultural guidance and product labels.
- Preserve drone-specific context: image result, confidence, severity, field location, moisture, flight history, and crop report history.

## Candidate Sources

- Nepal crop disease factsheets.
- Local rice, wheat, and maize disease manuals.
- Extension worker notes and verified Q&A pairs.
- Agricultural university or government PDFs.
- Pesticide safety disclaimers and safe handling guidance.
- Project report content for final-year demonstration explanations.
- Local language translation pairs for common farmer questions.

## Future Architecture

1. Curate source documents and record title, crop, region, language, and review status.
2. Convert PDFs/manuals into clean text chunks with citations.
3. Store chunks with metadata in a vector-capable backend table.
4. Retrieve relevant chunks using crop type, disease name, severity, language, and farmer question.
5. Send retrieved snippets to the backend AI Advisor prompt.
6. Return farmer-facing guidance with a short source note and expert-review disclaimer.
7. Collect feedback: Helpful, Not helpful, Needs expert review, Disease seems wrong, Image unclear.

## Safety Rules

- Do not fabricate disease, GPS, weather, sensor, or report data.
- Do not provide exact pesticide dosage or unsafe application instructions.
- Escalate serious, spreading, or uncertain cases to an agriculture expert.
- Make low-confidence image results ask for retake or expert review.
- Keep provider and backend implementation names out of normal farmer UI.

## Phase Status

Current phase: general AI Advisor guidance plus feedback collection.

Not implemented yet: vector search, document ingestion, citations, multilingual document retrieval, voice input/output, image upload inside chat, and video help clips.
