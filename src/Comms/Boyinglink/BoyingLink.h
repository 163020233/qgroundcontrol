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
#include <QTimer>
#include <QDateTime>
#include <mavlink.h>
#ifdef Q_OS_ANDROID
#include <QJniObject>
#endif

struct VibrationData {
    float x;
    float y;
    float z;
    int clip[3];
};
struct RangefinderData {
    float distance;   // 米
    int status;
    int type;
};


// BoyingWorker.h 或专用头文件
enum BoyingMsgID {
    BY_MSG_ID_SYSTEM_STATUS       = 1,
    BY_MSG_ID_HEARTBEAT           = 8,  // 博盈的心跳是 8
    BY_MSG_ID_SET_MODE            = 11, //
    BY_MSG_ID_NUM_ITEM            = 15, // 身份证(SN)回传
    BY_MSG_ID_NUM_REQ             = 16, // 请求身份证
    BY_MSG_ID_PARAM_VALUE         = 22,
    BY_MSG_ID_COMMAND_LONG        = 76, // 核心指令通道
    BY_MSG_ID_STATUSTEXT          = 253
};

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
    uint16_t _lastQgcCommandId = 0; // 记录 QGC 最近一次发出的指令号
    uint8_t  _lastQgcSystemId  = 255; // 记录 QGC 的系统 ID（通常是 255）


    // --- 实时精度监控变量 ---
    float   _lastEph = 99.0f;       // 水平精度 (单位：米)，初始设为极大值表示不可靠
    int     _lastGpsCount = 0;      // 实时卫星数量记录


    int32_t _lastLat = 0;
    int32_t _lastLon = 0;


    // --- 工业安全：家点控制变量 ---
    bool    _isHomeSet = false;     // 核心标志位：确保每次开机只锁定一次家点
    int32_t _homeLat = 0;           // 存储锁定的家点纬度
    int32_t _homeLon = 0;           // 存储锁定的家点经度
    int32_t _homeAlt = 0;           // 存储锁定的家点海拔高度

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
    // uint8_t  _lastMavState    = MAV_STATE_STANDBY;
    uint8_t  _lastMavState    = 0;

    // --- [新增] 专门负责发送 UI 实时数据的辅助函数 ---
    /**
    * @brief 向 QGC 发送文字通知，显示在屏幕左下角并由语音读出
    * @param text     通知内容（支持中文，最长 50 字节）
    * @param severity 严重程度（6=INFO, 4=WARNING, 3=CRITICAL/红色报警）
    */
    void reportToUser(const QString& text, int severity = 6);

    // 将博盈原始 ID 转换为 PX4 32位模式 ID (用于心跳包上报)
    uint32_t boyingToPx4Mode(int boyingMode);

    // 将 QGC 发来的 PX4 模式 ID 转回博盈指令 ID (用于指令下发)
    int px4ToBoyingMode(uint32_t px4Mode);

    /**
     * @brief 发送 NAMED_VALUE_FLOAT 消息，用于驱动 QGC 仪表盘实时显示
     * @param sdkCommand
     * @param name  数据的名称，注意：MAVLink 限制长度最多 10 个字符 (例如 "SprayFlow")
     * @param value 具体的数值
     */
    // 发送参数值 (用于响应 QGC 的参数请求)
    void _sendMavlinkParam(const char* id, float val, uint16_t total, uint16_t index,uint8_t targetSys, uint8_t targetComp);
    void sendAutopilotVersion();
    /**
        * @brief 发送 MISSION_COUNT 消息，告诉 QGC 任务数量
        * @param count 数值，通常传 0
        * @param missionType 任务类型 (0:航点, 1:围栏, 2:集结点)
        */
    void _sendMavlinkMissionCount(int count, int type, uint8_t targetSys, uint8_t targetComp);

    // 发送指令应答 (用于告诉 QGC 指令执行结果)
    void _sendMavlinkAck(uint16_t cmdId, uint8_t result);

    uint16_t _mapSdkCommandToQgc(int sdkCommand);
    void sendNamedValue(const char* name, float value);
    void handleModePacket(const QJsonObject& obj);      // Type 0, 29
    void handlePacketAck(const QJsonObject& obj);       // Type 1
    void handleStaticInfoPacket(const QJsonObject& obj);// Type 2
    void handleGPSPacket(const QJsonObject& obj);       // Type 3, 4, 12
    void handleBatteryPacket(const QJsonObject& obj);   // Type 5
    void handleRawSensorPacket(const QJsonObject& obj); // Type 6
    void handleVibrationPacket(const QJsonObject& obj); // Type 7
    void handleHUDPacket(const QJsonObject& obj);       // Type 8
    void handleAttitudePacket(const QJsonObject& obj);  // Type 9
    void handleVersionPacket(const QJsonObject& obj);   // Type 11
    void handlePayloadPacket(const QJsonObject& obj);   // Type 14, 24, 13, 26
    void handleServoPacket(const QJsonObject& obj);     // Type 21
    void handleRCChannelsPacket(const QJsonObject& obj);// Type 22, 25
    void handleTimePacket(const QJsonObject& obj);      // Type 23
    void handleTextPacket(const QJsonObject& obj);      // Type 20
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
