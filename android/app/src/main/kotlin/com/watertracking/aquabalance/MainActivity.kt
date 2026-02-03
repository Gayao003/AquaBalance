package com.watertracking.aquabalance

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
	private val CHANNEL = "com.watertracking.aquabalance/alarm"
	private lateinit var channel: MethodChannel
	private var pendingAction: Map<String, Any>? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
		channel.setMethodCallHandler { call, result ->
			when (call.method) {
				"scheduleAlarm" -> {
					val seconds = call.argument<Int>("seconds") ?: 30
					val success = scheduleAlarm(seconds)
					result.success(success)
				}
				"scheduleDailyAlarm" -> {
					val alarmId = call.argument<Int>("alarmId") ?: 0
					val hour = call.argument<Int>("hour") ?: 9
					val minute = call.argument<Int>("minute") ?: 0
					val title = call.argument<String>("title") ?: "Time to Hydrate! 💧"
					val body = call.argument<String>("body") ?: "Remember to log your water intake and stay hydrated!"
					val payload = call.argument<String>("payload") ?: ""
					val success = scheduleDailyAlarm(alarmId, hour, minute, title, body, payload)
					result.success(success)
				}
				"cancelAlarm" -> {
					val alarmId = call.argument<Int>("alarmId") ?: 0
					val success = cancelAlarm(alarmId)
					result.success(success)
				}
				else -> result.notImplemented()
			}
		}

		pendingAction?.let { action ->
			channel.invokeMethod("nativeNotificationAction", action)
			pendingAction = null
		}
		maybeHandleNotificationIntent(intent)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		setIntent(intent)
		maybeHandleNotificationIntent(intent)
	}

	private fun maybeHandleNotificationIntent(intent: Intent?) {
		if (intent == null) return
		val actionId = intent.action ?: return
		if (actionId != "action_drink" && actionId != "action_skip") return
		val payload = intent.getStringExtra("payload") ?: ""
		val action = mapOf(
			"actionId" to actionId,
			"payload" to payload
		)
		if (::channel.isInitialized) {
			channel.invokeMethod("nativeNotificationAction", action)
		} else {
			pendingAction = action
		}
	}

	private fun scheduleAlarm(seconds: Int): Boolean {
		return try {
			val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
			val intent = Intent(this, AlarmReceiver::class.java)
			val pendingIntent = PendingIntent.getBroadcast(
				this,
				0,
				intent,
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
				} else {
					PendingIntent.FLAG_UPDATE_CURRENT
				}
			)

			val triggerTime = SystemClock.elapsedRealtime() + (seconds * 1000)

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				alarmManager.setExactAndAllowWhileIdle(
					AlarmManager.ELAPSED_REALTIME_WAKEUP,
					triggerTime,
					pendingIntent
				)
			} else {
				alarmManager.setExact(
					AlarmManager.ELAPSED_REALTIME_WAKEUP,
					triggerTime,
					pendingIntent
				)
			}
			true
		} catch (e: Exception) {
			e.printStackTrace()
			false
		}
	}

	private fun scheduleDailyAlarm(alarmId: Int, hour: Int, minute: Int, title: String, body: String, payload: String): Boolean {
		return try {
			val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
				if (!alarmManager.canScheduleExactAlarms()) {
					return false
				}
			}

			val intent = Intent(this, AlarmReceiver::class.java).apply {
				putExtra("title", title)
				putExtra("body", body)
				putExtra("alarmId", alarmId)
				putExtra("hour", hour)
				putExtra("minute", minute)
				putExtra("payload", payload)
			}

			val pendingIntent = PendingIntent.getBroadcast(
				this,
				alarmId,
				intent,
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
				} else {
					PendingIntent.FLAG_UPDATE_CURRENT
				}
			)

			val now = System.currentTimeMillis()
			val calendar = Calendar.getInstance().apply {
				set(Calendar.HOUR_OF_DAY, hour)
				set(Calendar.MINUTE, minute)
				set(Calendar.SECOND, 0)
				set(Calendar.MILLISECOND, 0)
				if (timeInMillis <= now) {
					add(Calendar.DAY_OF_MONTH, 1)
				}
			}

			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
				alarmManager.setExactAndAllowWhileIdle(
					AlarmManager.RTC_WAKEUP,
					calendar.timeInMillis,
					pendingIntent
				)
			} else {
				alarmManager.setExact(
					AlarmManager.RTC_WAKEUP,
					calendar.timeInMillis,
					pendingIntent
				)
			}
			true
		} catch (e: Exception) {
			e.printStackTrace()
			false
		}
	}

	private fun cancelAlarm(alarmId: Int): Boolean {
		return try {
			val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
			val intent = Intent(this, AlarmReceiver::class.java)
			val pendingIntent = PendingIntent.getBroadcast(
				this,
				alarmId,
				intent,
				if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
					PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
				} else {
					PendingIntent.FLAG_NO_CREATE
				}
			)

			if (pendingIntent != null) {
				alarmManager.cancel(pendingIntent)
				pendingIntent.cancel()
			}
			true
		} catch (e: Exception) {
			e.printStackTrace()
			false
		}
	}
}
