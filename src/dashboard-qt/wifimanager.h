#ifndef WIFIMANAGER_H
#define WIFIMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QString>

class WifiManager : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.josue.wifi")
    Q_PROPERTY(QVariantList networks READ networks NOTIFY networksChanged)
    Q_PROPERTY(bool wifiPower READ wifiPower WRITE setWifiPower NOTIFY wifiPowerChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QString connectingSsid READ connectingSsid NOTIFY connectingSsidChanged)

public:
    explicit WifiManager(QObject *parent = nullptr);

    Q_INVOKABLE bool hasProfile(const QString &ssid);

    QVariantList networks() const { return m_networks; }
    bool wifiPower() const { return m_wifiPower; }
    void setWifiPower(bool power);

    bool active() const { return m_active; }
    void setActive(bool active);

    bool scanning() const { return m_scanning; }
    QString connectingSsid() const { return m_connectingSsid; }

public slots:
    Q_SCRIPTABLE void toggle();
    Q_SCRIPTABLE void refresh();
    Q_SCRIPTABLE void connectToNetwork(const QString &ssid, const QString &password);
    Q_SCRIPTABLE void disconnectNetwork(const QString &ssid);

signals:
    void networksChanged();
    void wifiPowerChanged();
    void activeChanged();
    void scanningChanged();
    void connectingSsidChanged();

private:
    QVariantList m_networks;
    bool m_wifiPower = false;
    bool m_active = false;
    bool m_scanning = false;
    QString m_connectingSsid = "";

    void updatePowerState();
};

#endif // WIFIMANAGER_H
