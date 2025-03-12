default:
    just --list

setup:
    mkdir -p src/generated
    nix build .#rnnoise-wasm-build-script
    rsync -a --delete --chown=$(whoami) --chmod=+rX ./result/ src/generated/
    rm result
