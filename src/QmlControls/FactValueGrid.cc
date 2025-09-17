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
    // 最大行数限制
    if (_rowCount >= 4) {
        qDebug() << "已达到最大行数，无法添加新行";
        return;
    }

    // 遍历每列，向每个列的 QmlObjectListModel 添加新元素
    for (int colIndex = 0; colIndex < _columns->count(); colIndex++) {
        QmlObjectListModel* list = _columns->value<QmlObjectListModel*>(colIndex);
        if (list) {
            list->append(_createNewInstrumentValueWorker(list));
        }
    }

    // 更新行数
    _rowCount++;
    emit rowCountChanged(_rowCount);

    // _saveSettings();
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
    // _saveSettings();
}

QmlObjectListModel* FactValueGrid::appendColumn(void)
{
    if (_columns->count() >= 3)  // 最大列数3
        return nullptr;

    QmlObjectListModel* newList = new QmlObjectListModel(_columns);
    _columns->append(newList);

    int cRowsToAdd = qMax(_rowCount, 1);
    if (cRowsToAdd > 4)  // 最大行数4
        cRowsToAdd = 4;

    for (int i=0; i<cRowsToAdd; i++) {
        newList->append(_createNewInstrumentValueWorker(newList));
    }

    if (cRowsToAdd != _rowCount) {
        _rowCount = cRowsToAdd;
        emit rowCountChanged(_rowCount);
    }

    // _saveSettings();
    return newList;
}

void FactValueGrid::deleteLastColumn(void)
{
    if (_columns->count() > 1) {
        _columns->removeAt(_columns->count() - 1)->deleteLater();
        // _saveSettings();
    }
}

InstrumentValueData* FactValueGrid::_createNewInstrumentValueWorker(QObject* parent)
{
    // 创建一个新的 InstrumentValueData，用来显示某个飞控参数
    InstrumentValueData* value = new InstrumentValueData(this, parent);

    // 默认要绑定的参数名
    QString factName = _nextFactToAdd.isEmpty() ? "airSpeed" : _nextFactToAdd;
    _nextFactToAdd.clear();

    QString groupName = InstrumentValueData::vehicleFactGroupName; // 默认所属 FactGroup
    // --- 新增条件判断，如果是经纬度就用 gps group ---
    if (factName == "lon" || factName == "lat") {
        groupName = InstrumentValueData::gpsFactGroupName;
    }

    QString displayName = factName; // 默认显示名称

    // 直接从 Vehicle 获取对应的 FactGroup
    Fact* fact = nullptr;
    if (_activeVehicle) {
        FactGroup* fg = _activeVehicle->getFactGroup(groupName);
        if (fg) {
            fact = fg->getFact(factName); // 获取单个 Fact
            if (!fact) {
                qWarning() << "在 FactGroup 中未找到对应 Fact:" << groupName << factName;
            }
        } else {
            qWarning() << "未找到对应的 FactGroup:" << groupName;
        }
    }

    // 使用双参数的 setFact 来绑定 Fact，保证单位可以正常显示
    value->setFact(groupName, factName);

    // 设置显示文字：如果找到 Fact，就用 Fact 的 shortDescription，否则显示参数名
    value->setText(fact ? fact->shortDescription() : displayName);

    // 设置是否显示单位：找到了 Fact 就显示单位，找不到就不显示
    value->setShowUnits(fact != nullptr);

    // 连接信号，保证 UI 可以跟随 Fact 值变化
    _connectSaveSignals(value);

    return value;
}

