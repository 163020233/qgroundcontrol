package org.qjkj.gcs;

import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.util.Log;

// 引入搬运过来的 Util 类
import com.test.sdk.rc.MKUtil;
import com.test.sdk.rc.SkydroidRcConnectUtil;
import com.test.sdk.rc.SkydroidRcSdkUtil;
// 引入 Qt 的原生辅助类来获取 Context
import org.qtproject.qt.android.QtNative;
// 需要引入这个包用来获取 Context (Qt6 环境下)
// 如果上面这行报错，试试 import org.qtproject.qt.android.QtApplication;

public class QGCConnectionManager {
    private static final String TAG = "QGCConnection";

    // ---------------------------------------------------------
    // 1. JNI 接口：Java -> C++
    // ---------------------------------------------------------
    public static native void nativeOnDataReceived(byte[] data, int length);

    // ---------------------------------------------------------
    // 2. C++ 调用接口：初始化连接
    // ---------------------------------------------------------


    public static void initConnection() {
        Log.i(TAG, " Java: initConnection CALLED! Starting Hardware...");

        Handler handler = new Handler(Looper.getMainLooper()) {
            @Override
            public void handleMessage(Message msg) {
                // ---------------------------------------------------------
                // ★★★ 修改 1：打印所有状态，包括错误码 ★★★
                // ---------------------------------------------------------
                if (msg.what == 0) {
                    Log.i(TAG, "✅ Hardware Connected Success!");
                } else {
                    // 如果看到 1700，说明 SDK 服务没启动
                    // 如果看到 800，说明连接断开
                    Log.e(TAG, "❌ Connection Error/Status Code: " + msg.what);
                }

                // 打印收到的数据类型，辅助调试
                if (msg.obj != null) {
                    // Log.d(TAG, "MSG OBJ Type: " + msg.obj.getClass().getName());
                }
            }
        };

        try {
            if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
                Log.i(TAG, "Detected Siyi Remote, Connecting MKUtil...");
                MKUtil.getInstance().connect(handler);
            }
            else if (SkydroidRcConnectUtil.isSkydroidRc()) {
                Log.i(TAG, "Detected Skydroid Remote...");

                // ---------------------------------------------------------
                // ★★★ 修改 2：补全云卓后台服务连接 (缺了这步会报 1700) ★★★
                // ---------------------------------------------------------
                // 尝试获取 Activity Context，如果失败可能需要调整
                // 这里的 Context 必须传，否则 Skydroid SDK 崩或者连不上
                try {
                    // 尝试连接后台服务
                    if (!SkydroidRcSdkUtil.getInstance().isConnected()) {
                        Log.i(TAG, "Binding Skydroid Service...");
                        // 注意：Qt6 获取 Context 的方式可能不同，通常是 QtNative.activity()
                        // 或者在这个静态方法里很难拿到，先试试传 null 或者反射获取
                        // 如果这里报错，先把这行注释掉，先看 Handler 报什么错
//                         SkydroidRcSdkUtil.getInstance().connect(QtNative.activity());
                        SkydroidRcSdkUtil.getInstance().connect(QGCActivity.getActivity());
                    }
                } catch (Throwable t) {
                    Log.e(TAG, "Bind Service Warning: " + t.toString());
                }

                // 连接串口
                SkydroidRcConnectUtil.getInstance().connect(handler);
            }
            else {
                Log.w(TAG, "Unknown Device, forcing MKUtil connect...");
                MKUtil.getInstance().connect(handler);
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Connection Exception: " + e.toString());
            e.printStackTrace();
        }
    }

    // ---------------------------------------------------------
    // 3. C++ 调用接口：发送数据 (C++ -> Java -> 串口)
    // ---------------------------------------------------------
    public static void sendData(byte[] data) {

        if (data == null || data.length == 0) return;

        // ★ 关键：如果是 Skydroid 机型，也务必走 Skydroid 下行接口 ★
        try {
            if (SkydroidRcConnectUtil.isSkydroidRc() && SkydroidRcConnectUtil.getInstance() != null) {
                SkydroidRcConnectUtil.getInstance().sendDataToDevice(data);
                Log.d(TAG, "Sent data via SkydroidRcConnectUtil, len=" + data.length);
            }
        } catch (Exception e) {
            Log.e(TAG, "Send Data via Skydroid Failed: " + e.toString());
        }

        // MKUtil 发送（保留）
        try {
            MKUtil.getInstance().sendRawData(data);
        } catch (Exception e) {
            Log.e(TAG, "Send Data via MKUtil Failed: " + e.toString());
        }
    }
}