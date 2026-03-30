#include "ShoutingManager.h"

#include <QDebug>
#include <QJsonArray>

ShoutingManager::ShoutingManager(QObject *parent)
    : QObject(parent)
{
    _controller = new ShoutingController(this);

    // 1. 基础信号 (没有参数，所以可以写空括号)
    connect(_controller, &ShoutingController::connectionChanged, this, &ShoutingManager::connectedChanged);

    // 2. 修正：播放列表信号 (必须带 QVariantList 参数)
    connect(_controller, &ShoutingController::playListParsed, this, [this](QVariantList list) {
        _playList = list;          // 将收到的数据存入成员变量
        emit playListChanged();     // 通知 QML 刷新列表
    });

    // 3. 修正：音量更新信号 (必须带 int 参数)
    connect(_controller, &ShoutingController::volumeUpdated, this, [this](int vol) {
        _currentVolume = vol;      // 更新音量成员变量
        emit currentVolumeChanged(); // 通知 QML 刷新滑动条
    });

    // 4. 基础日志信号
    connect(_controller, &ShoutingController::logUpdate, this, &ShoutingManager::_handleLogUpdate);
}

ShoutingManager::~ShoutingManager()
{
    // _controller 会随 this 自动销毁
}

void ShoutingManager::connectToDevice(const QString& ip)
{
    if (_controller) {
        // 逻辑：如果 QML 传了 IP，就连接 QML 的 IP；
        // 如果传空，Controller 会在 connectToDevice 里处理（使用 PlayerConfig 的默认值）
        _controller->connectToDevice(ip);
    }
}

void ShoutingManager::startMic()
{
    if (_controller) {
        _controller->checkPermissionAndStart();
    }
}

void ShoutingManager::stopMic()
{
    if (_controller) {
        _controller->stopMic();
    }
}

void ShoutingManager::sendAlarm(int index)
{
    if (!_controller) return;

    // 根据协议：1. 先切模式
    QVariantMap p;
    p["model"] = "one_key";
    _controller->sendCommand("model_change", p);

    // 2. 发送播放指令 (延时或紧跟发送)
    QVariantMap p2;
    p2["index"] = QString::number(index);
    _controller->sendCommand("one_key", p2);
}

void ShoutingManager::setVolume(int vol)
{
    if (!_controller) return;

    QVariantMap p;
    p["vol"] = QString::number(vol);
    // 注意：协议里设置音量指令是 play_vol
    _controller->sendCommand("play_vol", p);
}

// 对应 Q_PROPERTY(bool connected ...)
bool ShoutingManager::connected() const
{
    // 必须调用 controller 的 isConnected()
    return _controller && _controller->isConnected();
}

void ShoutingManager::_handleLogUpdate(QString msg)
{
    _lastLog = msg;
    emit lastLogChanged();
    // 使用 qInfo 或 qDebug 方便在 QGC 控制台查看
    qInfo() << "[ShoutingLog]: " << msg;
}

#include "ShoutingManager.h"
#include <QVariantMap>
#include <QFileInfo>

// ... 之前的构造函数和 connect 代码保持不变 ...

// 1. 实现刷新播放列表
void ShoutingManager::refreshPlayList() {
    if (_controller) {
        _controller->sendCommand("get_play_list");
    }
}

// 2. 实现路径播放 (对应协议 V2.0.5)
void ShoutingManager::playByPath(QString path) {
    if (_controller) {
        QVariantMap params;
        params["index"] = path; // 协议规定 index 可以传路径
        _controller->sendCommand("repeat_play", params);
    }
}

// 3. 实现上传文件
void ShoutingManager::uploadMp3(QString localPath) {
    if (_controller) {
        // 去掉路径前缀，只保留文件名 (Android 系统路径处理)
        _controller->uploadFile(localPath);
    }
}

// 4. 实现删除文件
void ShoutingManager::deleteMp3(QString fileName) {
    if (_controller) {
        QVariantMap params;
        params["name"] = fileName;
        _controller->sendCommand("del_mp3_file", params);

        // 删除后建议延迟刷新一下列表
        QTimer::singleShot(500, this, &ShoutingManager::refreshPlayList);
    }
}

// 5. 实现设置音量 (Q_PROPERTY 的 WRITE 函数)
void ShoutingManager::setCurrentVolume(int vol) {
    if (vol != _currentVolume) {
        _currentVolume = vol;
        if (_controller) {
            QVariantMap params;
            params["vol"] = QString::number(vol);
            _controller->sendCommand("play_vol", params);
        }
        emit currentVolumeChanged();
    }
}