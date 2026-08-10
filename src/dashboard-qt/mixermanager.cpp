#include "mixermanager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QDebug>
#include <cmath>

MixerManager::MixerManager(QObject *parent)
    : QObject(parent)
{
    connect(&m_timer, &QTimer::timeout, this, &MixerManager::onTimerTimeout);
    refresh();
}

void MixerManager::setActive(bool active)
{
    if (m_active != active) {
        m_active = active;
        emit activeChanged();
        if (m_active) {
            refresh();
            m_timer.start(1500); // refresh every 1.5 seconds when active
        } else {
            m_timer.stop();
        }
    }
}

void MixerManager::toggle()
{
    setActive(!m_active);
}

void MixerManager::onTimerTimeout()
{
    if (m_active) {
        refresh();
    }
}

void MixerManager::refresh()
{
    if (m_scanning) return;

    m_scanning = true;
    emit scanningChanged();

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("pw-dump");

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        m_scanning = false;
        emit scanningChanged();

        if (exitCode != 0 || status == QProcess::CrashExit) {
            qWarning() << "pw-dump failed with exit code" << exitCode << "status" << status;
            return;
        }

        QByteArray output = process->readAllStandardOutput();
        QJsonParseError parseError;
        QJsonDocument doc = QJsonDocument::fromJson(output, &parseError);
        if (doc.isNull()) {
            qWarning() << "Failed to parse pw-dump JSON:" << parseError.errorString();
            return;
        }

        QVariantList newList;
        QJsonArray arr = doc.array();
        for (const QJsonValue &val : arr) {
            QJsonObject obj = val.toObject();
            QJsonObject info = obj["info"].toObject();
            QJsonObject props = info["props"].toObject();
            QString mediaClass = props["media.class"].toString();

            if (mediaClass == "Stream/Output/Audio" || mediaClass == "Stream/Input/Audio") {
                int id = obj["id"].toInt();
                QString nodeName = props["node.name"].toString();
                QString appName = props["application.name"].toString();
                if (appName.isEmpty()) appName = props["node.description"].toString();
                if (appName.isEmpty()) appName = nodeName;

                // Clean up app name
                if (appName.contains("/")) {
                    appName = appName.split('/').last();
                }
                if (appName.startsWith(".")) {
                    appName = appName.mid(1);
                }
                // Capitalize first letter
                if (!appName.isEmpty()) {
                    appName[0] = appName[0].toUpper();
                }

                QJsonObject params = info["params"].toObject();
                QJsonArray propsArray = params["Props"].toArray();
                double volume = 1.0;
                bool mute = false;

                if (!propsArray.isEmpty()) {
                    QJsonObject propsObj = propsArray.first().toObject();
                    mute = propsObj["mute"].toBool();
                    QJsonArray chanVols = propsObj["channelVolumes"].toArray();
                    if (!chanVols.isEmpty()) {
                        double cv = chanVols.first().toDouble();
                        volume = std::pow(cv, 1.0/3.0); // cubic to linear
                    } else {
                        volume = propsObj["volume"].toDouble();
                    }
                }

                if (std::isnan(volume) || volume < 0.0) volume = 0.0;
                if (volume > 1.0) volume = 1.0;

                QVariantMap stream;
                stream["id"] = id;
                stream["name"] = appName;
                stream["type"] = (mediaClass == "Stream/Output/Audio") ? "Salida" : "Entrada";
                stream["volume"] = (float)volume;
                stream["muted"] = mute;

                newList.append(stream);
            }
        }

        m_streams = newList;
        emit streamsChanged();
    });
}

void MixerManager::setVolume(int id, float volume)
{
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("wpctl", QStringList() << "set-volume" << QString::number(id) << QString::number(volume, 'f', 2));

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        refresh();
    });
}

void MixerManager::setMute(int id, bool mute)
{
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("wpctl", QStringList() << "set-mute" << QString::number(id) << (mute ? "1" : "0"));

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        refresh();
    });
}
