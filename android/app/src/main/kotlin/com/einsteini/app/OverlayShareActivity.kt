package com.einsteini.app

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.widget.Toast

class OverlayShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        val action = intent?.action
        val type = intent?.type
        if (Intent.ACTION_SEND == action && type == "text/plain") {
            val sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
            if (sharedText != null) {
                // Support LinkedIn, Twitter, and X URLs
                val urlPattern = "(https?://([\\w-]+\\.)?(linkedin\\.com|twitter\\.com|x\\.com)/[^\\s]+)".toRegex()
                val matchResult = urlPattern.find(sharedText)
                if (matchResult != null) {
                    val socialUrl = matchResult.value
                    val serviceIntent = Intent(this, EinsteiniOverlayService::class.java)
                    serviceIntent.action = "PROCESS_SOCIAL_URL"
                    serviceIntent.putExtra("socialUrl", socialUrl)
                    serviceIntent.putExtra("fromShare", true)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                } else {
                    Toast.makeText(this, "No supported URL found in shared content", Toast.LENGTH_SHORT).show()
                }
            }
        }
        finish()
    }
}
