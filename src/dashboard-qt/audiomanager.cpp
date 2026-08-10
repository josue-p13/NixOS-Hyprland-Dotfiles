#include "audiomanager.h"
#include <QProcess>
#include <QProcessEnvironment>
#include <QDebug>

AudioManager::AudioManager(QObject *parent)
    : QObject(parent)
{
    refresh();
}

void AudioManager::setActive(bool active)
{
    if (m_active != active) {
        m_active = active;
        emit activeChanged();
        if (m_active) {
            refresh();
        }
    }
}

void AudioManager::toggle()
{
    setActive(!m_active);
}

void AudioManager::refresh()
{
    if (m_scanning) return;

    m_scanning = true;
    emit scanningChanged();

    QString script = 
        "python3 -c '\n"
        "import subprocess, re\n"
        "res = subprocess.run([\"wpctl\", \"status\"], capture_output=True, text=True)\n"
        "current_section = None\n"
        "for line in res.stdout.splitlines():\n"
        "    if \"Sinks:\" in line:\n"
        "        current_section = \"sinks\"\n"
        "        continue\n"
        "    elif \"Sources:\" in line:\n"
        "        current_section = \"sources\"\n"
        "        continue\n"
        "    elif \"Filters:\" in line or \"Streams:\" in line or \"Devices:\" in line:\n"
        "        current_section = None\n"
        "        continue\n"
        "    if current_section in (\"sinks\", \"sources\"):\n"
        "        match = re.search(r\"\\s*(\\d+)\\.\\s*(.+)\", line)\n"
        "        if match:\n"
        "            is_default = \"1\" if \"*\" in line else \"0\"\n"
        "            dev_id = match.group(1)\n"
        "            rest = match.group(2).strip()\n"
        "            vol = \"0.0\"\n"
        "            muted = \"0\"\n"
        "            if \"[vol:\" in rest:\n"
        "                name = rest.split(\"[vol:\")[0].strip()\n"
        "                vol_match = re.search(r\"vol:\\s*([\\d\\.]+)\", rest)\n"
        "                if vol_match:\n"
        "                    vol = vol_match.group(1)\n"
        "            elif \"MUTED\" in rest:\n"
        "                name = rest.split(\"[\")[0].strip() if \"[\" in rest else rest\n"
        "                muted = \"1\"\n"
        "            else:\n"
        "                name = rest.split(\"[\")[0].strip() if \"[\" in rest else rest\n"
        "            print(f\"{current_section}|{dev_id}|{name}|{vol}|{muted}|{is_default}\")\n"
        "'";

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("bash", QStringList() << "-c" << script);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        m_scanning = false;
        emit scanningChanged();

        if (exitCode != 0 || status == QProcess::CrashExit) {
            qWarning() << "Audio devices query failed with exit code" << exitCode << "status" << status;
            qWarning() << "Stderr:" << process->readAllStandardError();
            return;
        }

        QByteArray output = process->readAllStandardOutput();
        QStringList lines = QString::fromUtf8(output).split('\n', Qt::SkipEmptyParts);

        QVariantList newList;
        for (const QString &line : lines) {
            QStringList fields = line.split('|');
            if (fields.size() < 6) continue;

            QString type = fields.at(0);
            QString id = fields.at(1);
            QString name = fields.at(2);
            float volume = fields.at(3).toFloat();
            bool muted = (fields.at(4) == "1");
            bool isDefault = (fields.at(5) == "1");

            // Clean up name if it has brackets at the end
            if (name.contains('[')) {
                name = name.split('[').first().trimmed();
            }

            QVariantMap dev;
            dev["type"] = type; // "sinks" or "sources"
            dev["id"] = id;
            dev["name"] = name;
            dev["volume"] = volume;
            dev["muted"] = muted;
            dev["isDefault"] = isDefault;

            newList.append(dev);
        }

        m_devices = newList;
        emit devicesChanged();
    });
}

void AudioManager::setDefaultDevice(const QString &id)
{
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("wpctl", QStringList() << "set-default" << id);

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        refresh();
    });
}

void AudioManager::setVolume(const QString &id, float volume)
{
    // Bound check volume
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;

    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("wpctl", QStringList() << "set-volume" << id << QString::number(volume, 'f', 2));

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        refresh();
    });
}

void AudioManager::setMute(const QString &id, bool mute)
{
    QProcess *process = new QProcess(this);
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.insert("LC_ALL", "C");
    process->setProcessEnvironment(env);
    process->start("wpctl", QStringList() << "set-mute" << id << (mute ? "1" : "0"));

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished), this, [this, process](int exitCode, QProcess::ExitStatus status) {
        process->deleteLater();
        refresh();
    });
}
