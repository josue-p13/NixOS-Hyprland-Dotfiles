#ifndef THEMEMANAGER_H
#define THEMEMANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QFileSystemWatcher>

class ThemeManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap colors READ colors NOTIFY colorsChanged)

public:
    explicit ThemeManager(QObject *parent = nullptr);

    QVariantMap colors() const;

signals:
    void colorsChanged();

private slots:
    void onFileChanged(const QString &path);

private:
    void loadColors();
    
    QVariantMap m_colors;
    QFileSystemWatcher m_watcher;
    QString m_colorsPath;
};

#endif // THEMEMANAGER_H
