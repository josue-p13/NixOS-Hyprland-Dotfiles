#include "equalizermanager.h"
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QProcess>
#include <QFileInfo>
#include <QDebug>

EqualizerManager::EqualizerManager(QObject *parent)
    : QObject(parent)
{
    m_stateFilePath = QDir::homePath() + "/.config/dashboard-qt/eq_state.json";
    m_presetFilePath = QDir::homePath() + "/.config/easyeffects/output/live_eq.json";

    // Initialize default state
    m_eqData["b1"] = 0.0;
    m_eqData["b2"] = 0.0;
    m_eqData["b3"] = 0.0;
    m_eqData["b4"] = 0.0;
    m_eqData["b5"] = 0.0;
    m_eqData["b6"] = 0.0;
    m_eqData["b7"] = 0.0;
    m_eqData["b8"] = 0.0;
    m_eqData["b9"] = 0.0;
    m_eqData["b10"] = 0.0;
    m_eqData["preset"] = "Flat";
    m_eqData["pending"] = false;

    loadState();
}

void EqualizerManager::loadState()
{
    QFile file(m_stateFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    if (doc.isObject()) {
        QJsonObject obj = doc.object();
        for (auto it = obj.constBegin(); it != obj.constEnd(); ++it) {
            m_eqData[it.key()] = it.value().toVariant();
        }
        emit eqDataChanged();
    }
}

void EqualizerManager::saveState()
{
    QJsonObject obj;
    for (auto it = m_eqData.constBegin(); it != m_eqData.constEnd(); ++it) {
        obj[it.key()] = QJsonValue::fromVariant(it.value());
    }

    QJsonDocument doc(obj);

    QFileInfo info(m_stateFilePath);
    QDir().mkpath(info.absolutePath());

    QFile file(m_stateFilePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Compact));
        file.close();
    }
}

void EqualizerManager::setBand(int bandIdx, double value)
{
    QString key = QString("b%1").arg(bandIdx);
    m_eqData[key] = value;
    m_eqData["preset"] = "Custom";
    m_eqData["pending"] = true;
    saveState();
    emit eqDataChanged();
}

void EqualizerManager::applyPreset(const QString &presetName)
{
    QMap<QString, QList<double>> presets = {
        { "Flat",    { 0.0,  0.0, 0.0,  0.0,  0.0,  0.0, 0.0, 0.0, 0.0, 0.0 } },
        { "Bass",    { 5.0,  7.0, 5.0,  2.0,  1.0,  0.0, 0.0, 0.0, 1.0, 2.0 } },
        { "Treble",  {-2.0, -1.0, 0.0,  1.0,  2.0,  3.0, 4.0, 5.0, 6.0, 6.0 } },
        { "Vocal",   {-2.0, -1.0, 1.0,  3.0,  5.0,  5.0, 4.0, 2.0, 1.0, 0.0 } },
        { "Pop",     { 2.0,  4.0, 2.0,  0.0,  1.0,  2.0, 4.0, 2.0, 1.0, 2.0 } },
        { "Rock",    { 5.0,  4.0, 2.0, -1.0, -2.0, -1.0, 2.0, 4.0, 5.0, 6.0 } },
        { "Jazz",    { 3.0,  3.0, 1.0,  1.0,  1.0,  1.0, 2.0, 1.0, 2.0, 3.0 } },
        { "Classic", { 0.0,  1.0, 2.0,  2.0,  2.0,  2.0, 1.0, 2.0, 3.0, 4.0 } }
    };

    if (presets.contains(presetName)) {
        QList<double> vals = presets[presetName];
        for (int i = 0; i < 10; ++i) {
            QString key = QString("b%1").arg(i + 1);
            m_eqData[key] = vals[i];
        }
        m_eqData["preset"] = presetName;
        m_eqData["pending"] = false;
        saveState();
        writePresetAndApply();
        emit eqDataChanged();
    }
}

void EqualizerManager::apply()
{
    m_eqData["pending"] = false;
    saveState();
    writePresetAndApply();
    emit eqDataChanged();
}

void EqualizerManager::writePresetAndApply()
{
    QMap<int, int> sliderMap;
    sliderMap[1] = 0;
    sliderMap[2] = 3;
    sliderMap[3] = 6;
    sliderMap[4] = 9;
    sliderMap[5] = 12;
    sliderMap[6] = 15;
    sliderMap[7] = 18;
    sliderMap[8] = 21;
    sliderMap[9] = 24;
    sliderMap[10] = 27;

    QList<double> freqs = {
        32.0, 40.0, 50.0, 63.0, 80.0, 100.0, 125.0, 160.0, 200.0, 250.0, 315.0, 400.0, 500.0, 630.0, 800.0, 1000.0,
        1250.0, 1600.0, 2000.0, 2500.0, 3150.0, 4000.0, 5000.0, 6300.0, 8000.0, 10000.0, 12500.0, 16000.0,
        20000.0, 22000.0, 24000.0, 24000.0
    };

    QJsonObject leftBands;
    QJsonObject rightBands;

    for (int i = 0; i < 32; ++i) {
        double freq = (i < freqs.size()) ? freqs[i] : 20000.0;
        double gain = 0.0;
        
        for (auto it = sliderMap.constBegin(); it != sliderMap.constEnd(); ++it) {
            if (it.value() == i) {
                QString key = QString("b%1").arg(it.key());
                gain = m_eqData.value(key, 0.0).toDouble();
                break;
            }
        }

        QJsonObject band;
        band["frequency"] = freq;
        band["gain"] = gain;
        band["mode"] = "Bell";
        band["mute"] = false;
        band["q"] = 1.0;
        band["solo"] = false;
        band["width"] = 1.0;
        band["slope"] = "x1";

        QString bandKey = QString("band%1").arg(i);
        leftBands[bandKey] = band;
        rightBands[bandKey] = band;
    }

    QJsonObject equalizer;
    equalizer["bypass"] = false;
    equalizer["input-gain"] = 0.0;
    equalizer["output-gain"] = 0.0;
    equalizer["left"] = leftBands;
    equalizer["right"] = rightBands;
    equalizer["mode"] = "IIR";
    equalizer["num-bands"] = 32;
    equalizer["split-channels"] = false;

    QJsonObject output;
    output["blocklist"] = QJsonArray();
    output["plugins_order"] = QJsonArray { "equalizer" };
    output["equalizer"] = equalizer;

    QJsonObject preset;
    preset["output"] = output;

    QJsonDocument doc(preset);

    QFileInfo info(m_presetFilePath);
    QDir().mkpath(info.absolutePath());

    QFile file(m_presetFilePath);
    if (file.open(QIODevice::WriteOnly)) {
        file.write(doc.toJson(QJsonDocument::Indented));
        file.close();
    }

    QProcess::startDetached("easyeffects", QStringList() << "-l" << "live_eq");
}
