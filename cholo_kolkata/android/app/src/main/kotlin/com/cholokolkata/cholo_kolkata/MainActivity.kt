package com.cholokolkata.cholo_kolkata

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.SpannableString
import android.text.Spanned
import android.text.style.RelativeSizeSpan
import android.text.style.StyleSpan
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.max
import kotlin.math.min

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.cholokolkata/live_notification"
    private val NOTIFICATION_CHANNEL_ID = "cholo_kolkata_live_tracking"

    private var pendingRouteNo: String? = null
    private var pendingRouteId: Int? = null
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        if (intent?.getStringExtra("navigate_to") == "live_track") {
            val rNo = intent.getStringExtra("route_no")
            val rId = intent.getIntExtra("route_id", 0)
            pendingRouteNo = rNo
            pendingRouteId = rId
            if (rNo != null) {
                methodChannel?.invokeMethod(
                    "onNotificationOpened",
                    mapOf("routeNo" to rNo, "routeId" to rId)
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialNotificationPayload" -> {
                    if (pendingRouteNo != null) {
                        val map = mapOf("routeNo" to pendingRouteNo, "routeId" to pendingRouteId)
                        pendingRouteNo = null
                        pendingRouteId = null
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }
                "showCustomLiveNotification" -> {
                    val id = call.argument<Int>("id") ?: 818
                    val routeNo = call.argument<String>("routeNo") ?: ""
                    val origin = call.argument<String>("origin") ?: ""
                    val destination = call.argument<String>("destination") ?: ""
                    val nextStop = call.argument<String>("nextStop") ?: ""
                    val distStr = call.argument<String>("distStr") ?: ""
                    val speedStr = call.argument<String>("speedStr") ?: "Speed: 24 km/h • On Time"
                    val etaStr = call.argument<String>("etaStr") ?: ""
                    val arrivalTimeStr = call.argument<String>("arrivalTimeStr") ?: ""
                    val progress = (call.argument<Double>("progress") ?: 0.25).toFloat()

                    showCustomLiveNotification(
                        id = id,
                        routeNo = routeNo,
                        origin = origin,
                        destination = destination,
                        nextStop = nextStop,
                        distStr = distStr,
                        speedStr = speedStr,
                        etaStr = etaStr,
                        arrivalTimeStr = arrivalTimeStr,
                        progress = progress
                    )
                    result.success(true)
                }
                "cancelCustomLiveNotification" -> {
                    val id = call.argument<Int>("id") ?: 818
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancel(id)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Live Bus Trip Tracking"
            val descriptionText = "Where Is My Train style live trip track notifications"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(true)
                enableVibration(false)
                setSound(null, null)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun showCustomLiveNotification(
        id: Int,
        routeNo: String,
        origin: String,
        destination: String,
        nextStop: String,
        distStr: String,
        speedStr: String,
        etaStr: String,
        arrivalTimeStr: String,
        progress: Float
    ) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 1. Generate the Where Is My Train Wide Rectangular Trip Card
        val cardBitmap = drawTripCardBitmap(
            origin = origin,
            destination = destination,
            etaStr = etaStr,
            arrivalTimeStr = arrivalTimeStr,
            progress = progress.coerceIn(0.05f, 0.95f)
        )

        // 2. Intents for interaction
        val contentIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("navigate_to", "live_track")
            putExtra("route_id", id)
            putExtra("route_no", routeNo)
        }
        val contentPendingIntent = PendingIntent.getActivity(
            this, id, contentIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val dismissIntent = Intent(this, NotificationDismissReceiver::class.java).apply {
            action = "ACTION_DISMISS_TRIP"
            putExtra("notification_id", id)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            this, id, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmIntent = Intent(this, MainActivity::class.java).apply {
            action = "ACTION_SET_ALARM"
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val alarmPendingIntent = PendingIntent.getActivity(
            this, id + 1, alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val titleRaw = "$distStr to $nextStop"
        val titleSpan = SpannableString(titleRaw).apply {
            setSpan(StyleSpan(Typeface.BOLD), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            setSpan(RelativeSizeSpan(1.22f), 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        val summary = speedStr

        // 3. Build Notification with BigPictureStyle & Native Action Buttons
        // Full wide rectangular layout matching Where Is My Train exactly (no largeIcon clutter on the right)
        val bigPictureStyle = NotificationCompat.BigPictureStyle()
            .bigPicture(cardBitmap)
            .setBigContentTitle(titleSpan)
            .setSummaryText(summary)

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_bus_white)
            .setSubText(routeNo)
            .setContentTitle(titleSpan)
            .setContentText(summary)
            .setStyle(bigPictureStyle)
            .addAction(0, "Set alarm", alarmPendingIntent)
            .addAction(0, "Dismiss", dismissPendingIntent)
            .setContentIntent(contentPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setColor(0xFF0288D1.toInt())

        notificationManager.notify(id, builder.build())
    }

    /**
     * Circular Blue Vehicle Badge matching Where Is My Train app icon
     */
    private fun createCircleBusBitmap(): Bitmap {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // Circle background: #0288D1
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0288D1")
            style = Paint.Style.FILL
        }
        val center = size / 2f
        canvas.drawCircle(center, center, center - 4f, bgPaint)

        // White border ring
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = 5f
        }
        canvas.drawCircle(center, center, center - 6.5f, borderPaint)

        // White Bus Glyph
        val busPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        val busRect = RectF(center - 24f, center - 26f, center + 24f, center + 22f)
        canvas.drawRoundRect(busRect, 8f, 8f, busPaint)

        // Blue window cut-out
        val winPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0288D1")
            style = Paint.Style.FILL
        }
        val winRect = RectF(center - 18f, center - 20f, center + 18f, center - 4f)
        canvas.drawRoundRect(winRect, 4f, 4f, winPaint)

        // Wheels
        canvas.drawCircle(center - 13f, center + 24f, 5f, busPaint)
        canvas.drawCircle(center + 13f, center + 24f, 5f, busPaint)

        return bitmap
    }

    /**
     * Draws the exact Where Is My Train Trip Card:
     * - Wide horizontal rectangular layout (1040 x 340 px)
     * - Dark rounded card background (#201422) matching WIMT charcoal-violet
     * - Origin (top left) & Destination (top right) in bold white
     * - Horizontal transit rail track (#633934) with white terminal dot
     * - Circular Blue Bus Pin traveling along the track at exact progress %
     * - Remaining ETA (bottom left) & Scheduled Arrival time (bottom right)
     */
    private fun drawTripCardBitmap(
        origin: String,
        destination: String,
        etaStr: String,
        arrivalTimeStr: String,
        progress: Float
    ): Bitmap {
        val width = 1040
        val height = 340
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        // 1. Dark Card Background with Rounded Corners
        val cardPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#201422") // Exact dark charcoal-violet from WIMT
            style = Paint.Style.FILL
        }
        val cardRect = RectF(0f, 0f, width.toFloat(), height.toFloat())
        canvas.drawRoundRect(cardRect, 28f, 28f, cardPaint)

        // 2. Top Labels: Origin (Left) & Destination (Right)
        val topTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 36f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        val cleanOrigin = if (origin.length > 24) origin.substring(0, 22) + "..." else origin
        val cleanDest = if (destination.length > 22) destination.substring(0, 20) + "..." else destination

        canvas.drawText(cleanOrigin, 48f, 76f, topTextPaint)

        val destWidth = topTextPaint.measureText(cleanDest)
        canvas.drawText(cleanDest, width - 48f - destWidth, 76f, topTextPaint)

        // 3. Horizontal Transit Track Line
        val trackStartX = 54f
        val trackEndX = width - 54f
        val trackY = 172f

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#633934") // Rich warm brown rail color from WIMT
            strokeWidth = 16f
            strokeCap = Paint.Cap.ROUND
            style = Paint.Style.STROKE
        }
        canvas.drawLine(trackStartX, trackY, trackEndX, trackY, trackPaint)

        // Right Endpoint Terminal Dot (White)
        val endDotPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(trackEndX, trackY, 8f, endDotPaint)

        // 4. Moving Circular Vehicle Pin along the Track Line
        val busX = trackStartX + progress * (trackEndX - trackStartX)

        // White border ring
        val pinBorderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        canvas.drawCircle(busX, trackY, 28f, pinBorderPaint)

        // Blue Inner Circle Badge
        val pinInnerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0288D1") // Blue badge matching WIMT
            style = Paint.Style.FILL
        }
        canvas.drawCircle(busX, trackY, 24f, pinInnerPaint)

        // Bus Icon Glyphs inside the badge
        val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            style = Paint.Style.FILL
        }
        // Bus body
        val busRect = RectF(busX - 12f, trackY - 13f, busX + 12f, trackY + 10f)
        canvas.drawRoundRect(busRect, 4f, 4f, iconPaint)

        // Windshield
        val windowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.parseColor("#0288D1")
            style = Paint.Style.FILL
        }
        val windowRect = RectF(busX - 9f, trackY - 11f, busX + 9f, trackY - 3f)
        canvas.drawRoundRect(windowRect, 2f, 2f, windowPaint)

        // Wheels
        canvas.drawCircle(busX - 6.5f, trackY + 12f, 3f, iconPaint)
        canvas.drawCircle(busX + 6.5f, trackY + 12f, 3f, iconPaint)

        // 5. Bottom Labels: ETA (Left) & Scheduled Arrival (Right)
        val bottomTextPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 34f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        val cleanEta = if (etaStr.isNotEmpty()) etaStr else "On Schedule"
        canvas.drawText(cleanEta, 48f, 276f, bottomTextPaint)

        val cleanArrival = if (arrivalTimeStr.isNotEmpty()) arrivalTimeStr else "In Transit"
        val arrivalWidth = bottomTextPaint.measureText(cleanArrival)
        canvas.drawText(cleanArrival, width - 48f - arrivalWidth, 276f, bottomTextPaint)

        return bitmap
    }
}

/**
 * BroadcastReceiver triggered when the user taps "Dismiss" in the custom notification
 */
class NotificationDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("notification_id", 0)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(id)
    }
}
