{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        emscripten = pkgs.callPackage ./nix/emscripten.nix {
          llvmPackages = pkgs.llvmPackages_git;
        };

        rnnoise-wasm-build-script = pkgs.stdenv.mkDerivation {
          name = "rnnoise-wasm-build-script";
          src = ./.;

          buildPhase = "true";
          installPhase = ''
            mkdir -p $out/
            sed -i 's|cd rnnoise||' build.sh
            sed -i 's|git clean -f -d||' build.sh
            sed -i 's|mv $ENTRY_POINT_SYNC ../src/generated/||' build.sh
            cp build.sh $out/
          '';
        };

        rnnoise-wasm-sync-js = pkgs.stdenv.mkDerivation {
          name = "rnnoise-wasm-sync-js";

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-xRWjoIfrvUGmY+Mo78o3wd2PKuVJ8c6bca2/yiAAiJA=";

          src = pkgs.fetchFromGitHub {
            owner = "xiph";
            repo = "rnnoise";
            rev = "70f1d256acd4b34a572f999a05c87bf00b67730d";
            sha256 = "sha256-fkSy7Sqnx0yLfGLciHf8PaptzFVzFAeRrhE4R5z8hSw=";
          };

          nativeBuildInputs = with pkgs; [
            emscripten
            autoconf
            automake
            libtool
            wget
            cacert
          ];

          buildPhase = ''
            cp ${rnnoise-wasm-build-script}/build.sh .
            export HOME=$(mktemp -d)
            export XDG_CACHE_HOME=$HOME/.cache
            sh ./build.sh
          '';

          installPhase = ''
            mkdir -p $out/
            cp rnnoise-sync.js $out/
          '';
        };

        rnnoise-wasm = pkgs.buildNpmPackage {
          name = "@hypervideo/rnnoise";
          src = ./.;
          npmDepsHash = "sha256-G2fzFvcH2I2ykeCSq5asQECPiwesHrBIoktQhqtA7Ag=";

          doCheck = false;

          nativeBuildInputs = with pkgs; [
            typescript
          ];

          preBuild = ''
            mkdir src/generated
            cp -r ${rnnoise-wasm-sync-js}/* src/generated/
          '';

          npmBuildScript = "build:typescript";

          installPhase = ''
            mkdir -p $out/dist/
            cp -r dist/* $out/dist/
            cp package.json $out/
          '';
        };

      in
      {
        devShells.default = pkgs.mkShell {
          inputsFrom = [ rnnoise-wasm rnnoise-wasm-sync-js ];

          nativeBuildInputs = with pkgs; [ just ];
        };

        packages = {
          inherit rnnoise-wasm rnnoise-wasm-build-script rnnoise-wasm-sync-js;
        };

        overlays.default = final: prev: {
          inherit rnnoise-wasm;
        };
      }
    );
}
