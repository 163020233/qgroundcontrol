//
// Created by Administrator on 25-11-26.
//

#ifndef BOYINGLINKCONFIGURATION_H
#define BOYINGLINKCONFIGURATION_H

#pragma once

#include "LinkConfiguration.h"

class BoyingLinkConfiguration : public LinkConfiguration
{
    Q_OBJECT

    // Q_PROPERTY 声明：允许 QML 访问 highLatency 属性
    Q_PROPERTY(bool highLatency READ isHighLatency WRITE setHighLatency NOTIFY highLatencyChanged)

public:
    BoyingLinkConfiguration(const QString& name);
    BoyingLinkConfiguration(const BoyingLinkConfiguration* copy);

    // =============================================================
    // 标准虚函数重写
    // =============================================================
    LinkType type(void) const override;
    void saveSettings(QSettings& settings, const QString& root) const override;
    void loadSettings(QSettings& settings, const QString& root) override;
    void copyFrom(const LinkConfiguration* source) override;
    QString settingsURL(void) const override;
    QString settingsTitle(void) const override;

    // =============================================================
    // ★★★ 新增：属性访问函数 (对应 Q_PROPERTY) ★★★
    // =============================================================
    bool isHighLatency(void) const { return _highLatency; }

    void setHighLatency(bool highLatency) {
        if (_highLatency != highLatency) {
            _highLatency = highLatency;
            emit highLatencyChanged(); // 通知 QML 界面刷新
        }
    }

    signals:
        // ★★★ 新增：信号定义 ★★★
        void highLatencyChanged(void);

private:
    // ★★★ 新增：私有变量存储 ★★★
    bool _highLatency;
};

#endif // BOYINGLINKCONFIGURATION_H