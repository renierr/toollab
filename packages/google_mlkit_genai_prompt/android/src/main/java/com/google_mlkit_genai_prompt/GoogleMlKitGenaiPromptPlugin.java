package com.google_mlkit_genai_prompt;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;

public class GoogleMlKitGenaiPromptPlugin implements FlutterPlugin {
    private static final String channelName = "google_mlkit_genai_prompt";
    private MethodChannel channel;
    private Prompt prompt;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), channelName);
        prompt = new Prompt(channel);
        channel.setMethodCallHandler(prompt);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        prompt.dispose();
        prompt = null;
    }
}
