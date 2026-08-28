package com.tick.app.android.data

import android.content.Context

/**
 * API Key 存储：使用 SharedPreferences（应用的私有内存），不入库、不打日志。
 * 满足「API Key 存 Android Keystore/SharedPreferences」的要求。
 */
object SecurePrefs {
    private const val PREFS_NAME = "tick_secure_prefs"
    private const val KEY_API_KEY = "ai_api_key"

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getApiKey(context: Context): String = prefs(context).getString(KEY_API_KEY, "").orEmpty()

    fun setApiKey(context: Context, apiKey: String) {
        prefs(context).edit().putString(KEY_API_KEY, apiKey.trim()).apply()
    }
}