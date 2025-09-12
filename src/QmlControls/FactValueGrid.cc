/****************************************************************************
 *
 * (c) 2009-2024 QGROUNDCONTROL PROJECT <http://www.qgroundcontrol.org>
 *
 * QGroundControl is licensed according to the terms in the file
 * COPYING.md in the root of the source code directory.
 *
 ****************************************************************************/

#include "FactValueGrid.h"
#include "InstrumentValueData.h"
#include "QGCApplication.h"
#include "QGCCorePlugin.h"
#include "MultiVehicleManager.h"
#include "Vehicle.h"

#include <QtCore/QSettings>
#include <QtCore/QDir>

QStringList FactValueGrid::_iconNames;

// Important: The indices of these strings must match the FactValueGrid::FontSize enum
const QStringList FactValueGrid::_fontSizeNames = {
    QT_TRANSLATE_NOOP("FactValueGrid", "Default"),
    QT_TRANSLATE_NOOP("FactValueGrid", "Small"),
    QT_TRANSLATE_NOOP("FactValueGrid", "Medium"),
    QT_TRANSLATE_NOOP("FactValueGrid", "Large"),
};

QList<FactValueGrid*> FactValueGrid::_vehicleCardInstanceList;

FactValueGrid::FactValueGrid(QQuickItem* parent)
    : QQuickItem(parent)
    , _columns  (new QmlObjectListModel(this))
{
    if (_iconNames.isEmpty()) {
        QDir iconDir(":/InstrumentValueIcons/");
        _iconNames = iconDir.entryList();
    }
}

void FactValueGrid::componentComplete(void)
{
    QQuickItem::componentComplete();

    connect(this, &FactValueGrid::fontSizeChanged, this, &FactValueGrid::_saveSettings);

    if (_specificVehicleForCard) {
        _vehicleCardInstanceList.append(this);
        _initForNewVehicle(_specificVehicleForCard);
    } else {
        // We are not tracking a specific vehicle so we need to track the active vehicle or offline editing vehicle if not active vehicle
        auto multiVehicleManager = MultiVehicleManager::instance();
        connect(multiVehicleManager, &MultiVehicleManager::activeVehicleChanged, this, &FactValueGrid::_activeVehicleChanged);
        _activeVehicle = multiVehicleManager->activeVehicle();
        if (!_activeVehicle) {
            _activeVehicle = multiVehicleManager->offlineEditingVehicle();
        }
        _initForNewVehicle(_activeVehicle);
    }
}

void FactValueGrid::_initForNewVehicle(Vehicle* vehicle)
{
    if (!vehicle) {
        qCritical() << "FactValueGrid::_initForNewVehicle: vehicle is NULL";
        return;
    }

    connect(vehicle, &Vehicle::vehicleTypeChanged, this, &FactValueGrid::_resetFromSettings);
    _resetFromSettings();
}

void FactValueGrid::_deinitVehicle(Vehicle* vehicle)
{
    disconnect(vehicle, &Vehicle::vehicleTypeChanged, this, &FactValueGrid::_resetFromSettings);
}

void FactValueGrid::_activeVehicleChanged(Vehicle* activeVehicle)
{
    if (!_activeVehicle) {
        qCritical() << "FactValueGrid::_activeVehicleChanged: _activeVehicle is NULL";
    }

    if (_activeVehicle) {
        _deinitVehicle(_activeVehicle);
        _activeVehicle = nullptr;
    }

    if (!activeVehicle) {
        activeVehicle = MultiVehicleManager::instance()->offlineEditingVehicle();
    }
    _activeVehicle = activeVehicle;
    _initForNewVehicle(activeVehicle);
}

FactValueGrid::~FactValueGrid() 
{
    _vehicleCardInstanceList.removeAll(this);
}

QGCMAVLink::VehicleClass_t FactValueGrid::vehicleClass(void) const 
{
    return QGCMAVLink::vehicleClass(currentVehicle()->vehicleType());
}

