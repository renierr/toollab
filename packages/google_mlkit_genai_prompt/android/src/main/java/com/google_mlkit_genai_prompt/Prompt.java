package com.google_mlkit_genai_prompt;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.google.common.util.concurrent.FutureCallback;
import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executor;
import java.util.concurrent.atomic.AtomicBoolean;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import com.google.mlkit.genai.common.DownloadCallback;
import com.google.mlkit.genai.common.FeatureStatus;
import com.google.mlkit.genai.common.GenAiException;
import com.google.mlkit.genai.common.StreamingCallback;
import com.google.mlkit.genai.prompt.Candidate;
import com.google.mlkit.genai.prompt.GenerateContentRequest;
import com.google.mlkit.genai.prompt.GenerateContentResponse;
import com.google.mlkit.genai.prompt.Generation;
import com.google.mlkit.genai.prompt.ImagePart;
import com.google.mlkit.genai.prompt.SystemInstruction;
import com.google.mlkit.genai.prompt.TextPart;
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures;

public class Prompt implements MethodChannel.MethodCallHandler {
    private static final String CHECK_FEATURE_STATUS = "genai#checkFeatureStatus";
    private static final String IS_SYSTEM_PROMPT_AVAILABLE = "genai#isSystemPromptAvailable";
    private static final String DOWNLOAD_FEATURE = "genai#downloadFeature";
    private static final String RUN_INFERENCE = "genai#runInference";
    private static final String RUN_INFERENCE_STREAMING = "genai#runInferenceStreaming";
    private static final String CANCEL_REQUEST = "genai#cancelRequest";
    private static final String CLOSE = "genai#closePrompt";

    private static final String ON_DOWNLOAD_EVENT = "genai#onDownloadEvent";
    private static final String ON_STREAM_CHUNK = "genai#onStreamChunk";

    private final MethodChannel channel;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Executor mainExecutor = mainHandler::post;
    private final Map<String, GenerativeModelFutures> instances = new HashMap<>();
    private final Map<String, ListenableFuture<?>> running = new ConcurrentHashMap<>();

