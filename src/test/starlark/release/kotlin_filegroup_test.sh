#!/bin/bash
# Checks that the public kotlin filegroup of the release archive holds android.bzl.
set -euo pipefail

build_file=$1

# The text of the kotlin filegroup, up to the closing parenthesis.
filegroup=$(awk '
  /^filegroup\(/ { buf = ""; capture = 1 }
  capture { buf = buf $0 "\n" }
  capture && /^\)/ { capture = 0; if (buf ~ /name = "kotlin"/) { printf "%s", buf; exit } }
' "$build_file")

if [[ -z "${filegroup}" ]]; then
  echo "No filegroup named kotlin in ${build_file}"
  exit 1
fi

if [[ "${filegroup}" == *android.bzl* ]]; then
  echo "The kotlin filegroup must not exclude android.bzl:"
  echo "${filegroup}"
  exit 1
fi
