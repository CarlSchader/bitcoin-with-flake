{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        dependencies = with pkgs; [
          cmake
          clang
          libevent
          glibc
          sqlite
          boost
          pkg-config
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = dependencies;
          shellHook = ''
            export LD_LIBRARY_PATH=LD_LIBRARY_PATH:${pkgs.lib.makeLibraryPath dependencies}
          '';
        };
      });
}
