#!/bin/bash

timestamp=$(date +"%Y%m%d_%H%M%S")
archive_name="full_backup_$timestamp.tar.gz"
dirs=()
encrypt=false

load_dirs_from_file() {
    while IFS= read -r line; do
        [[ -n "$line" ]] && dirs+=("$line")
    done < "$1"
}

if [[ $# -lt 1 ]]; then
    echo "Utilizare: $0 [-e] [-f fisier_directoare] <dir1> <dir2> ..."
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e)
            encrypt=true
            shift
            ;;
        -f)
            if [[ -f "$2" ]]; then
                load_dirs_from_file "$2"
                shift 2
            else
                echo "Fisierul '$2' nu exista."
                exit 1
            fi
            ;;
        *)
            dirs+=("$1")
            shift
            ;;
    esac
done

tmp_dir=$(mktemp -d)

for dir in "${dirs[@]}"; do
    if [[ -d "$dir" ]]; then
        base=$(basename "$dir")
        cp -r "$dir" "$tmp_dir/$base"
    else
        echo "'$dir' nu este un director valid. Se ignora."
    fi
done

tar -czf "$archive_name" -C "$tmp_dir" .
echo "Backup complet creat: $archive_name"

if $encrypt; then
    read -s -p "Introdu parola pentru criptare: " pass
    echo
    openssl enc -aes-256-cbc -salt -in "$archive_name" -out "${archive_name}.enc" -pass pass:"$pass"
    rm "$archive_name"
    echo "Arhiva criptata salvata: ${archive_name}.enc"
    archive_name="${archive_name}.enc"
fi

rm -rf "$tmp_dir"

if [[ -x ./generate_meta.sh ]]; then
    original_archive_name=$(basename "$archive_name" .enc)
    ./generate_meta.sh -a "$original_archive_name" "${dirs[@]}"
    echo "Metadate salvate pentru: $original_archive_name"
else
    echo "Scriptul generate_meta.sh nu este executabil sau nu exista."
fi

