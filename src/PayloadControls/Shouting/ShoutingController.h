#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QUdpSocket>
#include <QTimer>
#include <QAudioSource>
#include <QVariantMap>
#include <QAudioFormat>

// --- 必须包含这两个头文件 ---
#include <QJsonArray>  // <--- 解决报错 C2664 和 C2027 的关键
#include <QJsonObject>
#include <QJsonDocument>

// 定义配置结构体
struct DevConfig {
    struct Network {
        QString dev_ip      = "127.0.0.1";
        int     tcp_port    = 9527;  // 控制端口
        int     udp_port    = 8999;  // 视频端口
        int     time_delay  = 3000;
        int     time_heart  = 25000;
    } network;

    struct Audio {
        int     sampleRate       = 16000;
        int     dev_channelCount = 1;
        QAudioFormat::SampleFormat sampleType = QAudioFormat::Int16;
    } audio;
};

class ShoutingController : public QObject {
    Q_OBJECT
public:
    explicit ShoutingController(QObject *parent = nullptr);
    void forceSyncPlayList(); // 强制同步逻辑
    // 静态成员声明
    static DevConfig PlayerConfig;
    // 在 public 下增加
    void disconnectDevice();
    void connectToDevice(const QString &ip = QString());
    void sendCommand(const QString &cmd, QVariantMap params = QVariantMap());
    void startMic();
    void stopMic();
    void checkPermissionAndStart();

    void getPlayList();
    void forceRefreshPlayerMode(); // 核心：强制刷新并重载列表
    void uploadFile(const QString& localPath);
    bool isConnected() const;
    void _onSocketConnected();// 链接喊话器设备
    void _onSocketError(QAbstractSocket::SocketError socketError);
signals:
    void logUpdate(QString msg);
    void connectionChanged(bool connected);
    // 发送解析后的 JSON 数组 (播放列表)
    void playListParsed(QVariantList list);

    // 发送解析后的音量值 (0-100)
    void volumeUpdated(int vol);


private slots:
    void onTcpData();
    void onHeartbeat();


private:
    // --- 在这里定义 ---
    QByteArray  _tcpBuffer; // 用于暂存 TCP 接收到的原始字节流
    QTcpSocket* m_tcp   = nullptr;
    QUdpSocket* m_udp   = nullptr;
    QTimer*     m_timer = nullptr;
    QString     m_ip;
    int         m_cseq  = 1;
    QAudioSource* m_audioSource = nullptr;
    QIODevice*    m_audioDevice = nullptr;
};
