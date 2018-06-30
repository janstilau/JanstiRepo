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

```cpp
 //check cloud layer
    QStringList checkLayers =
    {
        QLatin1String("di"),
        QLatin1String("random"),
        QLatin1String("res"),
        QLatin1String("mountain"),
        QLatin1String("biaoji")
    };

    mLayers.clear();
    mTilesets.clear();
    auto cloud = QLatin1String("cloud");
    if(mMap->indexOfLayer(cloud, Layer::TileLayerType) >= 0)
    {
        checkLayers << cloud;
    }
    auto otherRegionLayer = BusinessUtil::getFirstLayerByType(mDocument, LayerType::otherRegion);
    if (otherRegionLayer) {
        checkLayers << otherRegionLayer->name();
    }
    auto beginningLayers = BusinessUtil::getLayersByName(mDocument, QLatin1String("beginning"), tr("beginning"));
    if (!beginningLayers.isEmpty()) {
        auto beginningLayer = beginningLayers.first();
        if (beginningLayer) {
            checkLayers << beginningLayer->name();
        }
    }
    auto tilesetProperty = QLatin1String("tileset");
    int sameNameLayerCount = 0;
    for(auto checkName : checkLayers)
    {
        sameNameLayerCount = 0;
        for(auto layer : mMap->layers())
        {
            if(layer->name() == checkName) sameNameLayerCount ++;
            if(sameNameLayerCount > 1)
            {
                err = tr("There are other names %1 layers").arg(checkName);
                return true;
            }
        }
        auto layerIndex = mMap->indexOfLayer(checkName, Layer::TileLayerType);
        if(layerIndex < 0)
        {
            err = tr("Layer with name %1 not found").arg(checkName);
            return true;
        }

        TileLayer *tileLayer = mMap->layerAt(layerIndex)->asTileLayer();
        if(!tileLayer)
        {
            err = tr("Layer with name %1 is not tile layer").arg(checkName);
            return true;
        }
        mLayers[layerIndex] = checkName;
        // get tileset value
        if(!tileLayer->hasProperty(tilesetProperty))
        {
            err = tr("Property with name %1 not found in layer with name %2").arg(tilesetProperty).arg(checkName);
            return true;
        }
        auto propertyValue = tileLayer->propertyAsString(tilesetProperty);
        if(propertyValue.isEmpty())
        {
            err = tr("Property with name %1 value is null in layer with name %2").arg(tilesetProperty).arg(checkName);
            return true;
        }
        auto tilesetValues = propertyValue.split(QLatin1String(","));
        if(tilesetValues.count() > 1)
        {
            err = tr("Property with name %1 value more than one in layer with name %2").arg(tilesetProperty).arg(checkName);
            return true;
        }
        auto tilesetSetValue = tilesetValues.at(0);
        // check used tileset
        auto layerUsedTilesets = tileLayer->usedTilesets();
        bool noUsed = layerUsedTilesets.isEmpty();
        if(!noUsed && layerUsedTilesets.count() > 1)
        {
            err = tr("Layer with name %1 use more than one tileset.").arg(checkName).append(tr("Please check error cell"));
            return true;
        }
        if(noUsed)
        {
            mTilesets.insert(layerIndex, tilesetSetValue);
            continue;
        }

        SharedTileset layerTileset = (*layerUsedTilesets.begin());
        QString usedTilesetName = layerTileset->name();

        if(tilesetSetValue != usedTilesetName)
        {
            err = tr("Property with name %1 value %2 different from using tileset %3 in layer with name %4")
                    .arg(tilesetProperty).arg(tilesetSetValue)
                    .arg(usedTilesetName).arg(checkName);
            return true;
        }
        mTilesets.insert(layerIndex, tilesetSetValue);
    }
    return false;
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