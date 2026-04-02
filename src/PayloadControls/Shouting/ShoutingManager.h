#pragma once

#include <QObject>
#include <QVariantMap>

#include "ShoutingController.h"

/**
 * @brief ShoutingManager 是 QML 和 C++ 协议逻辑之间的桥梁
 * 它会被注入到 QML 上下文中，变量名为 shoutingManager
 */
class ShoutingManager : public QObject
{
    Q_OBJECT

    // 增加属性供 QML ListView 使用
    Q_PROPERTY(QVariantList playList READ playList NOTIFY playListChanged)
    Q_PROPERTY(int currentVolume READ currentVolume WRITE setCurrentVolume NOTIFY currentVolumeChanged)

    // 暴露给 QML 的属性：连接状态
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    // 暴露给 QML 的属性：最后一条日志/错误信息
    Q_PROPERTY(QString lastLog READ lastLog NOTIFY lastLogChanged)

public:
    explicit ShoutingManager(QObject *parent = nullptr);
    ~ShoutingManager();

    // --- 供 QML 调用的接口 ---

    // 连接喊话器 IP
    // 确保在 public ，否则 QML 无法调用
    Q_INVOKABLE void connectToDevice(const QString& ip);

    Q_INVOKABLE void disconnectDevice() { _controller->disconnectDevice(); }

    // 开始实时喊话 (内部包含 Android 权限请求)
    Q_INVOKABLE void startMic();

    // 停止实时喊话
    Q_INVOKABLE void stopMic();

    // 发送一键报警/驱散 (index 通常为 1)
    Q_INVOKABLE void sendAlarm(int index = 1);

    // 设置音量 (1-100)
    Q_INVOKABLE void setVolume(int vol);

    // --- 属性读取函数 ---
    bool connected() const;
    QString lastLog() const { return _lastLog; }

    Q_INVOKABLE void refreshPlayList();    // 获取列表
    Q_INVOKABLE void playByPath(QString path); // V2.0.5 路径播放



    // --- MP3 播放控制接口 ---
    Q_INVOKABLE void playIndex(int index);       // 按索引播放
    Q_INVOKABLE void stopPlayer();              // 停止播放
    Q_INVOKABLE void nextSong();                // 下一首
    Q_INVOKABLE void previousSong();            // 上一首
    Q_INVOKABLE void repeatPath(QString path);  // 路径循环播放 (V2.0.5)

    // --- 文件管理接口 ---
    Q_INVOKABLE void uploadMp3(QString localPath);
    Q_INVOKABLE void deleteMp3(QString fileName);

    QVariantList playList() const { return _playList; }
    int currentVolume() const { return _currentVolume; }
    void setCurrentVolume(int vol);

    signals:
    void connectedChanged();
    void lastLogChanged();
    void playListChanged();
    void currentVolumeChanged();

private slots:
    // 处理来自控制器的原始日志信号
    void _handleLogUpdate(QString msg);

private:
    ShoutingController* _controller; // 真正的协议实现类
    QString             _lastLog;
    QVariantList _playList; // 存储格式：[{"name":"xxx.mp3", "index":"0"}, ...]
    int _currentVolume = 50;
};
