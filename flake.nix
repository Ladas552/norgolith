{
  description = "The monolithic Norg static site generator built with Rust";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    crane.url = "github:ipetkov/crane";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      crane,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        toolchain = pkgs.rustPlatform;
        craneLib = crane.mkLib pkgs;
        # Common arguments can be set here to avoid repeating them later
        # Note: changes here will rebuild all dependency crates
        commonArgs = {
          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              # Default files from crane (Rust and cargo files)
              (craneLib.fileset.commonCargoSources ./.)
              # Also keep any files in resources
              (pkgs.lib.fileset.maybeMissing ./src/resources)
              (pkgs.lib.fileset.maybeMissing ./res)
            ];
          };

          strictDeps = true;

          buildInputs = with pkgs; [
            openssl
          ];

          nativeBuildInputs = with pkgs; [
            pkg-config
            perl
          ];

          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };

        # # Build *just* the cargo dependencies, so we can reuse
        # all of that work (e.g. via cachix) when running in CI
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;

        lith = craneLib.buildPackage commonArgs // {
          inherit cargoArtifacts;
        };
      in
      {
        checks.lith-nextest = craneLib.cargoNextest (
          commonArgs
          // {
            inherit cargoArtifacts;
            partitions = 1;
            partitionType = "count";
            cargoNextestPartitionsExtraArgs = "--no-tests=pass";
          }
        );
        # nix build
        packages.default = lith;

        # nix run
        apps.default = flake-utils.lib.mkApp { drv = lith; };

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
            cargo-edit
            rust-analyzer
            pkg-config # Required by git2 crate
            openssl # Required by git2 crate
          ];

          # Many editors rely on this rust-src PATH variable
          RUST_SRC_PATH = "${toolchain.rustLibSrc}";

          PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
        };
      }
    );
}
