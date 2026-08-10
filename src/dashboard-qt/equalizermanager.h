#ifndef EQUALIZERMANAGER_H
#define EQUALIZERMANAGER_H

#include <QObject>
#include <QVariantMap>

class EqualizerManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap eqData READ eqData NOTIFY eqDataChanged)

public:
    explicit EqualizerManager(QObject *parent = nullptr);

    QVariantMap eqData() const { return m_eqData; }

public slots:
    void setBand(int bandIdx, double value);
    void applyPreset(const QString &presetName);
    void apply();
    void loadState();

signals:
    void eqDataChanged();

private:
    void saveState();
    void writePresetAndApply();

    QVariantMap m_eqData;
    QString m_stateFilePath;
    QString m_presetFilePath;
};

#endif // EQUALIZERMANAGER_H
