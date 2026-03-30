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
    } else {
        emit logUpdate("连接失败: " + m_tcp->errorString());
    }
}

void ShoutingController::sendCommand(const QString &cmd, QVariantMap params) {
    if (!m_tcp || m_tcp->state() != QAbstractSocket::ConnectedState) return;

    QJsonObject json;
    json["command"] = cmd;
    json["cseq"] = QString::number(m_cseq++);

    for(auto it = params.begin(); it != params.end(); ++it) {
        json[it.key()] = QJsonValue::fromVariant(it.value());
    }

    // 协议强制结尾 \r\n\r\n
    QByteArray data = QJsonDocument(json).toJson(QJsonDocument::Compact) + "\r\n\r\n";
    m_tcp->write(data);
    emit logUpdate("发送指令: " + data.trimmed());
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
    QByteArray data = m_tcp->readAll();

    // 解析 JSON
    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();
    QString cmd = obj["command"].toString();

    if (cmd == "post_play_list") {
        QJsonArray arr = obj["list"].toArray();
        // 转换后再发射
        emit playListParsed(arr.toVariantList());
    }
    else if (cmd == "post_vol") {
        // 提取音量并发射信号
        int vol = obj["play_vol"].toString().toInt();
        emit volumeUpdated(vol);
    }
    else if (cmd == "post_status") {
        // 也可以增加对当前模式的解析
        QString model = obj["model"].toString();
        emit logUpdate("当前模式: " + model);
    }
}

// 3. 上传文件 (关键：指令 + 二进制)
void ShoutingController::uploadFile(const QString& localPath) {
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        emit logUpdate("无法打开本地文件: " + localPath);
        return;
    }

    QByteArray fileData = file.readAll();
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