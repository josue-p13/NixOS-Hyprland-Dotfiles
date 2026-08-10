{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];

  buildInputs = with pkgs; [
    qt6.qtbase
    qt6.qtdeclarative
  ];

  shellHook = ''
    echo "❄️  Entorno de desarrollo de Qt6/C++ cargado con éxito."
    echo "💡 Puedes compilar con: cmake -B build -S . && cmake --build build"
  '';
}
