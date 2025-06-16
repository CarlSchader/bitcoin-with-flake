{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "bitcoin-nixos";
          version = "1.0.0";

          src = ./.;

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            gcc
          ];

          buildInputs = with pkgs; [
            boost
            libevent
            sqlite
            libatomic_ops
            gcc.cc.lib # For libatomic
          ];

          cmakeFlags = [
            "-DCMAKE_BUILD_TYPE=Release"
          ];

          NIX_LDFLAGS = "-latomic";

          # Create a simplified version of TestAppendRequiredLibraries.cmake that always links with libatomic
          preConfigure = ''
            cat > cmake/module/TestAppendRequiredLibraries.cmake << 'EOL'
# Copyright (c) 2023-present The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or https://opensource.org/license/mit/.

include_guard(GLOBAL)

# Illumos/SmartOS requires linking with -lsocket if
# using getifaddrs & freeifaddrs.
function(test_append_socket_library target)
  if (NOT TARGET ''${target})
    message(FATAL_ERROR "''${CMAKE_CURRENT_FUNCTION}() called with non-existent target \"''${target}\".")
  endif()

  set(check_socket_source "
    #include <sys/types.h>
    #include <ifaddrs.h>

    int main() {
      struct ifaddrs* ifaddr;
      getifaddrs(&ifaddr);
      freeifaddrs(ifaddr);
    }
  ")

  include(CheckCXXSourceCompiles)
  check_cxx_source_compiles("''${check_socket_source}" IFADDR_LINKS_WITHOUT_LIBSOCKET)
  if(NOT IFADDR_LINKS_WITHOUT_LIBSOCKET)
    include(CheckSourceCompilesWithFlags)
    check_cxx_source_compiles_with_flags("''${check_socket_source}" IFADDR_NEEDS_LINK_TO_LIBSOCKET
      LINK_LIBRARIES socket
    )
    if(IFADDR_NEEDS_LINK_TO_LIBSOCKET)
      target_link_libraries(''${target} INTERFACE socket)
    else()
      message(FATAL_ERROR "Cannot figure out how to use getifaddrs/freeifaddrs.")
    endif()
  endif()
  set(HAVE_IFADDRS TRUE PARENT_SCOPE)
endfunction()

# Always link with libatomic on NixOS
function(test_append_atomic_library target)
  if (NOT TARGET ''${target})
    message(FATAL_ERROR "''${CMAKE_CURRENT_FUNCTION}() called with non-existent target \"''${target}\".")
  endif()

  message(STATUS "NixOS detected - forcing linking with libatomic")
  target_link_libraries(''${target} INTERFACE atomic)
endfunction()
EOL
          '';

          meta = with pkgs.lib; {
            description = "Bitcoin Core";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            cmake
            pkg-config
            boost
            libevent
            sqlite
            libatomic_ops
            gcc.cc.lib # For libatomic
          ];

          shellHook = ''
            export NIX_LDFLAGS="-latomic $NIX_LDFLAGS"
          '';
        };
      });
}
