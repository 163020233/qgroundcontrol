//
// Created by Administrator on 25-11-26.
//

#ifndef BOYINGLINK_H
#define BOYINGLINK_H

/****************************************************************************
 *   BoyingLink.h
 *   Header for Boying SDK Link (UDP Version with Polling)
 ****************************************************************************/

#pragma once

#include "LinkInterface.h"
#include "BoyingLinkConfiguration.h"
#include <QThread>
#include <QMutex>
#include <QTimer> // 别忘了这个
#include <QDateTime> // 引入时间库
#include <mavlink.h>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

class BoyingWorker : public QObject {
    Q_OBJECT
public:
    BoyingWorker() {}

public slots:
    void init();
    void sendData(const QByteArray bytes);
    void cleanup();
    // ★★★ 新增：供 JNI 回调的槽函数 ★★★
    // void onJavaDataReceived(const QByteArray& rawData);
    void onJsonReceived(const QString& jsonStr);
    void _sendHeartbeat(); // 定时发送心跳的槽函数
    signals:
        void dataReceived(QByteArray data);

private:
    float _smoothBatteryPercent = -1.0f; // 存储平滑后的百分比
    // --- 【新增定义点 1】：参数内存仓库 ---
    // 这个 Map 存储了飞机当前所有的“真实状态参数”
    QMap<QString, float> _parameters;
    int _lastCustomMode = -1;
    // --- 【新增定义点 2】：采集函数声明 ---
    // 负责把 JSON 里的值存入 Map 并通知 QGC
    void harvestParam(const QString& id, float value);
    void _processJsonData(const QString& jsonStr);

    bool _isFirstDataReceived = false; // 是否收到了第一条 SDK 数据
    QElapsedTimer _dataTimeoutTimer;  // 记录最后一次收到数据的时间

    // ★★★ 2. 在这里补上定义 ★★★
    QTimer* _heartbeatTimer = nullptr; // 定时器指针

    // 缓存最新状态，确保定时器发出的是真实的业务数据
    uint8_t  _lastMavBaseMode = MAV_MODE_FLAG_CUSTOM_MODE_ENABLED;
    uint32_t _lastArduMode    = 0; // 对应映射后的 2, 5, 6 等
    uint8_t  _lastMavState    = MAV_STATE_STANDBY;

#ifdef Q_OS_ANDROID
    QJniObject _javaSdk;
#endif
};

// =========================================================
// BoyingLink: 主线程接口类
// 负责：适配 QGC LinkInterface 接口，管理 Worker 线程
// =========================================================
class BoyingLink : public LinkInterface
{
    Q_OBJECT

public:
    // QGC 5.0 使用 SharedLinkConfigurationPtr
    BoyingLink(SharedLinkConfigurationPtr& config);
    ~BoyingLink();

    // --- LinkInterface 纯虚函数实现 ---
    virtual bool    isConnected (void) const override;
    virtual void    disconnect  (void) override;

    // QGC 核心调用此函数发送数据 (注意 const & 签名)
    virtual void    _writeBytes (const QByteArray &bytes) override;

signals:
    // --- 跨线程控制信号 ---
    void _workerInit();
    void _workerSend(const QByteArray bytes);
    void _workerCleanup();

private slots:
    // --- 接收 Worker 数据 ---
    void _onWorkerData(QByteArray data);



private:
    // 内部连接函数
    bool _connect(void) override;

    bool          _is_connected;
    QThread*      _thread;
    BoyingWorker* _worker;
};

#endif // BOYINGLINK_H
