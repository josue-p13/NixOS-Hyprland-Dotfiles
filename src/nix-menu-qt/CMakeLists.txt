cmake_minimum_required(VERSION 3.16)
project(nix-menu-qt VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Buscar los componentes necesarios de Qt6
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Concurrent QuickControls2)

# Forzar la política de Qt para usar :/qt/qml/ como prefijo de recursos
qt_policy(SET QTP0001 NEW)

qt_standard_project_setup()

# Definir el ejecutable y sus archivos fuente
qt_add_executable(nix-menu-qt
    main.cpp
    thememanager.h
    thememanager.cpp
    configmanager.h
    configmanager.cpp
    pwamanager.h
    pwamanager.cpp
    nixpkgssearcher.h
    nixpkgssearcher.cpp
)

# Definir el módulo QML e integrar los archivos QML al recurso compilado
qt_add_qml_module(nix-menu-qt
    URI NixMenu
    VERSION 1.0
    QML_FILES
        main.qml
)

# Enlazar las librerías de Qt6
target_link_libraries(nix-menu-qt PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::Concurrent
    Qt6::QuickControls2
)

# Definir la regla de instalación para que nix-build pueda empaquetarlo
install(TARGETS nix-menu-qt RUNTIME DESTINATION bin)
