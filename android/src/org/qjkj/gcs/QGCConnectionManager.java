package org.qjkj.gcs;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.util.Log;
import androidx.annotation.NonNull; // 需要引入这个

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;

import boying.sdk.BoyingSdk;
import com.test.sdk.rc.MKUtil;
import com.test.sdk.rc.SkydroidRcConnectUtil;
import com.test.sdk.rc.SkydroidRcSdkUtil;
import com.test.sdk.rc.RcSkyDataManager; // 引入管理器
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.SDKManagerCallBack;
import com.skydroid.rcsdk.common.error.SkyException;


public class QGCConnectionManager {
    private static final String TAG = "QGCConnection";
    private static boolean isRunning = false; // 控制心跳线程
    private static final Object sendLock = new Object(); // 发送锁

    // ---------------------------------------------------------
    public static native void nativeOnJsonReceived(String jsonStr);

    // 保留这个旧接口，防止 C++ 那边链接报错，但实际上不再调用它
//     public static native void nativeOnDataReceived(byte[] data, int length);

    // =========================================================
    // ★★★ 关键点：定义一个全局强引用监听器 ★★★
    // =========================================================
    // 为什么必须定义成成员变量？
    // 因为 RcSkyDataManager 内部使用 WeakReference (弱引用) 来存储监听器。
    // 如果你直接在 initConnection 里 new 一个匿名对象传进去，
    // Java 垃圾回收器 (GC) 会在几秒钟后把它回收掉，导致数据接收突然中断！
//     private static RcSkyDataManager.OnGetRcSkyDataListener mSkydroidListener = new RcSkyDataManager.OnGetRcSkyDataListener() {
//         @Override
//         public boolean onGetRcSkyData(@NonNull byte[] datas) {
//             if (datas != null && datas.length > 0) {
//                 // 透传给 C++
//                 nativeOnDataReceived(datas, datas.length);
//             }
//             return false; // 返回 false，让其他监听器也能收到数据
//         }
//     };

    private static RcSkyDataManager.OnGetRcSkyDataListener mSkydroidListener = new RcSkyDataManager.OnGetRcSkyDataListener() {
        @Override
        public boolean onGetRcSkyData(@NonNull byte[] datas) {
            if (datas != null && datas.length > 0) {

               JSONArray jsonArray = BoyingSdk.getInstance().onReceive(datas, datas.length);

                // 2. 如果解析出 JSON，转成字符串传给 C++
                if (jsonArray != null && !jsonArray.isEmpty()) {
                    String jsonStr = jsonArray.toJSONString();
                    // 透传给 C++
                    nativeOnJsonReceived(jsonStr);
                }
            }
            return false; // 返回 false，让其他监听器也能收到数据
        }
    };

    public static void onHardwareDataReceived(byte[] data) {
        if (data == null || data.length == 0) return;

        try {
            // 1. 交给 SDK 解析 (onReceive)
            JSONArray jsonArray = BoyingSdk.getInstance().onReceive(data, data.length);

            // 2. 如果解析出 JSON，转成字符串传给 C++
            if (jsonArray != null && !jsonArray.isEmpty()) {
                String jsonStr = jsonArray.toJSONString();
                // 传给 C++ JNI
                nativeOnJsonReceived(jsonStr);
            }
        } catch (Exception e) {
            // 解析出错不要崩
        }
    }

    public static void initConnection() {
        Log.i(TAG, "Java: initConnection CALLED! ");
        Log.i(TAG, "init called from", new Throwable("init trace"));

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
            Log.i(TAG, "Detected Skydroid Remote");

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
            Log.i(TAG, "Registered Skydroid Data Listener");

            // (D) 启动连接
            SkydroidRcConnectUtil.getInstance().connect(handler);
        }

