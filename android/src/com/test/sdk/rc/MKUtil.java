package com.test.sdk.rc;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.siyi.connect.MkSerialPortConnection;
import com.test.sdk.DataUtil;

import java.io.IOException;
import java.util.Locale;

import boying.sdk.BoyingSdk;
// import okhttp3.internal.Util;

import org.qjkj.gcs.QGCConnectionManager;

public class MKUtil
{

    /**
     * MK
     */
    int MK_EXP = 800;
    private static final String TAG = "MKUtil";

    /**
     * 设备型号Standard_94
     */
    static String DEVICE_MODEL_UNIRC7 = "Standard_94";
    /**
     * 设备型号Pro_94
     */
    static String DEVICE_MODEL_UNIRC7PRO = "Pro_94";
    private static volatile MKUtil instance;
    public  MkSerialPortConnection serialPort;

    private boolean isConnected = false;


    private Handler connectHandler;


    public static MKUtil getInstance()
    {
        if (instance == null)
        {
            synchronized (MKUtil.class)
            {
                if (instance == null)
                {
                    instance = new MKUtil();
                }
            }
        }
        return instance;
    }

    // =========================================================
    // ★★★ 新增：供 QGC 调用，发送原始数据到串口 ★★★
    // =========================================================
    public void sendRawData(byte[] data) {
        if (serialPort != null && isConnected) {
            Log.d(TAG, "Java TX: " + data.length + " bytes"); // 调试可开
            serialPort.sendData(data);
        } else {
            Log.e(TAG, "Serial Port not ready!");
        }
    }

    /**
     * 连接
     */

    public void connect(Handler handler)
    {
        this.connectHandler=handler;
        disconnect(false);
        try
        {
            serialPort = MkSerialPortConnection.newBuilder(this.getDevicePath(), this.getBuadrate())
                                 .flags(this.getConnectFlag())
                                 .build();
            serialPort.setDelegate(getDelegate());
            serialPort.openConnection();
        } catch (Exception e)
        {
            Log.e(TAG, e.toString());
            disconnect(false);
            handler.sendEmptyMessage(MK_EXP);
        }
    }

    protected String getDevicePath()
    {
        return (isUnirc7() || isUnirc7Pro()) ? "/dev/ttyHS3" : "/dev/ttyHS0";
    }

    protected int getBuadrate()
    {
        return 115200;
    }

    protected int getConnectFlag()
    {
        return 0;
    }


public MkSerialPortConnection.Delegate getDelegate()
    {
        return new MkSerialPortConnection.Delegate()
        {
            @Override
            public void onConnected()
            {
                isConnected = true;

                // ★★★ 增加判空保护 ★★★
                if (connectHandler != null) {
                    connectHandler.sendEmptyMessage(0);
                }

                // ★★★ 必须保留 SDK 心跳维护 ★★★
                startWriteSdkData();

                // ★★★ 建议注释掉业务发送队列 (QGC不用这个) ★★★
                // startWriteBySdk();
            }

            @Override
            public void received(byte[] bytes, int size)
            {
                parseReceivedData(bytes, size);
            }
        };
    }


