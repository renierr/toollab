package de.renier.tool_lab

import android.app.Activity
import android.content.Context
import android.location.GnssStatus
import android.location.LocationManager
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class GpsInfoHelper(private val activity: Activity) {
    private val GPS_INFO_CHANNEL = "de.renier.tool_lab/gps_info"
    private var gpsInfoMethodChannel: MethodChannel? = null
    private var gnssStatusCallback: Any? = null
    private var locationManager: LocationManager? = null

    fun registerChannel(messenger: BinaryMessenger) {
        gpsInfoMethodChannel = MethodChannel(messenger, GPS_INFO_CHANNEL)
        gpsInfoMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startGpsInfoUpdates" -> {
                    val success = startGpsInfoUpdates()
                    result.success(success)
                }
                "stopGpsInfoUpdates" -> {
                    stopGpsInfoUpdates()
                    result.success(true)
                }
                "getProviders" -> {
                    val providers = getProvidersInfo()
                    result.success(providers)
                }
            }
        }
    }

    private fun startGpsInfoUpdates(): Boolean {
        if (android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.N) {
            return false
        }
        try {
            if (locationManager == null) {
                locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            }
            if (gnssStatusCallback == null) {
                gnssStatusCallback = object : GnssStatus.Callback() {
                    override fun onSatelliteStatusChanged(status: GnssStatus) {
                        val count = status.satelliteCount
                        val satellitesList = mutableListOf<Map<String, Any>>()
                        var usedInFixCount = 0
                        
                        for (i in 0 until count) {
                            val used = status.usedInFix(i)
                            if (used) {
                                usedInFixCount++
                            }
                            
                            val satMap = mapOf(
                                "svid" to status.getSvid(i),
                                "constellationType" to status.getConstellationType(i),
                                "cn0DbHz" to status.getCn0DbHz(i),
                                "hasAlmanacData" to status.hasAlmanacData(i),
                                "hasEphemerisData" to status.hasEphemerisData(i),
                                "usedInFix" to used,
                                "elevationDegrees" to status.getElevationDegrees(i),
                                "azimuthDegrees" to status.getAzimuthDegrees(i)
                            )
                            satellitesList.add(satMap)
                        }
                        
                        activity.runOnUiThread {
                            gpsInfoMethodChannel?.invokeMethod("onGnssStatusChanged", mapOf(
                                "satelliteCount" to count,
                                "usedInFixCount" to usedInFixCount,
                                "satellites" to satellitesList
                            ))
                        }
                    }
                    
                    override fun onStarted() {
                        activity.runOnUiThread {
                            gpsInfoMethodChannel?.invokeMethod("onGnssStarted", null)
                        }
                    }
                    
                    override fun onStopped() {
                        activity.runOnUiThread {
                            gpsInfoMethodChannel?.invokeMethod("onGnssStopped", null)
                        }
                    }
                }
            }
            
            locationManager?.registerGnssStatusCallback(
                gnssStatusCallback as GnssStatus.Callback,
                Handler(Looper.getMainLooper())
            )
            return true
        } catch (e: SecurityException) {
            e.printStackTrace()
            return false
        } catch (e: Exception) {
            e.printStackTrace()
            return false
        }
    }

    fun stopGpsInfoUpdates() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
            try {
                if (locationManager != null && gnssStatusCallback != null) {
                    locationManager?.unregisterGnssStatusCallback(gnssStatusCallback as GnssStatus.Callback)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun getProvidersInfo(): List<Map<String, Any>> {
        val resultList = mutableListOf<Map<String, Any>>()
        try {
            if (locationManager == null) {
                locationManager = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
            }
            val mgr = locationManager ?: return resultList
            val all = mgr.allProviders
            for (provider in all) {
                val enabled = mgr.isProviderEnabled(provider)
                val info = mapOf(
                    "name" to provider,
                    "enabled" to enabled
                )
                resultList.add(info)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return resultList
    }
}
