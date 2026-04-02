package com.test.sdk.rc;

import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Message;
import android.util.Log;

import androidx.annotation.NonNull;

import com.alibaba.fastjson.JSONArray;
import com.alibaba.fastjson.JSONObject;
import com.skydroid.rcsdk.PipelineManager;
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.comm.CommListener;
import com.skydroid.rcsdk.common.DeviceType;
import com.skydroid.rcsdk.common.Uart;
import com.skydroid.rcsdk.common.error.SkyException;
import com.skydroid.rcsdk.common.pipeline.Pipeline;
import com.skydroid.rcsdk.utils.RCSDKUtils;
import com.test.sdk.DataUtil;
import com.test.sdk.log.Logs;

import java.util.Locale;

import boying.sdk.BoyingSdk;
import org.qjkj.gcs.QGCConnectionManager;
/**
 * 云卓遥控器连接工具类
 */
public class SkydroidRcConnectUtil  implements CommListener
{
    private final static String TAG = "云卓遥控器连接工具";


    static String DEVICE_MODEL_H12 = "msm8953 for arm64";

    private volatile static SkydroidRcConnectUtil instance;

    public static SkydroidRcConnectUtil getInstance()
    {
        if (instance == null)
        {
            synchronized (SkydroidRcConnectUtil.class)
            {
                if (instance == null)
                {
                    instance = new SkydroidRcConnectUtil();
                }
            }
        }
        return instance;
    }

    /**
     * 通信管道
     */
    private Pipeline pipeline;
    /**
     * 连接时用的Handler
     */
    private Handler connectHandler;

    private volatile boolean isConnected = false;

    int SKYDROID_RC_EXP = 1700;


    private SkydroidRcConnectUtil()
    {
    }

    /**
     * 是否已连接
     *
     * @return
     */
    public boolean isConnected()
    {
        return isConnected;
    }


    public void connect(Handler handler)
    {
        this.disconnect(false);
        //SDK未连接
        if (!SkydroidRcSdkUtil.getInstance().isConnected())
        {
            Log.d(TAG, "连接失败,SDK未连接");
            handler.sendEmptyMessage(SKYDROID_RC_EXP);
            return;
        }
        //设备类型错误
        DeviceType deviceType = RCSDKManager.INSTANCE.getDeviceType();
        if (deviceType == DeviceType.UNKNOWN)
        {
            Log.d(TAG, "连接失败,设备类型错误");
            handler.sendEmptyMessage(SKYDROID_RC_EXP);
            return;
        }
        Log.d(TAG, "开始连接,deviceType=" + deviceType);
        //连接串口0
        Pipeline pipeline = PipelineManager.INSTANCE.createPipeline(deviceType, Uart.UART0);
        if (pipeline == null)
        {
            Log.d(TAG, "连接失败,创建pipeline返回null");
            handler.sendEmptyMessage(SKYDROID_RC_EXP);
            return;
        }
        this.pipeline = pipeline;
        this.connectHandler = handler;
        this.pipeline.setOnCommListener(this);
        PipelineManager.INSTANCE.connectPipeline(this.pipeline);
    }

    public void disconnect(boolean isShowMsg)
    {
        if (this.pipeline != null)
        {
            PipelineManager.INSTANCE.disconnectPipeline(this.pipeline);
        }
        this.pipeline = null;
        this.connectHandler = null;
        isConnected = false;
    }

    @Override
    public void onConnectSuccess()
    {
        Log.d(TAG, "SDK 连接成功");

//         this.connectHandler = null;
        connectHandler.sendEmptyMessage(0);
        isConnected = true;
//         this.startWrite();
        this.startWriteSdkData();
    }

    @Override
    public void onConnectFail(SkyException e)
    {
        Log.e(TAG,  "连接失败"+e);
        this.disconnect(false);
        if (this.connectHandler != null)
        {
            this.connectHandler.sendEmptyMessage(800);
        }
        this.connectHandler = null;
    }

    @Override
    public void onDisconnect()
    {
        Log.d(TAG, "已断开连接");
    }

    @Override
    public void onReadData(byte[] bytes)
    {
       parseReceivedData(bytes, bytes.length);
    }

