package com.google_mlkit_genai_prompt;

import android.content.Context;

import androidx.annotation.NonNull;

import com.google.common.util.concurrent.Futures;
import com.google.common.util.concurrent.ListenableFuture;
import com.google.common.util.concurrent.FutureCallback;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import com.google.mlkit.genai.prompt.Generation;
import com.google.mlkit.genai.prompt.GenerativeModel;
import com.google.mlkit.genai.prompt.java.GenerativeModelFutures;
import com.google.mlkit.genai.prompt.GenerateContentResponse;
import com.google.mlkit.genai.common.FeatureStatus;
import com.google.mlkit.genai.common.DownloadCallback;
import com.google.mlkit.genai.common.GenAiException;

public class Prompt implements MethodChannel.MethodCallHandler {
    private static final String CHECK_FEATURE_STATUS = "genai#checkFeatureStatus";
    private static final String DOWNLOAD_FEATURE = "genai#downloadFeature";
    private static final String RUN_INFERENCE = "genai#runInference";
    private static final String RUN_INFERENCE_STREAMING = "genai#runInferenceStreaming";
    private static final String CLOSE = "genai#closePrompt";

    private final Context context;
    private final Map<String, GenerativeModelFutures> instances = new HashMap<>();
    private final Executor executor = Executors.newSingleThreadExecutor();

    public Prompt(Context context) {
        this.context = context;
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        String method = call.method;
        switch (method) {
            case CHECK_FEATURE_STATUS:
                checkFeatureStatus(call, result);
                break;
            case DOWNLOAD_FEATURE:
                downloadFeature(call, result);
                break;
            case RUN_INFERENCE:
                runInference(call, result);
                break;
            case RUN_INFERENCE_STREAMING:
                runInferenceStreaming(call, result);
                break;
            case CLOSE:
                closePrompt(call);
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private GenerativeModelFutures initialize(MethodCall call) throws Exception {
        GenerativeModel generativeModel = Generation.INSTANCE.getClient();
        return GenerativeModelFutures.from(generativeModel);
    }

    private void checkFeatureStatus(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        GenerativeModelFutures generativeModel = instances.get(id);
        if (generativeModel == null) {
            try {
                generativeModel = initialize(call);
                instances.put(id, generativeModel);
            } catch (Exception e) {
                result.error("PromptError", "Failed to initialize: " + e.toString(), null);
                return;
            }
        }

        try {
            ListenableFuture<Integer> future = generativeModel.checkStatus();
            Futures.addCallback(future, new FutureCallback<Integer>() {
                @Override
                public void onSuccess(Integer status) {
                    int statusValue;
                    if (status == FeatureStatus.UNAVAILABLE) {
                        statusValue = 0;
                    } else if (status == FeatureStatus.DOWNLOADABLE) {
                        statusValue = 1;
                    } else if (status == FeatureStatus.DOWNLOADING) {
                        statusValue = 2;
                    } else if (status == FeatureStatus.AVAILABLE) {
                        statusValue = 3;
                    } else {
                        statusValue = 0;
                    }
                    result.success(statusValue);
                }

                @Override
                public void onFailure(Throwable e) {
                    result.error("PromptError", e.toString(), null);
                }
            }, executor);
        } catch (Exception e) {
            result.error("PromptError", "Failed to check status: " + e.toString(), null);
        }
    }

    private void downloadFeature(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        GenerativeModelFutures generativeModel = instances.get(id);
        if (generativeModel == null) {
            try {
                generativeModel = initialize(call);
                instances.put(id, generativeModel);
            } catch (Exception e) {
                result.error("PromptError", "Failed to initialize: " + e.toString(), null);
                return;
            }
        }

        try {
            generativeModel.download(new DownloadCallback() {
                @Override
                public void onDownloadStarted(long bytesToDownload) {
                    // Handle download started
                }

                @Override
                public void onDownloadFailed(GenAiException e) {
                    result.error("DownloadError", e.toString(), null);
                }

                @Override
                public void onDownloadProgress(long totalBytesDownloaded) {
                    // Handle download progress
                }

                @Override
                public void onDownloadCompleted() {
                    result.success(null);
                }
            });
        } catch (Exception e) {
            result.error("PromptError", "Failed to download: " + e.toString(), null);
        }
    }

    private void runInference(MethodCall call, MethodChannel.Result result) {
        String id = call.argument("id");
        String text = call.argument("text");
        GenerativeModelFutures generativeModel = instances.get(id);
        if (generativeModel == null) {
            try {
                generativeModel = initialize(call);
                instances.put(id, generativeModel);
            } catch (Exception e) {
                result.error("PromptError", "Failed to initialize: " + e.toString(), null);
                return;
            }
        }

        try {
            ListenableFuture<GenerateContentResponse> future = generativeModel.generateContent(text);

            Futures.addCallback(future, new FutureCallback<GenerateContentResponse>() {
                @Override
                public void onSuccess(GenerateContentResponse response) {
                    try {
                        String responseText = "";
                        if (response.getCandidates() != null && !response.getCandidates().isEmpty()) {
                            responseText = response.getCandidates().get(0).getText();
                        }
                        Map<String, Object> resultMap = new HashMap<>();
                        resultMap.put("text", responseText);
                        result.success(resultMap);
                    } catch (Exception e) {
                        result.error("PromptError", "Failed to parse response: " + e.toString(), null);
                    }
                }

                @Override
                public void onFailure(Throwable e) {
                    result.error("PromptError", "Inference failed: " + e.toString(), null);
                }
            }, executor);
        } catch (Exception e) {
            result.error("PromptError", "Failed to run inference: " + e.toString(), null);
        }
    }

    private void runInferenceStreaming(MethodCall call, MethodChannel.Result result) {
        // Streaming implementation would require EventChannel
        result.notImplemented();
    }

    private void closePrompt(MethodCall call) {
        String id = call.argument("id");
        instances.remove(id);
    }
}
