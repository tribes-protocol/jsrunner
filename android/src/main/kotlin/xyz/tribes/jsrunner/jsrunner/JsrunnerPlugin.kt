package xyz.tribes.jsrunner.jsrunner

import android.annotation.TargetApi
import android.app.Activity
import android.content.pm.ApplicationInfo
import android.graphics.Bitmap
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.FrameLayout
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/** JsrunnerPlugin */
class JsrunnerPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  companion object {
    lateinit var channel: MethodChannel
  }

  private val webClient = JsrunnerWebViewClient(listOf())
  private lateinit var activity: Activity
  private lateinit var webView: WebView


  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "jsrunner")
    channel.setMethodCallHandler(this)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    webView = WebView(activity)

    val params = FrameLayout.LayoutParams(0, 0)
    val decorView = activity.window.decorView as FrameLayout
    decorView.addView(webView, params)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      if (0 != (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE)) {
        WebView.setWebContentsDebuggingEnabled(true)
      }
    }

    webView.visibility = View.GONE
    webView.settings.javaScriptEnabled = true
    webView.settings.domStorageEnabled = true
    webView.settings.allowFileAccessFromFileURLs = true
    webView.addJavascriptInterface(JsInterface(), "native")
    webView.webViewClient = webClient
  }


  override fun onMethodCall(call: MethodCall, result: Result): Unit {
    val method = CallMethod.valueOf(call.method)
    when (method) {
      CallMethod.setOptions -> setOptions(call, result)
      CallMethod.evalJavascript -> evalJavascript(call, result)
      CallMethod.loadHTML -> loadHTML(call, result)
      CallMethod.loadUrl -> loadUrl(call, result)
      CallMethod.call -> callFunc(call, result)
    }
  }

  private fun setOptions(call: MethodCall, result: Result) {
    (call.arguments as? HashMap<*, *>)?.let {
      val restrictedSchemes = it["restrictedSchemes"]
      if (restrictedSchemes is Array<*>)
        webClient.restrictedSchemes = restrictedSchemes.filterIsInstance<String>()
    }

    result.success(null)
  }

  private fun callFunc(call: MethodCall, result: Result) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      val arguments = call.arguments as? HashMap<*, *>
      var request = arguments?.get("request") as? String
      if (request != null) {
        val script = "window.call($request)"
        webView.evaluateJavascript(script) {
          result.success(null)
        }
        return;
      }
    }
    result.success(null)
  }

  private fun evalJavascript(call: MethodCall, result: Result) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
      val arguments = call.arguments as? HashMap<*, *>
      var script = arguments?.get("script") as? String
      if (script != null) {
        webView.evaluateJavascript(script) {
          result.success(null)
        }
        return;
      }
    }

    result.success(null)
  }

  private fun loadHTML(call: MethodCall, result: Result) {
    (call.arguments as? HashMap<*, *>)?.let { arguments ->
      val html = arguments["html"] as String
      if (arguments.containsKey("baseUrl")) {
        (arguments["baseUrl"] as? String)?.let {
          webView.loadDataWithBaseURL(it, html, "text/html", "UTF-8", null)
        }
      } else {
        webView.loadData(html, "text/html", "UTF-8")
      }
    }
    result.success(null)
  }

  private fun loadUrl(call: MethodCall, result: Result) {
    (call.arguments as? HashMap<*, *>)?.let { arguments ->
      val url = arguments["url"] as String
      webView.loadUrl(url)
    }
    result.success(null)
  }

  override fun onDetachedFromActivityForConfigChanges() {

  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {

  }

  override fun onDetachedFromActivity() {

  }
}


class JsrunnerWebViewClient(var restrictedSchemes: List<String>): WebViewClient() {

  override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
    val data = hashMapOf<String, Any>()
    data["url"] = url!!
    data["type"] = "didStart"
    JsrunnerPlugin.channel.invokeMethod("stateChanged", data)
  }

  override fun onPageFinished(view: WebView?, url: String?) {
    val data = hashMapOf<String, Any>()
    data["url"] = url!!
    data["type"] = "didFinish"
    JsrunnerPlugin.channel.invokeMethod("stateChanged", data)
  }

  override fun shouldOverrideUrlLoading(view: WebView?, url: String?): Boolean {
    return shouldOverrideUrlLoading(url)
  }

  @TargetApi(Build.VERSION_CODES.LOLLIPOP)
  override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
    val url = request?.url.toString()
    return shouldOverrideUrlLoading(url)

  }

  private fun shouldOverrideUrlLoading(url: String?): Boolean {
    for (l in restrictedSchemes) {
      if (url != null && url.contains(l))
        return false
    }

    return true
  }
}

class JsInterface {

  @JavascriptInterface
  fun postMessage(data: String?) {
    data?.let {
      val message = hashMapOf<String, Any>()
      message["name"] = "native"

      try {
        when (it[0]) {
          '{' -> {
            val jsonObj = JSONObject(it)
            message["data"] = toMap(jsonObj)
          }
          '[' -> {
            val jsonArray = JSONArray(it)
            message["data"] = toList(jsonArray)
          }
          else -> message["data"] = it
        }
      } catch (e: JSONException) {
        message["data"] = it
      }

      Handler(Looper.getMainLooper()).post {
        JsrunnerPlugin.channel.invokeMethod("didReceiveMessage", message)
      }
    }
  }

  @Throws(JSONException::class)
  private fun toMap(obj: JSONObject): Map<String, Any> {
    val map = HashMap<String, Any>()

    val keysItr = obj.keys()
    while (keysItr.hasNext()) {
      val key = keysItr.next()
      var value = obj.get(key)

      if (value is JSONArray) {
        value = toList(value)
      } else if (value is JSONObject) {
        value = toMap(value)
      }
      map[key] = value
    }
    return map
  }

  @Throws(JSONException::class)
  private fun toList(array: JSONArray): List<Any> {
    val list = ArrayList<Any>()
    for (i in 0 until array.length()) {
      var value = array.get(i)
      if (value is JSONArray) {
        value = toList(value)
      } else if (value is JSONObject) {
        value = toMap(value)
      }
      list.add(value)
    }
    return list
  }
}

enum class CallMethod {
  setOptions, evalJavascript, loadHTML, loadUrl, call
}