// InstrumentValueData* FactValueGrid::_createNewInstrumentValueWorker(QObject* parent)
// {
//     // 创建一个新的数据展示单元，用来绑定某个 Fact（飞行器参数/状态）
//     InstrumentValueData* value = new InstrumentValueData(this, parent);
//     // 设置它要绑定的 Fact（这里绑定的是 "AltitudeRelative" 相对高度）
//     // vehicleFactGroupName 表示这个 Fact 是来自 Vehicle 的 FactGroup
//     value->setFact(InstrumentValueData::vehicleFactGroupName, "airSpeed");
//     // 设置显示的文字（用 Fact 的 shortDescription）
//     value->setText(value->fact()->shortDescription());
//     // 连接保存/更新信号，保证 UI 跟 Fact 值同步
//     _connectSaveSignals(value);
//     // 返回这个 InstrumentValueData
//     return value;
//
// }

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
    if (factName.isEmpty()) return;

    // 1. 删除匹配的数据
    bool removed = false;
    for (int col = 0; col < _columns->count(); ++col) {
        QmlObjectListModel* colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
        if (!colModel) continue;

        for (int row = colModel->count() - 1; row >= 0; --row) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(colModel->get(row));
            if (val && val->factName() == factName) {
                colModel->removeAt(row);
                removed = true;
            }
        }
    }

    if (!removed) return; // 如果没删除，不做排序

    // 2. 判断是否需要重新排序
    bool needReorder = false;
    int maxRows = 0;
    for (int col = 0; col < _columns->count(); ++col) {
        QmlObjectListModel* colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
        if (!colModel) continue;

        if (colModel->count() > maxRows)
            maxRows = colModel->count();

        // 检查是否存在空洞或乱序
        for (int i = 0; i < colModel->count(); ++i) {
            if (!colModel->get(i)) {
                needReorder = true;
                break;
            }
        }
        if (needReorder) break;
    }

    // 3. 如果需要，按行优先重新填充
    if (needReorder) {
        QList<InstrumentValueData*> allFacts;
        for (int col = 0; col < _columns->count(); ++col) {
            QmlObjectListModel* colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
            if (!colModel) continue;
            for (int i = 0; i < colModel->count(); ++i) {
                InstrumentValueData* val = qobject_cast<InstrumentValueData*>(colModel->get(i));
                if (val) allFacts.append(val);
            }
        }

        _columns->clear();
        int index = 0;
        const int maxCols = 3; // 最大列数
        for (int row = 0; row < maxRows && index < allFacts.size(); ++row) {
            for (int col = 0; col < maxCols && index < allFacts.size(); ++col) {
                QmlObjectListModel* colModel = nullptr;
                if (col < _columns->count()) {
                    colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
                } else {
                    colModel = new QmlObjectListModel(this);
                    _columns->append(colModel);
                }
                colModel->append(allFacts[index++]);
            }
        }
    }

    // 4. 更新行列数
    _rowCount = 0;
    for (int col = 0; col < _columns->count(); ++col) {
        QmlObjectListModel* colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
        if (colModel && colModel->count() > _rowCount)
            _rowCount = colModel->count();
    }

    emit rowCountChanged(_rowCount);
    emit columnCountChanged(_columns->count());
    emit factsChanged();
    _saveSettings();
}





QStringList FactValueGrid::facts() const {
    QStringList list;
    for (int i = 0; i < _columns->count(); i++) {
        QmlObjectListModel* col = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!col) continue;

        for (int j = 0; j < col->count(); j++) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(col->get(j));
            if (val)
                list.append(val->factName());
        }
    }
    return list;
}

void FactValueGrid::appendFact(const QString& factName)
{
    if (factName.isEmpty()) return;

    QStringList existingFacts = facts();
    if (existingFacts.contains(factName)) return;  // 已存在则跳过
    if (existingFacts.size() >= 12) {              // 最大12个
        qWarning() << "仪表盘最多只能添加 12 个参数，忽略:" << factName;
        return;
    }

    _nextFactToAdd = factName;
    InstrumentValueData* value = _createNewInstrumentValueWorker(this);

    bool added = false;

    // 行优先遍历
    for (int row = 0; row < 4 && !added; ++row) {          // 最大4行
        for (int col = 0; col < _columns->count(); ++col) { // 遍历已有列
            QmlObjectListModel* colModel = qobject_cast<QmlObjectListModel*>(_columns->get(col));
            if (!colModel) continue;

            // 如果当前列第 row 行为空，则添加
            if (colModel->count() <= row) {
                colModel->append(value);
                added = true;
                break;
            }
        }

        // 如果当前行所有列都满了，但列数未达到最大（3列），则新建列添加
        if (!added && _columns->count() < 3) {
            QmlObjectListModel* newCol = new QmlObjectListModel(this);
            newCol->append(value);
            _columns->append(newCol);
            added = true;
            break;
        }
    }

    if (!added) {
        qWarning() << "所有格子已满，无法添加:" << factName;
        return;
    }

    // 更新行数
    _rowCount = 0;
    for (int i = 0; i < _columns->count(); ++i) {
        QmlObjectListModel* col = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (col && col->count() > _rowCount)
            _rowCount = col->count();
    }

    emit rowCountChanged(_rowCount);
    emit columnCountChanged(_columns->count());
    emit factsChanged();
    _saveSettings();

    _nextFactToAdd.clear();
}




