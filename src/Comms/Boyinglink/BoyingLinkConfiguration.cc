//
// Created by Administrator on 25-11-26.
//

#include "BoyingLinkConfiguration.h"

//Boying 配置
// 1. 构造函数
// ★★★ 修正：必须初始化 _highLatency，否则它是个随机值 ★★★
BoyingLinkConfiguration::BoyingLinkConfiguration(const QString& name)
    : LinkConfiguration(name)
    , _highLatency(false)  // 默认关闭高延迟模式
{
}

// 2. 拷贝构造函数
// ★★★ 修正：当克隆对象时，也要拷贝 _highLatency 的值 ★★★
BoyingLinkConfiguration::BoyingLinkConfiguration(const BoyingLinkConfiguration* copy)
    : LinkConfiguration(copy)
    , _highLatency(copy->_highLatency)
{
}

// 3. 复制函数 (用于编辑配置时的临时对象复制)
void BoyingLinkConfiguration::copyFrom(const LinkConfiguration* source)
{
    LinkConfiguration::copyFrom(source);

    // ★★★ 修正：尝试将源对象转为 Boying 类型，并复制属性 ★★★
    const BoyingLinkConfiguration* boyingSource = qobject_cast<const BoyingLinkConfiguration*>(source);
    if (boyingSource) {
        setHighLatency(boyingSource->isHighLatency());
    }
}

// 4. 保存设置 (写入磁盘/注册表)
void BoyingLinkConfiguration::saveSettings(QSettings& settings, const QString& root) const
{
    settings.beginGroup(root);

    // ★★★ 修正：保存你的配置项 ★★★
    // 这里的字符串 "HighLatency" 就是存在磁盘里的 Key
    settings.setValue("HighLatency", _highLatency);

    settings.endGroup();
}

// 5. 读取设置 (从磁盘/注册表加载)
void BoyingLinkConfiguration::loadSettings(QSettings& settings, const QString& root)
{
    settings.beginGroup(root);

    // ★★★ 修正：读取配置项，如果读不到则默认为 false ★★★
    _highLatency = settings.value("HighLatency", false).toBool();

    settings.endGroup();
}

// 6. 返回连接类型
LinkConfiguration::LinkType BoyingLinkConfiguration::type(void) const
{
    return LinkConfiguration::TypeBoying;
}

// 7. 返回设置页面的 QML 文件名
QString BoyingLinkConfiguration::settingsURL(void) const
{
    qDebug() << " QGC 正在请求 Boying 设置页面 URL"; // 加这一行
    return "BoyingLinkSettings.qml";
}

// 8. 返回设置页面在左侧列表中显示的标题
QString BoyingLinkConfiguration::settingsTitle(void) const
{
    return tr("Boying SDK");
}