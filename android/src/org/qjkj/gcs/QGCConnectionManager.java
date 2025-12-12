package org.qjkj.gcs;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.util.Log;
import androidx.annotation.NonNull; // 需要引入这个

// 引入 Boying
import boying.sdk.BoyingSdk;

// 引入 硬件驱动
import com.test.sdk.rc.MKUtil;
import com.test.sdk.rc.SkydroidRcConnectUtil;
import com.test.sdk.rc.SkydroidRcSdkUtil;
import com.test.sdk.rc.RcSkyDataManager; // 引入管理器
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.SDKManagerCallBack;
import com.skydroid.rcsdk.common.error.SkyException;

public class QGCConnectionManager {
    private static final String TAG = "QGCConnection";

    public static native void nativeOnDataReceived(byte[] data, int length);

    // =========================================================
    // ★★★ 关键点：定义一个全局强引用监听器 ★★★
    // =========================================================
    // 为什么必须定义成成员变量？
    // 因为 RcSkyDataManager 内部使用 WeakReference (弱引用) 来存储监听器。
    // 如果你直接在 initConnection 里 new 一个匿名对象传进去，
    // Java 垃圾回收器 (GC) 会在几秒钟后把它回收掉，导致数据接收突然中断！
    private static RcSkyDataManager.OnGetRcSkyDataListener mSkydroidListener = new RcSkyDataManager.OnGetRcSkyDataListener() {
        @Override
        public boolean onGetRcSkyData(@NonNull byte[] datas) {
            if (datas != null && datas.length > 0) {
                // 透传给 C++
                nativeOnDataReceived(datas, datas.length);
            }
            return false; // 返回 false，让其他监听器也能收到数据
        }
    };

    public static void initConnection() {
        Log.i(TAG, "🔥🔥🔥 Java: initConnection CALLED! 🔥🔥🔥");

        Context context = QGCActivity.getActivity();
        if (context == null) return;

        // 1. 初始化 Boying SDK (略...)
        try {
            BoyingSdk.getInstance().initSdk();
            BoyingSdk.getInstance().startSdk();
        } catch (Exception e) {}

        // 2. 初始化硬件
        if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
            // 思翼逻辑 (略...)
            MKUtil.getInstance().connect(handler);
        }
        else if (SkydroidRcConnectUtil.isSkydroidRc()) {
            Log.i(TAG, "👉 Detected Skydroid Remote");

            // (A) 初始化 RCSDK
            try {
                RCSDKManager.INSTANCE.initSDK(context, new SDKManagerCallBack() {
                    @Override public void onRcConnectFail(SkyException e) {}
                    @Override public void onRcConnected() {}
                    @Override public void onRcDisconnect() {}
                });
            } catch (Throwable t) {}

            // (B) 绑定服务
            try {
                if (!SkydroidRcSdkUtil.getInstance().isConnected()) {
                    SkydroidRcSdkUtil.getInstance().connect(context);
                }
            } catch (Exception e) {}

            // (C) ★★★ 注册监听器 (替代修改源码) ★★★
            // 只要注册了，RcSkyDataManager 收到数据就会回调 mSkydroidListener
            RcSkyDataManager.getInstance().addOnGetRcSkyDataListener(mSkydroidListener);
            Log.i(TAG, "✅ Registered Skydroid Data Listener");

            // (D) 启动连接
            SkydroidRcConnectUtil.getInstance().connect(handler);
        }
    }

    // ---------------------------------------------------------
    // 发送数据
    // ---------------------------------------------------------
    public static void sendData(byte[] data) {
        if (data == null || data.length == 0) return;

        try {
            if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
                MKUtil.getInstance().sendRawData(data);
            }
            else if (SkydroidRcConnectUtil.isSkydroidRc()) {
                // ★★★ 直接调用管理器的发送方法 ★★★
                // 不需要改 SkydroidRcSdkUtil 源码，因为管理器是公开的
                RcSkyDataManager.getInstance().sendRcSkyData(data);
            }
        } catch (Exception e) {
            Log.e(TAG, "Send Error: " + e.toString());
        }
    }

    // 没什么用的 Handler，仅用于保活
    private static Handler handler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(Message msg) {}
    };
}