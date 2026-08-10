#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "wallpapermanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // Ajustar los nombres de la app para que Hyprland reconozca la ventana y aplique las reglas
    QGuiApplication::setApplicationName("wallpaper-carousel-qt");
    QGuiApplication::setDesktopFileName("wallpaper-carousel-qt");

    // Instanciar el gestor de wallpapers
    WallpaperManager manager;

    QQmlApplicationEngine engine;

    // Registrar la clase C++ en el contexto de QML
    engine.rootContext()->setContextProperty("wallpaperManager", &manager);

    // Cargar los wallpapers al iniciar
    manager.loadWallpapers();

    // Cargar el archivo QML principal (empacado en los recursos del módulo)
    const QUrl url(QStringLiteral("qrc:/qt/qml/WallpaperCarousel/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.load(url);

    return app.exec();
}
