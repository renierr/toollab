package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorManager
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.opengl.EGL14
import android.opengl.EGLConfig
import android.opengl.GLES10
import android.os.Build
import android.os.Environment
import android.os.SystemClock
import android.os.StatFs
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

object DeviceInfoHelper {
    private const val BATTERY_DETAILS_CHANNEL = "de.renier.tool_lab/battery_details"
    private const val DEVICE_INFO_CHANNEL = "de.renier.tool_lab/device_info"

    fun registerChannels(context: Context, messenger: BinaryMessenger) {
        // Battery Details MethodChannel
        MethodChannel(messenger, BATTERY_DETAILS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getBatteryDetails") {
                    try {
                        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
                        val currentMicroAmps = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                            batteryManager.getLongProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
                        } else {
                            0L
                        }

                        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
                        val voltageMilliVolts = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, -1) ?: -1
                        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
                        val plugged = intent?.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1) ?: -1
                        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

                        val details = mapOf(
                            "voltage" to voltageMilliVolts,
                            "current" to currentMicroAmps,
                            "isCharging" to isCharging,
                            "pluggedType" to plugged
                        )
                        result.success(details)
                    } catch (e: Exception) {
                        result.error("BATTERY_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Device Info MethodChannel
        MethodChannel(messenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getStorageInfo" -> {
                        try {
                            val path = Environment.getDataDirectory().path
                            val stat = StatFs(path)
                            val blockSize = stat.blockSizeLong
                            val availableBlocks = stat.availableBlocksLong
                            val totalBlocks = stat.blockCountLong

                            val details = mapOf(
                                "free" to (availableBlocks * blockSize),
                                "total" to (totalBlocks * blockSize)
                            )
                            result.success(details)
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", e.message, null)
                        }
                    }
                    "getStorageVolumes" -> {
                        try {
                            val volumes = context.getExternalFilesDirs(null)
                                .filterNotNull()
                                .mapIndexed { index, directory ->
                                    val stat = StatFs(directory.path)
                                    mapOf(
                                        "name" to if (index == 0) "App storage" else "Storage ${index + 1}",
                                        "free" to (stat.availableBlocksLong * stat.blockSizeLong),
                                        "total" to (stat.blockCountLong * stat.blockSizeLong)
                                    )
                                }
                            result.success(volumes)
                        } catch (e: Exception) {
                            result.error("STORAGE_ERROR", e.message, null)
                        }
                    }
                    "getSensorInfo" -> {
                        try {
                            val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
                            val sensors = mapOf(
                                "accelerometer" to (sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) != null),
                                "gyroscope" to (sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null),
                                "magnetometer" to (sensorManager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD) != null),
                                "barometer" to (sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE) != null),
                                "light" to (sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT) != null)
                            )
                            result.success(sensors)
                        } catch (e: Exception) {
                            result.error("SENSOR_ERROR", e.message, null)
                        }
                    }
                    "getSystemDiagnostics" -> {
                        try {
                            val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                            val refreshRate = windowManager.defaultDisplay.refreshRate

                            var gpuRenderer = ""
                            var gpuVramBytes = 0L
                            try {
                                val eglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
                                if (eglDisplay != EGL14.EGL_NO_DISPLAY) {
                                    val version = IntArray(2)
                                    if (EGL14.eglInitialize(eglDisplay, version, 0, version, 1)) {
                                        val configs = arrayOfNulls<EGLConfig>(1)
                                        val numConfigs = IntArray(1)
                                        val configSpec = intArrayOf(
                                            EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                                            EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                                            EGL14.EGL_BLUE_SIZE, 8,
                                            EGL14.EGL_GREEN_SIZE, 8,
                                            EGL14.EGL_RED_SIZE, 8,
                                            EGL14.EGL_NONE
                                        )
                                        EGL14.eglChooseConfig(eglDisplay, configSpec, 0, configs, 0, 1, numConfigs, 0)
                                        if (numConfigs[0] > 0) {
                                            val eglContext = EGL14.eglCreateContext(eglDisplay, configs[0], EGL14.EGL_NO_CONTEXT, intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE), 0)
                                            if (eglContext != EGL14.EGL_NO_CONTEXT) {
                                                val eglSurface = EGL14.eglCreatePbufferSurface(eglDisplay, configs[0], intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE), 0)
                                                if (eglSurface != EGL14.EGL_NO_SURFACE) {
                                                    EGL14.eglMakeCurrent(eglDisplay, eglSurface, eglSurface, eglContext)
                                                    gpuRenderer = GLES10.glGetString(GLES10.GL_RENDERER) ?: ""
                                                    EGL14.eglMakeCurrent(eglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                                                    EGL14.eglDestroySurface(eglDisplay, eglSurface)
                                                }
                                                EGL14.eglDestroyContext(eglDisplay, eglContext)
                                            }
                                        }
                                        EGL14.eglTerminate(eglDisplay)
                                    }
                                }
                            } catch (_: Exception) {}

                            result.success(mapOf(
                                "cpuModel" to Build.HARDWARE,
                                "cpuArchitecture" to Build.SUPPORTED_ABIS.joinToString(", "),
                                "uptimeSeconds" to (SystemClock.elapsedRealtime() / 1000),
                                "refreshRate" to refreshRate,
                                "gpuModel" to gpuRenderer,
                                "gpuVramBytes" to gpuVramBytes
                            ))
                        } catch (e: Exception) {
                            result.error("DIAGNOSTICS_ERROR", e.message, null)
                        }
                    }
                    "getWifiInfo" -> {
                        try {
                            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
                            val wifiInfo = wifiManager.connectionInfo
                            val ssid = wifiInfo.ssid?.removeSurrounding("\"") ?: ""
                            val rssi = wifiInfo.rssi
                            val signalPercent = if (rssi <= 0 && rssi >= -100) {
                                (100.0 + rssi).toInt().coerceIn(0, 100)
                            } else 0
                            result.success(mapOf(
                                "ssid" to ssid,
                                "bssid" to (wifiInfo.bssid ?: ""),
                                "rssi" to rssi,
                                "signalPercent" to signalPercent,
                                "frequency" to wifiInfo.frequency,
                                "linkSpeed" to wifiInfo.linkSpeed
                            ))
                        } catch (e: Exception) {
                            result.error("WIFI_ERROR", e.message, null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
