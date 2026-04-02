#include "ShoutingController.h"
#include <QAudioDevice>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMediaDevices>
#include <QCoreApplication>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>

#include <QPermission>       // 基础权限类

// 初始化类静态成员
DevConfig ShoutingController::PlayerConfig;

ShoutingController::ShoutingController(QObject *parent) : QObject(parent) {
    // 确保指针初始化
    m_tcp = new QTcpSocket(this);
    m_udp = new QUdpSocket(this);
    m_timer = new QTimer(this);

    // 从全局配置读取默认IP
    m_ip = PlayerConfig.network.dev_ip;

    // 在构造函数里
    connect(m_tcp, &QTcpSocket::disconnected, this, [this](){
        emit logUpdate("连接已断开，请检查网络");
        emit connectionChanged(false); // 异常掉线，立即通知 UI
        m_timer->stop(); // 停止心跳
    });

    // 【新增：监听错误信号】
    connect(m_tcp, &QTcpSocket::errorOccurred, this, [this](QAbstractSocket::SocketError socketError) {
        QString errorMsg;
        switch (socketError) {
            case QAbstractSocket::RemoteHostClosedError:
                errorMsg = "设备主动断开了连接"; break;
            case QAbstractSocket::HostNotFoundError:
                errorMsg = "找不到目标设备，请检查IP"; break;
            case QAbstractSocket::ConnectionRefusedError:
                errorMsg = "连接被拒绝，硬件可能未启动端口"; break;
            default:
                errorMsg = "通信错误: " + m_tcp->errorString();
        }
        emit logUpdate(errorMsg);       // 发送给 UI 显示
        emit connectionChanged(false);  // 强制 UI 状态变红
    });

    connect(m_tcp, &QTcpSocket::readyRead, this, &ShoutingController::onTcpData);
    connect(m_timer, &QTimer::timeout, this, &ShoutingController::onHeartbeat);
}

void ShoutingController::connectToDevice(const QString &ip) {
    if (!ip.isEmpty()) m_ip = ip;

    m_tcp->abort();
    // 使用配置中的端口和延迟
    m_tcp->connectToHost(m_ip, (quint16)PlayerConfig.network.tcp_port);

    if (m_tcp->waitForConnected(PlayerConfig.network.time_delay)) {
        emit logUpdate("成功连接到设备: " + m_ip);
        emit connectionChanged(true);
        m_timer->start(PlayerConfig.network.time_heart);
        // --- 在这里加：初始化音量 ---
        QVariantMap p;
        p["vol"] = "20"; // 建议先设为 20，如果还大就改成 10
        sendCommand("cap_vol", p);  // 限制麦克风采集增益
        sendCommand("play_vol", p); // 限制喇叭输出音量

        forceRefreshPlayerMode();
    } else {
        emit logUpdate("连接失败: " + m_tcp->errorString());
        emit connectionChanged(false); // <--- 【必须
    }
}

void ShoutingController::sendCommand(const QString &cmd, QVariantMap params) {
    if (m_tcp->state() != QAbstractSocket::ConnectedState) return;

    QJsonObject json;
    json["command"] = cmd;
    json["cseq"] = QString::number(m_cseq++);
    for(auto it = params.begin(); it != params.end(); ++it) {
        json[it.key()] = QJsonValue::fromVariant(it.value());
    }

    // 重点：显式转换为 UTF-8 并手动拼接 0x0D 0x0A
    QByteArray data = QJsonDocument(json).toJson(QJsonDocument::Compact);
    data.append("\r\n\r\n");

    m_tcp->write(data);
    m_tcp->flush(); // 强制 Android 立即物理发送，不等待缓冲区
    qDebug() << "QGC_Shouting_Sent:" << data;
}

// void ShoutingController::onTcpData() {
//     if(!m_tcp) return;
//     QByteArray data = m_tcp->readAll();
//     emit logUpdate("设备回复: " + data.trimmed());
// }

void ShoutingController::onHeartbeat() {
    sendCommand("online");
}

void ShoutingController::startMic() {
    QVariantMap p;
    p["model"] = "mic_broadcast";
    sendCommand("model_change", p);

    // --- 在这里加：确保采集音量处于低位 ---
    QVariantMap p_vol;
    p_vol["vol"] = "15";
    sendCommand("cap_vol", p_vol);
    
    // 配置音频格式
    QAudioFormat format;
    format.setSampleRate(16000); // 修正：使用采样率变量
    format.setChannelCount(1);
    format.setSampleFormat(QAudioFormat::Int16);

    auto device = QMediaDevices::defaultAudioInput();
    if (device.isNull()) {
        emit logUpdate("错误：未找到麦克风设备！");
        return;
    }

    if (m_audioSource) { stopMic(); }

    m_audioSource = new QAudioSource(device, format, this);
    m_audioDevice = m_audioSource->start();

    if (!m_audioDevice) {
        emit logUpdate("错误：麦克风启动失败！");
        return;
    }

    // 修正：4参数 connect 语法
    connect(m_audioDevice, &QIODevice::readyRead, this, [this](){
        if (!m_audioDevice) return;
        QByteArray pcmData = m_audioDevice->readAll();
        if (!pcmData.isEmpty()) {
            m_udp->writeDatagram(pcmData, QHostAddress(m_ip), (quint16)PlayerConfig.network.udp_port);
        }
    });

    emit logUpdate("麦克风启动，正在送话...");
}

void ShoutingController::stopMic() {
    if (m_audioSource) {
        m_audioSource->stop();
        m_audioSource->deleteLater();
        m_audioSource = nullptr;
        m_audioDevice = nullptr;
    }
    QVariantMap p;
    p["model"] = "idle";
    sendCommand("model_change", p);
    emit logUpdate("送话结束。");
}

