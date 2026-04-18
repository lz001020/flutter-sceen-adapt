package com.example.example

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.View
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class ExamplePlatformView(
    context: Context,
    private val viewId: Int,
    creationParams: Map<String, Any?>?,
    messenger: BinaryMessenger,
) : PlatformView {

    private val channel = MethodChannel(messenger, "example_view/$viewId")

    private val container: FrameLayout = FrameLayout(context).apply {
        setBackgroundColor(Color.parseColor("#EAF3FF"))
    }

    private var clickCount = 0

    init {
        val title = (creationParams?.get("text") as? String) ?: "Native Card"
        val initialMessage = (creationParams?.get("message") as? String) ?: "Hello from Android PlatformView"

        val root = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(24, 24, 24, 24)
        }

        val titleView = TextView(context).apply {
            text = title
            textSize = 18f
            setTextColor(Color.parseColor("#0D47A1"))
            gravity = Gravity.CENTER
        }

        val messageView = TextView(context).apply {
            text = initialMessage
            textSize = 14f
            setTextColor(Color.parseColor("#1565C0"))
            gravity = Gravity.CENTER
        }

        val button = Button(context).apply {
            text = "Native Click"
            setOnClickListener {
                clickCount += 1
                messageView.text = "Native clicked $clickCount times"
                channel.invokeMethod(
                    "onNativeClick",
                    mapOf(
                        "viewId" to viewId,
                        "count" to clickCount,
                        "message" to "Android button clicked"
                    )
                )
            }
        }

        root.addView(
            titleView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        )
        root.addView(
            messageView,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 12
            }
        )
        root.addView(
            button,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = 16
            }
        )

        container.addView(
            root,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setMessage" -> {
                    val text = call.argument<String>("text") ?: ""
                    messageView.text = text
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun getView(): View = container

    override fun dispose() {
        channel.setMethodCallHandler(null)
    }
}
