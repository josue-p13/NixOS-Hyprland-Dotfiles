#ifndef SYSTEMMONITOR_H
#define SYSTEMMONITOR_H

#include <QObject>
#include <QTimer>
#include <QProcess>

class SystemMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(double cpu READ cpu NOTIFY cpuChanged)
    Q_PROPERTY(double ram READ ram NOTIFY ramChanged)
    Q_PROPERTY(double gpu READ gpu NOTIFY gpuChanged)
    Q_PROPERTY(double temp READ temp NOTIFY tempChanged)
    Q_PROPERTY(double disk READ disk NOTIFY diskChanged)
    Q_PROPERTY(double rxRate READ rxRate NOTIFY netChanged)
    Q_PROPERTY(double txRate READ txRate NOTIFY netChanged)
    Q_PROPERTY(QString face READ face NOTIFY faceChanged)

public:
    explicit SystemMonitor(QObject *parent = nullptr);

    double cpu() const { return m_cpu; }
    double ram() const { return m_ram; }
    double gpu() const { return m_gpu; }
    double temp() const { return m_temp; }
    double disk() const { return m_disk; }
    double rxRate() const { return m_rxRate; }
    double txRate() const { return m_txRate; }
    QString face() const { return m_face; }

signals:
    void cpuChanged();
    void ramChanged();
    void gpuChanged();
    void tempChanged();
    void diskChanged();
    void netChanged();
    void faceChanged();

private slots:
    void updateStats();
    void onGpuProcessFinished(int exitCode, QProcess::ExitStatus exitStatus);

private:
    void updateCpu();
    void updateRam();
    void updateTemp();
    void updateGpu();
    void updateDisk();
    void updateNet();
    void updateFace();

    double m_cpu = 0.0;
    double m_ram = 0.0;
    double m_gpu = 0.0;
    double m_temp = 0.0;
    double m_disk = 0.0;
    double m_rxRate = 0.0;
    double m_txRate = 0.0;
    QString m_face = "( ˶ˆ꒳ˆ˵ )";

    QTimer m_timer;
    QProcess *m_gpuProcess = nullptr;
    bool m_hasNvidiaSmi = false;
    QString m_tempPath;

    // For CPU calculation
    unsigned long long m_prevActive = 0;
    unsigned long long m_prevTotal = 0;

    // For Network calculation
    unsigned long long m_prevRxBytes = 0;
    unsigned long long m_prevTxBytes = 0;
    qint64 m_prevNetTime = 0;
};

#endif // SYSTEMMONITOR_H
