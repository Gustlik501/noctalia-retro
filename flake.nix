{
  description = "Workstation '95 IRIX/CDE bar plugin for Noctalia 5.4.1";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      package = { lib, stdenvNoCC, python3, luau }:
        stdenvNoCC.mkDerivation {
          pname = "noctalia-retro";
          version = "0.1.0";
          src = lib.cleanSource ./.;
          nativeBuildInputs = [ python3 luau ];
          dontBuild = true;
          doCheck = true;
          checkPhase = ''
            runHook preCheck
            python3 tests/check.py
            luau tests/layout.luau
            runHook postCheck
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/noctalia/plugins/noctalia-retro $out/share/noctalia-retro
            cp -r plugin/. $out/share/noctalia/plugins/noctalia-retro/
            cp -r examples $out/share/noctalia-retro/
            substituteInPlace $out/share/noctalia-retro/examples/retro.toml \
              --replace-fail '@PLUGIN_ROOT@' "$out/share/noctalia/plugins" \
              --replace-fail 'profiles/user-base.toml' "$out/share/noctalia-retro/examples/profiles/user-base.toml"
            cp README.md TESTING.md LICENSE $out/share/noctalia-retro/
            runHook postInstall
          '';
          meta = {
            description = "Opaque IRIX text bar and CDE front panel for Noctalia 5.4.1";
            license = lib.licenses.mit;
            homepage = "https://docs.noctalia.dev/noctalia/plugins/";
            platforms = [ "x86_64-linux" ];
          };
        };
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
            retro = pkgs.callPackage package { };
        in { default = retro; noctalia-retro = retro; });
      overlays.default = final: prev: { noctalia-retro = final.callPackage package { }; };
      checks = forAllSystems (system: { package = self.packages.${system}.default; });
      devShells = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in { default = pkgs.mkShell { packages = [
          pkgs.python3 pkgs.luau pkgs.socat pkgs.gcc pkgs.pkg-config
          pkgs.wayland pkgs.wayland-scanner pkgs.wlr-protocols pkgs.imagemagick
        ]; }; });
    };
}
