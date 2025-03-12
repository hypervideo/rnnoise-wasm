default:
    just --list

setup:
    mkdir -p src/generated
    nix build .#rnnoise-sync-js
    rsync -a --delete --chown=$(whoami) --chmod=+rX ./result/ src/generated/
    rm result