void FactValueGrid::resetToDefaults(void)
{
    QSettings settings;
    settings.remove(_settingsGroup);
    _resetFromSettings();
}

QString FactValueGrid::_pascalCase(const QString& text)
{
    return text[0].toUpper() + text.right(text.length() - 1);
}

void FactValueGrid::setFontSize(FontSize fontSize)
{
    if (fontSize != _fontSize) {
        _fontSize = fontSize;
        emit fontSizeChanged(fontSize);
    }
}

void FactValueGrid::_saveValueData(QSettings& settings, InstrumentValueData* value)
{
    settings.setValue(_textKey,         value->text());
    settings.setValue(_showUnitsKey,    value->showUnits());
    settings.setValue(_iconKey,         value->icon());
    settings.setValue(_rangeTypeKey,    value->rangeType());

    if (value->rangeType() != InstrumentValueData::NoRangeInfo) {
        settings.setValue(_rangeValuesKey, value->rangeValues());
    }

    switch (value->rangeType()) {
    case InstrumentValueData::NoRangeInfo:
        break;
    case InstrumentValueData::ColorRange:
        settings.setValue(_rangeColorsKey,      value->rangeColors());
        break;
    case InstrumentValueData::OpacityRange:
        settings.setValue(_rangeOpacitiesKey,   value->rangeOpacities());
        break;
    case InstrumentValueData::IconSelectRange:
        settings.setValue(_rangeIconsKey,       value->rangeIcons());
        break;
    }

    settings.setValue(_factGroupNameKey,    value->factGroupName());
    settings.setValue(_factNameKey,         value->factName());
}

void FactValueGrid::_loadValueData(QSettings& settings, InstrumentValueData* value)
{
    QString factName = settings.value(_factNameKey).toString();
    if (!factName.isEmpty()) {
        value->setFact(settings.value(_factGroupNameKey).toString(), factName);
    }

    value->setText      (settings.value(_textKey).toString());
    value->setShowUnits (settings.value(_showUnitsKey, true).toBool());
    value->setIcon      (settings.value(_iconKey).toString());
    value->setRangeType (settings.value(_rangeTypeKey, InstrumentValueData::NoRangeInfo).value<InstrumentValueData::RangeType>());

    if (value->rangeType() != InstrumentValueData::NoRangeInfo) {
        value->setRangeValues(settings.value(_rangeValuesKey).value<QVariantList>());
    }
    switch (value->rangeType()) {
    case InstrumentValueData::NoRangeInfo:
        break;
    case InstrumentValueData::ColorRange:
        value->setRangeColors(settings.value(_rangeColorsKey).value<QVariantList>());
        break;
    case InstrumentValueData::OpacityRange:
        value->setRangeOpacities(settings.value(_rangeOpacitiesKey).value<QVariantList>());
        break;
    case InstrumentValueData::IconSelectRange:
        value->setRangeIcons(settings.value(_rangeIconsKey).value<QVariantList>());
        break;
    }
}

void FactValueGrid::_connectSaveSignals(InstrumentValueData* value)
{
    connect(value, &InstrumentValueData::factNameChanged,       this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::factGroupNameChanged,  this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::textChanged,           this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::showUnitsChanged,      this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::iconChanged,           this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::rangeTypeChanged,      this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::rangeValuesChanged,    this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::rangeColorsChanged,    this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::rangeOpacitiesChanged, this, &FactValueGrid::_saveSettings);
    connect(value, &InstrumentValueData::rangeIconsChanged,     this, &FactValueGrid::_saveSettings);
}

void FactValueGrid::appendRow(void)
{
    for (int colIndex=0; colIndex<_columns->count(); colIndex++) {
        QmlObjectListModel* list = _columns->value<QmlObjectListModel*>(colIndex);
        list->append(_createNewInstrumentValueWorker(list));

    }
    _rowCount++;
    emit rowCountChanged(_rowCount);
    _saveSettings();
}

