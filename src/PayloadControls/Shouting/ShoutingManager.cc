#include "ShoutingManager.h"

#include <QDebug>
#include <QJsonArray>

#include "ShoutingManager.h"
#include <QVariantMap>
#include <QFileInfo>

ShoutingManager::ShoutingManager(QObject *parent)
    : QObject(parent)
{
    _controller = new ShoutingController(this);

    // 1. 基础信号 (没有参数，所以可以写空括号)
    connect(_controller, &ShoutingController::connectionChanged, this, [this](bool connected){
      // 当底层发出连接改变信号时，通知 QML
      emit connectedChanged();
      if (!connected) {
          _lastLog = "未连接成功：请检查链路";
          emit lastLogChanged();
        }
    });


    // 2. 播放列表信号 (必须带 QVariantList 参数)
    connect(_controller, &ShoutingController::playListParsed, this, [this](QVariantList list){
        _playList = list;          // 将收到的数据存入成员变量
        // 2. 【核心点】手动覆盖日志文字，否则它会一直显示“正在重载...”
        _lastLog = QString("同步完成：发现 %1 个文件").arg(list.size());

        // 3. 【最关键】发出通知信号，没有这两行，QML 就不会刷新界面
        emit playListChanged();
        emit lastLogChanged();
    });

    // 3. 音量更新信号 (必须带 int 参数)
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
    _controller->sendCommand("model_change",{{"model","one_key"}});
    QVariantMap p;
    p["index"] = "/xmedia/onekey/alarm.mp3";
    _controller->sendCommand("one_key",p);
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


// 1. 实现刷新播放列表
void ShoutingManager::refreshPlayList() {
    if (_controller) {
        // _controller->sendCommand("get_play_list");
        _controller->forceRefreshPlayerMode();
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

// 1. 播放指定索引
void ShoutingManager::playIndex(int index) {
    if (_controller) {
        QVariantMap p;
        p["index"] = QString::number(index);
        _controller->sendCommand("start_play", p);
    }
}

// 2. 停止播放
void ShoutingManager::stopPlayer() {
    if (_controller) {
        _controller->sendCommand("stop_play");
    }
}

// 3. 下一首 / 上一首
void ShoutingManager::nextSong() {
    if (_controller) _controller->sendCommand("next_play");
}

void ShoutingManager::previousSong() {
    if (_controller) _controller->sendCommand("pre_play");
}

// 4. 路径播放 (支持 V2.0.5 协议)
void ShoutingManager::repeatPath(QString path) {
    if (_controller) {
        QVariantMap p;
        p["index"] = path;
        _controller->sendCommand("repeat_play", p);
    }
}

// 5. 文件上传 (带自动刷新)
void ShoutingManager::uploadMp3(QString localPath) {
    if (_controller) {
        _controller->uploadFile(localPath);
        // 上传后延迟 1.5 秒刷新列表，给硬件写入时间
        QTimer::singleShot(1500, this, &ShoutingManager::refreshPlayList);
    }
}

// 6. 删除文件
void ShoutingManager::deleteMp3(QString fileNameOrPath) {
    if (!_controller) return;

            // 1. 路径处理逻辑：
            // 如果传进来的是 "/xmedia/mp3/disarm.mp3"
            // 我们需要提取出最后一部分 "disarm.mp3"
    QString nameOnly = fileNameOrPath;
    if (nameOnly.contains("/")) {
        nameOnly = nameOnly.section('/', -1);
    }

    qDebug() << "准备删除文件，原始路径:" << fileNameOrPath << " 提取文件名:" << nameOnly;

            // 2. 构造指令
    QVariantMap p;
    p["name"] = nameOnly;
    _controller->sendCommand("del_mp3_file", p);

            // 3. 核心：协议要求删除后必须 reload 列表才会更新
            // 延迟 1 秒执行强制刷新，给硬件物理删除预留时间
    QTimer::singleShot(1000, _controller, &ShoutingController::forceRefreshPlayerMode);

    _handleLogUpdate("正在请求删除文件: " + nameOnly);
}
