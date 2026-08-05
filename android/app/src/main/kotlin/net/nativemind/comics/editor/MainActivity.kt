package net.nativemind.comics.editor

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val broker = DocumentOpenBroker()
    private val copyExecutor = Executors.newSingleThreadExecutor()
    private var initialIntentHandled = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DOCUMENT_OPEN_CHANNEL,
        )
        channel.setMethodCallHandler { call, result ->
            if (call.method == "takePendingDocuments") {
                result.success(broker.takePendingDocuments())
            } else {
                result.notImplemented()
            }
        }
        broker.notificationHandler = {
            channel.invokeMethod("documentsAvailable", null)
        }

        if (!initialIntentHandled) {
            initialIntentHandled = true
            handleDocumentIntent(intent)
        }
        IncomingDocumentCopier(this).pruneStaleCopies(broker.pendingPaths())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleDocumentIntent(intent)
    }

    override fun onDestroy() {
        broker.notificationHandler = null
        copyExecutor.shutdown()
        super.onDestroy()
    }

    private fun handleDocumentIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_VIEW) return
        copyExecutor.execute {
            val entry = IncomingDocumentCopier(applicationContext).copy(intent)
            runOnUiThread {
                if (!isDestroyed) broker.enqueue(entry)
            }
        }
    }

    private companion object {
        const val DOCUMENT_OPEN_CHANNEL =
            "net.nativemind.comics_editor/document_open"
    }
}