void FactValueGrid::deleteLastRow(void)
{
    if (_rowCount <= 1) {
        return;
    }
    for (int colIndex=0; colIndex<_columns->count(); colIndex++) {
        QmlObjectListModel* list = _columns->value<QmlObjectListModel*>(colIndex);
        list->removeAt(list->count() - 1)->deleteLater();
    }
    _rowCount--;
    emit rowCountChanged(_rowCount);
    _saveSettings();
}

QmlObjectListModel* FactValueGrid::appendColumn(void)
{
    QmlObjectListModel* newList = new QmlObjectListModel(_columns);
    _columns->append(newList);

    // If this is the first row then we automatically add the first column as well
    int cRowsToAdd = qMax(_rowCount, 1);
    for (int i=0; i<cRowsToAdd; i++) {
        newList->append(_createNewInstrumentValueWorker(newList));
    }

    if (cRowsToAdd != _rowCount) {
        _rowCount = cRowsToAdd;
        emit rowCountChanged(_rowCount);
    }

    _saveSettings();

    return newList;
}

void FactValueGrid::deleteLastColumn(void)
{
    if (_columns->count() > 1) {
        _columns->removeAt(_columns->count() - 1)->deleteLater();
        _saveSettings();
    }
}

InstrumentValueData* FactValueGrid::_createNewInstrumentValueWorker(QObject* parent)
{
    // 创建一个新的数据展示单元，用来绑定某个 Fact（飞行器参数/状态）
    InstrumentValueData* value = new InstrumentValueData(this, parent);
    // 设置它要绑定的 Fact（这里绑定的是 "AltitudeRelative" 相对高度）
    // vehicleFactGroupName 表示这个 Fact 是来自 Vehicle 的 FactGroup
    value->setFact(InstrumentValueData::vehicleFactGroupName, "AltitudeRelative");
    // 设置显示的文字（用 Fact 的 shortDescription）
    value->setText(value->fact()->shortDescription());
    // 连接保存/更新信号，保证 UI 跟 Fact 值同步
    _connectSaveSignals(value);
    // 返回这个 InstrumentValueData
    return value;

}

void FactValueGrid::_saveSettings(void)
{
    if (_preventSaveSettings) {
        return;
    }

    QSettings   settings;
    QString     groupNameFormat("%1-%2");

    settings.beginGroup(_settingsKey());
    settings.remove(""); // Remove any previous settings

    settings.setValue(_versionKey,  1);
    settings.setValue(_fontSizeKey, _fontSize);
    settings.setValue(_rowCountKey, _rowCount);

    settings.beginWriteArray(_columnsKey);
    for (int colIndex=0; colIndex<_columns->count(); colIndex++) {
        QmlObjectListModel* columns = _columns->value<QmlObjectListModel*>(colIndex);

        settings.setArrayIndex(colIndex);
        settings.beginWriteArray(_rowsKey);

        for (int colIndex=0; colIndex<columns->count(); colIndex++) {
            InstrumentValueData* value = columns->value<InstrumentValueData*>(colIndex);
            settings.setArrayIndex(colIndex);
            _saveValueData(settings, value);
        }

        settings.endArray();
    }
    settings.endArray();

    // If this settings change was set from a Vehicle card, this makes so the changes are
    // immediately applied to the other Vehicle cards.
    if (_specificVehicleForCard) {
        for (FactValueGrid* obj : _vehicleCardInstanceList) {
            if (obj != this) {
                obj->_resetFromSettings();
            }
        }
    }
}

QString FactValueGrid::_settingsKey(void)
{
    return QStringLiteral("%1-%2").arg(_settingsGroup).arg(vehicleClass());
}

