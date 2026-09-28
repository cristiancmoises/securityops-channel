#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
    printf 'Uso: %s /gnu/store/...-docker-VERSAO\n' "$0" >&2
    exit 2
fi

references=$(guix gc --references "$1")
for package in containerd runc; do
    if ! printf '%s\n' "$references" | rg -q "/[^/]+-${package}-[^/]+$"; then
        printf 'Falta referência de runtime: %s\n' "$package" >&2
        exit 1
    fi
done
"$1/bin/dockerd" --version
