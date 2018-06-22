# errorPanel

## mapId

```cpp
    mMapId = map->property(QLatin1String("mapID")).toInt(&ok);
    if(!ok)
    {
        err = tr("Map property mapID can't be found");
        return false;
    }
```

## layer

```cpp
{
    auto layerGroup = BusinessUtil::getLayersByType(mDoc, type);
    if(layerGroup.isEmpty())
    {
        if((type != LayerType::influenceRegion) && (type != LayerType::born) && (type != LayerType::otherRegion))
        {
            err = tr("Type %1 layer is not found").arg(BusinessUtil::getLayerTypeName(type));
            return false;
        }
        continue;
    }
    switch (type) {
    case LayerType::terrain:
        mTaskSequences.push_back(Task::River);
        break;
    case LayerType::resource:
        mTaskSequences.push_back(Task::Resource);
        break;
    case LayerType::mountain:
        mTaskSequences.push_back(Task::Mountain);
        continue;
    case LayerType::zoneRegion:
        mTaskSequences.push_back(Task::Zone);
        continue;
    case LayerType::influenceRegion:
        count++;
        continue;
    case LayerType::born:
        count++;
        continue;
    case LayerType::otherRegion:
        mTaskSequences.push_back(Task::OtherRegion);
        continue;
    default:
        continue;
    }

    TileLayer * tileLayer = layerGroup.at(0);
    QString tileset = QLatin1String("tileset");
    if(!tileLayer->hasProperty(tileset))
    {
        err = tr("Tileset of type %1 layer is not found").arg(BusinessUtil::getLayerTypeName(type));
        return false;
    }
    auto tilesetStr = tileLayer->propertyAsString(tileset);
    if(tilesetStr.isEmpty())
    {
        err = tr("Tileset of type %1 layer value is blank!").arg(BusinessUtil::getLayerTypeName(type));
        return false;
    }
    auto tilesetValues = tilesetStr.split(QLatin1String(","));
    if(tilesetValues.count() == 1)
    {
        mLayerTileset.insert(type, tilesetStr);
        continue;
    }
    else
    {
        err = tr("Tileset of type %1 layer value more than one").arg(BusinessUtil::getLayerTypeName(type));
        return false;
    }
}
```

## tileset 的属性值是否是有效值

```cpp
bool ExportMapManager::getTilesetSetting(QString tilesetName, QString propertyName, QString &err)
{
    err.clear();
    Map *map = mDoc->map();
    if(!map)
    {
        err = tr("Current map is null");
        return false;
    };
    auto tilesets = map->tilesets();
    for(SharedTileset tileset : tilesets)
    {
        if(tileset->name() != tilesetName) continue;
        if(!tileset->hasProperty(propertyName))
        {
            err = tr("Property %1 is not found in tileset %2").arg(propertyName).arg(tilesetName);
            return false;
        }
        auto propertyValue = tileset->propertyAsString(propertyName);
        if(propertyValue.isEmpty())
        {
            err = tr("Property %1 value is blank in tileset %2").arg(propertyName).arg(tilesetName);
            return false;
        }
        QList<int> value;
        if(!settingValuCheck(propertyName, propertyValue, value, err)) return false;
        else
        {
            mGroup.insert(propertyName, value);
            return true;
        }
    }
    err = tr("Tileset %1 is not found").arg(tilesetName);
    return false;
}
```

## tileset 的属性, 是否有重复相交的

```cpp
if(isCrossOver(QLatin1String("resGroup"),QLatin1String("bridgeGroup"), err))
```