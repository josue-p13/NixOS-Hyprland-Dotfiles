#ifndef PWAMANAGER_H
#define PWAMANAGER_H

#include <QObject>

class PwaManager : public QObject
{
    Q_OBJECT

public:
    explicit PwaManager(QObject *parent = nullptr);

    Q_INVOKABLE bool createPwa(const QString &name, const QString &url, const QString &iconPath);
};

#endif // PWAMANAGER_H