    public Prompt(MethodChannel channel) {
        this.channel = channel;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case CHECK_FEATURE_STATUS:
                checkFeatureStatus(call, result);
                break;
            case IS_SYSTEM_PROMPT_AVAILABLE:
                isSystemPromptAvailable(call, result);
                break;
            case DOWNLOAD_FEATURE:
                downloadFeature(call, result);
                break;
            case RUN_INFERENCE:
                runInference(call, result, false);
                break;
            case RUN_INFERENCE_STREAMING:
                runInference(call, result, true);
                break;
            case CANCEL_REQUEST:
                cancelRequest(call.argument("requestId"));
                result.success(null);
                break;
            case CLOSE:
                instances.remove(call.<String>argument("id"));
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    public void dispose() {
        for (ListenableFuture<?> future : running.values()) {
            future.cancel(true);
        }
        running.clear();
        instances.clear();
    }

    @Nullable
    private GenerativeModelFutures model(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        GenerativeModelFutures model = instances.get(id);
        if (model != null) return model;
        try {
            model = GenerativeModelFutures.from(Generation.INSTANCE.getClient());
            instances.put(id, model);
            return model;
        } catch (Exception e) {
            result.error("PromptError", "Failed to initialize: " + e, null);
            return null;
        }
    }

    private void checkFeatureStatus(MethodCall call, MethodChannel.Result result) {
        GenerativeModelFutures model = model(call, result);
        if (model == null) return;
        try {
            Futures.addCallback(model.checkStatus(), new FutureCallback<Integer>() {
                @Override
                public void onSuccess(Integer status) {
                    result.success(mapStatus(status));
                }

                @Override
                public void onFailure(@NonNull Throwable e) {
                    result.error("PromptError", e.toString(), null);
                }
            }, mainExecutor);
        } catch (Exception e) {
            result.error("PromptError", "Failed to check status: " + e, null);
        }
    }

    private static int mapStatus(@Nullable Integer status) {
        if (status == null) return 0;
        if (status == FeatureStatus.DOWNLOADABLE) return 1;
        if (status == FeatureStatus.DOWNLOADING) return 2;
        if (status == FeatureStatus.AVAILABLE) return 3;
        return 0;
    }

    private void isSystemPromptAvailable(MethodCall call, MethodChannel.Result result) {
        GenerativeModelFutures model = model(call, result);
        if (model == null) return;
        try {
            Futures.addCallback(model.isSystemPromptAvailable(), new FutureCallback<Boolean>() {
                @Override
                public void onSuccess(Boolean available) {
                    result.success(Boolean.TRUE.equals(available));
                }

                @Override
                public void onFailure(@NonNull Throwable e) {
                    result.success(false);
                }
            }, mainExecutor);
        } catch (Exception e) {
            result.success(false);
        }
    }

    private void downloadFeature(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        GenerativeModelFutures model = model(call, result);
        if (model == null) return;
        AtomicBoolean replied = new AtomicBoolean(false);
        try {
            model.download(new DownloadCallback() {
                @Override
                public void onDownloadStarted(long bytesToDownload) {
                    sendDownloadEvent(id, "started", bytesToDownload);
                }

                @Override
                public void onDownloadProgress(long totalBytesDownloaded) {
                    sendDownloadEvent(id, "progress", totalBytesDownloaded);
                }

                @Override
                public void onDownloadFailed(@NonNull GenAiException e) {
                    if (replied.compareAndSet(false, true)) {
                        mainHandler.post(() -> result.error(
                                "DownloadError", e.toString(), e.getErrorCode()));
                    }
                }

                @Override
                public void onDownloadCompleted() {
                    if (replied.compareAndSet(false, true)) {
                        mainHandler.post(() -> result.success(null));
                    }
                }
            });
        } catch (Exception e) {
            if (replied.compareAndSet(false, true)) {
                result.error("PromptError", "Failed to download: " + e, null);
            }
        }
    }

    private void sendDownloadEvent(String id, String type, long bytes) {
        Map<String, Object> event = new HashMap<>();
        event.put("id", id);
        event.put("type", type);
        event.put("bytes", bytes);
        mainHandler.post(() -> channel.invokeMethod(ON_DOWNLOAD_EVENT, event));
    }

    private void runInference(MethodCall call, MethodChannel.Result result, boolean streaming) {
        String requestId = call.argument("requestId");
        GenerativeModelFutures model = model(call, result);
        if (model == null) return;

        GenerateContentRequest request;
        try {
            request = buildRequest(call);
        } catch (Exception e) {
            result.error("PromptError", "Invalid request: " + e, null);
            return;
        }

        try {
            ListenableFuture<GenerateContentResponse> future;
            if (streaming) {
                future = model.generateContent(request, new StreamingCallback() {
                    @Override
                    public void onNewText(@NonNull String text) {
                        Map<String, Object> chunk = new HashMap<>();
                        chunk.put("requestId", requestId);
                        chunk.put("text", text);
                        mainHandler.post(() -> channel.invokeMethod(ON_STREAM_CHUNK, chunk));
                    }
                });
            } else {
                future = model.generateContent(request);
            }
            if (requestId != null) running.put(requestId, future);

            Futures.addCallback(future, new FutureCallback<GenerateContentResponse>() {
                @Override
                public void onSuccess(GenerateContentResponse response) {
                    if (requestId != null) running.remove(requestId);
                    Map<String, Object> resultMap = new HashMap<>();
                    resultMap.put("text", firstCandidateText(response));
                    result.success(resultMap);
                }

                @Override
                public void onFailure(@NonNull Throwable e) {
                    if (requestId != null) running.remove(requestId);
                    if (future.isCancelled()) {
                        result.error("Cancelled", "Request cancelled", null);
                    } else {
                        result.error("PromptError", "Inference failed: " + e, null);
                    }
                }
            }, mainExecutor);
        } catch (Exception e) {
            if (requestId != null) running.remove(requestId);
            result.error("PromptError", "Failed to run inference: " + e, null);
        }
    }

    private static GenerateContentRequest buildRequest(MethodCall call) {
        String text = call.argument("text");
        String systemInstruction = call.argument("systemInstruction");
        byte[] imageData = call.argument("imageData");

        TextPart textPart = new TextPart(text != null ? text : "");
        ImagePart imagePart = imageData != null ? new ImagePart(imageData) : null;
        boolean hasSystem = systemInstruction != null && !systemInstruction.isEmpty();

        GenerateContentRequest.Builder builder;
        if (hasSystem && imagePart != null) {
            builder = new GenerateContentRequest.Builder(
                    new SystemInstruction(systemInstruction), imagePart, textPart);
        } else if (hasSystem) {
            builder = new GenerateContentRequest.Builder(
                    new SystemInstruction(systemInstruction), textPart);
        } else if (imagePart != null) {
            builder = new GenerateContentRequest.Builder(imagePart, textPart);
        } else {
            builder = new GenerateContentRequest.Builder(textPart);
        }
        return builder.build();
    }

    private static String firstCandidateText(@Nullable GenerateContentResponse response) {
        if (response == null || response.getCandidates() == null
                || response.getCandidates().isEmpty()) {
            return "";
        }
        Candidate candidate = response.getCandidates().get(0);
        String text = candidate.getText();
        return text != null ? text : "";
    }

    private void cancelRequest(@Nullable String requestId) {
        if (requestId == null) return;
        ListenableFuture<?> future = running.remove(requestId);
        if (future != null) future.cancel(true);
    }
}
