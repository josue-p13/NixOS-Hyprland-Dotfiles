#ifndef BLUETOOTHMANAGER_H
#define BLUETOOTHMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class BluetoothManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.bluetooth")
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(bool bluetoothPower READ bluetoothPower WRITE setBluetoothPower NOTIFY bluetoothPowerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString connectingMac READ connectingMac NOTIFY connectingMacChanged)

public:
    explicit BluetoothManager(QObject *parent = nullptr);

    QVariantList devices() const { return m_devices; }
    bool bluetoothPower() const { return m_bluetoothPower; }

    bool active() const { return m_active; }
    void setActive(bool active);

    bool scanning() const { return m_scanning; }
    QString connectingMac() const { return m_connectingMac; }

public slots:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void refresh();
    Q_SCRIPTABLE void connectDevice(const QString &mac);
    Q_SCRIPTABLE void disconnectDevice(const QString &mac);
    Q_SCRIPTABLE void setBluetoothPower(bool power);

signals:
    void devicesChanged();
    void bluetoothPowerChanged();
    void activeChanged();
    void scanningChanged();
    void connectingMacChanged();

private:
    QVariantList m_devices;
    bool m_bluetoothPower = false;
    bool m_active = false;
    bool m_scanning = false;
    QString m_connectingMac = "";

    void updatePowerState();
};

#endif // BLUETOOTHMANAGER_H
