package com.localmovie.streaming.local_movie_streaming

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.localmovie.streaming/player"
    private var result: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "playVideo") {
                this.result = result
                val url = call.argument<String>("url")
                val title = call.argument<String>("title")
                val position = call.argument<Number>("position")?.toLong() ?: 0L

                val intent = Intent(this, VlcPlayerActivity::class.java)
                intent.putExtra("url", url)
                intent.putExtra("title", title)
                intent.putExtra("position", position)
                startActivityForResult(intent, 1001)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1001) {
            val position = data?.getLongExtra("position", 0L) ?: 0L
            result?.success(position)
        }
    }
}
