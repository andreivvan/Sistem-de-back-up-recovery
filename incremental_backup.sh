#!/bin/bash

encrypt=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e)
            encrypt=true
            shift
            ;;
        *)
            full_backup="$1"
            shift
            ;;
    esac
done

if [[ -z "$full_backup" ]]; then
    echo "Utilizare: $0 [-e] <arhiva_backup_complet>"
    exit 1
fi

original_name=$(basename "$full_backup")
original_name="${original_name%.enc}"
meta_file=".metadata/${original_name%.tar.gz}.meta"

if [[ ! -f "$meta_file" ]]; then
    echo "Nu am gasit fisierul de metadate: $meta_file"
    exit 2
fi

tmp_dir=$(mktemp -d)
user_home="$HOME"

declare -A known_files
declare -A scanned_dirs

while IFS='|' read -r path checksum perms owner acl atime mtime; do
    known_files["$path"]=1
    dir=$(dirname "$path")
    scanned_dirs["$dir"]=1

    if [[ ! -f "$path" ]]; then
        continue
    fi

    new_checksum=$(sha256sum "$path" | awk '{print $1}')
    new_perms=$(stat -c "%a" "$path")
    new_owner=$(stat -c "%u:%g" "$path")
    new_acl=$(getfacl --absolute-names -p "$path" 2>/dev/null | sha256sum | awk '{print $1}')
    new_atime=$(stat -c "%X" "$path")
    new_mtime=$(stat -c "%Y" "$path")

    if [[ "$checksum" != "$new_checksum" || \
          "$perms" != "$new_perms" || \
          "$owner" != "$new_owner" || \
          "$acl" != "$new_acl" || \
          "$atime" != "$new_atime" || \
          "$mtime" != "$new_mtime" ]]; then

        rel_path="${path#$user_home/}"
        dest_path="$tmp_dir/$rel_path"
        mkdir -p "$(dirname "$dest_path")"
        cp "$path" "$dest_path"
    fi
done < "$meta_file"

for base_dir in "${!scanned_dirs[@]}"; do
    if [[ -d "$base_dir" ]]; then
        find "$base_dir" -type d | while read -r subdir; do
            find "$subdir" -maxdepth 1 -type f | while read -r new_file; do
                if [[ -z "${known_files["$new_file"]}" ]]; then
                    rel_path="${new_file#$user_home/}"
                    dest_path="$tmp_dir/$rel_path"
                    mkdir -p "$(dirname "$dest_path")"
                    cp "$new_file" "$dest_path"
                fi
            done
        done
    fi
done

timestamp=$(date +"%Y%m%d_%H%M%S")
inc_archive="incremental_backup_$timestamp.tar.gz"

if [[ "$(find "$tmp_dir" -type f | wc -l)" -gt 0 ]]; then
    tar -czf "$inc_archive" -C "$tmp_dir" .
    echo "Backup incremental creat: $inc_archive"

    if $encrypt; then
        read -s -p "Introdu parola pentru criptare: " pass
        echo
        openssl enc -aes-256-cbc -salt -in "$inc_archive" -out "${inc_archive}.enc" -pass pass:"$pass"
        rm "$inc_archive"
        echo "Backup incremental criptat: ${inc_archive}.enc"
    fi
else
    echo "Nicio modificare sau fisier nou detectat. Arhiva nu a fost creata."
fi

rm -rf "$tmp_dir"

