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

        rnnoise-sync-js = pkgs.stdenv.mkDerivation {
          name = "rnnoise-sync-js";

          outputHashMode = "recursive";
          outputHashAlgo = "sha256";
          outputHash = "sha256-hFrdfUaSpcHNaONQiNBw4Baiek8QTFgLlHwP1OPYtHw=";

          src = pkgs.fetchFromGitHub {
            owner = "xiph";
            repo = "rnnoise";
            rev = "2e3c812c62c32b3ac486c3cd4f4894e6f57d45fd";
            sha256 = "sha256-NPmkFeMBj6QuDCOqFaSpvLduuHXBr0cR+KnNY7PC6YI=";
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

        build-rnnoise-wasm = from-source: pkgs.buildNpmPackage {
          name = "@hypervideo/rnnoise";
          src = ./.;
          npmDepsHash = "sha256-G2fzFvcH2I2ykeCSq5asQECPiwesHrBIoktQhqtA7Ag=";

          doCheck = false;

          nativeBuildInputs = with pkgs; [
            typescript
          ];

          preBuild =
            if from-source then ''
              mkdir src/generated
              cp -r ${rnnoise-sync-js}/* src/generated/
            '' else "";

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
          inputsFrom = [ rnnoise-sync-js ];
          nativeBuildInputs = with pkgs; [ typescript just ];
        };

        packages = {
          rnnoise-wasm = build-rnnoise-wasm false;
          rnnoise-wasm-from-source = build-rnnoise-wasm true;
          inherit rnnoise-wasm-build-script rnnoise-sync-js;
        };
      }
    );
}
