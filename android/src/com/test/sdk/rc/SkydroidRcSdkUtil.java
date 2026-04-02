package com.test.sdk.rc;

import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.skydroid.rcsdk.KeyManager;
import com.skydroid.rcsdk.PipelineManager;
import com.skydroid.rcsdk.RCSDKManager;
import com.skydroid.rcsdk.SDKManagerCallBack;
import com.skydroid.rcsdk.comm.CommListener;
import com.skydroid.rcsdk.common.DeviceType;
import com.skydroid.rcsdk.common.Uart;
import com.skydroid.rcsdk.common.callback.CompletionCallbackWith;
import com.skydroid.rcsdk.common.callback.KeyListener;
import com.skydroid.rcsdk.common.error.SkyException;
import com.skydroid.rcsdk.common.pipeline.Pipeline;
import com.skydroid.rcsdk.common.remotecontroller.ControlMode;
import com.skydroid.rcsdk.key.RemoteControllerKey;

import org.jetbrains.annotations.Nullable;

import java.util.concurrent.ScheduledThreadPoolExecutor;


/**
 * 云卓遥控器SDK工具类
 */
public class SkydroidRcSdkUtil implements SDKManagerCallBack, CommListener, RcSkyDataManager.OnSendRcSkyDataListener
{
    private final static String TAG = "云卓遥控器SDK工具类";


    private static volatile SkydroidRcSdkUtil instance;

    public static SkydroidRcSdkUtil getInstance()
    {
        if (instance == null)
        {
            synchronized (SkydroidRcSdkUtil.class)
            {
                if (instance == null)
                {
                    instance = new SkydroidRcSdkUtil();
                }
            }
        }
        return instance;
    }

    /**
     * 是否正在连接中
     */
    private boolean isConnecting = false;

    /**
     * 是否已连接
     */
    private boolean isConnected = false;
    /**
     * SDK是否已初始化
     */
    private boolean isSdkInited = false;
    /**
     * 通信管道
     */
    private Pipeline pipeline;
    /**
     * 通道舵量定时请求器
     */
    private ScheduledThreadPoolExecutor channelsAmountExecutor;


    /**
     * 读取H12版本重试次数
     */
    private int readH12VersionRetryTimes = 0;
    /**
     * 要设置到H12的波特率,-1表示没有要设置的
     */
    private int pendingSetH12BaudRate = -1;
    /**
     * 设置H12波特率重试次数
     */
    private int setH12BaudRateRetryTimes = 0;

    private SkydroidRcSdkUtil()
    {
    }

    /**
     * 初始化SDK
     */
    private void initSdk(Context context)
    {
        if (this.isSdkInited)
        {
            return;
        }
        RCSDKManager.INSTANCE.initSDK(context, this);
        this.isSdkInited = true;
        Log.d(TAG, "初始化SDK");
    }

    /**
     * 连接
     */
    public synchronized void connect(Context context)
    {
        this.initSdk(context);
        if (this.isConnecting() || this.isConnected())
        {
            return;
        }
        Log.d(TAG, "连接遥控器");
        this.isConnecting = true;

        RCSDKManager.INSTANCE.connectToRC();
    }

    /**
     * 断开连接
     */
    public synchronized void disconnect()
    {
        if (!(this.isConnecting() || this.isConnected()))
        {
            return;
        }
        Log.d(TAG, "断开连接");
        this.isConnecting = false;
        this.isConnected = false;
        this.readH12VersionRetryTimes = 0;
        this.pendingSetH12BaudRate = -1;
        setH12BaudRateRetryTimes = 0;
        this.disconnectPipeline();

        RCSDKManager.INSTANCE.disconnectRC();
    }

    @Override
    public void onRcConnectFail(@Nullable SkyException e)
    {
        Log.e(TAG, "连接异常" + e);
        this.isConnecting = false;
    }

    @Override
    public void onRcConnected()
    {
        Log.d(TAG, "sdk连接成功");
        this.isConnected = true;
        this.isConnecting = false;
        //初始化手型
        this.initHandType();
        //读取H12版本号
        this.readH12Version();

        this.connectPipeline();
//        this.startRequestChannelsAmount();

    }

    @Override
    public void onRcDisconnect()
    {
        Log.d(TAG, "已断开连接");
    }

