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
    signals:
        void dataReceived(QByteArray data);

private:
    void _processJsonData(const QString& jsonStr);
    // ★★★ 2. 在这里补上定义 ★★★
    QTimer* _heartbeatTimer;

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