void FactValueGrid::removeFact(const QString& factName)
{
    if (factName.isEmpty()) return;

    bool removed = false;

    // 遍历所有列删除指定 fact
    for (int i = _columns->count() - 1; i >= 0; --i) {
        QmlObjectListModel* col = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!col) continue;

        for (int j = col->count() - 1; j >= 0; --j) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(col->get(j));
            if (val && val->factName().compare(factName, Qt::CaseInsensitive) == 0) {
                col->removeAt(j);
                removed = true;
            }
        }
    }

    if (!removed) return;

    // 同步 _checkedFacts
    _checkedFacts.removeAll(factName);

    // 重新计算行数
    _rowCount = 0;
    for (int i = 0; i < _columns->count(); ++i) {
        QmlObjectListModel* col = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (col && col->count() > _rowCount)
            _rowCount = col->count();
    }

    emit rowCountChanged(_rowCount);
    emit columnCountChanged(_columns->count());
    emit factsChanged();

    // 保存到 JSON
    _saveSettings();
}


// FactValueGrid.cpp


void FactValueGrid::saveCheckedFacts()
{
    QString dirPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir dir(dirPath);
    if (!dir.exists()) dir.mkpath("."); // 确保目录存在

    QString path = dir.filePath("checkedFacts.json");
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        qWarning() << "无法写入 checkedFacts.json 文件:" << path;
        return;
    }

    QJsonArray arr;
    for (const QString& f : _checkedFacts) arr.append(f);

    QJsonObject obj;
    obj["checkedFacts"] = arr;

    file.write(QJsonDocument(obj).toJson());
    file.close();
}



// FactValueGrid.cpp

void FactValueGrid::clearAllFacts() {
    for (int i = 0; i < _columns->count(); ++i) {
        QmlObjectListModel* col = qobject_cast<QmlObjectListModel*>(_columns->get(i));
        if (!col) continue;
        for (int j = col->count() - 1; j >= 0; --j) {
            InstrumentValueData* val = qobject_cast<InstrumentValueData*>(col->get(j));
            if (val) val->deleteLater();
        }
        col->clear();
    }

    _columns->clear();
    _rowCount = 0;
    emit rowCountChanged(_rowCount);
    emit columnCountChanged(_columns->count());
    emit factsChanged();

    // _saveSettings();
}

bool FactValueGrid::loadCheckedFacts()
{
    QString path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/checkedFacts.json";
    QFile file(path);

    if (!file.exists() || !file.open(QIODevice::ReadOnly)) {
        return false; // 文件不存在或无法读取
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (!doc.isObject()) {
        return false;
    }

    QJsonArray arr = doc.object().value("checkedFacts").toArray();
    QStringList restored;
    for (auto v : arr) restored.append(v.toString());

    _checkedFacts = restored;
    emit factsChanged();
    return true;
}


// 首次启动/后续初始化
void FactValueGrid::setCheckedFacts(const QStringList& facts)
{
    _checkedFacts = facts;

    // 如果为空则使用默认参数（首次启动）
    if (_checkedFacts.isEmpty()) {
        _checkedFacts = {
            "altitudeRelative", "distanceToHome", "climbRate",
            "flightTime", "flightDistance", "groundSpeed"
        };
    }

    saveCheckedFacts();   // 持久化保存
    emit factsChanged();  // 发信号给 QML 更新
}



//  生成默认6个参数 在第一次启动时，第二次会根据loadjson 数据进行匹配  ok
void FactValueGrid::InitialFacts()
{
    bool loaded = loadCheckedFacts(); // 尝试从 JSON 加载
    if (!loaded) {
        // 首次启动，使用默认参数
        // _checkedFacts = { "altitudeRelative", "distanceToHome", "climbRate",
        //                   "flightTime", "flightDistance", "groundSpeed" };
        setCheckedFacts(_checkedFacts);
    }
}


void FactValueGrid::load_facts()
{
    // 尝试从 JSON 加载
    bool loaded = loadCheckedFacts();

    if (!loaded) {
        // 首次启动，使用默认 6 个参数
        _checkedFacts = { "altitudeRelative", "distanceToHome", "climbRate",
                          "flightTime", "flightDistance", "groundSpeed" };

        // 按顺序创建这些默认参数
        for (const QString& factName : _checkedFacts) {
            appendFact(factName);
        }

        _saveSettings();
    } else {

        // 已有 JSON 配置，按保存顺序加载参数
        for (const QString& factName : _checkedFacts) {
            appendFact(factName);
        }
    }
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





