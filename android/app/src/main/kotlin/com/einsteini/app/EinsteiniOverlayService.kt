package com.einsteini.app

import android.animation.AnimatorListenerAdapter
import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.content.res.Configuration
import android.content.res.Resources
import android.content.res.ColorStateList
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.ColorDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.util.Log
import android.view.ContextThemeWrapper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.OvershootInterpolator
import android.widget.ArrayAdapter
import android.widget.AdapterView
import android.widget.Button
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.RelativeLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.cardview.widget.CardView
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.core.content.res.ResourcesCompat
import androidx.core.view.children
import androidx.core.widget.NestedScrollView
import com.google.android.material.card.MaterialCardView
import com.einsteini.app.R
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.lang.Exception
import java.lang.Math.abs
import java.lang.Math.max
import java.lang.Math.min
import java.net.HttpURLConnection
import java.net.URL
import kotlin.properties.Delegates
import kotlinx.coroutines.*

class EinsteiniOverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private lateinit var bubbleView: View
    private lateinit var overlayView: View
    private lateinit var closeButtonView: View
    
    // Content view containers for different tabs
    private lateinit var contentViewLinkedIn: LinearLayout
    private lateinit var contentViewTwitter: LinearLayout
    private lateinit var contentViewComment: LinearLayout
    
    private var bubbleParams: WindowManager.LayoutParams? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var closeButtonParams: WindowManager.LayoutParams? = null
    
    private var initialX: Int = 0
    private var initialY: Int = 0
    private var initialTouchX: Float = 0f
    private var initialTouchY: Float = 0f
    private var screenWidth: Int = 0
    private var screenHeight: Int = 0
    private var bubbleSize: Int = 120 // Increased size
    private var closeButtonSize: Int = 180 // Slightly larger than bubble for easier targeting
    private var lastUpdateTime: Long = 0
    private val FRAME_RATE = 60 // Target 60 FPS
    private val FRAME_TIME = (1000 / FRAME_RATE).toLong() // Time per frame in milliseconds
    private var currentAnimator: ValueAnimator? = null
    private var isOverlayVisible = false
    private val NOTIFICATION_ID = 101
    private val CHANNEL_ID = "einsteini_overlay_channel"
    private var isDraggingOverlay = false
    
    private var overlayWidth = 800
    private var overlayHeight = 600
    private val CLOSE_TRIGGER_DISTANCE = 100
    private var isDarkTheme: Boolean = false
    private var fromShare: Boolean = false

    // Global flag to track if bubble is shown
    private var isBubbleShown = false

    // Store scraped data
    private var scrapedData: Map<String, Any> = mapOf()

    // Return the cached theme value instead of checking system settings
    private fun isDarkModeEnabled(): Boolean {
        // Always use our stored isDarkTheme value instead of checking system settings
        return isDarkTheme
    }

    companion object {
        private var instance: EinsteiniOverlayService? = null
        private var methodChannel: MethodChannel? = null
        private var running = false

        fun isRunning(): Boolean {
            return running && instance != null
        }

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
            Log.d(TAG, "Method channel set successfully. Channel: $channel")
            Log.d(TAG, "Current instance: $instance")
            
            // Method channel is no longer needed since we use direct API calls
            Log.d(TAG, "Method channel available but using direct API calls instead")
        }
        
        fun isMethodChannelAvailable(): Boolean {
            return methodChannel != null
        }

        fun getInstance(): EinsteiniOverlayService? {
            return instance
        }

        private const val TAG = "EinsteiniOverlayService"
        private const val NOTIFICATION_ID_NEW = 1001
        private const val CHANNEL_ID_NEW = "EinsteiniOverlayChannel"
        private const val CHANNEL_NAME = "Overlay Service"
        
        // Theme-related constants
        private const val THEME_PREFERENCE_KEY = "theme_preference"
        
        // Public methods to control service from outside
        fun showOverlay(context: Context) {
            Log.d(TAG, "showOverlay called from companion")
            try {
                val intent = Intent(context, EinsteiniOverlayService::class.java)
                intent.action = "START_OVERLAY"
                
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    Log.d(TAG, "Starting as foreground service")
                    context.startForegroundService(intent)
                } else {
                    Log.d(TAG, "Starting as regular service")
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception in showOverlay", e)
            }
        }
        
        fun hideOverlay(context: Context) {
            Log.d(TAG, "hideOverlay called from companion")
            try {
                val intent = Intent(context, EinsteiniOverlayService::class.java)
                intent.action = "STOP_SERVICE"
                context.startService(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Exception in hideOverlay", e)
            }
        }
        
        // Send scraped content to Flutter
        fun sendScrapedContentToFlutter(content: Map<String, Any>) {
            try {
                methodChannel?.invokeMethod("onContentScraped", content)
            } catch (e: Exception) {
                Log.e(TAG, "Error sending scraped content to Flutter", e)
            }
        }
    }
    
    @SuppressLint("ClickableViewAccessibility")
    override fun onCreate() {
        super.onCreate()
        Log.d("EinsteiniOverlay", "Service onCreate")
        
        // Create notification channel for Android O and above
        createNotificationChannel()
        
        // Start as foreground service with notification IMMEDIATELY
        // This must be called within 5 seconds of service creation to avoid ForegroundServiceDidNotStartInTimeException
        try {
            startForeground(NOTIFICATION_ID, createNotification())
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Failed to start as foreground service", e)
            // Continue anyway, as we might still be able to show the overlay
            // even if the foreground service fails
        }
        
        try {
            // Apply the Material Components theme for proper styling
            // We don't set the theme directly on the service as it doesn't work that way
            // Instead, we'll use ContextThemeWrapper when inflating views
            
            windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
            
            // Get screen dimensions
            val metrics = DisplayMetrics()
            windowManager.defaultDisplay.getMetrics(metrics)
            screenWidth = metrics.widthPixels
            screenHeight = metrics.heightPixels
            
            // Initialize with the proper theme from shared preferences
            isDarkTheme = getInitialThemeFromPreferences()
            Log.d("EinsteiniOverlay", "Initializing with theme from preferences: isDarkTheme=$isDarkTheme")
            
            // Update instance and running state
            instance = this
            running = true
            
            // Setup components in sequence, with error handling for each
            try {
                setupBubble()
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error setting up bubble", e)
            }
            
            try {
                setupOverlay()
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error setting up overlay", e)
            }
            
            try {
                setupCloseButton()
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error setting up close button", e)
            }
            
            // Register for theme changes from Flutter
            registerThemeChangeReceiver()
            
            // Log method channel status
            Log.d(TAG, "Service created. Method channel available: ${methodChannel != null}")
            
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Fatal error in onCreate", e)
            stopSelf()
        }
    }
    
    // Helper method to make API calls directly
    private fun makeApiCall(
        endpoint: String,
        jsonBody: String,
        callback: (String?) -> Unit
    ) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = URL("https://backend.einsteini.ai/api/$endpoint")
                val connection = url.openConnection() as HttpURLConnection
                
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("x-app-platform", "android")
                connection.doOutput = true
                connection.doInput = true
                
                // Write request body
                val writer = OutputStreamWriter(connection.outputStream)
                writer.write(jsonBody)
                writer.flush()
                writer.close()
                
                // Read response
                val responseCode = connection.responseCode
                Log.d(TAG, "API call to $endpoint - Response code: $responseCode")
                
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = reader.readText()
                    reader.close()
                    
                    Log.d(TAG, "API response: ${response.take(100)}...")
                    callback(response)
                } else {
                    val errorReader = BufferedReader(InputStreamReader(connection.errorStream ?: connection.inputStream))
                    val errorResponse = errorReader.readText()
                    errorReader.close()
                    
                    Log.e(TAG, "API error: $responseCode - $errorResponse")
                    callback(null)
                }
                
                connection.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Exception in API call", e)
                callback(null)
            }
        }
    }
    
    // Get user email from shared preferences
    private fun getUserEmail(): String {
        val sharedPref = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        return sharedPref.getString("flutter.user_email", "") ?: ""
    }

    // Override onConfigurationChanged to prevent system theme changes from affecting our UI
    override fun onConfigurationChanged(newConfig: Configuration) {
        super.onConfigurationChanged(newConfig)
        // Deliberately ignore configuration changes to prevent system theme changes from affecting our UI
        Log.d(TAG, "Configuration changed, but keeping current theme: $isDarkTheme")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("EinsteiniOverlay", "Service onStartCommand with intent: $intent, action: ${intent?.action}")
        Log.d(TAG, "onStartCommand - Method channel available: ${methodChannel != null}")
        
        // Store whether this came from a share
        val wasFromShare = intent?.getBooleanExtra("fromShare", false) ?: false
        fromShare = wasFromShare
        
        Log.d("EinsteiniOverlay", "fromShare set to: $fromShare")
        
        // Always check for theme update in any intent
        if (intent?.hasExtra("isDarkMode") == true) {
            val newIsDarkMode = intent.getBooleanExtra("isDarkMode", isDarkTheme)
            if (newIsDarkMode != isDarkTheme) {
                Log.d("EinsteiniOverlay", "Updating theme from intent: isDarkMode=$newIsDarkMode (previous: $isDarkTheme)")
                isDarkTheme = newIsDarkMode
                updateAllViews()
            }
        }
        
        try {
            if (intent?.action == "UPDATE_THEME") {
                val isDarkMode = intent.getBooleanExtra("isDarkMode", false)
                Log.d("EinsteiniOverlay", "Received explicit theme update: isDarkMode=$isDarkMode")
                isDarkTheme = isDarkMode
                updateAllViews()
                return START_STICKY
            }
            
            if (intent?.action == "PROCESS_SOCIAL_URL") {
                val socialUrl = intent.getStringExtra("socialUrl")
                Log.d("EinsteiniOverlay", "Processing social URL: $socialUrl, fromShare: $fromShare")
                
                if (!socialUrl.isNullOrEmpty()) {
                    Log.d("EinsteiniOverlay", "About to show bubble for social URL")
                    
                    // First show the bubble to ensure it's visible
                    showBubble()
                    
                    // Add a small delay to ensure bubble is shown before overlay
                    Handler(Looper.getMainLooper()).postDelayed({
                        Log.d("EinsteiniOverlay", "About to show overlay window for social URL")
                        // Then show the overlay window (which will keep bubble visible)
                        showOverlayWindow()
                        
                        // Process the social URL and update the overlay content
                        processSocialUrl(socialUrl)
                    }, 100) // Small delay to ensure bubble is rendered
                }
                
                return START_STICKY
            }
            
            if (intent?.action == "SHOW_TRANSLATED_CONTENT") {
                val original = intent.getStringExtra("original") ?: ""
                val translation = intent.getStringExtra("translation") ?: ""
                val language = intent.getStringExtra("language") ?: ""
                
                // Make sure the overlay is visible (keep bubble visible)
                showOverlayWindow()
                
                // Show the translated content
                showTranslatedContent(original, translation, language)
                
                return START_STICKY
            }
            
            if (intent?.action == "SHOW_COMMENT_OPTIONS") {
                val professional = intent.getStringExtra("professional") ?: ""
                val question = intent.getStringExtra("question") ?: ""
                val thoughtful = intent.getStringExtra("thoughtful") ?: ""
                
                // Make sure the overlay is visible (keep bubble visible)
                showOverlayWindow()
                
                // Show the comment options
                showCommentOptions(professional, question, thoughtful)
                
                return START_STICKY
            }
            
            if (intent?.action == "STOP_SERVICE") {
                Log.d("EinsteiniOverlay", "Stopping service by request")
                stopSelf()
                return START_NOT_STICKY
            }
            
            // Default behavior - show the bubble if not showing overlay
            if (!isOverlayVisible) {
                Log.d("EinsteiniOverlay", "Default behavior - showing bubble")
            showBubble()
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error in onStartCommand", e)
        }
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Einsteini Overlay"
            val descriptionText = "Notifications for Einsteini overlay service"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
                setShowBadge(false)
            }
            val notificationManager: NotificationManager = 
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else 
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Create a stop action
        val stopIntent = Intent(this, EinsteiniOverlayService::class.java).apply {
            action = "STOP_SERVICE"
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 1, stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) 
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            else 
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Einsteini Floating Assistant")
            .setContentText("Tap to open app")
            .setSmallIcon(android.R.drawable.ic_dialog_info) // Fallback icon
            .setColor(0xC58AFF) // Purple color
            .setColorized(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .build()
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupBubble() {
        Log.d("EinsteiniOverlay", "Creating bubble")
        try {
            // Create the bubble view
            bubbleView = LayoutInflater.from(this).inflate(R.layout.bubble, null)
            
            // Get the image view
            val bubbleImageView = bubbleView.findViewById<ImageView>(R.id.bubble_icon)
            
            // Always use our stored theme value, not system theme
            updateBubbleTheme()
            
            Log.d(TAG, "Bubble setup complete with theme isDarkTheme=$isDarkTheme")
            
            // Create a layout type based on Android version
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            bubbleParams = WindowManager.LayoutParams(
                bubbleSize,
                bubbleSize,
                type,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 100
            }

            bubbleView.setOnTouchListener { view, event ->
                when (event.action) {
                    MotionEvent.ACTION_DOWN -> {
                        Log.d("EinsteiniOverlay", "Bubble touched down")
                        currentAnimator?.cancel()
                        initialX = bubbleParams?.x ?: 0
                        initialY = bubbleParams?.y ?: 0
                        initialTouchX = event.rawX
                        initialTouchY = event.rawY
                        try {
                            showCloseButton()
                        } catch (e: Exception) {
                            Log.e("EinsteiniOverlay", "Error showing close button", e)
                        }
                        true
                    }
                    MotionEvent.ACTION_MOVE -> {
                        val currentTime = System.currentTimeMillis()
                        if (currentTime - lastUpdateTime >= FRAME_TIME) {
                            bubbleParams?.x = initialX + (event.rawX - initialTouchX).toInt()
                            bubbleParams?.y = initialY + (event.rawY - initialTouchY).toInt()

                            // Ensure bubble stays within screen bounds
                            bubbleParams?.x = max(0, min(bubbleParams?.x ?: 0, screenWidth - bubbleSize))
                            bubbleParams?.y = max(0, min(bubbleParams?.y ?: 0, screenHeight - bubbleSize))

                            try {
                                if (bubbleView.parent != null) {
                                    windowManager.updateViewLayout(bubbleView, bubbleParams)
                                }
                            } catch (e: Exception) {
                                Log.e("EinsteiniOverlay", "Error updating bubble position", e)
                            }

                            // Update close button alpha based on proximity
                            if (isNearCloseButton(event.rawX, event.rawY)) {
                                animateCloseButtonAlpha(1f)
                            } else {
                                animateCloseButtonAlpha(0.5f)
                            }

                            lastUpdateTime = currentTime
                        }
                        true
                    }
                    MotionEvent.ACTION_UP -> {
                        Log.d("EinsteiniOverlay", "Bubble touched up")
                        val moved = abs(event.rawX - initialTouchX) > 10 ||
                                  abs(event.rawY - initialTouchY) > 10

                        if (moved) {
                            if (isNearCloseButton(event.rawX, event.rawY)) {
                                animateAndClose()
                            } else {
                                snapToEdge(bubbleParams)
                            }
                        } else {
                            // It was a click
                            Log.d("EinsteiniOverlay", "Bubble clicked, showing overlay")
                            toggleOverlayVisibility()
                        }
                        try {
                            hideCloseButton()
                        } catch (e: Exception) {
                            Log.e("EinsteiniOverlay", "Error hiding close button", e)
                        }
                        true
                    }
                    else -> false
                }
            }

            // Don't add view here, we'll add it in onStartCommand
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up bubble", e)
        }
    }
    
    // Update bubble theme based on current dark mode setting
    private fun updateBubbleTheme() {
        if (!::bubbleView.isInitialized) {
            Log.d(TAG, "Bubble view not initialized yet, skipping theme update")
            return
        }
        
        Log.d(TAG, "Updating bubble theme. Dark mode: $isDarkTheme")
        
        try {
            val bubbleImageView = bubbleView.findViewById<ImageView>(R.id.bubble_icon)
            
            // Set the correct background based on theme
            val bubbleBackground = if (isDarkTheme) {
                R.drawable.bubble_background_dark
            } else {
                R.drawable.bubble_background_light
            }
            
            // Set the correct icon based on theme
            val iconResource = if (isDarkTheme) {
                R.drawable.einsteini_white
            } else {
                R.drawable.einsteini_black
            }
            
            // Apply background and image immediately in a UI-thread safe way
            bubbleView.post {
                try {
                    // Update background
                    bubbleImageView?.background = ContextCompat.getDrawable(this, bubbleBackground)
                    
                    // Update image
                    bubbleImageView?.setImageResource(iconResource)
                    
                    Log.d(TAG, "Bubble theme updated successfully. Using background: $bubbleBackground and icon: $iconResource")
                } catch (e: Exception) {
                    Log.e(TAG, "Error setting bubble background or image", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating bubble theme", e)
        }
    }
    
    @SuppressLint("ClickableViewAccessibility")
    private fun setupOverlay() {
        Log.d("EinsteiniOverlay", "Creating overlay")
        try {
            // Create overlay view from layout using a themed context
            val contextThemeWrapper = ContextThemeWrapper(this, R.style.EinsteiniOverlayTheme)
            val inflater = LayoutInflater.from(contextThemeWrapper)
            overlayView = inflater.inflate(R.layout.overlay_window, null)
            
            // Get the tab elements (now simple LinearLayout without indicator)
            val tabContainer = overlayView.findViewById<LinearLayout>(R.id.tabContainer)
            val tabComment = overlayView.findViewById<TextView>(R.id.tab_comment)
            val tabTranslate = overlayView.findViewById<TextView>(R.id.tab_translate)
            val tabSummarize = overlayView.findViewById<TextView>(R.id.tab_summarize)
            
            // Load and apply custom fonts - updated to use TikTok Sans and DM Sans
            val tiktokSans = ResourcesCompat.getFont(this, R.font.tiktok_sans)
            val dmSans = ResourcesCompat.getFont(this, R.font.dm_sans)
            
            // Apply TikTok Sans font to all tab TextViews explicitly
            tabTranslate.typeface = tiktokSans
            tabSummarize.typeface = tiktokSans
            tabComment.typeface = tiktokSans
            
            // Get content view containers from XML
            contentViewLinkedIn = overlayView.findViewById(R.id.contentViewLinkedIn)
            contentViewTwitter = overlayView.findViewById(R.id.contentViewTwitter)
            contentViewComment = overlayView.findViewById(R.id.contentViewComment)
            
            // Apply fonts to all text elements in the overlay
            applyFontsToAllTextViews(overlayView, tiktokSans, dmSans)
            
            // Apply initial theme-based styling
            updateOverlayTheme(isDarkTheme)
            
            // Set up click listener for the scrim to close the overlay
            val overlayScrim = overlayView.findViewById<View>(R.id.overlay_scrim)
            overlayScrim.setOnClickListener {
                hideOverlay()
            }
            
            // Set background based on theme with simple design
            val overlayContainer = overlayView.findViewById<LinearLayout>(R.id.overlay_container)
            overlayContainer.background = ContextCompat.getDrawable(
                this, 
                if (isDarkTheme) R.drawable.overlay_background_dark else R.drawable.overlay_background_light
            )
            
            // Update tab navigation styles based on theme
            updateTabNavigationTheme()
            
            // Setup the dropdowns
            setupSummaryOptions()
            setupTranslationOptions()
            setupCommentOptions()
            
            // Set up tab navigation listeners
            tabComment.setOnClickListener {
                updateTabs(0)
            }
            
            tabTranslate.setOnClickListener {
                Log.d("EinsteiniOverlay", "Translate tab clicked")
                updateTabs(1)
            }
            
            tabSummarize.setOnClickListener {
                updateTabs(2)
            }
            
            // Default to the first tab (Comment)
            updateTabs(0)
            
            // Get reference to the ScrollView
            val scrollView = overlayView.findViewById<NestedScrollView>(R.id.contentScrollView)
            
            // Set up resize handle with direct window manager updates
            val resizeHandle = overlayView.findViewById<View>(R.id.resizeHandle)
            var initialTouchY = 0f
            var initialHeight = 0
            
            // Minimum height to ensure tabs are always visible
            val minHeightCalculated = (resources.displayMetrics.heightPixels * 0.45).toInt()  // Reduced to 45%
            val minHeight = maxOf(minHeightCalculated, 650) // Reduced to 650dp for better spacing
            
            // Intercept touch events on the resize handle to prevent scroll conflicts
            resizeHandle.setOnTouchListener(object : View.OnTouchListener {
                override fun onTouch(view: View, event: MotionEvent): Boolean {
                    // Prevent scroll view from intercepting touch events during resize
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            scrollView.requestDisallowInterceptTouchEvent(true)
                            initialTouchY = event.rawY
                            initialHeight = overlayContainer.height
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            // Calculate new height based on drag (moving up increases height)
                            val dy = initialTouchY - event.rawY
                            val newHeight = initialHeight + dy.toInt()
                            
                            // If height is below minimum threshold, immediately dismiss
                            if (newHeight < minHeight) {
                                hideOverlay()
                                return true
                            } else {
                                overlayContainer.alpha = 1f
                                
                                // Update the overlay container height
                                try {
                                    val params = overlayContainer.layoutParams
                                    params.height = newHeight
                                    overlayContainer.layoutParams = params
                                } catch (e: Exception) {
                                    Log.e("EinsteiniOverlay", "Error updating overlay height", e)
                                }
                            }
                            return true
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            scrollView.requestDisallowInterceptTouchEvent(false)
                            // If we ended with a height below minimum, hide the overlay
                            if (overlayContainer.height < minHeight) {
                                hideOverlay()
                            }
                            return true
                        }
                        else -> return false
                    }
                }
            })
            
            // Add drag functionality to the tab container
            tabContainer.setOnTouchListener(object : View.OnTouchListener {
                private var initialX = 0
                private var initialY = 0
                private var initialTouchX = 0f
                private var initialTouchY = 0f
                
                @SuppressLint("ClickableViewAccessibility")
                override fun onTouch(v: View, event: MotionEvent): Boolean {
                    // Handle touch events for dragging the overlay
                    when (event.action) {
                        MotionEvent.ACTION_DOWN -> {
                            // Store initial positions
                            initialX = overlayParams?.x ?: 0
                            initialY = overlayParams?.y ?: 0
                            initialTouchX = event.rawX
                            initialTouchY = event.rawY
                            isDraggingOverlay = true
                            return true
                        }
                        MotionEvent.ACTION_MOVE -> {
                            if (isDraggingOverlay) {
                                // Calculate new position
                                val newX = initialX + (event.rawX - initialTouchX).toInt()
                                val newY = initialY + (event.rawY - initialTouchY).toInt()
                                
                                // Update overlay position
                                overlayParams?.x = newX
                                overlayParams?.y = newY
                                
                                // Apply the new position
                                try {
                                    if (::overlayView.isInitialized && overlayView.isAttachedToWindow) {
                                        windowManager.updateViewLayout(overlayView, overlayParams)
                                    }
                                } catch (e: Exception) {
                                    Log.e("EinsteiniOverlay", "Error updating overlay position", e)
                                }
                                return true
                            }
                        }
                        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                            isDraggingOverlay = false
                            return true
                        }
                    }
                    return false
                }
            })
            
            // Make sure to apply the current theme immediately after creating the overlay
            updateOverlayTheme(isDarkTheme)
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up overlay", e)
        }
    }
    
    // Setup summary options dropdown
    private fun setupSummaryOptions() {
        try {
            // Get references to the spinner
            val summarySpinner = overlayView.findViewById<Spinner>(R.id.summary_type_spinner)
            
            // Create an adapter for the spinner with summary types that match Flutter implementation
            val summaryTypes = arrayOf("Brief", "Detailed", "Concise")
            val adapter = object : ArrayAdapter<String>(
                this,
                android.R.layout.simple_spinner_item,
                summaryTypes
            ) {
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                    val view = super.getView(position, convertView, parent)
                    val textView = view.findViewById<TextView>(android.R.id.text1)
                    textView.setTextColor(Color.parseColor("#E0E0E0"))
                    textView.setPadding(16, 16, 16, 16)
                    textView.textSize = 14f
                    return view
                }
                
                override fun getDropDownView(position: Int, convertView: View?, parent: ViewGroup): View {
                    val view = super.getDropDownView(position, convertView, parent)
                    val textView = view.findViewById<TextView>(android.R.id.text1)
                    textView.setTextColor(Color.parseColor("#E0E0E0"))
                    textView.setBackgroundColor(Color.parseColor("#1E1E1E"))
                    textView.setPadding(16, 16, 16, 16)
                    textView.textSize = 14f
                    return view
                }
            }
            
            // Apply the adapter to the spinner
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            summarySpinner.adapter = adapter
            
            // Set up generate button click listener
            val generateButton = overlayView.findViewById<Button>(R.id.generate_summary_button)
            generateButton.setOnClickListener {
                val selectedSummaryType = summaryTypes[summarySpinner.selectedItemPosition]
                generateSummary(selectedSummaryType)
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up summary options", e)
        }
    }
    
    // Setup translation options dropdown (using existing XML views)
    private fun setupTranslationOptions() {
        try {
            Log.d("EinsteiniOverlay", "Setting up translation options dynamically")
            
            // The translation UI is now in XML, so we just need to set up the language spinner
            val languageSpinner = contentViewTwitter.findViewById<Spinner>(R.id.language_spinner)
            val generateButton = contentViewTwitter.findViewById<Button>(R.id.generate_translation_button)
            
            if (languageSpinner != null && generateButton != null) {
                // Setup language spinner with options that match Flutter implementation
                val languages = arrayOf("Spanish", "French", "German", "Italian", "Portuguese", "Chinese", "Japanese", "Korean", "Russian", "Arabic")
                val languageAdapter = object : ArrayAdapter<String>(
                    this,
                    android.R.layout.simple_spinner_item,
                    languages
                ) {
                    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                        val view = super.getView(position, convertView, parent)
                        val textView = view.findViewById<TextView>(android.R.id.text1)
                        textView.setTextColor(Color.parseColor("#E0E0E0"))
                        textView.setPadding(16, 16, 16, 16)
                        textView.textSize = 14f
                        return view
                    }
                    
                    override fun getDropDownView(position: Int, convertView: View?, parent: ViewGroup): View {
                        val view = super.getDropDownView(position, convertView, parent)
                        val textView = view.findViewById<TextView>(android.R.id.text1)
                        textView.setTextColor(Color.parseColor("#E0E0E0"))
                        textView.setBackgroundColor(Color.parseColor("#1E1E1E"))
                        textView.setPadding(16, 16, 16, 16)
                        textView.textSize = 14f
                        return view
                    }
                }
                languageAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                languageSpinner.adapter = languageAdapter
                
                // Setup button click listener
                generateButton.setOnClickListener {
                    val selectedLanguage = languageSpinner.selectedItem.toString()
                    Log.d("EinsteiniOverlay", "Generate translation clicked: $selectedLanguage")
                    generateTranslation(selectedLanguage)
                }
                
                Log.d("EinsteiniOverlay", "Translation UI setup completed")
            } else {
                Log.e("EinsteiniOverlay", "Translation UI elements not found in XML")
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up translation options", e)
        }
    }
    
    // Extension function to convert dp to pixels
    private fun Int.dpToPx(): Int {
        return (this * resources.displayMetrics.density).toInt()
    }
    
    // Setup comment options dropdowns (using existing XML views)
    private fun setupCommentOptions() {
        try {
            Log.d("EinsteiniOverlay", "Setting up comment options dynamically")
            
            // The comment UI is now in XML, so we just need to set up the spinner
            val toneSpinner = contentViewComment.findViewById<Spinner>(R.id.tone_spinner)
            val generateButton = contentViewComment.findViewById<Button>(R.id.generate_comment_button)
            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
            
            if (toneSpinner != null && generateButton != null) {
                // Setup tone spinner - these match the Flutter implementation exactly
                val tones = arrayOf("Applaud", "Agree", "Fun", "Personalize", "Perspective", "Question", "Contradict")
                val toneAdapter = object : ArrayAdapter<String>(
                    this,
                    android.R.layout.simple_spinner_item,
                    tones
                ) {
                    override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                        val view = super.getView(position, convertView, parent)
                        val textView = view.findViewById<TextView>(android.R.id.text1)
                        textView.setTextColor(Color.parseColor("#E0E0E0"))
                        textView.setPadding(16, 16, 16, 16)
                        textView.textSize = 14f
                        return view
                    }
                    
                    override fun getDropDownView(position: Int, convertView: View?, parent: ViewGroup): View {
                        val view = super.getDropDownView(position, convertView, parent)
                        val textView = view.findViewById<TextView>(android.R.id.text1)
                        textView.setTextColor(Color.parseColor("#E0E0E0"))
                        textView.setBackgroundColor(Color.parseColor("#1E1E1E"))
                        textView.setPadding(16, 16, 16, 16)
                        textView.textSize = 14f
                        return view
                    }
                }
                toneAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                toneSpinner.adapter = toneAdapter
                
                // Setup spinner selection listener to show/hide personalization fields
                toneSpinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                        val selectedTone = tones[position]
                        Log.d("EinsteiniOverlay", "Selected tone: $selectedTone")
                        
                        // Show/hide personalization fields based on selection
                        val personalizationContainer = contentViewComment.findViewById<LinearLayout>(R.id.personalization_container)
                        if (selectedTone == "Personalize") {
                            personalizationContainer?.visibility = View.VISIBLE
                            setupPersonalizationFields()
                        } else {
                            personalizationContainer?.visibility = View.GONE
                        }
                    }
                    
                    override fun onNothingSelected(parent: AdapterView<*>?) {}
                }
                
                // Setup personalization fields
                setupPersonalizationFields()
                
                // Setup button click listener
                generateButton.setOnClickListener {
                    val selectedTone = toneSpinner.selectedItem.toString()
                    Log.d("EinsteiniOverlay", "Generate comment clicked: tone=$selectedTone")
                    
                    if (selectedTone == "Personalize") {
                        generatePersonalizedComment()
                    } else {
                        // Use the selected tone as the comment type
                        generateComment(selectedTone.lowercase(), "professional")
                    }
                }
                
                // Setup copy button click listener
                copyButton?.setOnClickListener {
                    val commentContent = contentViewComment.findViewById<TextView>(R.id.comment_content)
                    val commentText = commentContent?.text?.toString()
                    
                    if (!commentText.isNullOrBlank() && 
                        commentText != "Your generated comment will appear here." &&
                        !commentText.contains("Generating")) {
                        
                        // Copy to clipboard
                        val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                        val clipData = android.content.ClipData.newPlainText("Comment", commentText)
                        clipboardManager.setPrimaryClip(clipData)
                        
                        // Show toast to confirm copy
                        android.widget.Toast.makeText(this, "Comment copied to clipboard!", android.widget.Toast.LENGTH_SHORT).show()
                        
                        Log.d("EinsteiniOverlay", "Comment copied to clipboard: ${commentText.take(50)}...")
                    } else {
                        android.widget.Toast.makeText(this, "No comment to copy", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
                
                Log.d("EinsteiniOverlay", "Comment UI setup completed")
            } else {
                Log.e("EinsteiniOverlay", "Comment UI elements not found in XML")
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up comment options", e)
        }
    }
    
    // Setup personalization fields
    private fun setupPersonalizationFields() {
        try {
            val personalizationToneField = contentViewComment.findViewById<EditText>(R.id.personalization_tone_field)
            if (personalizationToneField != null) {
                // Don't prefill the tone - let user enter their own
                personalizationToneField.hint = "e.g., Professional, Casual, Supportive"
                
                // Apply theme-appropriate styling
                personalizationToneField.setTextColor(if (isDarkTheme) Color.parseColor("#E0E0E0") else Color.parseColor("#333333"))
                personalizationToneField.setHintTextColor(if (isDarkTheme) Color.parseColor("#666666") else Color.parseColor("#888888"))
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up personalization tone field", e)
        }
    }
    
    // Generate personalized comment using XML fields
    private fun generatePersonalizedComment() {
        try {
            Log.d("EinsteiniOverlay", "Generating personalized comment")
            
            val commentContent = contentViewComment.findViewById<TextView>(R.id.comment_content)
            commentContent?.text = "Generating personalized comment..."
            
            // Hide copy button while generating
            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
            copyButton?.visibility = View.GONE
            
            // Get personalization details from XML elements
            val personalizationToneField = contentViewComment.findViewById<EditText>(R.id.personalization_tone_field)
            val personalizationDetails = contentViewComment.findViewById<EditText>(R.id.personalization_details)
            
            val personalTone = personalizationToneField?.text?.toString()?.takeIf { it.isNotBlank() } ?: "Professional"
            val personalDetails = personalizationDetails?.text?.toString() ?: ""
            
            Log.d("EinsteiniOverlay", "Personalization - Tone: $personalTone, Details: $personalDetails")
            
            // Get content from scraped data
            val content = scrapedData["content"] as? String ?: ""
            val author = scrapedData["author"] as? String ?: "Author"
            
            val finalContent = if (content.isBlank()) {
                "This is a sample LinkedIn post about the importance of continuous learning in technology."
            } else {
                content
            }
            
            // Clean up the content
            var cleanedContent = finalContent
                .replace(Regex("\\n+"), " ")
                .replace(Regex("\\s+"), " ")
                .replace("…more", "")
                .trim()
            
            if (cleanedContent.length > 300) {
                cleanedContent = cleanedContent.substring(0, 300) + "...";
            }
            
            // Create personalized prompt
            val basePrompt = "Generate a $personalTone tone comment for a LinkedIn post by $author: $cleanedContent"
            val fullPrompt = if (personalDetails.isNotBlank()) {
                "$basePrompt. Additional instructions: $personalDetails"
            } else {
                basePrompt
            }
            
            Log.d("EinsteiniOverlay", "Using personalized prompt: $fullPrompt")
            
            // Create JSON body
            val jsonBody = JSONObject().apply {
                put("requestContext", JSONObject().put("httpMethod", "POST"))
                put("prompt", fullPrompt)
                put("email", getUserEmail())
            }.toString()
            
            // Make API call
            makeApiCall("comment", jsonBody) { response ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        if (response != null) {
                            var comment = response
                            
                            // Parse response exactly like Flutter's ApiService does
                            try {
                                val responseJson = JSONObject(response)
                                comment = if (responseJson.has("text")) {
                                    responseJson.getString("text")
                                } else if (responseJson.has("comment")) {
                                    responseJson.getString("comment")
                                } else if (responseJson.has("response")) {
                                    responseJson.getString("response")
                                } else {
                                    responseJson.toString()
                                }
                            } catch (e: Exception) {
                                comment = response
                            }
                            
                            val cleanedComment = if (comment?.startsWith("\"") == true && comment.endsWith("\"")) {
                                comment.substring(1, comment.length - 1)
                            } else {
                                comment ?: "Unable to generate personalized comment"
                            }
                            
                            commentContent?.text = cleanedComment
                            copyButton?.visibility = View.VISIBLE
                            
                            Log.d("EinsteiniOverlay", "Personalized comment generated: ${cleanedComment.take(50)}...")
                        } else {
                            commentContent?.text = "This looks like an exciting opportunity in the tech space!"
                            copyButton?.visibility = View.VISIBLE
                        }
                    } catch (e: Exception) {
                        Log.e("EinsteiniOverlay", "Error processing personalized comment response", e)
                        commentContent?.text = "Great opportunity for developers interested in AI and software development!"
                        copyButton?.visibility = View.VISIBLE
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error generating personalized comment", e)
            val commentContent = contentViewComment.findViewById<TextView>(R.id.comment_content)
            commentContent?.text = "Great opportunity for developers interested in AI and software development!"
            
            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
            copyButton?.visibility = View.VISIBLE
        }
    }
    
    // Generate summary based on selected type
    private fun generateSummary(summaryType: String) {
        try {
            Log.d("EinsteiniOverlay", "Generating summary of type: $summaryType")
            
            val blockContent = contentViewLinkedIn.findViewById<TextView>(R.id.block_content)
            blockContent?.text = "Generating $summaryType summary..."
            
            // Get the content and author from our stored data
            val content = scrapedData["content"] as? String ?: ""
            val author = scrapedData["author"] as? String ?: ""
            
            // Map the UI summary type to the API expected format (match Flutter implementation)
            val apiSummaryType = when (summaryType.lowercase()) {
                "brief" -> "brief"
                "detailed" -> "detailed"
                "concise" -> "concise"
                else -> "brief"
            }
            
            val finalContent = if (content.isBlank()) {
                Log.w(TAG, "No content available for summarization, using test content")
                "This is a sample LinkedIn post about the importance of continuous learning in technology. The tech industry evolves rapidly, and staying updated with the latest trends, frameworks, and best practices is crucial for career growth. Whether it's learning a new programming language, understanding cloud computing, or exploring AI and machine learning, the journey of learning never stops. Embracing this mindset not only enhances professional skills but also opens doors to new opportunities and innovations."
            } else {
                content
            }
            
            Log.d(TAG, "Generating summary with type: $apiSummaryType")
            Log.d(TAG, "Content length: ${finalContent.length}")
            
            // Create JSON body for API call
            val jsonBody = JSONObject().apply {
                put("requestContext", JSONObject().put("httpMethod", "POST"))
                put("text", finalContent)
                put("email", getUserEmail())
                put("style", apiSummaryType)
            }.toString()
            
            // Make direct API call
            makeApiCall("summarize", jsonBody) { response ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        if (response != null) {
                            var summary = response
                            
                            // Try to parse as JSON first, fallback to plain text
                            try {
                                val responseJson = JSONObject(response)
                                summary = if (responseJson.has("body")) {
                                    if (responseJson.get("body") is String) {
                                        responseJson.getString("body")
                                    } else {
                                        responseJson.getJSONObject("body").optString("summary", responseJson.getString("body"))
                                    }
                                } else {
                                    responseJson.optString("summary", response)
                                }
                            } catch (e: Exception) {
                                // Response is likely plain text, use as-is
                                Log.d(TAG, "Response is plain text, using directly")
                            }
                            
                            // Ensure summary is not null
                            val safeSummary = summary ?: "Unable to generate summary"
                            
                            // Clean up the response (remove quotes if present)
                            var cleanedSummary = if (safeSummary.startsWith("\"") && safeSummary.endsWith("\"")) {
                                safeSummary.substring(1, safeSummary.length - 1)
                            } else {
                                safeSummary
                            }
                            
                            // Remove irrelevant post details from summary
                            cleanedSummary = cleanedSummary.replace(Regex("Post details:.*?(?=\\n|$)", RegexOption.DOT_MATCHES_ALL), "")
                                .replace(Regex("Author:.*?(?=\\n|$)"), "")
                                .replace(Regex("Posted on:.*?(?=\\n|$)"), "")
                                .replace(Regex("Likes:.*?(?=\\n|$)"), "")
                                .replace(Regex("Comments:.*?(?=\\n|$)"), "")
                                .trim()
                            
                            blockContent?.text = cleanedSummary
                            Log.d(TAG, "Summary generated successfully")
                        } else {
                            blockContent?.text = "Unable to generate summary at this time. Please try again later."
                            Log.e(TAG, "Failed to generate summary - null response")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing summary response", e)
                        blockContent?.text = "Error processing summary. Please try again."
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error generating summary", e)
            
            // Show error in UI
            val blockContent = contentViewLinkedIn.findViewById<TextView>(R.id.block_content)
            blockContent?.text = "Error: ${e.message}"
        }
    }
    
    // Generate translation based on selected language
    // Generate translation based on selected language  
    private fun generateTranslation(language: String) {
        try {
            Log.d("EinsteiniOverlay", "Generating translation to: $language")
            Log.d(TAG, "contentViewLinkedIn status: ${if (::contentViewLinkedIn.isInitialized) "initialized" else "not initialized"}")
            Log.d(TAG, "overlayView status: ${if (::overlayView.isInitialized) "initialized" else "not initialized"}")
            
            // Try to find the translation content TextView from both contentViewLinkedIn and overlayView
            var translationContent: TextView? = null
            
            if (::contentViewLinkedIn.isInitialized) {
                translationContent = contentViewLinkedIn.findViewById<TextView>(R.id.translation_content)
                Log.d(TAG, "Found translation_content from contentViewLinkedIn: ${translationContent != null}")
            }
            
            if (translationContent == null && ::overlayView.isInitialized) {
                translationContent = overlayView.findViewById<TextView>(R.id.translation_content)
                Log.d(TAG, "Found translation_content from overlayView: ${translationContent != null}")
            }
            
            if (translationContent == null) {
                Log.e(TAG, "Translation content TextView not found in either view!")
                if (::contentViewLinkedIn.isInitialized) {
                    Log.d(TAG, "Available child views in contentViewLinkedIn:")
                    for (i in 0 until contentViewLinkedIn.childCount) {
                        val child = contentViewLinkedIn.getChildAt(i)
                        Log.d(TAG, "Child $i: ${child.javaClass.simpleName} with id: ${child.id}")
                        if (child is ViewGroup) {
                            for (j in 0 until child.childCount) {
                                val grandChild = child.getChildAt(j)
                                Log.d(TAG, "  GrandChild $j: ${grandChild.javaClass.simpleName} with id: ${grandChild.id}")
                            }
                        }
                    }
                }
                return
            }
            
            translationContent.text = "Translating to $language..."
            Log.d(TAG, "Translation UI updated with loading text")
            
            // Get the content from our stored data
            val content = scrapedData["content"] as? String ?: ""
            
            val finalContent = if (content.isBlank()) {
                Log.w(TAG, "No content available for translation, using test content")
                "This is a sample LinkedIn post about the importance of continuous learning in technology."
            } else {
                content
            }
            
            // Clean content like Flutter does
            val cleanedContent = finalContent
                .replace(Regex("\\n+"), " ") // Replace newlines with spaces
                .replace(Regex("\\s+"), " ") // Replace multiple spaces with single space
                .replace("…more", "") // Remove LinkedIn "...more" text
                .trim()
            
            Log.d(TAG, "Translating content to: $language")
            Log.d(TAG, "Content length: ${cleanedContent.length}")
            
            // Create JSON body matching Flutter implementation exactly
            val jsonBody = JSONObject().apply {
                put("text", cleanedContent)
                put("targetLanguage", language)
                put("email", getUserEmail())
            }.toString()
            
            // Make direct API call
            makeApiCall("translate", jsonBody) { response ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        if (response != null) {
                            var translation = response
                            Log.d(TAG, "Translation response: $response")
                            
                            // Try to parse as JSON first, fallback to plain text
                            try {
                                val responseJson = JSONObject(response)
                                translation = if (responseJson.has("body")) {
                                    if (responseJson.get("body") is String) {
                                        responseJson.getString("body")
                                    } else {
                                        val bodyObj = responseJson.getJSONObject("body")
                                        bodyObj.optString("translation", bodyObj.toString())
                                    }
                                } else {
                                    responseJson.optString("translation", response)
                                }
                            } catch (e: Exception) {
                                // Response is likely plain text, use as-is
                                Log.d(TAG, "Translation response is plain text, using directly")
                            }
                            
                            // Ensure translation is not null
                            val safeTranslation = translation ?: "Unable to generate translation"
                            
                            // Clean up the response
                            val cleanedTranslation = if (safeTranslation.startsWith("\"") && safeTranslation.endsWith("\"")) {
                                safeTranslation.substring(1, safeTranslation.length - 1)
                            } else {
                                safeTranslation
                            }
                            
                            translationContent.text = cleanedTranslation
                            Log.d(TAG, "Translation generated successfully: ${cleanedTranslation.take(50)}...")
                        } else {
                            translationContent.text = "Unable to generate translation at this time. Please try again later."
                            Log.e(TAG, "Failed to generate translation - null response")
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing translation response", e)
                        translationContent.text = "Error processing translation. Please try again."
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error generating translation", e)
            
            // Try to find translation content to show error
            var errorTranslationContent: TextView? = null
            if (::contentViewLinkedIn.isInitialized) {
                errorTranslationContent = contentViewLinkedIn.findViewById<TextView>(R.id.translation_content)
            }
            if (errorTranslationContent == null && ::overlayView.isInitialized) {
                errorTranslationContent = overlayView.findViewById<TextView>(R.id.translation_content)
            }
            errorTranslationContent?.text = "Error: ${e.message}"
        }
    }
    
    // Generate comment based on selected type and tone - Updated to match Flutter app logic exactly
    private fun generateComment(commentType: String, commentTone: String) {
        try {
            Log.d("EinsteiniOverlay", "Generating $commentType comment with $commentTone tone")
            
            // Try to find the comment content TextView from both contentViewComment and overlayView
            var commentContent: TextView? = null
            
            if (::contentViewComment.isInitialized) {
                commentContent = contentViewComment.findViewById<TextView>(R.id.comment_content)
                Log.d(TAG, "Found comment_content from contentViewComment: ${commentContent != null}")
            }
            
            if (commentContent == null && ::contentViewLinkedIn.isInitialized) {
                commentContent = contentViewLinkedIn.findViewById<TextView>(R.id.comment_content)
                Log.d(TAG, "Found comment_content from contentViewLinkedIn: ${commentContent != null}")
            }
            
            if (commentContent == null && ::overlayView.isInitialized) {
                commentContent = overlayView.findViewById<TextView>(R.id.comment_content)
                Log.d(TAG, "Found comment_content from overlayView: ${commentContent != null}")
            }
            
            if (commentContent == null) {
                Log.e(TAG, "Comment content TextView not found in any view!")
                return
            }
            
            commentContent.text = "Generating $commentType comment..."
            
            // Hide copy button while generating
            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
            copyButton?.visibility = View.GONE
            
            Log.d(TAG, "Comment UI updated with loading text")
            
            // Get the content from our stored data
            val content = scrapedData["content"] as? String ?: ""
            val author = scrapedData["author"] as? String ?: "Author"
            
            val finalContent = if (content.isBlank()) {
                Log.w(TAG, "No content available for comment generation, using test content")
                "This is a sample LinkedIn post about the importance of continuous learning in technology."
            } else {
                content
            }
            
            // Clean up the content exactly like Flutter's ApiService does
            var cleanedContent = finalContent
                .replace(Regex("\\n+"), " ") // Replace newlines with spaces
                .replace(Regex("\\s+"), " ") // Replace multiple spaces with single space
                .replace("…more", "") // Remove "…more" text
                .trim()
            
            // Truncate to first 300 chars to avoid server errors (like Flutter does)
            if (cleanedContent.length > 300) {
                cleanedContent = cleanedContent.substring(0, 300) + "..."
            }
            
            // Use exact prompt format from Flutter's ApiService.generateComment
            val prompt = "Generate a $commentType tone comment for a LinkedIn post by $author: $cleanedContent"
            
            Log.d(TAG, "Generating comment with prompt length: ${prompt.length}")
            Log.d(TAG, "Using prompt: $prompt")
            
            // Create JSON body matching Flutter's ApiService implementation exactly
            val jsonBody = JSONObject().apply {
                put("requestContext", JSONObject().put("httpMethod", "POST"))
                put("prompt", prompt)
                put("email", getUserEmail())
            }.toString()
            
            // Make API call to exact same endpoint as Flutter app
            makeApiCall("comment", jsonBody) { response ->
                Handler(Looper.getMainLooper()).post {
                    try {
                        if (response != null) {
                            var comment = response
                            Log.d(TAG, "Comment response received: ${response.take(100)}...")
                            
                            // Parse response exactly like Flutter's ApiService does
                            try {
                                val responseJson = JSONObject(response)
                                comment = if (responseJson.has("text")) {
                                    responseJson.getString("text")
                                } else if (responseJson.has("comment")) {
                                    responseJson.getString("comment")
                                } else if (responseJson.has("response")) {
                                    responseJson.getString("response")
                                } else {
                                    responseJson.toString()
                                }
                            } catch (e: Exception) {
                                // Response is likely plain text, use as-is (matching Flutter logic)
                                Log.d(TAG, "Comment response is plain text, using directly")
                                comment = response
                            }
                            
                            // Clean up the response (remove surrounding quotes if present)
                            val cleanedComment = if (comment?.startsWith("\"") == true && comment.endsWith("\"")) {
                                comment.substring(1, comment.length - 1)
                            } else {
                                comment ?: "Unable to generate comment"
                            }
                            
                            commentContent.text = cleanedComment
                            
                            // Show copy button when comment is generated
                            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
                            copyButton?.visibility = View.VISIBLE
                            
                            Log.d(TAG, "Comment generated successfully: ${cleanedComment.take(50)}...")
                        } else {
                            // Use exact same fallback as Flutter app
                            Log.w(TAG, "No response received, using Flutter fallback")
                            commentContent.text = "This looks like an exciting opportunity in the tech space!"
                            
                            // Show copy button even for fallback
                            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
                            copyButton?.visibility = View.VISIBLE
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error processing comment response", e)
                        // Use Flutter's fallback for errors
                        commentContent.text = "Great opportunity for developers interested in AI and software development!"
                        
                        // Show copy button even for error
                        val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
                        copyButton?.visibility = View.VISIBLE
                    }
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Error generating comment", e)
            
            // Try to find comment content to show error
            var errorCommentContent: TextView? = null
            if (::contentViewComment.isInitialized) {
                errorCommentContent = contentViewComment.findViewById<TextView>(R.id.comment_content)
            }
            if (errorCommentContent == null && ::contentViewLinkedIn.isInitialized) {
                errorCommentContent = contentViewLinkedIn.findViewById<TextView>(R.id.comment_content)
            }
            if (errorCommentContent == null && ::overlayView.isInitialized) {
                errorCommentContent = overlayView.findViewById<TextView>(R.id.comment_content)
            }
            // Use exact same fallback as Flutter app
            errorCommentContent?.text = "Great opportunity for developers interested in AI and software development!"
            
            // Show copy button even for error fallback
            val copyButton = contentViewComment.findViewById<Button>(R.id.copy_comment_button)
            copyButton?.visibility = View.VISIBLE
        }
    }
    
    // Update overlay appearance based on current theme
    private fun updateOverlayTheme(isDark: Boolean) {
        if (!::overlayView.isInitialized) {
            Log.d(TAG, "Overlay view not initialized yet, skipping theme update")
            return
        }
        
        Log.d(TAG, "Updating overlay theme. Dark mode: $isDark")
        
        try {
            // Apply changes in UI-thread safe way
            overlayView.post {
                try {
                    // Get the main overlay container
                    val overlayContainer = overlayView.findViewById<LinearLayout>(R.id.overlay_container)
                    
                    // Set main background with simple design
                    if (isDark) {
                        overlayContainer?.setBackgroundResource(R.drawable.overlay_background_dark)
                    } else {
                        overlayContainer?.setBackgroundResource(R.drawable.overlay_background_light)
                    }
                    
                    // Update tab navigation themes
                    updateTabNavigationTheme()
                    
                    // Update content area text colors based on theme
                    updateContentThemeColors(isDark)
                    
                    // Update divider color
                    val divider = overlayView.findViewById<View>(R.id.divider)
                    divider?.setBackgroundColor(
                        if (isDark) Color.parseColor("#333333") else Color.parseColor("#E0E0E0")
                    )
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error updating overlay theme UI elements", e)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error updating overlay theme", e)
        }
    }
    
    private fun updateContentThemeColors(isDark: Boolean) {
        // Update content area colors
        if (::contentViewLinkedIn.isInitialized) {
            updateViewThemeColors(contentViewLinkedIn, isDark)
        }
        if (::contentViewTwitter.isInitialized) {
            updateViewThemeColors(contentViewTwitter, isDark)
        }
        if (::contentViewComment.isInitialized) {
            updateViewThemeColors(contentViewComment, isDark)
        }
        
        // Update generated content container
        val contentContainer = overlayView.findViewById<LinearLayout>(R.id.content_container)
        contentContainer?.setBackgroundColor(
            if (isDark) Color.parseColor("#1A1F2E") else Color.parseColor("#F8F8F8")
        )
    }
    
    private fun updateViewThemeColors(view: LinearLayout, isDark: Boolean) {
        // Update all child views recursively
        for (i in 0 until view.childCount) {
            val child = view.getChildAt(i)
            when (child) {
                is LinearLayout -> {
                    // Update background for content blocks
                    child.setBackgroundColor(
                        if (isDark) Color.parseColor("#1A1F2E") else Color.parseColor("#F8F8F8")
                    )
                    updateViewThemeColors(child, isDark)
                }
                is TextView -> {
                    // Update text colors - headers vs body text
                    if (child.textSize >= 18f) {
                        // Header text
                        child.setTextColor(
                            if (isDark) Color.WHITE else Color.parseColor("#1A1A1A")
                        )
                    } else {
                        // Body text
                        child.setTextColor(
                            if (isDark) Color.parseColor("#CCCCCC") else Color.parseColor("#666666")
                        )
                    }
                }
                is Button -> {
                    // Update button background
                    child.setBackgroundColor(
                        if (isDark) Color.parseColor("#007AFF") else Color.parseColor("#007AFF")
                    )
                }
                is Spinner -> {
                    // Update spinner background
                    child.setBackgroundResource(
                        if (isDark) R.drawable.dropdown_background_dark else R.drawable.dropdown_background_light
                    )
                }
            }
        }
    }

    // Update a specific content section with theme colors
    private fun updateContentSectionTheme(contentViewId: Int) {
        if (!::overlayView.isInitialized) return
        
        val contentView = overlayView.findViewById<LinearLayout>(contentViewId)
        val isDark = isDarkMode()
        
        // Handle all content blocks within this section
        for (i in 0 until contentView.childCount) {
            val child = contentView.getChildAt(i)
            if (child is LinearLayout) {
                // This is a content block 
                child.setBackgroundColor(Color.parseColor(if (isDark) "#1F1F1F" else "#FFFFFF"))
                
                // Update text colors within this block
                for (j in 0 until child.childCount) {
                    val textView = child.getChildAt(j)
                    if (textView is TextView) {
                        if (textView.textSize >= 18 * resources.displayMetrics.density) {
                            // This is a heading - keep accent color
                            textView.setTextColor(Color.parseColor("#BD79FF"))
                        } else {
                            // This is content text
                            textView.setTextColor(Color.parseColor(if (isDark) "#FFFFFF" else "#333333"))
                        }
                    }
                }
            }
        }
    }
    
    // Update a dynamically created content view with theme colors
    private fun updateDynamicContentTheme(contentView: LinearLayout) {
        val isDark = isDarkMode()
        
        // Handle all content blocks within this section
        for (i in 0 until contentView.childCount) {
            val child = contentView.getChildAt(i)
            if (child is LinearLayout) {
                // This is a content block 
                child.setBackgroundColor(Color.parseColor(if (isDark) "#1F1F2E" else "#F5F5F5"))
                
                // Update text colors within this block
                for (j in 0 until child.childCount) {
                    val textView = child.getChildAt(j)
                    if (textView is TextView) {
                        if (textView.textSize >= 18 * resources.displayMetrics.density) {
                            // This is a heading - keep accent color
                            textView.setTextColor(Color.parseColor("#BD79FF"))
                        } else {
                            // This is content text
                            textView.setTextColor(Color.parseColor(if (isDark) "#FFFFFF" else "#333333"))
                        }
                    }
                }
            }
        }
    }
    
    fun resizeExpandedView(width: Int, height: Int) {
        if (::overlayView.isInitialized && overlayView.parent != null && isOverlayVisible) {
            val params = overlayView.layoutParams as WindowManager.LayoutParams
            params.height = height
            
            try {
                windowManager.updateViewLayout(overlayView, params)
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error resizing overlay view", e)
            }
        }
    }
    
    private fun toggleOverlayVisibility() {
        Log.d("EinsteiniOverlay", "Toggling overlay visibility. Current state: isOverlayVisible=$isOverlayVisible")
        
        if (!isOverlayVisible) {
            // Show overlay (keep bubble visible)
            showOverlayWindow()
        } else {
            // Hide overlay (which will show bubble)
            hideOverlay()
        }
    }
    
    private fun showOverlayWindow() {
        if (isOverlayVisible) return
        
        try {
            // Keep bubble visible while showing overlay
            
            // Make sure overlay view is initialized
            if (!::overlayView.isInitialized) {
                try {
                    setupOverlay()
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to setup overlay", e)
                    // Show a toast to inform the user
                    Handler(Looper.getMainLooper()).post {
                        Toast.makeText(this, "Failed to show overlay window", Toast.LENGTH_SHORT).show()
                    }
                    // Show the bubble again since we couldn't show the overlay
                    showBubble()
                    return
                }
            } else {
                // Always update theme before showing
                Log.d(TAG, "Updating overlay theme before showing, isDarkTheme=$isDarkTheme")
                updateOverlayTheme(isDarkTheme)
            }
            
            // Calculate initial height (full screen for the container with the overlay at the bottom)
            val screenHeight = resources.displayMetrics.heightPixels
            val minHeight = 650 // Increased minimum height to ensure content isn't chopped
            val calculatedHeight = (screenHeight * 0.45).toInt()  // Reduced to 45% to leave more space at bottom
            val overlayHeight = maxOf(calculatedHeight, minHeight)
            
            // Position the overlay to fill the entire screen
            if (overlayParams == null) {
                val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                
                overlayParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    type,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT
                ).apply {
                    gravity = Gravity.TOP or Gravity.START
                    x = 0
                    y = 0
                }
            } else {
                // Update existing params
                overlayParams?.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                                      WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                overlayParams?.gravity = Gravity.TOP or Gravity.START
                overlayParams?.width = WindowManager.LayoutParams.MATCH_PARENT
                overlayParams?.height = WindowManager.LayoutParams.MATCH_PARENT
                overlayParams?.x = 0
                overlayParams?.y = 0
            }
            
            // Get the overlay container and set its height
            val overlayContainer = overlayView.findViewById<LinearLayout>(R.id.overlay_container)
            val params = overlayContainer?.layoutParams
            params?.height = overlayHeight
            overlayContainer?.layoutParams = params
            
            try {
                if (overlayView.parent == null) {
                    windowManager.addView(overlayView, overlayParams)
                }
                
                // Setup initial state for animation
                val scrim = overlayView.findViewById<View>(R.id.overlay_scrim)
                scrim.alpha = 0f
                
                overlayContainer.translationY = overlayHeight.toFloat()
                overlayContainer.alpha = 0.7f
                
                // Animate scrim fade in
                scrim.animate()
                    .alpha(1f)
                    .setDuration(250)
                    .start()
                
                // Animate container sliding up with bounce
                overlayContainer.animate()
                    .translationY(0f)
                    .alpha(1f)
                    .setDuration(400)
                    .setInterpolator(OvershootInterpolator(0.8f))
                    .start()
                
                overlayView.visibility = View.VISIBLE
                isOverlayVisible = true
                // Loading indicator removed
                // Keep the bubble visible even when overlay is shown
                if (::bubbleView.isInitialized) {
                    bubbleView.visibility = View.VISIBLE
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to add overlay view to window", e)
                return
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay window", e)
        }
    }
    
    private fun hideOverlay() {
        if (!isOverlayVisible) return
        
        Log.d("EinsteiniOverlay", "Hiding overlay")
        
        try {
            // Get references to views for animation
            val overlayContainer = overlayView.findViewById<LinearLayout>(R.id.overlay_container)
            val scrim = overlayView.findViewById<View>(R.id.overlay_scrim)
            
            // Animate scrim fade out
            scrim.animate()
                .alpha(0f)
                .setDuration(250)
                .start()
            
            // Animate container sliding down
            overlayContainer.animate()
                .translationY(overlayContainer.height.toFloat())
                .alpha(0.5f)
                .setDuration(350)
                .setInterpolator(android.view.animation.AccelerateInterpolator())
                .withEndAction {
                    try {
                        // First hide the overlay window
                        if (::overlayView.isInitialized && overlayView.isAttachedToWindow) {
                            windowManager.removeView(overlayView)
                        }
                        
                        // Hide the close button
                        if (::closeButtonView.isInitialized && closeButtonView.isAttachedToWindow) {
                            windowManager.removeView(closeButtonView)
                        }
                        
                        isOverlayVisible = false
                        
                        // Bubble should already be visible, no need to show it again
                        Log.d("EinsteiniOverlay", "Overlay hidden, bubble remains visible")
                    } catch (e: Exception) {
                        Log.e("EinsteiniOverlay", "Error hiding overlay after animation", e)
                        
                        // Fallback to direct removal
                        try {
                            if (::overlayView.isInitialized && overlayView.isAttachedToWindow) {
                                windowManager.removeView(overlayView)
                            }
                            
                            if (::closeButtonView.isInitialized && closeButtonView.isAttachedToWindow) {
                                windowManager.removeView(closeButtonView)
                            }
                            
                            isOverlayVisible = false
                            // Bubble should already be visible
                            Log.d("EinsteiniOverlay", "Overlay hidden (fallback), bubble remains visible")
                        } catch (e2: Exception) {
                            Log.e("EinsteiniOverlay", "Error in fallback overlay removal", e2)
                        }
                    }
                }
                .start()
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error hiding overlay", e)
            
            // Try direct approach as fallback

            try {
                if (::overlayView.isInitialized && overlayView.isAttachedToWindow) {
                    windowManager.removeView(overlayView)
                }
                
                if (::closeButtonView.isInitialized && closeButtonView.isAttachedToWindow) {
                    windowManager.removeView(closeButtonView)
                }
                
                isOverlayVisible = false
                // Bubble should already be visible
                Log.d("EinsteiniOverlay", "Overlay hidden (direct fallback), bubble remains visible")
            } catch (e2: Exception) {
                Log.e("EinsteiniOverlay", "Error in fallback overlay removal", e2)
            }
        }
    }
    
    private fun animateOverlayEntry() {
        try {
            if (!::overlayView.isInitialized) return
            
            // Set initial state
            overlayView.alpha = 0f
            overlayView.translationY = 200f
            
            // Animate fade in and slide up
            val animator = ValueAnimator.ofFloat(0f, 1f)
            animator.duration = 250
            animator.addUpdateListener { animation ->
                val value = animation.animatedValue as Float
                overlayView.alpha = value
                overlayView.translationY = 200f * (1 - value)
            }
            
            animator.start()
        } catch (e: Exception) {
            Log.e(TAG, "Error in animateOverlayEntry", e)
        }
    }

    private fun animateOverlayExit(onComplete: () -> Unit) {
        try {
            if (!::overlayView.isInitialized) {
                onComplete()
                return
            }
            
            // Animate the overlay sliding down
            val slideDown = ValueAnimator.ofFloat(1f, 0f)
            slideDown.duration = 200
            slideDown.addUpdateListener { animator ->
                val value = animator.animatedValue as Float
                overlayView.alpha = value
                
                val params = overlayView.layoutParams
                if (params != null) {
                    val translateY = (1 - value) * 200
                    overlayView.translationY = translateY
                }
            }
            
            slideDown.addListener(object : AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    onComplete()
                }
            })
            
            slideDown.start()
        } catch (e: Exception) {
            Log.e(TAG, "Error in animateOverlayExit", e)
            onComplete()
        }
    }

    private fun animateEntry(params: WindowManager.LayoutParams?) {
        if (params == null) return
        
        try {
            // Animate scale
            val scaleAnimator = ValueAnimator.ofFloat(0.5f, 1.0f)
            scaleAnimator.duration = 300
            scaleAnimator.interpolator = OvershootInterpolator()
            
            scaleAnimator.addUpdateListener { animation ->
                val scale = animation.animatedValue as Float
                bubbleView.scaleX = scale
                bubbleView.scaleY = scale
            }
            
            scaleAnimator.start()
            
            // Animate alpha
            bubbleView.alpha = 0f
            bubbleView.animate()
                .alpha(1f)
                .setDuration(200)
                .start()
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error animating entry", e)
        }
    }

    private fun animateAndClose() {
        val animator = ValueAnimator.ofFloat(1f, 0f)
        animator.duration = 300
        animator.addUpdateListener { animation ->
            try {
                // Check if views are still attached
                if (::bubbleView.isInitialized && bubbleView.parent != null) {
                    bubbleView.scaleX = animation.animatedValue as Float
                    bubbleView.scaleY = animation.animatedValue as Float
                    bubbleView.alpha = animation.animatedValue as Float
                    
                    if (::closeButtonView.isInitialized && closeButtonView.parent != null) {
                        closeButtonView.alpha = animation.animatedValue as Float
                    }
                    
                    windowManager.updateViewLayout(bubbleView, bubbleParams)
                } else {
                    // Cancel animation if views are detached
                    animation.cancel()
                }
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error in close animation", e)
                animation.cancel()
            }
        }
        animator.addListener(object : android.animation.Animator.AnimatorListener {
            override fun onAnimationStart(animation: android.animation.Animator) {}
            override fun onAnimationEnd(animation: android.animation.Animator) {
                stopSelf()
            }
            override fun onAnimationCancel(animation: android.animation.Animator) {
                stopSelf()
            }
            override fun onAnimationRepeat(animation: android.animation.Animator) {}
        })
        animator.start()
    }

    private fun snapToEdge(params: WindowManager.LayoutParams?) {
        if (params == null) return
        
        val middle = screenWidth / 2
        val targetX = if ((params.x + (bubbleSize / 2)) <= middle) 0 else screenWidth - bubbleSize

        currentAnimator?.cancel()
        val animator = ValueAnimator.ofInt(params.x, targetX)
        animator.duration = 300
        animator.interpolator = OvershootInterpolator(1.5f)
        animator.addUpdateListener { animation ->
            params.x = animation.animatedValue as Int
            try {
                // Check if the bubble view is still attached
                if (::bubbleView.isInitialized && bubbleView.parent != null) {
                    windowManager.updateViewLayout(bubbleView, params)
                } else {
                    // Cancel the animation if view is detached
                    animation.cancel()
                }
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error in snap animation", e)
                // Cancel the animation on error
                animation.cancel()
            }
        }
        animator.start()
        currentAnimator = animator
    }

    private fun animateCloseButtonAlpha(targetAlpha: Float) {
        try {
            if (::closeButtonView.isInitialized) {
                closeButtonView.animate()
                    .alpha(targetAlpha)
                    .setDuration(150)
                    .start()
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error animating close button alpha", e)
        }
    }

    private fun isNearCloseButton(rawX: Float, rawY: Float): Boolean {
        try {
            if (!::closeButtonView.isInitialized || closeButtonView.visibility != View.VISIBLE) {
                return false
            }
            
            val closeButtonY = screenHeight - closeButtonSize - 100 // Match the y offset in setupCloseButton
            val closeButtonX = screenWidth / 2 - closeButtonSize / 2

            return rawY > closeButtonY &&
                   rawX > closeButtonX &&
                   rawX < (closeButtonX + closeButtonSize)
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error checking close button proximity", e)
            return false
        }
    }

    private fun showCloseButton() {
        try {
            if (::closeButtonView.isInitialized) {
                // If the closeButtonView is not attached to window, re-add it
                if (closeButtonView.parent == null) {
                    try {
                        windowManager.addView(closeButtonView, closeButtonParams)
                    } catch (e: Exception) {
                        Log.e("EinsteiniOverlay", "Error re-adding close button view", e)
                    }
                }
                closeButtonView.visibility = View.VISIBLE
                animateCloseButtonAlpha(0.5f)
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error showing close button", e)
        }
    }

    private fun hideCloseButton() {
        try {
            if (::closeButtonView.isInitialized && closeButtonView.visibility == View.VISIBLE) {
                closeButtonView.animate()
                    .alpha(0f)
                    .setDuration(200)
                    .withEndAction {
                        closeButtonView.visibility = View.GONE
                    }
                    .start()
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error hiding close button", e)
        }
    }
    
    private fun setupCloseButton() {
        try {
            // Initialize close button view
            closeButtonView = LayoutInflater.from(this).inflate(R.layout.close_button, null)
            
            closeButtonParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            )
            
            closeButtonParams?.gravity = Gravity.BOTTOM or Gravity.CENTER_HORIZONTAL
            closeButtonParams?.y = 100
            
            // Set up click listener for close button
            closeButtonView.setOnClickListener {
                hideOverlay()
            }
            
            closeButtonView.visibility = View.GONE
            try {
                windowManager.addView(closeButtonView, closeButtonParams)
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error adding close button view", e)
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error setting up close button", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("EinsteiniOverlay", "Service onDestroy")
        
        // Clean up all views
        try {
            if (::bubbleView.isInitialized) {
                try {
                    if (bubbleView.parent != null) {
                        windowManager.removeView(bubbleView)
                    }
                } catch (e: Exception) {
                    Log.e("EinsteiniOverlay", "Error removing bubble view", e)
                }
            }
            
            if (::closeButtonView.isInitialized) {
                try {
                    if (closeButtonView.parent != null) {
                        windowManager.removeView(closeButtonView)
                    }
                } catch (e: Exception) {
                    Log.e("EinsteiniOverlay", "Error removing close button view", e)
                }
            }
            
            if (::overlayView.isInitialized) {
                try {
                    if (overlayView.parent != null) {
                        windowManager.removeView(overlayView)
                    }
                } catch (e: Exception) {
                    Log.e("EinsteiniOverlay", "Error removing overlay view", e)
                }
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error in onDestroy cleanup", e)
        } finally {
            // Always update instance and running state
            instance = null
            running = false
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        // Return null as this service doesn't support binding
        return null
    }

    // Get the current theme mode based on Flutter app's preference
    private fun getThemeMode(): String {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        // Default to "system" if not found
        return prefs.getString("flutter.${THEME_PREFERENCE_KEY}", "system") ?: "system"
    }
    
    // Check if the app should be in dark mode based on theme preference
    private fun isDarkMode(): Boolean {
        return isDarkTheme
    }

    // Get initial theme from shared preferences
    private fun getInitialThemeFromPreferences(): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            // Check for the current theme mode first
            val themeMode = prefs.getString("flutter.theme_mode", "system") ?: "system"
            
            when (themeMode) {
                "dark" -> true
                "light" -> false
                "system" -> {
                    // Check system dark mode setting
                    val configuration = resources.configuration
                    (configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
                }
                else -> false // Default to light mode
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting initial theme from preferences", e)
            false // Default to light mode on error
        }
    }

    // Register for theme changes from Flutter only, NOT from system
    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    private fun registerThemeChangeReceiver() {
        try {
            val filter = IntentFilter("com.example.einsteiniapp.THEME_CHANGED")
            registerReceiver(object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    // Only update if this is an explicit theme change from Flutter
                    if (intent.hasExtra("isDarkMode")) {
                        val newIsDarkTheme = intent.getBooleanExtra("isDarkMode", isDarkTheme)
                        Log.d(TAG, "Theme change from app detected: $newIsDarkTheme")
                        isDarkTheme = newIsDarkTheme
                    updateAllViews()
                    }
                }
            }, filter)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to register theme change receiver", e)
        }
    }
    
    // Update all UI components based on current theme
    private fun updateAllViews() {
        Log.d(TAG, "Updating all views with theme")
        updateBubbleTheme()
        updateOverlayTheme(isDarkTheme)
    }

    /**
     * Show generated content in the overlay
     */
    fun showGeneratedContent(content: String, type: String) {
        try {
            Log.d(TAG, "Showing generated content of type: $type with content: $content")
            val contentTextView = overlayView.findViewById<TextView>(R.id.generated_content)
            val contentTypeTextView = overlayView.findViewById<TextView>(R.id.content_type)
            
            if (contentTextView != null && contentTypeTextView != null) {
                // Update on UI thread
                contentTextView.post {
                    contentTextView.text = content
                    
                    // Set the content type label based on the type
                    val contentTypeLabel = when(type) {
                        "comment" -> "LinkedIn Comment"
                        "personalized_comment" -> "Personalized Comment"
                        "post" -> "LinkedIn Post"
                        "about" -> "About Section"
                        "connection_note" -> "Connection Note"
                        "translation" -> "Translation"
                        "grammar_correction" -> "Grammar Correction"
                        else -> "Generated Content"
                    }
                    
                    contentTypeTextView.text = contentTypeLabel
                    
                    // Make sure the content is visible
                    val contentContainer = overlayView.findViewById<CardView>(R.id.content_container)
                    if (contentContainer != null) {
                        contentContainer.visibility = View.VISIBLE
                    }
                    
                    // Ensure the overlay is expanded
                    if (!isOverlayVisible) {
                        expandOverlay()
                    }
                    
                    // Notify Flutter that content is ready
                    methodChannel?.invokeMethod("onGeneratedContentReady", content)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error showing generated content", e)
        }
    }
    
    /**
     * Handle action from Flutter
     */
    fun handleAction(action: String, data: org.json.JSONObject) {
        try {
            Log.d(TAG, "Handling action: $action")
            
            when (action) {
                "copy_content" -> {
                    // Copy content to clipboard
                    val clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
                    val content = data.optString("content", "")
                    val clipData = android.content.ClipData.newPlainText("Einsteini Generated Content", content)
                    clipboardManager.setPrimaryClip(clipData)
                    
                    // Show toast on UI thread
                    overlayView.post {
                        android.widget.Toast.makeText(applicationContext, "Copied to clipboard", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
                "clear_content" -> {
                    // Clear generated content
                    val contentTextView = overlayView.findViewById<TextView>(R.id.generated_content)
                    val contentContainer = overlayView.findViewById<CardView>(R.id.content_container)
                    
                    if (contentTextView != null && contentContainer != null) {
                        contentTextView.post {
                            contentTextView.text = ""
                            contentContainer.visibility = View.GONE
                        }
                    }
                }
                "expand_overlay" -> {
                    // Expand the overlay
                    if (!isOverlayVisible) {
                        expandOverlay()
                    }
                }
                "collapse_overlay" -> {
                    // Collapse the overlay
                    if (isOverlayVisible) {
                        collapseOverlay()
                    }
                }
                else -> {
                    Log.w(TAG, "Unknown action: $action")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling action", e)
        }
    }
    
    /**
     * Expand the overlay to show content
     */
    fun expandOverlay() {
        if (isOverlayVisible) return
        showOverlayWindow()
    }
    
    /**
     * Collapse the overlay to hide content
     */
    fun collapseOverlay() {
        if (!isOverlayVisible) return
        hideOverlay()
    }
    
    /**
     * Update theme of the overlay
     */
    fun updateTheme(newIsDarkTheme: Boolean): Boolean {
        try {
            // Only update if the theme actually changed
            if (this.isDarkTheme != newIsDarkTheme) {
            // Store the new theme value
            this.isDarkTheme = newIsDarkTheme
            Log.d(TAG, "Setting service theme state to isDarkTheme=$newIsDarkTheme")
            
                // Update all UI components with the new theme
                updateAllViews()
            } else {
                Log.d(TAG, "Theme state already set to isDarkTheme=$newIsDarkTheme, no update needed")
            }
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error updating theme", e)
            return false
        }
    }

    // Process social URL and update the overlay content
    private fun processSocialUrl(url: String) {
        // Make sure we're on a background thread
        Thread {
            try {
                Log.d("EinsteiniOverlay", "Starting to scrape social URL: $url")
                
                // Call the backend API to scrape the post
                val scrapedData = scrapePost(url)
                
                // Store the scraped data in the class variable
                this.scrapedData = scrapedData
                
                // Update the UI on the main thread
                Handler(Looper.getMainLooper()).post {
                    try {
                        updateOverlayWithScrapedData(scrapedData)
                        // Loading indicator removed
                        // Send the scraped content to Flutter
                        sendScrapedContentToFlutter(scrapedData)
                    } catch (e: Exception) {
                        Log.e("EinsteiniOverlay", "Error updating overlay with scraped data", e)
                    }
                }
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error processing social URL", e)
                
                // Update the UI with an error message
                Handler(Looper.getMainLooper()).post {
                    try {
                        showErrorInOverlay("Failed to process content: ${e.message}")
                        // Loading indicator removed
                    } catch (e: Exception) {
                        Log.e("EinsteiniOverlay", "Error showing error in overlay", e)
                    }
                }
            }
        }.start()
    }
    
    // Send scraped content to Flutter
    private fun sendScrapedContentToFlutter(content: Map<String, Any>) {
        try {
            // Make sure we have a valid method channel
            if (methodChannel != null) {
                methodChannel?.invokeMethod("onContentScraped", content)
            } else {
                Log.e("EinsteiniOverlay", "Method channel is null, can't send scraped content to Flutter")
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error sending scraped content to Flutter", e)
        }
    }
    
    // Scrape social post using appropriate API based on platform
    private fun scrapePost(url: String): Map<String, Any> {
        try {
            Log.d("EinsteiniOverlay", "Scraping social URL: $url")
            
            // Detect platform - use oEmbed for X/Twitter, backend scrape for LinkedIn
            val isTwitterUrl = url.contains("twitter.com") || url.contains("x.com")
            val encodedUrl = java.net.URLEncoder.encode(url, "UTF-8")
            
            val apiUrl = if (isTwitterUrl) {
                // Use X's oEmbed API which works great for tweets
                "https://publish.twitter.com/oembed?url=$encodedUrl"
            } else {
                // Use backend scrape for LinkedIn and other platforms
                "https://backend.einsteini.ai/scrape?url=$encodedUrl"
            }
            Log.d("EinsteiniOverlay", "Using API: $apiUrl")
            
            // Make the HTTP request
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Cache-Control", "no-cache")
            // Reduce timeouts for faster failure
            connection.connectTimeout = 4000
            connection.readTimeout = 4000
            
            // Get the response
            val responseCode = connection.responseCode
            Log.d("EinsteiniOverlay", "Scrape response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = StringBuilder()
                var line: String?
                
                while (reader.readLine().also { line = it } != null) {
                    response.append(line)
                }
                
                reader.close()
                val responseBody = response.toString()
                Log.d("EinsteiniOverlay", "Scrape response FULL: $responseBody")
                
                // Process the scraped data
                var content = ""
                var author = "Unknown author"
                var date = "Unknown date"
                var likes = 0
                var comments = 0
                val images = mutableListOf<String>()
                val commentsList = mutableListOf<Map<String, String>>()
                
                // Detect platform for appropriate parsing
                val isTwitterUrl = url.contains("twitter.com") || url.contains("x.com")
                
                try {
                    // Try to parse as JSON first
                    val jsonResponse = JSONObject(responseBody)
                    val keys = jsonResponse.keys().asSequence().toList()
                    Log.d("EinsteiniOverlay", "JSON keys: $keys")
                    
                    when {
                        isTwitterUrl && jsonResponse.has("html") -> {
                            // Handle X/Twitter oEmbed response
                            val html = jsonResponse.getString("html")
                            // Extract tweet text from HTML - remove tags and decode entities
                            val tweetText = html
                                .replace(Regex("<blockquote[^>]*>"), "")
                                .replace(Regex("</blockquote>"), "")
                                .replace(Regex("<a[^>]*>"), "")
                                .replace(Regex("</a>"), "")
                                .replace(Regex("<p[^>]*>"), "")
                                .replace(Regex("</p>"), " ")
                                .replace(Regex("<br[^>]*>"), " ")
                                .replace(Regex("<[^>]*>"), "")
                                .replace("&mdash;", "—")
                                .replace("&amp;", "&")
                                .replace("&lt;", "<")
                                .replace("&gt;", ">")
                                .replace("&quot;", "\"")
                                .replace("&#39;", "'")
                                .replace(Regex("\\s+"), " ")
                                .trim()
                            
                            content = tweetText
                            author = jsonResponse.optString("author_name", "Unknown author")
                            date = "Recent"
                            
                            Log.d("EinsteiniOverlay", "Extracted tweet from oEmbed - Author: $author, Content: ${content.take(100)}...")
                        }
                        
                        jsonResponse.has("content") -> {
                            // Fallback: backend scrape response format
                            content = cleanContent(jsonResponse.getString("content"))
                            author = jsonResponse.optString("author", "Unknown author")
                            date = jsonResponse.optString("date", "Unknown date")
                            likes = jsonResponse.optInt("likes", 0)
                            comments = jsonResponse.optInt("comments", 0)
                            
                            // Process images if available
                            if (jsonResponse.has("images")) {
                                val imagesArray = jsonResponse.getJSONArray("images")
                                for (i in 0 until imagesArray.length()) {
                                    images.add(imagesArray.getString(i))
                                }
                            }
                        }
                        
                        else -> {
                            // Treat the whole response as content - no custom extraction
                            content = cleanContent(responseBody)
                            author = "Unknown author"
                            date = "Unknown date"
                            likes = 0
                            comments = 0
                        }
                    }
                } catch (e: Exception) {
                    // If JSON parsing fails, treat as string content - no custom extraction
                    content = cleanContent(responseBody)
                    author = "Unknown author"
                    date = "Unknown date"
                    likes = 0
                    comments = 0
                }
                
                return mapOf(
                    "content" to content,
                    "author" to author,
                    "date" to date,
                    "likes" to likes,
                    "comments" to comments,
                    "images" to images,
                    "commentsList" to commentsList,
                    "url" to url
                )
            } else {
                Log.e("EinsteiniOverlay", "Error scraping LinkedIn post: $responseCode")
                val errorReader = BufferedReader(InputStreamReader(connection.errorStream ?: connection.inputStream))
                val errorResponse = errorReader.readText()
                errorReader.close()
                Log.e("EinsteiniOverlay", "Error response: $errorResponse")
                
                return mapOf(
                    "content" to "Error: $responseCode - Failed to scrape LinkedIn post",
                    "author" to "Error",
                    "date" to "Unknown date",
                    "likes" to 0,
                    "comments" to 0,
                    "images" to emptyList<String>(),
                    "commentsList" to emptyList<Map<String, String>>(),
                    "url" to url
                )
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Exception while scraping LinkedIn post", e)
            return mapOf(
                "content" to "Error: Network or server issue - ${e.message}",
                "author" to "Error",
                "date" to "Unknown date",
                "likes" to 0,
                "comments" to 0,
                "images" to emptyList<String>(),
                "commentsList" to emptyList<Map<String, String>>(),
                "url" to url
            )
        }
    }
    
    // Helper methods to clean and extract data from content (similar to Flutter implementation)
    private fun cleanContent(content: String): String {
        return content
            .replace(Regex("\\n+"), " ")
            .replace(Regex("\\s+"), " ")
            .replace("…more", "")
            .trim()
    }
    
    // Update the overlay with the scraped data
    private fun updateOverlayWithScrapedData(scrapedData: Map<String, Any>) {
        if (!::overlayView.isInitialized) {
            Log.e("EinsteiniOverlay", "Overlay view not initialized")
            return
        }
        
        try {
            // Get the LinkedIn content view
            val contentViewLinkedIn = overlayView.findViewById<LinearLayout>(R.id.contentViewLinkedIn)
            
            // Don't change the active tab - just populate the content
            
            // Show the LinkedIn content view
            contentViewLinkedIn.visibility = View.VISIBLE
            // The other views will be hidden by updateTabs
            
            // Get the content blocks
            val contentBlocks = contentViewLinkedIn.children.filterIsInstance<LinearLayout>().toList()
            
            // Update the summary block
            if (contentBlocks.isNotEmpty()) {
                val summaryBlock = contentBlocks[0]
                // Find the TextViews using findViewById
                val titleTextView = summaryBlock.findViewById<TextView>(R.id.block_title)
                val contentTextView = summaryBlock.findViewById<TextView>(R.id.block_content)
                
                if (titleTextView != null && contentTextView != null) {
                    titleTextView.text = "Summary"
                    
                    val content = scrapedData["content"] as? String ?: "No content found"
                    contentTextView.text = content
                }
            }
            
            // Get the key points block
            if (contentBlocks.size > 1) {
                val keyPointsBlock = contentBlocks[1]
                // Find the TextViews using findViewById
                val titleTextView = keyPointsBlock.findViewById<TextView>(R.id.block_title)
                val contentTextView = keyPointsBlock.findViewById<TextView>(R.id.block_content)
                
                if (titleTextView != null && contentTextView != null) {
                    titleTextView.text = "Post Details"
                    
                    val author = scrapedData["author"] as? String ?: "Unknown author"
                    val date = scrapedData["date"] as? String ?: "Unknown date"
                    contentTextView.text = "Author: $author\nDate: $date"
                }
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error updating overlay with scraped data", e)
        }
    }
    
    // Show an error message in the overlay
    private fun showErrorInOverlay(errorMessage: String) {
        if (!::overlayView.isInitialized) {
            Log.e("EinsteiniOverlay", "Overlay view not initialized")
            return
        }
        
        try {
            // Get the content view
            val contentViewLinkedIn = overlayView.findViewById<LinearLayout>(R.id.contentViewLinkedIn)
            
            // Make sure it's visible
            contentViewLinkedIn.visibility = View.VISIBLE
            
            // Get the content blocks
            val contentBlocks = contentViewLinkedIn.children.filterIsInstance<LinearLayout>().toList()
            
            // Update the summary block with the error message
            if (contentBlocks.isNotEmpty()) {
                val summaryBlock = contentBlocks[0]
                // Find the TextViews using findViewById
                val titleTextView = summaryBlock.findViewById<TextView>(R.id.block_title)
                val contentTextView = summaryBlock.findViewById<TextView>(R.id.block_content)
                
                if (titleTextView != null && contentTextView != null) {
                    titleTextView.text = "Error"
                    contentTextView.text = errorMessage
                }
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error showing error in overlay", e)
        }
    }

    // Show translated content in the overlay
    private fun showTranslatedContent(original: String, translation: String, language: String) {
        if (!::overlayView.isInitialized) {
            Log.e("EinsteiniOverlay", "Overlay view not initialized")
            return
        }
        
        try {
            // Set the active tab using the updateTabs function
            updateTabs(1)
            
            // Check if the Twitter view is initialized
            if (!::contentViewTwitter.isInitialized) {
                Log.e("EinsteiniOverlay", "Twitter content view not initialized")
                return
            }
            
            // Create content blocks if they don't exist
            if (contentViewTwitter.childCount == 0) {
                // Create translation header block
                val translationHeaderBlock = createContentBlock("Translation", 
                    "Here is the translated content from the original post.")
                contentViewTwitter.addView(translationHeaderBlock)
                
                // Create original content block
                val originalBlock = createContentBlock("Original", original)
                contentViewTwitter.addView(originalBlock)
                
                // Create translation content block
                val translationBlock = createContentBlock("Translation ($language)", translation)
                contentViewTwitter.addView(translationBlock)
            } else {
            // Get the content blocks
            val contentBlocks = contentViewTwitter.children.filterIsInstance<LinearLayout>().toList()
            
                // Update the blocks if they exist
            if (contentBlocks.isNotEmpty()) {
                    updateContentBlock(contentBlocks[0], "Translation", 
                        "Here is the translated content from the original post.")
                }
                
            if (contentBlocks.size > 1) {
                    updateContentBlock(contentBlocks[1], "Original", original)
            }
            
            if (contentBlocks.size > 2) {
                    updateContentBlock(contentBlocks[2], "Translation ($language)", translation)
                }
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error showing translated content", e)
        }
    }
    
    // Helper method to create a content block
    private fun createContentBlock(title: String, content: String): LinearLayout {
        // Create outer linear layout that will hold our card
        val blockContainer = LinearLayout(this)
        blockContainer.orientation = LinearLayout.VERTICAL
        blockContainer.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            setMargins(16, 8, 16, 8)
        }
        
        // Create card view
        val cardView = androidx.cardview.widget.CardView(this)
        cardView.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        cardView.cardElevation = 4.dpToPx().toFloat()
        cardView.radius = 16.dpToPx().toFloat()
        cardView.setCardBackgroundColor(Color.parseColor(if (isDarkTheme) "#1A1F2E" else "#F5F5F5"))
        
        // Create card content layout
        val cardContent = LinearLayout(this)
        cardContent.orientation = LinearLayout.VERTICAL
        cardContent.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        
        // Create header container
        val headerContainer = LinearLayout(this)
        headerContainer.orientation = LinearLayout.VERTICAL
        headerContainer.layoutParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        headerContainer.setPadding(20.dpToPx(), 20.dpToPx(), 20.dpToPx(), 12.dpToPx())
        
        // Create title TextView
        val titleView = TextView(this)
        titleView.id = View.generateViewId()
        titleView.text = title
        titleView.setTextColor(ContextCompat.getColor(this, R.color.purple_accent))
        titleView.textSize = 18f
        titleView.setTypeface(null, Typeface.BOLD)
        headerContainer.addView(titleView)
        
        // Add colored divider under title
        val divider = View(this)
        divider.layoutParams = LinearLayout.LayoutParams(40.dpToPx(), 3.dpToPx()).apply {
            topMargin = 8.dpToPx()
        }
        divider.setBackgroundColor(Color.parseColor("#BD79FF"))
        headerContainer.addView(divider)
        
        // Create content TextView
        val contentView = TextView(this)
        contentView.id = View.generateViewId()
        contentView.text = content
        contentView.setTextColor(if (isDarkTheme) Color.WHITE else Color.BLACK)
        contentView.textSize = 15f
        contentView.setLineSpacing(0f, 1.2f)  // Use setLineSpacing instead of reassigning lineSpacingMultiplier
        contentView.setPadding(20.dpToPx(), 4.dpToPx(), 20.dpToPx(), 20.dpToPx())
        
        // Add views to card content
        cardContent.addView(headerContainer)
        cardContent.addView(contentView)
        
        // Add card content to card
        cardView.addView(cardContent)
        
        // Add card to container
        blockContainer.addView(cardView)
        
        return blockContainer
    }
    
    // Helper method to update a content block
    private fun updateContentBlock(block: LinearLayout, title: String, content: String) {
        val titleView = block.getChildAt(0) as? TextView
        val contentView = block.getChildAt(1) as? TextView
        
        titleView?.text = title
        contentView?.text = content
    }
    
    // Show comment options in the overlay
    private fun showCommentOptions(professional: String, question: String, thoughtful: String) {
        if (!::overlayView.isInitialized) {
            Log.e("EinsteiniOverlay", "Overlay view not initialized")
            return
        }
        
        try {
            // Set the active tab using the updateTabs function
            updateTabs(2)
            
            // Check if the Comment view is initialized
            if (!::contentViewComment.isInitialized) {
                Log.e("EinsteiniOverlay", "Comment content view not initialized")
                return
            }
            
            // Create content blocks if they don't exist
            if (contentViewComment.childCount == 0) {
                // Create comment ideas header block
                val commentIdeasBlock = createContentBlock("Comment Ideas", 
                    "Here are some suggested comments you could post in response to this content.")
                contentViewComment.addView(commentIdeasBlock)
                
                // Create professional comment block
                val professionalBlock = createContentBlock("Professional", professional)
                contentViewComment.addView(professionalBlock)
                
                // Create question comment block
                val questionBlock = createContentBlock("Question", question)
                contentViewComment.addView(questionBlock)
                
                // Create thoughtful comment block
                val thoughtfulBlock = createContentBlock("Thoughtful", thoughtful)
                contentViewComment.addView(thoughtfulBlock)
            } else {
            // Get the content blocks
            val contentBlocks = contentViewComment.children.filterIsInstance<LinearLayout>().toList()
            
                // Update the blocks if they exist
            if (contentBlocks.isNotEmpty()) {
                    updateContentBlock(contentBlocks[0], "Comment Ideas", 
                        "Here are some suggested comments you could post in response to this content.")
                }
                
            if (contentBlocks.size > 1) {
                    updateContentBlock(contentBlocks[1], "Professional", professional)
            }
            
            if (contentBlocks.size > 2) {
                    updateContentBlock(contentBlocks[2], "Question", question)
            }
            
            if (contentBlocks.size > 3) {
                    updateContentBlock(contentBlocks[3], "Thoughtful", thoughtful)
                }
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error showing comment options", e)
        }
    }

    // Show the bubble when the overlay is collapsed
    private fun showBubble() {
        if (isBubbleShown) return
        
        Log.d("EinsteiniOverlay", "Showing bubble")
        
        try {
            // Make sure the bubble view is initialized
            if (!::bubbleView.isInitialized) {
                setupBubble()
            }
            
            // Reset bubble properties
            bubbleView.alpha = 0f
            bubbleView.scaleX = 0f
            bubbleView.scaleY = 0f
            bubbleView.rotation = -15f
            
            try {
                windowManager.addView(bubbleView, bubbleParams)
                isBubbleShown = true
                
                // Enhanced animation sequence
                bubbleView.animate()
                    .alpha(1f)
                    .scaleX(1f)
                    .scaleY(1f)
                    .rotation(0f)
                    .setDuration(500)
                    .setInterpolator(OvershootInterpolator(1.5f))
                    .withEndAction {
                        // Add a subtle bounce after appearing
                        val bouncer = ValueAnimator.ofFloat(1f, 1.1f, 1f)
                        bouncer.duration = 300
                        bouncer.interpolator = OvershootInterpolator(2f)
                        bouncer.addUpdateListener { animation ->
                            val scale = animation.animatedValue as Float
                            bubbleView.scaleX = scale
                            bubbleView.scaleY = scale
                        }
                        bouncer.startDelay = 300
                        bouncer.start()
                    }
                    .start()
            } catch (e: Exception) {
                Log.e("EinsteiniOverlay", "Error adding bubble view", e)
            }
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error showing bubble", e)
            
            // Try again after a delay as last resort
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    removeBubbleIfExists()
                    setupBubble()
                    windowManager.addView(bubbleView, bubbleParams)
                    isBubbleShown = true
                    Log.d("EinsteiniOverlay", "Bubble added on second attempt")
                } catch (e2: Exception) {
                    Log.e("EinsteiniOverlay", "Failed to add bubble on second attempt", e2)
                }
            }, 500)
        }
    }
    
    // Helper method to safely remove bubble if it exists
    private fun removeBubbleIfExists() {
        try {
            if (::bubbleView.isInitialized && bubbleView.parent != null) {
                windowManager.removeView(bubbleView)
                isBubbleShown = false
                Log.d("EinsteiniOverlay", "Removed existing bubble")
            }
                        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error removing existing bubble", e)
        }
    }

    // Add this new function
    private fun applyFontsToAllTextViews(view: View, titleFont: Typeface?, bodyFont: Typeface?) {
        if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                applyFontsToAllTextViews(view.getChildAt(i), titleFont, bodyFont)
            }
        } else if (view is TextView) {
            // Check if this is a title or body text based on text size or style
            if (view.textSize >= 18 * resources.displayMetrics.density || 
                view.text.toString().lowercase().contains("summary") ||
                view.text.toString().lowercase().contains("key points") ||
                view.text.toString().lowercase().contains("implementation") ||
                view.text.toString().lowercase().contains("results") ||
                view.text.toString().lowercase().contains("translation") ||
                view.text.toString().lowercase().contains("original") ||
                view.text.toString().lowercase().contains("comment") ||
                view.text.toString().lowercase().contains("customize")) {
                // Apply title font (TikTok Sans)
                view.typeface = titleFont
                view.setTextColor(
                    if (isDarkTheme) Color.WHITE else Color.parseColor("#1A1A1A")
                )
            } else {
                // Apply body font (DM Sans)
                view.typeface = bodyFont
                view.setTextColor(
                    if (isDarkTheme) Color.parseColor("#CCCCCC") else Color.parseColor("#666666")
                )
            }
        }
    }

    private fun updateTabNavigationTheme() {
        // Update tab navigation styles based on current theme
        if (!::overlayView.isInitialized) return
        
        val tabSummarize = overlayView.findViewById<TextView>(R.id.tab_summarize)
        val tabTranslate = overlayView.findViewById<TextView>(R.id.tab_translate)
        val tabComment = overlayView.findViewById<TextView>(R.id.tab_comment)
        
        // Set inactive style for non-active tabs
        tabSummarize?.setBackgroundResource(R.drawable.tab_button_inactive)
        tabSummarize?.setTextColor(Color.parseColor("#CCCCCC"))
        
        tabTranslate?.setBackgroundResource(R.drawable.tab_button_inactive)
        tabTranslate?.setTextColor(Color.parseColor("#CCCCCC"))
        
        // Set Comment as active (since it's the default tab)
        tabComment?.setBackgroundResource(R.drawable.tab_button_active)
        tabComment?.setTextColor(Color.parseColor("#FFFFFF"))
        tabComment?.setTypeface(tabComment.typeface, android.graphics.Typeface.BOLD)
    }

    private fun updateTabs(activeTabIndex: Int) {
        Log.d("EinsteiniOverlay", "updateTabs called with activeTabIndex: $activeTabIndex")
        
        // Update tab navigation styles with button appearance
        val tabSummarize = overlayView.findViewById<TextView>(R.id.tab_summarize)
        val tabTranslate = overlayView.findViewById<TextView>(R.id.tab_translate)
        val tabComment = overlayView.findViewById<TextView>(R.id.tab_comment)
        
        if (tabSummarize == null) Log.e("EinsteiniOverlay", "tabSummarize is null!")
        if (tabTranslate == null) Log.e("EinsteiniOverlay", "tabTranslate is null!")
        if (tabComment == null) Log.e("EinsteiniOverlay", "tabComment is null!")
        
        // Reset all tabs to inactive style
        val inactiveColor = Color.parseColor("#CCCCCC")
        val activeColor = Color.parseColor("#FFFFFF")
        
        tabSummarize?.setTextColor(inactiveColor)
        tabSummarize?.setBackgroundResource(R.drawable.tab_button_inactive)
        tabSummarize?.setTypeface(tabSummarize.typeface, android.graphics.Typeface.NORMAL)
        
        tabTranslate?.setTextColor(inactiveColor)
        tabTranslate?.setBackgroundResource(R.drawable.tab_button_inactive)
        tabTranslate?.setTypeface(tabTranslate.typeface, android.graphics.Typeface.NORMAL)
        
        tabComment?.setTextColor(inactiveColor)
        tabComment?.setBackgroundResource(R.drawable.tab_button_inactive)
        tabComment?.setTypeface(tabComment.typeface, android.graphics.Typeface.NORMAL)
        
        // Set active tab style with animation
        val activeTab = when (activeTabIndex) {
            0 -> {
                Log.d("EinsteiniOverlay", "Setting comment tab as active")
                tabComment?.setTextColor(activeColor)
                tabComment?.setBackgroundResource(R.drawable.tab_button_active)
                tabComment?.setTypeface(tabComment.typeface, android.graphics.Typeface.BOLD)
                tabComment
            }
            1 -> {
                Log.d("EinsteiniOverlay", "Setting translate tab as active")
                tabTranslate?.setTextColor(activeColor)
                tabTranslate?.setBackgroundResource(R.drawable.tab_button_active)
                tabTranslate?.setTypeface(tabTranslate.typeface, android.graphics.Typeface.BOLD)
                tabTranslate
            }
            2 -> {
                Log.d("EinsteiniOverlay", "Setting summarize tab as active")
                tabSummarize?.setTextColor(activeColor)
                tabSummarize?.setBackgroundResource(R.drawable.tab_button_active)
                tabSummarize?.setTypeface(tabSummarize.typeface, android.graphics.Typeface.BOLD)
                tabSummarize
            }
            else -> {
                Log.w("EinsteiniOverlay", "Unknown activeTabIndex: $activeTabIndex")
                null
            }
        }
        
        // Animate active tab
        activeTab?.let { animateTabSelection(it) }
        
        // Get all content views
        val contentViews = listOf(
            contentViewLinkedIn,
            if (::contentViewTwitter.isInitialized) contentViewTwitter else null,
            if (::contentViewComment.isInitialized) contentViewComment else null
        ).filterNotNull()
        
        // Get the current visible view and target view
        val currentVisibleView = contentViews.firstOrNull { it.visibility == View.VISIBLE }
        val targetView = when (activeTabIndex) {
            0 -> if (::contentViewComment.isInitialized) contentViewComment else null
            1 -> if (::contentViewTwitter.isInitialized) contentViewTwitter else null
            2 -> {
                // Always ensure summarize content is populated when switching to summarize tab
                Log.d("EinsteiniOverlay", "Switching to summarize tab, ensuring content is populated")
                ensureSummarizeContentPopulated()
                contentViewLinkedIn
            }
            else -> null
        }
        
        // If both current and target views exist and they're different, animate the transition
        if (currentVisibleView != null && targetView != null && currentVisibleView != targetView) {
            animateContentTransition(currentVisibleView, targetView)
        } else {
            // Otherwise just update visibility without animation
            contentViews.forEach { it.visibility = View.GONE }
            targetView?.visibility = View.VISIBLE
        }
        
        // Reset scroll position when changing tabs
        overlayView.findViewById<NestedScrollView>(R.id.contentScrollView)?.scrollTo(0, 0)
    }
    
    // Ensure summarize content is populated when switching to summarize tab
    private fun ensureSummarizeContentPopulated() {
        if (!::contentViewLinkedIn.isInitialized) {
            Log.d("EinsteiniOverlay", "contentViewLinkedIn not initialized")
            return
        }
        
        if (scrapedData.isEmpty()) {
            Log.d("EinsteiniOverlay", "scrapedData is empty, cannot populate")
            return
        }
        
        try {
            Log.d("EinsteiniOverlay", "Checking if summarize content needs population...")
            
            // Get the content blocks
            val contentBlocks = contentViewLinkedIn.children.filterIsInstance<LinearLayout>().toList()
            Log.d("EinsteiniOverlay", "Found ${contentBlocks.size} content blocks")
            
            // Check if content is empty or needs to be populated
            var needsPopulation = false
            
            if (contentBlocks.isEmpty()) {
                Log.d("EinsteiniOverlay", "No content blocks found, needs population")
                needsPopulation = true
            } else {
                // Check if the first block (summary) has meaningful content
                val summaryBlock = contentBlocks[0]
                val contentTextView = summaryBlock.findViewById<TextView>(R.id.block_content)
                
                if (contentTextView == null) {
                    Log.d("EinsteiniOverlay", "Content TextView not found, needs population")
                    needsPopulation = true
                } else {
                    val currentText = contentTextView.text?.toString() ?: ""
                    Log.d("EinsteiniOverlay", "Current content text: '$currentText'")
                    
                    if (currentText.isEmpty() || 
                        currentText == "No content found" ||
                        currentText.contains("Click") ||
                        currentText.contains("Tap") ||
                        currentText.length < 10) { // Assume real content should be longer
                        Log.d("EinsteiniOverlay", "Content is empty or placeholder, needs population")
                        needsPopulation = true
                    }
                }
            }
            
            if (needsPopulation) {
                Log.d("EinsteiniOverlay", "Populating summarize content with scraped data")
                updateOverlayWithScrapedData(scrapedData)
            } else {
                Log.d("EinsteiniOverlay", "Summarize content already populated")
            }
            
        } catch (e: Exception) {
            Log.e("EinsteiniOverlay", "Error ensuring summarize content populated", e)
        }
    }

    // Animate tab selection with a subtle scale effect
    private fun animateTabSelection(tab: TextView) {
        tab.scaleX = 0.95f
        tab.scaleY = 0.95f
        tab.alpha = 0.8f
        
        tab.animate()
            .scaleX(1f)
            .scaleY(1f)
            .alpha(1f)
            .setDuration(200)
            .setInterpolator(android.view.animation.OvershootInterpolator(1.1f))
            .start()
    }
    
    // Animate content transition between tabs
    private fun animateContentTransition(currentView: View, targetView: View) {
        // Make sure the target view is visible but transparent
        targetView.alpha = 0f
        targetView.visibility = View.VISIBLE
        targetView.translationX = 100f
        
        // Animate current view out
        currentView.animate()
            .alpha(0f)
            .translationX(-100f)
            .setDuration(200)
            .withEndAction {
                currentView.visibility = View.GONE
                // Use setTranslationX instead of reassigning translationX property
                currentView.setTranslationX(0f)
            }
            .start()
        
        // Animate target view in with a slight delay
        targetView.postDelayed({
            targetView.animate()
                .alpha(1f)
                .translationX(0f)
                .setDuration(200)
                .setInterpolator(android.view.animation.DecelerateInterpolator())
                .start()
        }, 100)
    }
    
    // Fallback translation when method channel is not available
    private fun generateFallbackTranslation(content: String, language: String): String {
        if (content.isBlank()) return "No content available to translate."
        
        return when (language.lowercase()) {
            "spanish", "español" -> "🇪🇸 [Traducción simulada] Este contenido ha sido traducido al español usando el sistema local."
            "french", "français" -> "🇫🇷 [Traduction simulée] Ce contenu a été traduit en français en utilisant le système local."
            "german", "deutsch" -> "🇩🇪 [Simulierte Übersetzung] Dieser Inhalt wurde mit dem lokalen System ins Deutsche übersetzt."
            "italian", "italiano" -> "🇮🇹 [Traduzione simulata] Questo contenuto è stato tradotto in italiano utilizzando il sistema locale."
            "portuguese", "português" -> "🇵🇹 [Tradução simulada] Este conteúdo foi traduzido para português usando o sistema local."
            "chinese", "中文" -> "🇨🇳 [模拟翻译] 此内容已使用本地系统翻译为中文。"
            "japanese", "日本語" -> "🇯🇵 [シミュレーション翻訳] このコンテンツはローカルシステムを使用して日本語に翻訳されました。"
            "korean", "한국어" -> "🇰🇷 [시뮬레이션 번역] 이 콘텐츠는 로컬 시스템을 사용하여 한국어로 번역되었습니다."
            else -> "🌐 [Simulated Translation to $language] This content has been translated using the local system. Note: This is a fallback translation. For accurate translations, please use the main app with internet connection."
        }
    }
    
    // Fallback summary generation when method channel is not available
    private fun generateFallbackSummary(content: String, summaryType: String): String {
        if (content.isBlank()) return "No content available to summarize."
        
        val sentences = content.split(Regex("[.!?]+")).filter { it.trim().isNotEmpty() }
        
        return when (summaryType.lowercase()) {
            "brief" -> {
                if (sentences.isNotEmpty()) {
                    "📄 ${sentences.first().trim()}..."
                } else {
                    "📄 Brief summary of the content."
                }
            }
            "detailed" -> {
                val firstSentences = sentences.take(3).joinToString(". ") { it.trim() }
                "📋 $firstSentences${if (sentences.size > 3) "..." else "."}"
            }
            "concise" -> {
                val words = content.split("\\s+".toRegex()).take(25)
                "⚡ ${words.joinToString(" ")}${if (content.split("\\s+".toRegex()).size > 25) "..." else ""}"
            }
            else -> {
                "📖 ${sentences.take(2).joinToString(". ") { it.trim() }}${if (sentences.size > 2) "..." else "."}"
            }
        }
    }
}