    /**
     * 连接管道
     */
    private void connectPipeline()
    {
        DeviceType deviceType = RCSDKManager.INSTANCE.getDeviceType();
        //仅部分遥控器有多个串口
        if (!(deviceType == DeviceType.H16 || deviceType == DeviceType.H30 || deviceType == DeviceType.H20))
        {
            Log.d(TAG, "创建管道,但是当前设备不支持多个串口,返回");
            return;
        }
        Log.d(TAG, "创建管道,deviceType=" + deviceType);
        //连接第二个串口
        this.pipeline = PipelineManager.INSTANCE.createPipeline(deviceType, Uart.UART1);
        if (this.pipeline == null)
        {
            Log.d(TAG, "创建管道返回null");
            return;
        }
        this.pipeline.setOnCommListener(this);
        PipelineManager.INSTANCE.connectPipeline(this.pipeline);
    }

    /**
     * 断开管道
     */
    private void disconnectPipeline()
    {
        if (this.pipeline == null)
        {
            return;
        }
        Log.d(TAG, "断开管道");
        PipelineManager.INSTANCE.disconnectPipeline(this.pipeline);
        this.pipeline = null;
    }

    /**
     * 发送数据
     *
     * @param bytes
     */
    private void sendData(@NonNull byte[] bytes)
    {
        if (this.pipeline == null || bytes.length == 0)
        {
            return;
        }
        new Thread(() ->
        {
            if (pipeline == null)
            {
                return;
            }
            pipeline.writeData(bytes);
        }).start();
    }

    @Override
    public void onConnectSuccess()
    {
        Log.d(TAG, "管道连接成功");
        RcSkyDataManager.getInstance().addOnSendRcSkyDataListener(this);
    }

    @Override
    public void onConnectFail(SkyException e)
    {
        Log.e(TAG, "管道连接失败" + e);
    }

    @Override
    public void onDisconnect()
    {
        Log.d(TAG, "已断开管道连接");
        this.pipeline = null;
    }

    @Override
    public void onReadData(byte[] bytes)
    {
        if (bytes == null || bytes.length == 0)
        {
            return;
        }
        RcSkyDataManager.getInstance().onGetSkyData(bytes);
    }

    @Override
    public void onSendRcSkyData(@NonNull byte[] datas)
    {
        this.sendData(datas);
    }


    /**
     * 初始化手型
     */
    private void initHandType()
    {
        KeyManager.INSTANCE.get(RemoteControllerKey.INSTANCE.getKeyControlMode(),
                new CompletionCallbackWith<ControlMode>()
                {
                    @Override
                    public void onSuccess(ControlMode controlMode)
                    {
                        Log.d(TAG, "初始化手型成功,手型=" + controlMode);
                        if (controlMode == ControlMode.UNKNOWN)
                        {
                            return;
                        }
                        switch (controlMode)
                        {
                            case USA:
                                //  Util.prefs.setHandType(Parameters.HAND_TYPE_USA);
                                break;
                            case JP:
                                //  Util.prefs.setHandType(Parameters.HAND_TYPE_JP);
                                break;
                            case USA_R:
                                //  Util.prefs.setHandType(Parameters.HAND_TYPE_ANTI_USA);
                                break;
                            case JP_R:
                                // Util.prefs.setHandType(Parameters.HAND_TYPE_ANTI_JP);
                                break;
                        }
                    }

                    @Override
                    public void onFailure(SkyException e)
                    {
                        Log.e(TAG, "初始化手型异常" + e);
                    }
                });
    }


    /**
     * 读取H12版本号
     */
    public void readH12Version()
    {
        if (RCSDKManager.INSTANCE.getDeviceType() != DeviceType.H12)
        {
            Log.d(TAG, "读取H12版本号,但是设备不是H12");
            return;
        }
        Log.d(TAG, "读取H12版本号");
        KeyManager.INSTANCE.get(RemoteControllerKey.INSTANCE.getKeyVersion(),
                new CompletionCallbackWith<String>()
                {
                    @Override
                    public void onSuccess(String s)
                    {
                        Log.d(TAG, "读取到H12版本号=" + s);
                        readH12VersionRetryTimes = 0;

                    }

                    @Override
                    public void onFailure(SkyException e)
                    {

                        if (readH12VersionRetryTimes < 2)
                        {
                            readH12Version();
                            readH12VersionRetryTimes++;
                        } else
                        {
                            readH12VersionRetryTimes = 0;
                        }
                    }
                });
    }


    /**
     * 是否正在连接中
     *
     * @return
     */
    public boolean isConnecting()
    {
        return isConnecting;
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

}