       // 4. 启动心跳线程
        startSdkHeartbeatLoop();
    }

 // ---------------------------------------------------------
    private static void startSdkHeartbeatLoop() {
        if (isRunning) return;
        isRunning = true;

        new Thread(new Runnable() {
            @Override
            public void run() {
                Log.i(TAG, "SDK Heartbeat Loop Started");
                while (isRunning) {
                    try {
                        // 1. 获取 SDK 内部数据 (GetByteCommandJava)
                        // 注意：这里使用文档规定的方法名
                        byte[] bytes = BoyingSdk.getInstance().getSdkData();

                        // 2. 如果有数据，发给云卓硬件
                        if (bytes != null && bytes.length > 0) {
                            sendToHardwareSafe(bytes);
                        }

                        // 3. 休眠 50ms (20Hz)
                        Thread.sleep(50);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
                Log.i(TAG, "SDK Heartbeat Loop Stopped");
            }
        }).start();
    }

    // ---------------------------------------------------------
    // 发送数据
    // ---------------------------------------------------------
    public static void sendData(String jsonCmd) {

         Log.w(TAG, "[1] Java sendCmdFromCpp CALLED! Cmd: " + jsonCmd);
         if (jsonCmd == null || jsonCmd.isEmpty()) {
                Log.e(TAG, "❌ Error: jsonCmd is empty!");
                return;
            }

        try {
//
//             // 1. 将字符串解析为 FastJSON 对象
//             // (因为 BoyingSdk.sendCmd 需要 JSONObject 参数)
            JSONObject cmdObj = JSONObject.parseObject(jsonCmd);
//              Log.d(TAG, "[2] JSON Parsed: " + (cmdObj != null ? cmdObj.toString() : "null"));

            // 2. 调用 SDK 公开方法获取二进制
            int result = BoyingSdk.getInstance().sendNewCmd(cmdObj);

            // 3. 发送 (走统一的安全发送通道)
            if (result == 0)
            {
                String hint = "测试ok" + result;
                Log.d(TAG, hint);
            }

        } catch (Exception e) {
            Log.e(TAG, "SendCmd Error: " + e.toString());
            e.printStackTrace();
        }
//         try {
//             if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
//                 MKUtil.getInstance().sendRawData(data);
//             }
//             else if (SkydroidRcConnectUtil.isSkydroidRc()) {
//                 // ★★★ 直接调用管理器的发送方法 ★★★
//                 // 不需要改 SkydroidRcSdkUtil 源码，因为管理器是公开的
//                 RcSkyDataManager.getInstance().sendRcSkyData(data);
//             }
//         } catch (Exception e) {
//             Log.e(TAG, "Send Error: " + e.toString());
//         }
    }

    private static void sendToHardwareSafe(byte[] data) {
        synchronized (sendLock) {
            try {
                if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
                    MKUtil.getInstance().sendRawData(data);
                }
                else if (SkydroidRcConnectUtil.isSkydroidRc()) {
                    SkydroidRcConnectUtil.getInstance().sendDataToDevice(data);
                }
                else {
                    MKUtil.getInstance().sendRawData(data);
                }
            } catch (Exception e) {
                // Log.e(TAG, "HW Send Fail: " + e.toString());
            }
        }
    }

    // ---------------------------------------------------------
    // 7. 停止连接与释放资源
    // ---------------------------------------------------------
    public static void stopConnection() {
        Log.i(TAG, "ava: stopConnection CALLED");
        // 1. 停止心跳循环线程
        isRunning = false;

//         // 2. 停止 Boying SDK
//         try {
//             BoyingSdk.getInstance().stopSdk();
//             Log.i(TAG, "Boying SDK Stopped");
//         } catch (Exception e) {
//             Log.e(TAG, "Stop SDK Error: " + e.toString());
//         }

        // 3. 断开硬件连接
        try {
            if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
                MKUtil.getInstance().disconnect(false);
            } else if (SkydroidRcConnectUtil.isSkydroidRc()) {
                SkydroidRcConnectUtil.getInstance().disconnect(true);
            }
        } catch (Exception e) {
            Log.e(TAG, "Hardware Disconnect Error: " + e.toString());
        }
    }


    // 没什么用的 Handler，仅用于保活
    private static Handler handler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(Message msg) {}
    };
}