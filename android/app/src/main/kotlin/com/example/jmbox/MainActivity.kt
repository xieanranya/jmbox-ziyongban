package com.example.jmbox

import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 系统屏幕亮度平台通道（jmbox/screen_brightness）：
 * - setWindowBrightness：设置本窗口亮度（BRIGHTNESS_OVERRIDE），即时生效、
 *   无需权限，退出页面传 null 清除覆盖交还系统亮度；
 * - setSystemBrightness / getSystemBrightness：读写系统亮度（需 WRITE_SETTINGS
 *   授权，自动亮度模式下先切手动再写入）；
 * - canWriteSettings / requestWriteSettings：授权查询与引导。
 *
 * 环境光事件通道（jmbox/ambient_light）：流式上报 TYPE_LIGHT 照度（lux），
 * 供护眼模式按环境明暗自适应滤镜强度；无传感器时流报错关闭。
 */
class MainActivity : FlutterActivity() {
    private val channelName = "jmbox/screen_brightness"

    private var lightSink: EventChannel.EventSink? = null
    private var lightListener: SensorEventListener? = null
    private val sensorManager by lazy {
        getSystemService(Context.SENSOR_SERVICE) as SensorManager
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWindowBrightness" -> {
                        val value = call.argument<Double>("value")
                        runOnUiThread {
                            try {
                                val lp = window.attributes
                                lp.screenBrightness =
                                    if (value == null || value < 0)
                                        WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                                    else
                                        value.toFloat().coerceIn(0.01f, 1.0f)
                                window.attributes = lp
                                result.success(null)
                            } catch (e: Exception) {
                                result.error("BRIGHTNESS", e.message, null)
                            }
                        }
                    }

                    "getSystemBrightness" -> {
                        try {
                            val v = Settings.System.getInt(
                                contentResolver,
                                Settings.System.SCREEN_BRIGHTNESS
                            )
                            result.success(v / 255.0)
                        } catch (e: Exception) {
                            result.success(-1.0)
                        }
                    }

                    "setSystemBrightness" -> {
                        val v = call.argument<Int>("value")
                        if (v == null || v < 1 || v > 255 ||
                            !Settings.System.canWrite(this)
                        ) {
                            result.success(false)
                        } else {
                            try {
                                val cr = contentResolver
                                // 自动亮度模式下写入无效，先切回手动模式。
                                val mode = Settings.System.getInt(
                                    cr,
                                    Settings.System.SCREEN_BRIGHTNESS_MODE
                                )
                                if (mode == Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC) {
                                    Settings.System.putInt(
                                        cr,
                                        Settings.System.SCREEN_BRIGHTNESS_MODE,
                                        Settings.System.SCREEN_BRIGHTNESS_MODE_MANUAL
                                    )
                                }
                                Settings.System.putInt(
                                    cr,
                                    Settings.System.SCREEN_BRIGHTNESS,
                                    v
                                )
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        }
                    }

                    "canWriteSettings" -> {
                        result.success(Settings.System.canWrite(this))
                    }

                    "requestWriteSettings" -> {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_WRITE_SETTINGS,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BRIGHTNESS", e.message, null)
                        }
                    }

                    "restoreAutoBrightnessMode" -> {
                        try {
                            if (Settings.System.canWrite(this)) {
                                Settings.System.putInt(
                                    contentResolver,
                                    Settings.System.SCREEN_BRIGHTNESS_MODE,
                                    Settings.System.SCREEN_BRIGHTNESS_MODE_AUTOMATIC
                                )
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // 环境光（lux）流：护眼滤镜强度自适应。
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "jmbox/ambient_light")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {
                    lightSink = events
                    val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_LIGHT)
                    if (sensor == null) {
                        events?.error(
                            "NO_SENSOR",
                            "device has no ambient light sensor",
                            null
                        )
                        return
                    }
                    val listener = object : SensorEventListener {
                        override fun onSensorChanged(event: SensorEvent) {
                            lightSink?.success(event.values[0].toDouble())
                        }

                        override fun onAccuracyChanged(
                            sensor: Sensor?,
                            accuracy: Int
                        ) {}
                    }
                    lightListener = listener
                    sensorManager.registerListener(
                        listener,
                        sensor,
                        SensorManager.SENSOR_DELAY_NORMAL
                    )
                }

                override fun onCancel(arguments: Any?) {
                    sensorManager.unregisterListener(lightListener)
                    lightListener = null
                    lightSink = null
                }
            })
    }
}
