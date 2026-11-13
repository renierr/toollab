## 0.2.0 (local)

* Upgrade to `genai-prompt:1.0.0-beta5`.
* Streaming responses via `runInferenceStreaming`, cancellable from Dart.
* Separate `systemInstruction`, folded into the prompt when the model lacks system prompt support.
* Image input (`imageData`) is now sent to the model.
* Download start/progress callbacks.

## 0.1.0

* Initial release of Google's ML Kit GenAI Prompt API for Flutter.
* Support for Android platform (API level 26+).
* Features:
  - Generate text content based on custom prompts
  - Support for text-only and multimodal (image + text) prompts
  - Feature status checking and downloading
