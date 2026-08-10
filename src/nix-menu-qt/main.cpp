#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "thememanager.h"
#include "configmanager.h"
#include "pwamanager.h"
#include "nixpkgssearcher.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Ajustar los nombres de la app para que Hyprland reconozca la ventana y aplique las reglas
    QGuiApplication::setApplicationName("nix-menu-qt");
    QGuiApplication::setDesktopFileName("nix-menu-qt");

    // Instanciar gestores
    ThemeManager themeManager;
    ConfigManager configManager;
    PwaManager pwaManager;
    NixpkgsSearcher nixpkgsSearcher;

    QQmlApplicationEngine engine;

    // Registrar las clases C++ en el contexto de QML
    engine.rootContext()->setContextProperty("themeManager", &themeManager);
    engine.rootContext()->setContextProperty("configManager", &configManager);
    engine.rootContext()->setContextProperty("pwaManager", &pwaManager);
    engine.rootContext()->setContextProperty("nixpkgsSearcher", &nixpkgsSearcher);

    // Cargar el archivo QML principal
    const QUrl url(QStringLiteral("qrc:/qt/qml/NixMenu/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
