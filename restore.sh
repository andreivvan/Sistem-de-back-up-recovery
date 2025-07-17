#!/bin/bash

if [[ $# -lt 1 ]]; then
    echo "Utilizare: $0 <arhiva_completa> [arhiva_incrementala]"
    exit 1
fi

full_backup="$1"
incremental_backup="$2"
cleanup_encrypted=false

timestamp=$(date +"%Y%m%d_%H%M%S")
restore_dir="restore_$timestamp"
mkdir -p "$restore_dir"

if [[ "$full_backup" == *.enc ]]; then
    echo "Arhiva completa criptata detectata: $full_backup"
    read -s -p "Introdu parola pentru decriptare: " pass
    echo
    tmp_decrypted="decrypted_$(basename "${full_backup%.enc}")"
    openssl enc -d -aes-256-cbc -in "$full_backup" -out "$tmp_decrypted" -pass pass:"$pass"
    if [[ $? -ne 0 ]]; then
        echo "Decriptare esuata. Verifica parola."
        exit 1
    fi
    full_backup="$tmp_decrypted"
    cleanup_encrypted=true
fi

echo "Se extrage arhiva completa în $restore_dir/"
tar -xzf "$full_backup" -C "$restore_dir"

if [[ -n "$incremental_backup" ]]; then

        if [[ "$incremental_backup" == *.enc ]]; then
        echo "Arhiva incrementala criptata detectata: $incremental_backup"
        read -s -p "Introdu parola pentru decriptare: " pass
        echo
        tmp_inc_decrypted="decrypted_$(basename "${incremental_backup%.enc}")"
        openssl enc -d -aes-256-cbc -in "$incremental_backup" -out "$tmp_inc_decrypted" -pass pass:"$pass"
        if [[ $? -ne 0 ]]; then
            echo "Decriptare esuata. Verifica parola."
            exit 1
        fi
        incremental_backup="$tmp_inc_decrypted"
        cleanup_inc=true
    fi

    echo "Se aplica arhiva incrementala în $restore_dir/"
    tar -xzf "$incremental_backup" -C "$restore_dir"
fi

if [[ "$cleanup_encrypted" == true ]]; then
    rm -f "$full_backup"
fi
if [[ "$cleanup_inc" == true ]]; then
    rm -f "$incremental_backup"
fi

echo "Restaurare completa in: $restore_dir"

