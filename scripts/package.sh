#!/bin/sh
# Package the plugin from the repository root:
#   sh scripts/package.sh VERSION
# VERSION must match the quoted version field in _meta.lua, for example:
#   version = "0.4.0"
# Writes dist/magpie.koplugin-VERSION.zip and never overwrites it.
set -eu

die() {
  printf '%s\n' "$1" >&2
  exit 1
}

if [ "$#" -ne 1 ]; then
  die "usage: sh scripts/package.sh VERSION (from the repository root)"
fi

version=$1

case $version in
  ''|*'..'*|*/*)
    die "error: version is empty or contains a path"
    ;;
esac
# A case pattern is ambiguous for a literal backslash; compare expansions.
rest=${version#*\\}
if [ "$rest" != "$version" ]; then
  die "error: version is empty or contains a path"
fi

set -- \
  _meta.lua \
  main.lua \
  dashview.lua \
  office.lua \
  projcost.lua \
  LICENSE \
  README.md \
  README.zh-CN.md
for required in "$@"; do
  if [ ! -f "$required" ]; then
    die "error: missing required file: $required"
  fi
done

cr=$(printf '\r')
meta_version=
meta_found=0

lstrip() {
  chunk=$1
  while :; do
    case $chunk in
      [[:space:]]*) chunk=${chunk#?} ;;
      *) break ;;
    esac
  done
}

rstrip() {
  chunk=$1
  while :; do
    case $chunk in
      *[[:space:]]) chunk=${chunk%?} ;;
      *) break ;;
    esac
  done
}

while IFS= read -r line || [ -n "$line" ]; do
  line=${line%"$cr"}
  lstrip "$line"
  case $chunk in
    version=*|version[[:space:]]*)
      ;;
    *)
      continue
      ;;
  esac
  lstrip "${chunk#version}"
  case $chunk in
    =*) ;;
    *) continue ;;
  esac
  lstrip "${chunk#=}"
  case $chunk in
    \"*) ;;
    *) continue ;;
  esac
  chunk=${chunk#\"}
  value=${chunk%%\"*}
  lstrip "${chunk#*\"}"
  rstrip "$chunk"
  case $chunk in
    ''|,)
      meta_version=$value
      meta_found=1
      break
      ;;
  esac
done < _meta.lua

if [ "$meta_found" -ne 1 ]; then
  die "error: _meta.lua has no version field"
fi

if [ "$version" != "$meta_version" ]; then
  die "error: version does not match _meta.lua"
fi

out_rel=dist/magpie.koplugin-${version}.zip
if [ -e "$out_rel" ] || [ -L "$out_rel" ]; then
  die "error: $out_rel already exists"
fi

command -v zip >/dev/null 2>&1 || die "error: zip is not installed"

root=$(mktemp -d)
cleanup() {
  if [ -n "${root:-}" ]; then
    rm -rf "$root"
    root=
  fi
}
trap cleanup EXIT
trap 'exit 1' INT TERM

mkdir "$root/magpie.koplugin"
for required in "$@"; do
  cp "$required" "$root/magpie.koplugin/$required"
done

archive=$root/archive.zip
(
  cd "$root"
  # Stage holds only the eight explicit copies above. -D omits the directory
  # entry so the archive members are exactly magpie.koplugin/<file>.
  zip -q -r -D "$archive" magpie.koplugin
)

mkdir -p dist
if [ -e "$out_rel" ] || [ -L "$out_rel" ]; then
  die "error: $out_rel already exists"
fi
mv "$archive" "$out_rel"
printf '%s\n' "$out_rel"
