package de.renier.tool_lab

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.BatteryManager
import android.os.Environment
import android.os.StatFs
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
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}
