{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  inputsFrom = [ (import ./default.nix { inherit pkgs; }) ];

  shellHook = ''
    echo "❄️  Entorno de desarrollo de dashboard-qt cargado con éxito."
    echo "💡 Puedes compilar con: cmake -B build -S . && cmake --build build"
  '';
}
