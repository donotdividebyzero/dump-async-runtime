{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-utils.url = "github:numtide/flake-utils";

    advisory-db = {
      url = "github:rustsec/advisory-db";
      flake = false;
    };

    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.rust-analyzer-src.follows = "";
    };

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, crane, fenix, flake-utils, advisory-db, ... }: {} // flake-utils.lib.eachSystem (system: # 
    let
      pkgs = import nixpkgs {
        inherit system;
      };

      inherit (pkgs) lib;
      craneLib = (crane.mkLib nixpkgs.legacyPackages.${system}).overrideToolchain
        fenix.packages.${system}.stable.toolchain;

      src = lib.cleanSourceWith {
        src = ./.; # The original, unfiltered source
      };

      buildDeps = {
        inherit (craneLib.crateNameFromCargoToml { cargoToml = ./Cargo.toml; }) pname version src;
      };
      commonArgs = {
        inherit src;
        inherit (imaginatorDeps) pname version;

        buildInputs = [
          pkgs.pkg-config
        ];
        nativeBuildInputs = with pkgs; [ pkg-config ];
      };

      cargoArtifacts = craneLib.buildDepsOnly commonArgs // {
        pname = "build-deps";
      };
      runtime = craneLib.buildPackage (commonArgs // {
        inherit cargoArtifacts;
        inherit src;
        cargoExtraArgs = "--bin runtime";
        pname = "runtime";
        doCheck = false;
        doNotLinkInheritedArtifacts = true;
      });

    in
    {
      packages = {
        default = runtime;
      };

      devShells.default = craneLib.devShell {
        buildInputs = with pkgs; [
        ];

        nativeBuildInputs = with pkgs; [ pkg-config ];
      };

      apps.default = flake-utils.lib.mkApp {
        drv = runtime;
      };
    }
  );
}
