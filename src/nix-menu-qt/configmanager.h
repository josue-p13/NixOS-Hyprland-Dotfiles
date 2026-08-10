#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QObject>
#include <QVariantList>

class ConfigManager : public QObject
{
    Q_OBJECT

public:
    explicit ConfigManager(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList getConfigs() const;
    Q_INVOKABLE void editConfig(const QString &name, const QString &path);
    Q_INVOKABLE QVariantList getSystemScripts() const;
    Q_INVOKABLE QVariantList getQtProjects() const;
    Q_INVOKABLE QVariantList getProjectFiles(const QString &projectPath) const;

signals:
    void editingFinished(const QString &name);
};

#endif // CONFIGMANAGER_H
