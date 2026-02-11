package com.test.sdk.rc;

import androidx.annotation.NonNull;

import java.lang.ref.WeakReference;
import java.util.concurrent.CopyOnWriteArrayList;

/**
 * 遥控器天空端数据管理器
 */
public class RcSkyDataManager
{
    /**
     * 接收遥控器天空端数据监听器
     */
    public interface OnGetRcSkyDataListener
    {
        /**
         * 收到遥控器天空端数据
         *
         * @param datas 数据
         * @return 返回true此数据已经被处理
         */
        boolean onGetRcSkyData(@NonNull byte[] datas);
    }

    /**
     * 发送天空端数据监听器
     */
    public interface OnSendRcSkyDataListener
    {
        /**
         * 当发送天空端数据
         *
         * @param datas
         */
        void onSendRcSkyData(@NonNull byte[] datas);
    }

    private static volatile RcSkyDataManager instance;

    public static RcSkyDataManager getInstance()
    {
        if (instance == null)
        {
            synchronized (RcSkyDataManager.class)
            {
                if (instance == null)
                {
                    instance = new RcSkyDataManager();
                }
            }
        }
        return instance;
    }

    /**
     * 接收监听器集合
     */
    private CopyOnWriteArrayList<WeakReference<OnGetRcSkyDataListener>> getListenerList;

    /**
     * 发送监听器集合
     */
    private CopyOnWriteArrayList<WeakReference<OnSendRcSkyDataListener>> sendListenerList;

    private RcSkyDataManager()
    {
        this.getListenerList = new CopyOnWriteArrayList<>();
        this.sendListenerList = new CopyOnWriteArrayList<>();
    }

    /**
     * 添加接收遥控器天空端数据监听器
     *
     * @param listener
     */
    public void addOnGetRcSkyDataListener(OnGetRcSkyDataListener listener)
    {
        if (listener == null)
        {
            return;
        }
        for (int i = 0; i < this.getListenerList.size(); i++)
        {
            WeakReference<OnGetRcSkyDataListener> weak = this.getListenerList.get(i);
            if (weak != null && weak.get() != null && weak.get() == listener)
            {
                return;
            }
        }
        this.getListenerList.add(new WeakReference<>(listener));
    }

    /**
     * 移除接收遥控器天空端数据监听器
     *
     * @param listener
     */
    public void removeOnGetRcSkyDataListener(OnGetRcSkyDataListener listener)
    {
        if (listener == null)
        {
            return;
        }
        for (int i = this.getListenerList.size() - 1; i >= 0; i--)
        {
            WeakReference<OnGetRcSkyDataListener> weak = this.getListenerList.get(i);
            if (weak == null || weak.get() == null)
            {
                continue;
            }
            if (weak.get() == listener)
            {
                weak.clear();
                this.getListenerList.remove(i);
                break;
            }
        }
    }

    /**
     * 接收天空端数据
     *
     * @param datas
     * @return 返回ture表示数据已经被处理过
     */
    public boolean onGetSkyData(@NonNull byte[] datas)
    {
        if (datas.length == 0 || this.getListenerList.isEmpty())
        {
            return false;
        }
        boolean result = false;
        for (int i = 0; i < this.getListenerList.size(); i++)
        {
            WeakReference<OnGetRcSkyDataListener> weak = this.getListenerList.get(i);
            if (weak == null || weak.get() == null)
            {
                continue;
            }
            if (weak.get().onGetRcSkyData(datas) && !result)
            {
                result = true;
            }
        }
        return result;
    }

    /**
     * 添加发送数据到天空端监听器
     *
     * @param listener
     */
    public void addOnSendRcSkyDataListener(OnSendRcSkyDataListener listener)
    {
        if (listener == null)
        {
            return;
        }
        for (int i = 0; i < this.sendListenerList.size(); i++)
        {
            WeakReference<OnSendRcSkyDataListener> weak = this.sendListenerList.get(i);
            if (weak != null && weak.get() != null && weak.get() == listener)
            {
                return;
            }
        }
        this.sendListenerList.add(new WeakReference<>(listener));
    }

    /**
     * 移除发送数据到天空端监听器
     *
     * @param listener
     */
    public void removeOnSendRcSkyDataListener(OnSendRcSkyDataListener listener)
    {
        if (listener == null)
        {
            return;
        }
        for (int i = this.sendListenerList.size() - 1; i >= 0; i--)
        {
            WeakReference<OnSendRcSkyDataListener> weak = this.sendListenerList.get(i);
            if (weak == null || weak.get() == null)
            {
                continue;
            }
            if (weak.get() == listener)
            {
                weak.clear();
                this.sendListenerList.remove(i);
                break;
            }
        }
    }

    /**
     * 发送遥控器天空端数据
     *
     * @param datas
     */
    public void sendRcSkyData(@NonNull byte[] datas)
    {
        if (datas.length == 0)
        {
            return;
        }
        for (int i = 0; i < this.sendListenerList.size(); i++)
        {
            WeakReference<OnSendRcSkyDataListener> weak = this.sendListenerList.get(i);
            if (weak == null || weak.get() == null)
            {
                continue;
            }
            weak.get().onSendRcSkyData(datas);
        }
    }
}
