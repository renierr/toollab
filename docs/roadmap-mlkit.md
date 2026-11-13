# Roadmap: ML Kit Extensions

Possible ML Kit extensions for existing and new tools. Status as of 2026-11.

## Device Availability

| Tier | APIs | Devices |
|---|---|---|
| Classic ML Kit | Barcode, Text Recognition, Document Scanner, Subject Segmentation, Face Detection, Image Labeling, Object Detection, Pose Detection, Selfie Segmentation, Digital Ink, Translation, Language ID, Entity Extraction, Smart Reply | All Android devices (some models download through Google Play services) |
| ML Kit GenAI | Prompt, Summarization, Proofreading, Rewriting, Image Description, Speech Recognition, Text-to-Speech, Speech Translation, Embeddings, Function Calling | Only Android devices with Gemini Nano (AICore) |

ML Kit does not run on Windows or Linux. Every feature needs either an offline fallback or a clear "Android only" hint.

### Already In Use

| API | Tool |
|---|---|
| Barcode Scanning | qr_code, totp_auth |
| Document Scanner | document_scanner |
| Subject Segmentation | image_viewer (ONNX u2netp as fallback and desktop path) |
| Text Recognition | image_viewer, paperless, document_scanner, grocery_list (receipts) |
| Face Detection | image_viewer (pixelate faces) |
| Image Labeling | image_viewer (image analysis) |
| Digital Ink Recognition | sketch_board (handwriting to text, shape cleanup) |
| Entity Extraction | paperless (upload suggestions) |
| Language ID + Translation | string_transformer, AI text sheet (notes, text_editor, markdown_viewer, pdf_viewer, news) |
| GenAI Prompt (`genai-prompt:1.0.0-beta5`, local plugin) | chat_ai, pdf_viewer Q&A + summary, AI text sheet, paperless |

## Phase 1: Paperless + Document Scanner (Auto-Metadata)

**Goal:** after scanning, title, date, correspondent, amount and tags are filled in automatically.

- OCR the scanned pages (Text Recognition, already a dependency).
- **Entity Extraction** (`google_mlkit_entity_extraction`): date, amount, IBAN, address, phone, email. Runs on all Android devices.
- **Prompt with structured output** (beta3+, Gemini Nano only): title, correspondent and document type as JSON, matched against the existing Paperless correspondents and tags.
- Show the result as suggestions in the upload form; the user confirms.
- Fallback without Nano: only the Entity Extraction fields. On desktop: no suggestions.

## Phase 2: Text Tools (GenAI) — done

Shared `TextAiSheet` (`lib/widgets/text_ai_sheet.dart`): proofread, rewrite (formal, shorter, friendlier) and summarize through the Prompt API; translate through ML Kit Translation. Without Gemini Nano only offline summary and translation remain.

- **notes / text_editor:** sheet works on the selection or the whole text; replace or insert below.
- **markdown_viewer / news reader:** summarize and translate (read only).
- **pdf_viewer:** summary uses Gemini Nano when available; translate button.
- **string_transformer:** "Translate (on device)" with language detection and target picker.
- **x_feed:** skipped, x.com already offers post translation.

## Phase 3: Chat AI — dropped

No further work on the chat_ai tool. Voice input, read-aloud, thinking mode and function calling are not planned.

## Phase 4: Images + Drawing — done except sudoku

- **image_viewer:** pixelate faces in one undo step (Face Detection); image analysis sheet with labels (Image Labeling) and an alt-text description (Prompt API with the image, Gemini Nano only).
- **sketch_board:** selected freehand strokes become text (handwriting model `de` / `en-US`) or a clean shape (`zxx-Zsym-x-shapes`: rectangle, ellipse, triangle, arrow). Models download on first use.
- **grocery_list:** add items by voice (`speech_to_text`, Android speech service); scan a receipt or open one from a file. OCR rows are rebuilt from line positions; Gemini Nano structures the items when available, otherwise priced lines are parsed. A review sheet confirms the items.
- **sudoku:** import a puzzle from a photo — not planned for now.

## Phase 5: New Tools

- **Offline translator (new tool) — done:** `lib/tools/translator`. Text with automatic language detection, Latin-script text from a camera photo or image (Text Recognition), voice input (`speech_to_text`, shared `VoiceInputSheet`), read aloud through the system text-to-speech engine (`TextToSpeechHelper.kt` platform channel, no plugin). Missing language models download on first use; the models sheet downloads and deletes them. Android only.
- **Memo transcript (sound_finder / Audio Lab recorder) — done:** memos are transcribed offline with Whisper (`whisper_ggml`, model Base or Small picked on first use, changeable and removable in the recorder settings). WAV and FLAC are converted to 16 kHz mono in Dart (FLAC through flutter_soloud's libFLAC), split into chunks of at most 30 s at quiet spots (Whisper pads every window to 30 s) and transcribed chunk by chunk, so a cancel stops after the running chunk. The transcript with timestamps lives next to the audio as `<file>.transcript.json`; it can be summarized (Gemini Nano, offline extract otherwise), copied, shared or turned into a note. New memos record as FLAC by default.
- Dropped: fitness rep counter (Pose Detection), semantic search (Embeddings).

## APK Size

- Prefer the unbundled ML Kit variants (models downloaded through Play services) over bundled models.
- ONNX Runtime (~28 MB) plus u2netp (~4 MB) is only a fallback on Android. Dropping it on Android only would cost background removal on devices without Google Play services; leave as is for now.
