package com.tick.app.android

import android.app.Application
import android.content.Context

/**
 * 应用入口：持有进程级上下文单例，供非 Activity 环境（如提醒广播接收器）使用。
 */
class TickApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        appContext = applicationContext
    }

    companion object {
        @Volatile
        private lateinit var appContext: Context

        fun instance(): Context = appContext
    }
}