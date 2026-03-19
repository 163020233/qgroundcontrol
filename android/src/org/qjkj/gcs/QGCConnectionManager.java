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
import java.io.File;

public class QGCConnectionManager {
    private static final String TAG = "QGCConnection";

    private static boolean isInitialized = false;
    private static boolean isSiyi = false;
    private static boolean isSkydroid = false;
    private static boolean  isConnected = false;
    // 声明一个新的 Native 回调，用于回传结果
//     public static native void nativeOnCmdResult(int mavCmdId, int sdkResult);

    private static boolean isRunning = false; // 控制心跳线程
    private static final Object sendLock = new Object(); // 发送锁

    // ---------------------------------------------------------
    public static native void nativeOnJsonReceived(String jsonStr);

    private static final Handler handler = new Handler(Looper.getMainLooper()) {
        @Override
        public void handleMessage(@NonNull android.os.Message msg) {

            if (msg.what == 0) Log.i(TAG, "物理链路已连接");
        }
    };


    private static RcSkyDataManager.OnGetRcSkyDataListener mSkydroidListener = new RcSkyDataManager.OnGetRcSkyDataListener() {
        @Override
        public boolean onGetRcSkyData(@NonNull byte[] datas) {
            // --- 逻辑归拢：直接调用我们写好的统一处理函数 ---
            // 这样无论以后数据处理逻辑怎么变，你只需要改 onHardwareDataReceived 一个地方
            onHardwareDataReceived(datas);

            return false; // 返回 false 表示数据不被拦截，允许云卓 SDK 其他部分继续使用
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

       if (isInitialized) {
            Log.w(TAG, "警告：检测到重复初始化请求，已拦截！");
            return;
        }
        Log.i(TAG, "Java: initConnection CALLED! ");
        Log.i(TAG, "init called from", new Throwable("init trace"));

        Context context = QGCActivity.getActivity();
        if (context == null) return;

        BoyingSdk.getInstance().initSdk();
        // 1. 初始化 Boying SDK

        getConnectType();

        // 2. 初始化硬件
        if (isSkydroid) {
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


            if (!SkydroidRcConnectUtil.getInstance().isAlive()) {

                 //  2. 再启动SDK
                BoyingSdk.getInstance().startSdk();

                //  4. 再连接遥控器
                SkydroidRcConnectUtil.getInstance().connect(handler);

                isInitialized = true;
                isConnected = true;
            }
         }
       else{
             isInitialized = false;
             isConnected = false;
      }
    }

    private static void getConnectType() {
        // 每次检测前先重置，确保干净
        isSiyi = false;
        isSkydroid = false;

        // 使用 if-else 确保互斥：只能选其一
        if (MKUtil.isUnirc7() || MKUtil.isUnirc7Pro()) {
            isSiyi = true;
            Log.i(TAG, ">>> 检测到硬件：思翼 (Siyi)");
        }
        else if (SkydroidRcConnectUtil.isSkydroidRc()) {
            isSkydroid = true;
            Log.i(TAG, ">>> 检测到硬件：云卓 (Skydroid)");
        }
        else {
            Log.w(TAG, ">>> 未检测到专业遥控器，将使用通用通讯模式");
        }
    }


    public static int sendDataWithResult(String jsonCmd) {
        // 1. 基础判空
        if (jsonCmd == null || jsonCmd.isEmpty()) {
            return -1;
        }

        // 只有物理链路（云卓）是通的，才去调用博盈 SDK
        if (SkydroidRcConnectUtil.getInstance().isConnected()) {
            try {
                JSONObject cmdObj = JSONObject.parseObject(jsonCmd);

                // 同步调用博盈 SDK
                int result = BoyingSdk.getInstance().sendNewCmd(cmdObj);

                Log.w(TAG, "[JNI] 指令发送成功: " + jsonCmd + " | 结果: " + result);
                return result;
            }
            catch (Exception e) {
                Log.e(TAG, "[JNI] 指令解析/发送异常", e);
                return -2; // 解析异常
            }
        } else {
            // 3. 链路未连接
            Log.e(TAG, "[JNI] 指令发送失败：云卓遥控器未连接飞机");
            return -1;
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
}