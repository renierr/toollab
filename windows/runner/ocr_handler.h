#ifndef RUNNER_OCR_HANDLER_H_
#define RUNNER_OCR_HANDLER_H_

#include <flutter/binary_messenger.h>

// Registers the "de.renier.tool_lab/ocr" MethodChannel, backed by the built-in
// Windows OCR engine (Windows.Media.Ocr). Handles a single method,
// "recognizeText", taking {"bytes": <encoded image>} and returning the
// recognized text as a string.
void RegisterOcrHandler(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_OCR_HANDLER_H_
