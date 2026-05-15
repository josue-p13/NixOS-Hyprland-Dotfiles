#!/usr/bin/env bash
# Lanzador de Affinity actualizado para usar Nix con el caché de Garnix
nix run github:mrshmllow/affinity-nix#affinity-v3 --extra-substituters https://cache.garnix.io --extra-trusted-public-keys cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g=