        /**
         *
         * @param bytes
         * @param size
         */
        /**
         * 处理接收到的数据
         * @param bytes 原始二进制数据
         * @param size 数据长度
         */
        protected void parseReceivedData(byte[] bytes, int size)
        {
            // =================================================================
            // ★★★ 新增：核心拦截逻辑 ★★★
            // 将原始数据直接传给 C++ (QGC)，不再在 Java 层做业务处理
            // =================================================================
//             if (bytes != null && size > 0) {
//                 // 这里的 nativeOnDataReceived 会触发 C++ 里的 JNI 函数
//                 // 最终数据会流向 BoyingLink.cc -> _processJsonData
//                 Log.d(TAG, "Java RX: " + size + " bytes -> Sending to C++");
//                 QGCConnectionManager.nativeOnDataReceived(bytes, size);
//             }
            if (bytes != null && size > 0) {
                // ★★★ 透传给 Manager ★★★
                QGCConnectionManager.onHardwareDataReceived(bytes);
            }
        // ==
            // =================================================================
            // ▼ 下面的旧代码建议全部注释掉 ▼
            // 因为 QGC 的 C++ 层会负责解析 JSON 和打印日志。
            // 如果 Java 层也解析一遍，会浪费 CPU 资源，甚至导致卡顿。
            // 只有当你发现 C++ 收不到数据，想在 Logcat 里调试时，才取消注释。
            // =================================================================

            /*
            // --- 原有 Demo 逻辑 (建议注释) ---
            JSONArray jsonArray = BoyingSdk.getInstance().onReceive(bytes, size);
            if (jsonArray != null)
            {
                for (int i = 0; i < jsonArray.size(); i++)
                {
                    JSONObject jsonObject = jsonArray.getJSONObject(i);
                    int type = jsonObject.getIntValue("byType");

                    // 调试时可以保留这行日志，证明 Java 收到了数据
                    if(type == 0) {
                        Log.d(TAG, "Java层收到心跳包: " + jsonObject.toString());
                    }

                    // ... (原本繁琐的 UI 更新代码全部略过) ...
                }
            }
            */
        }
    //    protected void parseReceivedData(byte[] bytes, int size)
    //    {
    //        // 关键调用：把串口原始数据喂给 SDK，SDK 返回解析好的 JSON 数组
    //        JSONArray jsonArray = BoyingSdk.getInstance().onReceive(bytes, size);
    //        if (jsonArray != null)
    //        {
    //            for (int i = 0; i < jsonArray.size(); i++)
    //            {
    //                JSONObject jsonObject = jsonArray.getJSONObject(i);
    //                int type = jsonObject.getIntValue("byType");
    //                if(type==0)
    //                {
    //                    //{"autopilot":19,"base_mode":81,"byType":0,"custom_mode":2,"mavlink_version":3,"seq":53,"system_status":3,"type":2}
    //                    Log.d(TAG, "心跳包:" + jsonObject.toString());
    //                    long customMode = jsonObject.getLong("custom_mode");
    //                    short baseMode = jsonObject.getShort("base_mode");
    //                    short systemStatus = jsonObject.getShort("system_status");
    //                    boolean isArm=((byte) baseMode & (byte) 128) == (byte) 128;
    //                    boolean isFlying=(systemStatus == 4);
    //                    Message message=Message.obtain();
    //                    Bundle bundle=new Bundle();
    //                    bundle.putString("flightMode","飞行模式:"+DataUtil.getFlightMode((int) customMode)+",  锁状态:"+(isArm?"已":"未")+"解锁,"+"  起飞状态:"+(isFlying?"已":"未")+"起飞");
    //                    bundle.putBoolean("isArm",isArm);
    //                    message.setData(bundle);
    //                    message.what=4;
    //                    connectHandler.sendMessage(message);
    //                }
    //                if (type == 2)
    //                {
    //                    //{"bo":66,"byType":2,"des_ver":8,"fli_con_seq":69,"har_pro_bat":1,"har_pro_time":1709,"imp_edi":1,"imu_ide":2,"reserve_pos1":0,"reserve_pos2":0,"seq":10,"ying":89}
    //                    byte bo = jsonObject.getByte("bo");
    //                    byte ying = jsonObject.getByte("ying");
    //                    short imp_edi = jsonObject.getShort("imp_edi");
    //                    short imu_ide = jsonObject.getShort("imu_ide");
    //                    short des_ver = jsonObject.getShort("des_ver");
    //                    short har_pro_bat = jsonObject.getShort("har_pro_bat");
    //                    short har_pro_time = jsonObject.getShort("har_pro_time");
    //                    short fli_con_seq = jsonObject.getShort("fli_con_seq");
    //                    String versionNum = new String(new byte[]{bo, ying}) + imp_edi + imu_ide + des_ver + har_pro_bat + har_pro_time + String.format(Locale.US, "%04d", fli_con_seq);
    //                    Message message=Message.obtain();
    //                    message.what=3;
    //                    message.obj=versionNum;
    //                    connectHandler.sendMessage(message);
    //                }
    //                if (type == 3)
    //                {
    //                    //{"alt":0,"byType":3,"cog":0,"count":0,"eph":9999,"epv":0,"fixType":0,"lat":0,"lon":0,"seq":225,"time_usec":0,"vel":0}
    //                    short count = jsonObject.getShort("count");
    //                    short fixType = jsonObject.getShort("fixType");
    //                    String versionNum = "GPS:" + count + "  " + DataUtil.getFixType(fixType);
    //                    Message message=Message.obtain();
    //                    message.what=5;
    //                    message.obj=versionNum;
    //                    connectHandler.sendMessage(message);
    //                }
    //                if (type == 4)
    //                {
    //                    //{"alt":0,"byType":4,"cog":0,"count":0,"dgps_age":0,"dgps_numch":0,"eph":0,"epv":0,"fixType":0,"lat":0,"lon":0,"seq":226,"time_usec":0,"vel":0}
    //                    short count = jsonObject.getShort("count");
    //                    short fixType = jsonObject.getShort("fixType");
    //                    int dgps_age = jsonObject.getIntValue("dgps_age");
    //                    String versionNum = "RTK GPS:" + count + "  " + DataUtil.getFixType(fixType)+","+dgps_age;
    //                    Message message=Message.obtain();
    //                    message.what=6;
    //                    message.obj=versionNum;
    //                    connectHandler.sendMessage(message);
    //                }
    //                if (type == 9)
    //                {
    //                    double pitch = jsonObject.getDoubleValue("pitch");
    //                    double roll = jsonObject.getDoubleValue("roll");
    //                    double yaw = jsonObject.getDoubleValue("yaw");
    //                    Message message=Message.obtain();
    //                    message.what=2;
    //                    message.obj=String.format(Locale.US, "%s:%d°,%s:%d°,%s:%d°", "pitch", (int) (pitch * 180.f / Math.PI), "roll", (int) (roll * 180.f / Math.PI), "yaw", (int) (yaw * 180.f / Math.PI % 360.0));
    //                    connectHandler.sendMessage(message);
    //
    //                }
    //                if (type == 12)
    //                {
    //                    //{"alt":4100,"byType":12,"hdg":8881,"lat":0,"lon":0,"relative_alt":4100,"seq":14,"timeBootMs":6714030,"vx":0,"vy":0,"vz":0}
    //                    //Log.d(TAG, "飞机位置数据:" + jsonObject.toString());
    //                }
    //                if (type == 13)
    //                {
    //                    float radarDis = jsonObject.getFloat("distance");
    //                    Log.d(TAG, "雷达数据:" + jsonObject.toString());
    //                    Message message=Message.obtain();
    //                    message.what=7;
    //                    message.obj=  radarDis;
    //                    connectHandler.sendMessage(message);
    //                }
    //
    //                if(type==20)
    //                {
    //                    //{"byType":20,"seq":207,"severity":2,"text":[92,117,53,57,49,54,92,117,55,70,54,69,92,117,55,70,53,55,92,117,55,54,68,56,92,117,54,55,50,65,92,117,56,70,68,69,92,117,54,51,65,53,0,92,117,55,70,53,55,92]}
    //                    short severity = jsonObject.getShort("severity");
    //                    JSONArray textArray= jsonObject.getJSONArray("text");
    //                    byte[] result = new byte[textArray.size()];
    //                    for (int j = 0; j < textArray.size(); j++) {
    //                        result[j] =  textArray.getByte(j);
    //                    }
    //                    Log.d(TAG, "文本信息:" + DataUtil.getInstance().getText(result));
    //
    //                }
    //
    //            }
    //
    //        }
    //
    //
    //    }
//     /**
//      * ★★★ 新增：供外部 (C++) 调用的发送接口 ★★★
//      * @param data 要发送给飞控的原始二进制数据
//      */
//     public void sendRawData(byte[] data) {
//         if (isConnected && serialPort != null && data != null && data.length > 0) {
//             try {
//                 // 调用 MkSerialPortConnection 的 sendData
//                 serialPort.sendData(data);
//                 // Log.d(TAG, "C++发送数据: " + bytesToLogString(data)); // 调试用
//             } catch (Exception e) {
//                 Log.e(TAG, "发送失败: " + e.toString());
//             }
//         }
//     }
    /**
     * 开始写数据,使用SDK
     */
    private void startWriteBySdk()
    {
        new Thread(() -> {
            while (isConnected)
            {
                if (com.test.sdk.Util.getInstance().sdkQueue.isEmpty())
                {
                    continue;
                }
                try
                {
                    JSONObject json = com.test.sdk.Util.getInstance().sdkQueue.take();
                    if (json == null)
                    {
                        continue;
                    }
                    byte[] bytes = BoyingSdk.getInstance().sendCmd(json);
                    if (bytes == null || bytes.length == 0)
                    {
                        Log.d(TAG, "发送命令为空返回了");
                        continue;
                    }
                    if (serialPort != null)
                    {
                        Log.d(TAG, "发送命令=" + bytes.length);
                        serialPort.sendData(bytes);
                    }
                } catch (Exception e)
                {
                    Log.e(TAG,e.toString());
                }
            }
        }).start();
    }


