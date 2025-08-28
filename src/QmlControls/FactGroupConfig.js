// FactGroupConfig.js
// 常用仪表盘 FactGroup 配置
// 每个 FactGroup 对应常用参数及中文显示标签

const factGroupConfig = {
    "vehicle": [
        { name: "roll", label: "横滚角" },
        { name: "pitch", label: "俯仰角" },
        { name: "heading", label: "航向" },
        { name: "rollRate", label: "横滚角速度" },
        { name: "pitchRate", label: "俯仰角速度" },
        { name: "yawRate", label: "偏航角速度" },
        { name: "groundSpeed", label: "地速" },
        { name: "airSpeed", label: "空速" },
        { name: "climbRate", label: "爬升率" },
        { name: "altitudeRelative", label: "相对高度" },
        { name: "altitudeAMSL", label: "海拔高度" }
    ],

    "gps": [
        { name: "lat", label: "纬度" },
        { name: "lon", label: "经度" },
        { name: "mgrs", label: "MGRS坐标" },
        { name: "hdop", label: "水平精度HDOP" },
        { name: "vdop", label: "垂直精度VDOP" },
        { name: "courseOverGround", label: "地面航向" },
        { name: "lock", label: "GPS锁定状态" },
        { name: "count", label: "卫星数量" }
    ],

    "gps2": [
        { name: "lat", label: "纬度2" },
        { name: "lon", label: "经度2" },
        { name: "hdop", label: "水平精度HDOP2" },
        { name: "vdop", label: "垂直精度VDOP2" }
    ],

    "wind": [
        { name: "speed", label: "风速" },
        { name: "direction", label: "风向" }
    ],

    "vibration": [
        { name: "x", label: "X轴振动" },
        { name: "y", label: "Y轴振动" },
        { name: "z", label: "Z轴振动" }
    ],

    "temperature": [
        { name: "temperature1", label: "温度1" },
        { name: "temperature2", label: "温度2" },
        { name: "temperature3", label: "温度3" }
    ],

    "clock": [
        { name: "timeUTC", label: "UTC时间" },
        { name: "timeLocal", label: "本地时间" }
    ],

    "setpoint": [
        { name: "altitudeSetpoint", label: "高度设定点" },
        { name: "speedSetpoint", label: "速度设定点" }
    ],

    "escStatus": [
        { name: "motor1", label: "电机1状态" },
        { name: "motor2", label: "电机2状态" }
    ],

    "estimatorStatus": [
        { name: "attitudeVariance", label: "姿态方差" },
        { name: "positionVariance", label: "位置方差" }
    ],

    "terrain": [
        { name: "distance", label: "地形距离" },
        { name: "altitude", label: "地形高度" }
    ],

    "distanceSensors": [
        { name: "front", label: "前方传感器" },
        { name: "back", label: "后方传感器" },
        { name: "left", label: "左侧传感器" },
        { name: "right", label: "右侧传感器" }
    ],

    "localPosition": [
        { name: "x", label: "本地X" },
        { name: "y", label: "本地Y" },
        { name: "z", label: "本地Z" }
    ],

    "localPositionSet": [
        { name: "xSetpoint", label: "X设定点" },
        { name: "ySetpoint", label: "Y设定点" },
        { name: "zSetpoint", label: "Z设定点" }
    ],

    "hygrometer": [
        { name: "humidity", label: "湿度" }
    ],

    "generator": [
        { name: "voltage", label: "发电机电压" },
        { name: "current", label: "发电机电流" }
    ],

    "efi": [
        { name: "rpm", label: "发动机转速" },
        { name: "throttle", label: "节气门" }
    ],

    "batteries": [
        { name: "voltage", label: "电池电压" },
        { name: "current", label: "电池电流" },
        { name: "remaining", label: "剩余电量" }
    ],

    "actuators": [
        { name: "servo1", label: "舵机1" },
        { name: "servo2", label: "舵机2" },
        { name: "motor1", label: "电机1" }
    ]
}