void FactValueGrid::_resetFromSettings(void)
{
    _preventSaveSettings = true;

    _columns->deleteLater();

    _columns    = new QmlObjectListModel(this);
    _rowCount   = 0;

    QSettings   settings;
    QString     groupNameFormat("%1-%2");

    if (settings.childGroups().contains(_settingsKey())) {
        // Load from settings
        settings.beginGroup(_settingsKey());

        int version = settings.value(_versionKey, 0).toInt();
        if (version != 1) {
            qgcApp()->showAppMessage(tr("Settings version %1 for %2 is not supported. Setup will be reset to defaults.").arg(version).arg(_settingsGroup), tr("Load Settings"));
            settings.remove("");
            QGCCorePlugin::instance()->factValueGridCreateDefaultSettings(this);
        }
        _fontSize = settings.value(_fontSizeKey, DefaultFontSize).value<FontSize>();
    
        // Initial setup of empty items
        int cRows       = settings.value(_rowCountKey).toInt();
        int cModelLists = settings.beginReadArray(_columnsKey);
        if (cModelLists && cRows) {
            appendColumn();
            for (int rowIndex=1; rowIndex<cRows; rowIndex++) {
                appendRow();
            }
            for (int colIndex=1; colIndex<cModelLists; colIndex++) {
                appendColumn();
            }
        }
    
        // Fill in the items from settings
        for (int colIndex=0; colIndex<cModelLists; colIndex++) {
            settings.setArrayIndex(colIndex);
            int cItems = settings.beginReadArray(_rowsKey);
            for (int itemIndex=0; itemIndex<cItems; itemIndex++) {
                QmlObjectListModel* list = _columns->value<QmlObjectListModel*>(colIndex);
                InstrumentValueData* value = list->value<InstrumentValueData*>(itemIndex);
                settings.setArrayIndex(itemIndex);
                _loadValueData(settings, value);
            }
            settings.endArray();
        }
        settings.endArray();
    } else {
        // Default settings are added directly to this FactValueGrid
        QGCCorePlugin::instance()->factValueGridCreateDefaultSettings(this);
    }

    emit columnsChanged(_columns);

    _preventSaveSettings = false;
}


// 优化布局函数，4x3 最大布局行4，列3
static QList<std::pair<int,int>> optimizeLayout(int totalCount, const int maxRow = 4, const int maxCol = 3)
{
    QList<std::pair<int,int>> positions;

    if (totalCount > maxRow * maxCol) {
        qWarning() << "Item count exceeds maximum allowed (12)";
        totalCount = maxRow * maxCol; // 超过12个只显示前12个
    }

    int rowCount = qMin(totalCount, maxRow);                       // 行数 ≤ maxRow
    int colCount = (totalCount + rowCount - 1) / rowCount;         // 向上取整保证行优先

    int index = 0;
    for (int r = 0; r < rowCount; ++r) {
        for (int c = 0; c < colCount; ++c) {
            if (index >= totalCount) break;
            positions.append(std::make_pair(r, c));
            index++;
        }
    }

    qDebug() << "New layout positions:" << positions;
    return positions;
}

void FactValueGrid::removeDuplicates()
{
    QSet<QString> seenFacts;

    for (int i = _columns->count() - 1; i >= 0; --i) {
        QmlObjectListModel* model = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!model) continue;

        for (int j = model->count() - 1; j >= 0; --j) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(model->get(j));
            if (!val) continue;

            QString name = val->factName();
            if (seenFacts.contains(name)) {
                model->removeAt(j);
                qWarning() << "Removed duplicate fact:" << name << "at row" << i << "index" << j;
            } else {
                seenFacts.insert(name);
            }
        }
    }
}