void ShoutingController::checkPermissionAndStart() {
#if defined(Q_OS_ANDROID)
    // Qt 使用 QMicrophonePermission 对象
    QMicrophonePermission micPermission;

            // 检查权限状态
    auto status = qApp->checkPermission(micPermission);

    if (status == Qt::PermissionStatus::Undetermined) {
        // 异步请求权限
        qApp->requestPermission(micPermission, this, [this](const QPermission &p) {
            if (p.status() == Qt::PermissionStatus::Granted) {
                emit logUpdate("麦克风权限已获取");
                startMic();
            } else {
                emit logUpdate("权限申请失败");
            }
        });
    } else if (status == Qt::PermissionStatus::Granted) {
        startMic();
    } else {
        emit logUpdate("麦克风权限已被禁止，请在系统设置中开启");
    }
#else
    startMic();
#endif
}

bool ShoutingController::isConnected() const {
    return m_tcp && m_tcp->state() == QAbstractSocket::ConnectedState;
}

void ShoutingController::disconnectDevice() {
    m_timer->stop();        // 停止心跳计时器
    m_tcp->disconnectFromHost(); // 主动断开 TCP
    if (m_audioSource) stopMic(); // 如果正在喊话，强制停止
    emit connectionChanged(false);
    emit logUpdate("已主动断开连接。");
}

// 1. 获取列表请求
void ShoutingController::getPlayList() {
    sendCommand("get_play_list");
}

// 2. 解析收到的列表 (在 onTcpData 中处理)
void ShoutingController::onTcpData() {
    _tcpBuffer.append(m_tcp->readAll());

    while (_tcpBuffer.contains("\r\n\r\n")) {
        int pos = _tcpBuffer.indexOf("\r\n\r\n");
        QByteArray completeData = _tcpBuffer.left(pos).trimmed();
        _tcpBuffer.remove(0, pos + 4);

        QJsonDocument doc = QJsonDocument::fromJson(completeData);
        if (doc.isNull()) continue;

        QJsonObject obj = doc.object();
        QString cmd = obj["command"].toString();

        // --- 修正点 1：兼容真机的 command 名称 ---
        if (cmd == "post_play_list" || cmd == "get_play_list") {

            // --- 修正点 2：优先读取 play_list 字段 ---
            QJsonArray arr;
            if (obj.contains("play_list")) {
                arr = obj["play_list"].toArray();
            } else {
                arr = obj["list"].toArray(); // 兼容文档描述
            }

            if (!arr.isEmpty()) {
                qDebug() << "[Shouting] 成功提取到列表，文件数:" << arr.count();
                emit playListParsed(arr.toVariantList());
            } else {
                qDebug() << "[Shouting] 提取列表失败或列表为空。原始数据:" << completeData;
            }
        }
        else if (cmd == "post_vol") {
            emit volumeUpdated(obj["play_vol"].toString().toInt());
        }
        else if (cmd == "post_status") {
            // 也可以增加对当前模式的解析
            QString model = obj["model"].toString();
            emit logUpdate("当前模式: " + model);
        }
    }
}

// 3. 上传文件 (关键：指令 + 二进制)
void ShoutingController::uploadFile(const QString& localPath) {
    // 1. 处理路径：去掉 QML 传过来的 "file://" 前缀
    QString cleanPath = localPath;
    if (cleanPath.startsWith("file://")) {
        cleanPath = QUrl(localPath).toLocalFile();
    }

    QFile file(cleanPath);
    if (!file.open(QIODevice::ReadOnly)) {
        // 如果这里报错，说明权限或路径问题，Android 10+ 经常发生
        emit logUpdate("错误：无法打开文件 " + cleanPath + " 错误码：" + QString::number(file.error()));
        return;
    }

    QByteArray fileData = file.readAll();
    qDebug() << "File Size Read:" << fileData.size(); // 如果这里是 0，说明没读到数据
    QString fileName = QFileInfo(localPath).fileName();

    QJsonObject json;
    json["command"] = "add_mp3_file";
    json["cseq"] = QString::number(m_cseq++);
    json["name"] = fileName;
    json["mp3_len"] = QString::number(fileData.size());

    // 1. 发送 JSON Header + 结束符
    QByteArray header = QJsonDocument(json).toJson(QJsonDocument::Compact) + "\r\n\r\n";
    m_tcp->write(header);

    // 2. 紧接着发送原始二进制数据
    m_tcp->write(fileData);

    emit logUpdate("正在上传文件: " + fileName);
}

void ShoutingController::forceSyncPlayList() {
    if (!isConnected()) return;

    // 1. 切换到 player 模式（有些硬件在 idle 模式下不返回列表）
    QVariantMap p1;
    p1["model"] = "player";
    sendCommand("model_change", p1);

    // 2. 发送重载指令（关键：让硬件去数 SD 卡里有几个文件）
    sendCommand("reload_play_list");

    // 3. 延迟 500ms 后再请求列表（给硬件扫描 SD 卡的时间）
    QTimer::singleShot(500, this, [this](){
        sendCommand("get_play_list");
    });
}

// 在 ShoutingController.cc 中
void ShoutingController::forceRefreshPlayerMode() {
    if (!isConnected()) return;

    // 第一步：切模式
    QVariantMap p;
    p["model"] = "player";
    sendCommand("model_change", p);

    // 第二步：发重载指令 (这是识别本地文件的关键)
    sendCommand("reload_play_list");

    // 第三步：延迟获取列表 (给硬件预留扫描 SD 卡的时间)
    QTimer::singleShot(1500, this, [this](){
        sendCommand("get_play_list");
    });

    emit logUpdate("正在重载设备文件系统...");
}

