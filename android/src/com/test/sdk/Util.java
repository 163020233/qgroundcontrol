package com.test.sdk;

import android.os.Handler;

import com.alibaba.fastjson.JSONObject;
import com.siyi.connect.MkSerialPortConnection;
import com.test.sdk.rc.MKUtil;

import java.util.concurrent.LinkedBlockingQueue;

/**
 * Author:Xujingtao
 * Date:2025/6/5
 */
public class Util
{

    private static volatile Util instance;





    public static Util getInstance()
    {
        if (instance == null)
        {
            synchronized (Util.class)
            {
                if (instance == null)
                {
                    instance = new Util();
                }
            }
        }
        return instance;
    }


    /**
     * SDK消息队列
     */
    public final LinkedBlockingQueue<JSONObject> sdkQueue = new LinkedBlockingQueue<>();



}
