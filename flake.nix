{
  description = "Rust development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }:
    flake-utils.lib.eachDefaultSystem(system: let
      pkgs = import nixpkgs { inherit system; };
      toolchain = pkgs.rustPlatform;
      cargoPackage = ((pkgs.lib.importTOML "${self}/Cargo.toml").package);
    in rec
    {
      # nix build
      packages.default = toolchain.buildRustPackage {
        pname = cargoPackage.name;
        version = cargoPackage.version;
        src = "${self}";
        cargoLock.lockFile = "${self}/Cargo.lock";

        meta = {
          description = cargoPackage.description;
          homepage = cargoPackage.repository;
          license = pkgs.lib.licenses.gpl2Only;
          maintainers = cargoPackage.authors;
        };

        # For other makeRustPlatform features see:
        # https://github.com/NixOS/nixpkgs/blob/master/doc/languages-frameworks/rust.section.md#cargo-features-cargo-features
      };

      # nix run
      apps.default = flake-utils.lib.mkApp { drv = packages.default; };

      # nix develop
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          (with toolchain; [
            cargo
            rustc
            rustLibSrc
          ])
          clippy
          rustfmt
          cargo-nextest
          rust-analyzer
          pkg-config
        ];

        # Many editors rely on this rust-src PATH variable
        RUST_SRC_PATH = "${toolchain.rustLibSrc}";
      };
    });
}