    /**
     * 开始发送SDK的数据
     */
    private void startWriteSdkData()
    {
        new Thread(() ->
        {
            while (isConnected)
            {
                try
                {
                    byte[] bytes = BoyingSdk.getInstance().getSdkData();
                    if (bytes == null || bytes.length == 0)
                    {
                        continue;
                    }
                    if (serialPort != null)
                    {
                        serialPort.sendData(bytes);
                    }
                } catch (Exception e)
                {
                    Log.e(TAG, e.toString());
                }
            }
        }).start();

    }


    /**
     * 断开连接
     *
     * @param isShowMsg 显示信息
     */

    public void disconnect(boolean isShowMsg)
    {

        try
        {
            if (serialPort != null)
            {
                serialPort.closeConnection();
                serialPort = null;
            }
        } catch (IOException e)
        {
            Log.e(TAG, e.toString());
        }
        isConnected = false;
    }


    public boolean isAlive()
    {
        return serialPort != null && (serialPort.isConnection());
    }

    /**
     * 是否是UNIRC7遥控器,仅用于检测硬件设备是否是UNIRC7
     *
     * @return
     */
    public static boolean isUnirc7()
    {
        return DEVICE_MODEL_UNIRC7.equals(Build.MODEL);
    }

    /**
     * 是否是UNIRC7pro遥控器,仅用于检测硬件设备是否是UNIRC7pro
     *
     * @return
     */
    public static boolean isUnirc7Pro()
    {
        return DEVICE_MODEL_UNIRC7PRO.equals(Build.MODEL);
    }


}
