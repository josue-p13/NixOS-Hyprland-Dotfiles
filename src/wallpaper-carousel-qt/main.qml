import QtQuick
import QtQuick.Controls

Window {
    id: root
    visible: true
    width: Screen.width
    height: Screen.height
    color: "transparent"
    title: "Wallpaper Carousel"
    flags: Qt.FramelessWindowHint | Qt.Window

    property string activeFilterName: "All"

    // Atajos globales y navegación
    FocusScope {
        id: focusScope
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                Qt.quit();
            } else if (event.key === Qt.Key_Left) {
                searchInput.focus = false;
                carousel.decrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                searchInput.focus = false;
                carousel.incrementCurrentIndex();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (carousel.count > 0 && carousel.currentIndex >= 0) {
                    var selectedFile = carousel.model[carousel.currentIndex];
                    wallpaperManager.applyWallpaper(selectedFile);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_F) {
                if (!searchInput.activeFocus && carousel.count > 0 && carousel.currentIndex >= 0) {
                    var selectedFile = carousel.model[carousel.currentIndex];
                    wallpaperManager.toggleFavorite(selectedFile);
                }
                event.accepted = true;
            }
        }

        // Fondo oscuro y translúcido (Dim background)
        Rectangle {
            anchors.fill: parent
            color: wallpaperManager.colors.bg ? wallpaperManager.colors.bg : "#282828"
            opacity: 0.93

            // Animación suave de aparición al iniciar
            Behavior on opacity { NumberAnimation { duration: 250 } }
        }

        // Contenedor principal vertical
        Column {
            anchors.centerIn: parent
            width: parent.width * 0.85
            spacing: 30

            // 1. Barra de búsqueda
            Rectangle {
                width: 500
                height: 50
                anchors.horizontalCenter: parent.horizontalCenter
                color: wallpaperManager.colors.bg_alt ? wallpaperManager.colors.bg_alt : "#1d2021"
                opacity: 0.9
                radius: 25
                border.color: searchInput.activeFocus ? (wallpaperManager.colors.accent ? wallpaperManager.colors.accent : "#fe8019") : "transparent"
                border.width: 2

                Behavior on border.color { ColorAnimation { duration: 150 } }

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    spacing: 10

                    Text {
                        text: "🔍"
                        font.pixelSize: 18
                        color: wallpaperManager.colors.fg ? wallpaperManager.colors.fg : "#ebdbb2"
                        opacity: 0.6
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 40
                        font.pixelSize: 17
                        font.family: "JetBrains Mono"
                        color: wallpaperManager.colors.fg ? wallpaperManager.colors.fg : "#ebdbb2"
                        focus: true
                        selectByMouse: true
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            text: "Buscar por nombre..."
                            font: parent.font
                            color: parent.color
                            opacity: 0.3
                            visible: parent.text.length === 0
                        }

                        onTextChanged: {
                            wallpaperManager.searchWallpapers(text);
                        }
                    }
                }
            }

            // 2. Fila de Filtros de Color (Botones redondos)
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 15

                // Modelo para los botones de color
                ListModel {
                    id: colorFiltersModel
                    ListElement { name: "All"; colorValue: "#ffffff"; tooltip: "Todos" }
                    ListElement { name: "Favorites"; colorValue: "transparent"; tooltip: "Favoritos" }
                    ListElement { name: "Red"; colorValue: "#fb4934"; tooltip: "Rojo" }
                    ListElement { name: "Orange"; colorValue: "#fe8019"; tooltip: "Naranja" }
                    ListElement { name: "Yellow"; colorValue: "#fabd2f"; tooltip: "Amarillo" }
                    ListElement { name: "Green"; colorValue: "#b8bb26"; tooltip: "Verde" }
                    ListElement { name: "Blue"; colorValue: "#83a598"; tooltip: "Azul" }
                    ListElement { name: "Purple"; colorValue: "#d3869b"; tooltip: "Morado" }
                    ListElement { name: "Pink"; colorValue: "#ff87af"; tooltip: "Rosa" }
                    ListElement { name: "Dark"; colorValue: "#3c3836"; tooltip: "Oscuros" }
                }

                Repeater {
                    model: colorFiltersModel
                    delegate: Item {
                        width: 38
                        height: 38

                        Rectangle {
                            id: filterCircle
                            width: 30
                            height: 30
                            anchors.centerIn: parent
                            radius: 15
                            color: model.colorValue
                            
                            // Efecto hover y active
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "black"
                                opacity: mouseArea.containsMouse ? 0.15 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            Text {
                                text: "♥"
                                anchors.centerIn: parent
                                font.pixelSize: 22
                                color: "#fb4934"
                                visible: model.name === "Favorites"
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.activeFilterName = model.name;
                                    wallpaperManager.filterByCategory(model.name);
                                }
                            }
                        }

                        // Anillo exterior si está seleccionado el filtro
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: wallpaperManager.colors.accent ? wallpaperManager.colors.accent : "#fe8019"
                            border.width: 2
                            visible: root.activeFilterName === model.name
                        }
                    }
                }
            }

            // 3. El Carrusel de Wallpapers (PathView)
            Item {
                width: root.width * 0.95
                height: 480
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    anchors.centerIn: parent
                    text: "(×﹏×) Sin resultados"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 22
                    font.bold: true
                    color: wallpaperManager.colors.fg ? wallpaperManager.colors.fg : "#ebdbb2"
                    opacity: 0.6
                    visible: carousel.count === 0
                }

                PathView {
                    id: carousel
                    anchors.fill: parent
                    model: wallpaperManager.wallpapers
                    pathItemCount: 5
                    highlightRangeMode: PathView.ApplyRange
                    preferredHighlightBegin: 0.5
                    preferredHighlightEnd: 0.5
                    focus: false // Dejamos el foco al FocusScope de la ventana

                    delegate: Item {
                        id: delegateItem
                        width: 680
                        height: 382

                        // Enlace dinámico con los atributos calculados por PathView para el efecto 3D
                        scale: PathView.itemScale
                        opacity: PathView.itemOpacity
                        z: PathView.itemZ

                        // Transiciones elásticas
                        Behavior on scale { SpringAnimation { spring: 2.2; damping: 0.8 } }
                        Behavior on opacity { NumberAnimation { duration: 250 } }

                        // Marco del wallpaper con bordes redondeados y borde de color
                        Rectangle {
                            anchors.fill: parent
                            radius: 24
                            color: wallpaperManager.colors.bg_alt ? wallpaperManager.colors.bg_alt : "#1d2021"
                            border.width: PathView.isCurrentItem ? 5 : 2
                            border.color: PathView.isCurrentItem ? 
                                          (wallpaperManager.colors.accent ? wallpaperManager.colors.accent : "#fe8019") : 
                                          (wallpaperManager.colors.bg_alt ? wallpaperManager.colors.bg_alt : "#3c3836")
                            clip: true

                            // Carga asíncrona de la imagen
                            Image {
                                anchors.fill: parent
                                anchors.margins: parent.border.width
                                source: "file://" + wallpaperManager.wallpaperDir + "/" + modelData
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                
                                // Redimensionar en backend para optimizar consumo de memoria RAM y VRAM
                                sourceSize.width: 720
                                sourceSize.height: 405

                                // Efecto desvanecido (fade-in) cuando termina de cargar en segundo plano
                                opacity: status === Image.Ready ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Corazón de Favoritos en la esquina superior derecha
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 15
                                width: 40
                                height: 40
                                radius: 20
                                color: "#CC000000" // Fusión oscura traslúcida
                                visible: wallpaperManager.favorites.indexOf(modelData) !== -1

                                Text {
                                    text: "♥"
                                    anchors.centerIn: parent
                                    color: "#fb4934"
                                    font.pixelSize: 22
                                }
                            }

                            // Overlay oscuro para los elementos laterales (no enfocados)
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "black"
                                opacity: PathView.isCurrentItem ? 0.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Nombre del wallpaper activo visible en la parte inferior
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 50
                                color: "#CC000000"
                                visible: PathView.isCurrentItem && opacity > 0.8
                                opacity: PathView.isCurrentItem ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.replace(/\.[^/.]+$/, "") // Quitar extensión
                                    color: wallpaperManager.colors.fg ? wallpaperManager.colors.fg : "#ebdbb2"
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }

                        // Permitir cambiar la selección haciendo clic directo en las imágenes laterales
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                searchInput.focus = false;
                                carousel.currentIndex = index;
                            }
                        }
                    }

                    // Definición de la curva del carrusel de wallpapers
                    path: Path {
                        startX: -150
                        startY: carousel.height / 2
                        PathAttribute { name: "itemScale"; value: 0.15 }
                        PathAttribute { name: "itemOpacity"; value: 0.0 }
                        PathAttribute { name: "itemZ"; value: 1 }

                        PathLine { x: carousel.width * 0.18; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 0.55 }
                        PathAttribute { name: "itemOpacity"; value: 0.5 }
                        PathAttribute { name: "itemZ"; value: 5 }

                        PathLine { x: carousel.width * 0.5; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 1.0 }
                        PathAttribute { name: "itemOpacity"; value: 1.0 }
                        PathAttribute { name: "itemZ"; value: 10 }

                        PathLine { x: carousel.width * 0.82; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 0.55 }
                        PathAttribute { name: "itemOpacity"; value: 0.5 }
                        PathAttribute { name: "itemZ"; value: 5 }

                        PathLine { x: carousel.width + 150; y: carousel.height / 2 }
                        PathAttribute { name: "itemScale"; value: 0.15 }
                        PathAttribute { name: "itemOpacity"; value: 0.0 }
                        PathAttribute { name: "itemZ"; value: 1 }
                    }

                    // Habilitar soporte de rueda de scroll
                    MouseArea {
                        anchors.fill: parent
                        propagateComposedEvents: true
                        onWheel: (wheel) => {
                            searchInput.focus = false;
                            if (wheel.angleDelta.y > 0) {
                                carousel.decrementCurrentIndex();
                            } else if (wheel.angleDelta.y < 0) {
                                carousel.incrementCurrentIndex();
                            }
                        }
                    }
                }
            }

            // 4. Atajos de teclado instructivos
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "[ Enter ] Aplicar   [ ← / → ] Navegar   [ F ] Favorito   [ Esc ] Salir"
                font.family: "JetBrains Mono"
                font.pixelSize: 13
                font.bold: true
                color: wallpaperManager.colors.fg ? wallpaperManager.colors.fg : "#ebdbb2"
                opacity: 0.55
            }
        }
    }

    // Actualizar el estado visual del filtro
    property string activeCategory: "All"
    Connections {
        target: wallpaperManager
        function onWallpapersChanged() {
            // Re-evaluar el índice activo para que se mantenga centrado
        }
    }
}
