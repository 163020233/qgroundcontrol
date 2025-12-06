//
// Created by Administrator on 25-11-26.
//

#ifndef BOYINGLINK_H
#define BOYINGLINK_H

#pragma once

#include "LinkInterface.h"
#include "BoyingLinkConfiguration.h"
#include <QThread>
#include <QUdpSocket>
#include <QTimer> // ★★★ 1. 必须加这个头文件 ★★★
#include <QMutex>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

class BoyingWorker : public QObject {
    Q_OBJECT
   public:
    BoyingWorker() : _udpSocket(nullptr), _keepAliveTimer(nullptr) {} // 初始化为空

   public slots:
    void init();
    void sendData(const QByteArray bytes);
    void cleanup();

   private slots:
    void _onUdpReadyRead(); // ★★★ 2. 改为 UDP 读取槽

   signals:
    void dataReceived(QByteArray data);

   private:
    bool _initUdpSocket();     // 初始化 UDP
    void _processJsonData(const QString& jsonStr);
    QTimer* _keepAliveTimer; // ★ 必须有这一行声明

    QUdpSocket* _udpSocket;    // ★★★ 3. 替换为 UDP Socket
    QHostAddress _targetIp;    // 飞控/转发服务的 IP
    quint16      _targetPort;  // 飞控/转发服务的 端口

#ifdef Q_OS_ANDROID
    QJniObject _javaSdk;
#endif
};
// =========================================================
// BoyingLink: 主线程，对接 QGC
// =========================================================
class BoyingLink : public LinkInterface
{
    Q_OBJECT

public:
    BoyingLink(SharedLinkConfigurationPtr& config);
    ~BoyingLink();

    virtual bool    isConnected (void) const override;
    virtual void    disconnect  (void) override;
    virtual void    _writeBytes (const QByteArray &bytes) override;

    signals:
     void _workerInit();
    void _workerSend(const QByteArray bytes);
    void _workerCleanup();

private slots:
    void _onWorkerData(QByteArray data);

private:
    bool _connect(void) override;

    bool _is_connected;
    QThread*      _thread;
    BoyingWorker* _worker;
};

#endif // BOYINGLINK_H