    /**
     * 处理接收到的数据
     * @param bytes 原始二进制数据
     * @param size 数据长度
     */
    protected void parseReceivedData(byte[] data, int size)
    {
        // =================================================================
        // ★★★ 新增：核心拦截逻辑 ★★★
        // 将原始数据直接传给 C++ (QGC)，不再在 Java 层做业务处理
        // =================================================================
//         if (data != null && size > 0) {
//             // ★★★ 透传给 Manager ★★★
//             QGCConnectionManager.nativeOnDataReceived(data, size);
//         }
        if (data != null && size > 0) {
            // ★★★ 透传给 Manager ★★★
            QGCConnectionManager.onHardwareDataReceived(data);
        }
        // =================================================================
        // ▼ 下面的旧代码建议全部注释掉 ▼
        // 因为 QGC 的 C++ 层会负责解析 JSON 和打印日志。nativeOnDataReceived
        // 如果 Java 层也解析一遍，会浪费 CPU 资源，甚至导致卡顿。
        // 只有当你发现 C++ 收不到数据，想在 Logcat 里调试时，才取消注释。
        // =================================================================

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
//     public void sendDataToDevice(byte[] data) {
//         if (isConnected && pipeline != null && data != null && data.length > 0) {
//             try {
//                 // 直接调用云卓 SDK 的 writeData
//                 pipeline.writeData(data);
//                 Logs.d(TAG, "C++发送数据: " + bytesToLogString(data)); // 调试用
//             } catch (Exception e) {
//                 Log.e(TAG, "发送失败: " + e.toString());
//             }
//         } else {
//             Log.e(TAG, "发送失败：未连接或数据为空");
//         }
//     }

/**
     * 发送指令队列 (如起飞、解锁指令)
     */
    private void startWrite()
    {
        new Thread(() ->
        {
            while (isConnected)
            {
                try
                {
                    // 1. 获取队列数据
                    // 如果队列为空，take() 方法会自动阻塞等待，直到有数据进来
                    // 所以不需要那个 if(isEmpty) continue 的死循环
                    JSONObject json = com.test.sdk.Util.getInstance().sdkQueue.take();

                    if (json == null) continue;

                    // 2. 转换数据
                    byte[] bytes = BoyingSdk.getInstance().sendCmd(json);

                    // 3. 判空
                    if (bytes == null || bytes.length == 0)
                    {
                        Log.d(TAG, "发送命令为空返回了");
                        continue;
                    }

                    // 4. 发送
                    if (pipeline != null)
                    {
                        Log.i(TAG, ">>> 发送指令数据: " + bytes.length + " bytes");
                        pipeline.writeData(bytes);
                    }
                } catch (InterruptedException e) {
                    // 线程被中断，退出循环
                    break;
                } catch (Exception e) {
                    Log.e(TAG, "指令发送异常: " + e.toString());
                }
            }
        }).start();
    }

    public boolean isAlive()
    {
        return this.pipeline != null && this.pipeline.isConnected();
    }
    /**
     * 字节数组转成日志字符串,用逗号分隔
     *
     * @param bytes
     * @return
     */
    public static String bytesToLogString(@NonNull byte[] bytes)
    {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < bytes.length; i++)
        {
            sb.append("0x");
            String hex = Integer.toHexString(bytes[i] & 0xFF);
            if (hex.length() == 1)
            {
                sb.append("0");
            }
            sb.append(hex);
            if (i < bytes.length - 1)
            {
                sb.append(",");
            }
        }
        return sb.toString();
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
                        Thread.sleep(50); // 稍微休息一下，防止空转太快
                        continue;
                    }
//                     Log.d("SEND 发送给飞控的数据",bytesToLogString(bytes));

                    if (bytes == null || bytes.length == 0)
                    {
                        continue;
                    }
                    if (pipeline != null)
                    {
                        pipeline.writeData(bytes);
                    }
                    Thread.sleep(100);
                } catch (Exception e)
                {
                    Log.e(TAG, e.toString());
                }
            }
        }).start();
    }
    /**
     * 是否是UNIRC7遥控器,仅用于检测硬件设备是否是UNIRC7
     *
     * @return
     */
    public static boolean isH12()
    {
        return DEVICE_MODEL_H12.equals(Build.MODEL);
    }

    /**
     * 是否是H12Pro
     *
     * @return
     */
    public static boolean isH12Pro()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.H12Pro;
    }


    public static boolean isH16()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.H16;
    }

    public static boolean isH30()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.H30;
    }

    public static boolean isH20()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.H20;
    }

    public static boolean isG12()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.G12;
    }

    public static boolean isG20()
    {
        return RCSDKUtils.getDeviceType() == DeviceType.G20;
    }

    public static boolean isSkydroidRc()
    {
        return isH12() || isH12Pro() || isH16() || isH30() || isH20() || isG12() || isG20();
    }
}