// === 删除数据并自动优化布局 ===
void FactValueGrid::removeFactByName(const QString &factName)
{
    // 1. 删除匹配的数据
    for (int i = _columns->count() - 1; i >= 0; --i) {
        QmlObjectListModel* model = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!model) continue;

        for (int j = model->count() - 1; j >= 0; --j) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(model->get(j));
            if (!val) continue;

            qDebug() << "Checking" << j
                     << "factName:" << val->factName()
                     << "text:" << val->text();

            if (val->factName() == factName) {
                model->removeAt(j);
                qDebug() << "Removed fact" << factName << "at model" << i << "index" << j;
            }
        }
    }

    // 2. 删除重复数据，保留每个 factName 的第一个
    removeDuplicates();

    // 3. 收集所有数据（最多12个）
    QList<InstrumentValueData*> allFacts;
    for (int i = 0; i < _columns->count(); ++i) {
        QmlObjectListModel* model = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!model) continue;

        for (int j = 0; j < model->count() && allFacts.size() < 12; ++j) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(model->get(j));
            if (val) allFacts.append(val);
        }
    }

    // 3. 获取新的紧凑布局坐标
    QList<std::pair<int,int>> newLayout = optimizeLayout(allFacts.size());

    // 4. 清空原 _columns
    _columns->clear();

    // 5. 按行重新生成模型，每行一个 QmlObjectListModel
    int currentRow = -1;
    QmlObjectListModel* rowModel = nullptr;
    for (int i = 0; i < allFacts.size(); ++i) {
        if (i >= newLayout.size()) break; // 安全保护
        int row = newLayout[i].first;

        if (row != currentRow) {
            rowModel = new QmlObjectListModel(this);
            _columns->append(rowModel);
            currentRow = row;
        }
        rowModel->append(allFacts[i]);
    }

    qDebug() << "Layout rearranged. Total rows:" << _columns->count();
}


// 优化布局函数
// static QList<std::pair<int,int>> optimizeLayout(int totalCount, const int maxRow = 4, const int maxCol = 3)
// {
//     // const int maxRow = 4;
//     // const int maxCol = 3;
//     QList<std::pair<int,int>> positions;
//
//     if (totalCount > maxRow * maxCol) {
//         qWarning() << "Item count exceeds maximum allowed (12)";
//         return positions;
//     }
//
//     int colCount = qMin(totalCount, maxCol);       // 列数 ≤ 3
//     int rowCount = (totalCount + colCount - 1) / colCount; // ceil(N / colCount)
//
//     // 生成紧凑坐标
//     int index = 0;
//     for (int r = 0; r < rowCount; ++r) {
//         for (int c = 0; c < colCount; ++c) {
//             if (index >= totalCount) break;
//             positions.append(std::make_pair(r, c));
//             index++;
//         }
//     }
//
//     qDebug() << "New layout positions:" << positions;
//     return positions;
// }
//
// void FactValueGrid::removeFactByName(const QString &factName)
// {
//     for (int i = _columns->count() - 1; i >= 0; --i) {
//         QmlObjectListModel* model = qobject_cast<QmlObjectListModel*>(_columns->get(i));
//         if (!model) continue;
//
//         for (int j = model->count() - 1; j >= 0; --j) {
//             InstrumentValueData* val = qobject_cast<InstrumentValueData*>(model->get(j));
//             if (!val) continue;
//             qDebug() << "Checking" << j
//                      << "factName:" << val->factName()
//                      << "text:" << val->text();
//
//             if (val->factName() == factName) {
//                 model->removeAt(j);
//                 qDebug() << "Removed fact" << factName << "at model" << i << "index" << j;
//             }
//         }
//     }
//
//     // === 自动调整布局 ===
//     int totalFacts = 0;
//     for (int i = 0; i < _columns->count(); ++i) {
//         QmlObjectListModel* model = qobject_cast<QmlObjectListModel*>(_columns->get(i));
//         if (model) totalFacts += model->count();
//     }
//
//     QList<std::pair<int,int>> newLayout = optimizeLayout(totalFacts);
//     qDebug() << "New layout positions:" << newLayout;
//     // TODO: 根据 newLayout 实际重新排列 _columns 中的模型
//
// }





