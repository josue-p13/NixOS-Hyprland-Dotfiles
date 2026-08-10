#ifndef NIXPKGSSEARCHER_H
#define NIXPKGSSEARCHER_H

#include <QObject>
#include <QStringList>

class NixpkgsSearcher : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList packages READ packages NOTIFY packagesChanged)
    Q_PROPERTY(bool isLoading READ isLoading NOTIFY isLoadingChanged)

public:
    explicit NixpkgsSearcher(QObject *parent = nullptr);

    QStringList packages() const;
    bool isLoading() const;

    Q_INVOKABLE QStringList search(const QString &query);
    Q_INVOKABLE void runTemp(const QString &packageName);
    Q_INVOKABLE void installPermanent(const QString &packageName);

signals:
    void packagesChanged();
    void isLoadingChanged();

private:
    void loadCacheAsync();
    
    QStringList m_packages;
    QStringList m_popularPackages;
    bool m_isLoading;
    QString m_cachePath;
};

#endif // NIXPKGSSEARCHER_H
