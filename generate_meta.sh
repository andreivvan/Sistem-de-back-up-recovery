#!/bin/bash

if [[ "$1" != "-a" || -z "$2" ]]; then
    echo "Utilizare: $0 -a nume_arhiva.tar.gz [-f fisier_directoare] <dir1> <dir2> ..."
    exit 1
fi

archive_name="$2"
shift 2

dirs=()

load_dirs_from_file() {
    while IFS= read -r line; do
        [[ -n "$line" ]] && dirs+=("$line")
    done < "$1"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            if [[ -f "$2" ]]; then
                load_dirs_from_file "$2"
                shift 2
            else
                echo "Fișierul '$2' nu există."
                exit 1
            fi
            ;;
        *)
            dirs+=("$1")
            shift
            ;;
    esac
done

if [[ ${#dirs[@]} -eq 0 ]]; then
    echo "Niciun director specificat."
    exit 1
fi

mkdir -p .metadata

meta_name=$(basename "$archive_name" .tar.gz).meta
meta_file=".metadata/$meta_name"
> "$meta_file"

for dir in "${dirs[@]}"; do
    find "$dir" -type f | while read -r file; do
        checksum=$(sha256sum "$file" | awk '{print $1}')
        perms=$(stat -c "%a" "$file")
        owner=$(stat -c "%u:%g" "$file")
        acl=$(getfacl --absolute-names -p "$file" 2>/dev/null | sha256sum | awk '{print $1}')
        atime=$(stat -c "%X" "$file")
        mtime=$(stat -c "%Y" "$file")
        echo "$file|$checksum|$perms|$owner|$acl|$atime|$mtime"
    done
done >> "$meta_file"

echo "Metadate salvate în: $meta_file"

