package com.s_health.monitor_channels

import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class SHealthMonitorPlugin :
    FlutterPlugin,
    ActivityAware {

    companion object {
        private const val TAG = "SHealthPlugin"

        const val ACTION_START_CAMERA =
            "com.s_health.action.START_CAMERA"
        const val ACTION_STOP_CAMERA =
            "com.s_health.action.STOP_CAMERA"

        const val DISTANCE_BROADCAST_ACTION =
            "com.s_health.broadcast.DISTANCE"
        const val EXTRA_DISTANCE = "distance"

        const val POSTURE_BROADCAST_ACTION =
            "com.s_health.broadcast.POSTURE"
        const val EXTRA_POSTURE_STATUS = "posture_status"
        const val EXTRA_PITCH = "pitch"
        const val EXTRA_ROLL = "roll"

        const val HUNCH_BROADCAST_ACTION =
            "com.s_health.broadcast.HUNCH"
        const val EXTRA_HUNCH_STATUS = "is_hunching"
        const val EXTRA_HUNCH_RATIO = "hunch_ratio"

        const val LIGHT_BROADCAST_ACTION =
            "com.s_health.broadcast.LIGHT"
        const val EXTRA_LIGHT_LUX = "light_lux"

        const val ACTION_START_LIGHT =
            "com.s_health.action.START_LIGHT"
        const val ACTION_STOP_LIGHT =
            "com.s_health.action.STOP_LIGHT"

        const val EXTRA_HUNCH_DIVISOR =
            "hunch_divisor"

        private const val PREFS_NAME =
            "s_health_monitor_preferences"
        private const val PREF_HUNCH_DIVISOR =
            "hunch_divisor"
    }

    private var applicationContext: Context? = null
    private var activity: Activity? = null

    private var lightEventChannel: EventChannel? = null
    private var distanceEventChannel: EventChannel? = null
    private var postureEventChannel: EventChannel? = null
    private var hunchEventChannel: EventChannel? = null

    private var cameraMethodChannel: MethodChannel? = null

    private var lightEventSink: EventChannel.EventSink? = null
    private var distanceEventSink: EventChannel.EventSink? = null
    private var postureEventSink: EventChannel.EventSink? = null
    private var hunchEventSink: EventChannel.EventSink? = null

    private var lightReceiver: BroadcastReceiver? = null
    private var distanceReceiver: BroadcastReceiver? = null
    private var postureReceiver: BroadcastReceiver? = null
    private var hunchReceiver: BroadcastReceiver? = null

    override fun onAttachedToEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        applicationContext = binding.applicationContext

        setupDistanceChannel(binding)
        setupPostureChannel(binding)
        setupLightChannel(binding)
        setupHunchChannel(binding)
        setupMethodChannel(binding)
    }

    override fun onDetachedFromEngine(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        unregisterDistanceReceiver()
        unregisterPostureReceiver()
        unregisterHunchReceiver()
        unregisterLightReceiver()

        distanceEventChannel?.setStreamHandler(null)
        postureEventChannel?.setStreamHandler(null)
        hunchEventChannel?.setStreamHandler(null)
        lightEventChannel?.setStreamHandler(null)
        cameraMethodChannel?.setMethodCallHandler(null)

        distanceEventChannel = null
        postureEventChannel = null
        hunchEventChannel = null
        lightEventChannel = null
        cameraMethodChannel = null

        distanceEventSink = null
        postureEventSink = null
        hunchEventSink = null
        lightEventSink = null

        activity = null
        applicationContext = null
    }

    // ========================================================================
    // ActivityAware
    // ========================================================================

    override fun onAttachedToActivity(
        binding: ActivityPluginBinding,
    ) {
        activity = binding.activity
        Log.d(TAG, "Attached to foreground Activity")
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(
        binding: ActivityPluginBinding,
    ) {
        activity = binding.activity
        Log.d(TAG, "Reattached to foreground Activity")
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun setupDistanceChannel(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        distanceEventChannel = EventChannel(
            binding.binaryMessenger,
            "com.s_health/distance_stream",
        )

        distanceEventChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    distanceEventSink = events
                    registerDistanceReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterDistanceReceiver()
                    distanceEventSink = null
                }
            },
        )
    }

    private fun setupPostureChannel(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        postureEventChannel = EventChannel(
            binding.binaryMessenger,
            "com.s_health/posture_stream",
        )

        postureEventChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    postureEventSink = events
                    registerPostureReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterPostureReceiver()
                    postureEventSink = null
                }
            },
        )
    }

    private fun setupLightChannel(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        lightEventChannel = EventChannel(
            binding.binaryMessenger,
            "com.s_health/light_stream",
        )

        lightEventChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    lightEventSink = events
                    registerLightReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterLightReceiver()
                    lightEventSink = null
                }
            },
        )
    }

    private fun setupHunchChannel(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        hunchEventChannel = EventChannel(
            binding.binaryMessenger,
            "com.s_health/hunch_stream",
        )

        hunchEventChannel?.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?,
                ) {
                    hunchEventSink = events
                    registerHunchReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterHunchReceiver()
                    hunchEventSink = null
                }
            },
        )
    }

    private fun setupMethodChannel(
        binding: FlutterPlugin.FlutterPluginBinding,
    ) {
        cameraMethodChannel = MethodChannel(
            binding.binaryMessenger,
            "com.s_health/camera_control",
        )

        cameraMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startCamera" -> {
                    // Camera FGS creation is deliberately UI-engine-only.
                    // The background service isolate has no Activity and must
                    // never be allowed to be the first caller of CameraService.
                    if (activity == null) {
                        result.error(
                            "CAMERA_START_REQUIRES_FOREGROUND_UI",
                            "CameraService must be started from the visible application UI.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    val divisor =
                        readHunchDivisorFromCall(
                            call.arguments,
                        )

                    if (
                        divisor == null ||
                        !divisor.isFinite() ||
                        divisor <= 0.0
                    ) {
                        result.error(
                            "INVALID_HUNCH_DIVISOR",
                            "startCamera requires a valid positive hunch_divisor.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    Log.d(
                        TAG,
                        "Starting camera with hunch_divisor=$divisor",
                    )

                    saveHunchDivisor(divisor)
                    startCameraService(
                        binding.applicationContext,
                        divisor,
                    )

                    result.success(
                        mapOf(
                            "status" to "CameraStarted",
                            "hunch_divisor" to divisor,
                        ),
                    )
                }

                "saveHunchDivisor" -> {
                    val divisor =
                        readHunchDivisorFromCall(
                            call.arguments,
                        )

                    if (
                        divisor == null ||
                        !divisor.isFinite() ||
                        divisor <= 0.0
                    ) {
                        result.error(
                            "INVALID_HUNCH_DIVISOR",
                            "saveHunchDivisor requires a valid positive hunch_divisor.",
                            null,
                        )
                        return@setMethodCallHandler
                    }

                    saveHunchDivisor(divisor)

                    Log.d(
                        TAG,
                        "Saved native hunch_divisor=$divisor",
                    )

                    result.success(
                        mapOf(
                            "hunch_divisor" to divisor,
                        ),
                    )
                }

                "getSavedHunchDivisor" -> {
                    result.success(getSavedHunchDivisor())
                }

                "stopCamera" -> {
                    Log.d(TAG, "Stopping camera")
                    stopCameraService(binding.applicationContext)
                    result.success("CameraStopped")
                }

                "startLightMonitor" -> {
                    Log.d(
                        TAG,
                        "Starting ambient-light monitor",
                    )

                    startLightService(
                        binding.applicationContext,
                    )

                    result.success("LightStarted")
                }

                "stopLightMonitor" -> {
                    Log.d(
                        TAG,
                        "Stopping ambient-light monitor",
                    )

                    stopLightService(
                        binding.applicationContext,
                    )

                    result.success("LightStopped")
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun readHunchDivisorFromCall(
        arguments: Any?,
    ): Double? {
        val args = arguments as? Map<*, *>
            ?: return null

        val canonicalValue =
            args[EXTRA_HUNCH_DIVISOR]

        val legacyValue =
            args["hunchDivisor"]

        val value =
            canonicalValue ?: legacyValue

        return when (value) {
            is Number -> value.toDouble()
            is String -> value.toDoubleOrNull()
            else -> null
        }
    }

    private fun saveHunchDivisor(
        divisor: Double,
    ) {
        val context = applicationContext ?: return

        context
            .getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE,
            )
            .edit()
            .putFloat(
                PREF_HUNCH_DIVISOR,
                divisor.toFloat(),
            )
            .apply()
    }

    private fun getSavedHunchDivisor(): Double? {
        val context = applicationContext ?: return null

        val prefs = context.getSharedPreferences(
            PREFS_NAME,
            Context.MODE_PRIVATE,
        )

        if (!prefs.contains(PREF_HUNCH_DIVISOR)) {
            return null
        }

        val divisor = prefs
            .getFloat(
                PREF_HUNCH_DIVISOR,
                0f,
            )
            .toDouble()

        return divisor.takeIf {
            it.isFinite() && it > 0.0
        }
    }

    private fun registerDistanceReceiver() {
        val context = applicationContext ?: return
        if (distanceReceiver != null) return

        distanceReceiver = object : BroadcastReceiver() {
            override fun onReceive(
                ctx: Context,
                intent: Intent,
            ) {
                if (intent.action != DISTANCE_BROADCAST_ACTION) {
                    return
                }

                val distance = intent.getDoubleExtra(
                    EXTRA_DISTANCE,
                    0.0,
                )

                distanceEventSink?.success(distance)
            }
        }

        registerReceiver(
            context = context,
            receiver = distanceReceiver!!,
            action = DISTANCE_BROADCAST_ACTION,
        )
    }

    private fun unregisterDistanceReceiver() {
        unregisterReceiverSafely(distanceReceiver)
        distanceReceiver = null
    }

    private fun registerPostureReceiver() {
        val context = applicationContext ?: return
        if (postureReceiver != null) return

        postureReceiver = object : BroadcastReceiver() {
            override fun onReceive(
                ctx: Context,
                intent: Intent,
            ) {
                if (intent.action != POSTURE_BROADCAST_ACTION) {
                    return
                }

                val status = intent.getStringExtra(
                    EXTRA_POSTURE_STATUS,
                ) ?: "unknown"

                val pitch = intent.getFloatExtra(
                    EXTRA_PITCH,
                    0f,
                )

                val roll = intent.getFloatExtra(
                    EXTRA_ROLL,
                    0f,
                )

                postureEventSink?.success(
                    mapOf(
                        "status" to status,
                        "pitch" to pitch.toDouble(),
                        "roll" to roll.toDouble(),
                        "timestamp" to System.currentTimeMillis(),
                    ),
                )
            }
        }

        registerReceiver(
            context = context,
            receiver = postureReceiver!!,
            action = POSTURE_BROADCAST_ACTION,
        )
    }

    private fun unregisterPostureReceiver() {
        unregisterReceiverSafely(postureReceiver)
        postureReceiver = null
    }

    private fun registerHunchReceiver() {
        val context = applicationContext ?: return
        if (hunchReceiver != null) return

        hunchReceiver = object : BroadcastReceiver() {
            override fun onReceive(
                ctx: Context,
                intent: Intent,
            ) {
                if (intent.action != HUNCH_BROADCAST_ACTION) {
                    return
                }

                val isHunching = intent.getBooleanExtra(
                    EXTRA_HUNCH_STATUS,
                    false,
                )

                val ratio = intent.getFloatExtra(
                    EXTRA_HUNCH_RATIO,
                    0f,
                )

                hunchEventSink?.success(
                    mapOf(
                        "is_hunching" to isHunching,
                        "hunch_ratio" to ratio.toDouble(),
                        "timestamp" to System.currentTimeMillis(),
                    ),
                )
            }
        }

        registerReceiver(
            context = context,
            receiver = hunchReceiver!!,
            action = HUNCH_BROADCAST_ACTION,
        )
    }

    private fun unregisterHunchReceiver() {
        unregisterReceiverSafely(hunchReceiver)
        hunchReceiver = null
    }

    private fun registerLightReceiver() {
        val context = applicationContext ?: return
        if (lightReceiver != null) return

        lightReceiver = object : BroadcastReceiver() {
            override fun onReceive(
                ctx: Context,
                intent: Intent,
            ) {
                if (intent.action != LIGHT_BROADCAST_ACTION) {
                    return
                }

                val lux = intent.getDoubleExtra(
                    EXTRA_LIGHT_LUX,
                    0.0,
                )

                lightEventSink?.success(
                    mapOf(
                        "lightLux" to lux,
                        "timestamp" to System.currentTimeMillis(),
                    ),
                )
            }
        }

        registerReceiver(
            context = context,
            receiver = lightReceiver!!,
            action = LIGHT_BROADCAST_ACTION,
        )
    }

    private fun unregisterLightReceiver() {
        unregisterReceiverSafely(lightReceiver)
        lightReceiver = null
    }

    private fun registerReceiver(
        context: Context,
        receiver: BroadcastReceiver,
        action: String,
    ) {
        val filter = IntentFilter(action)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(
                receiver,
                filter,
                Context.RECEIVER_NOT_EXPORTED,
            )
        } else {
            context.registerReceiver(
                receiver,
                filter,
            )
        }
    }

    private fun unregisterReceiverSafely(
        receiver: BroadcastReceiver?,
    ) {
        val context = applicationContext ?: return
        if (receiver == null) return

        try {
            context.unregisterReceiver(receiver)
        } catch (_: IllegalArgumentException) {
            // Receiver was already unregistered.
        }
    }

    private fun startCameraService(
        context: Context,
        hunchDivisor: Double,
    ) {
        val intent = Intent().apply {
            setClassName(
                context,
                "com.example.monitor.CameraService",
            )
            action = ACTION_START_CAMERA
            putExtra(
                EXTRA_HUNCH_DIVISOR,
                hunchDivisor,
            )
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopCameraService(
        context: Context,
    ) {
        val intent = Intent().apply {
            setClassName(
                context,
                "com.example.monitor.CameraService",
            )
        }

        context.stopService(intent)
    }

    private fun startLightService(
        context: Context,
    ) {
        val intent = Intent().apply {
            setClassName(
                context,
                "com.example.monitor.AmbientLightService",
            )
            action = ACTION_START_LIGHT
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    private fun stopLightService(
        context: Context,
    ) {
        val intent = Intent().apply {
            setClassName(
                context,
                "com.example.monitor.AmbientLightService",
            )
        }

        context.stopService(intent)
    }
}
