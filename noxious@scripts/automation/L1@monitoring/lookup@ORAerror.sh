#!/bin/bash
# Nama File: lookup@oraerror.sh
# Lokasi: /home/oracle/noxious@scripts/automation/L1@action/
# Fungsi: Menampilkan penjelasan dan solusi berdasarkan kode ORA error

ERROR_DB="/home/oracle/noxious@scripts/automation/ORAinventory/ORA_error_db.txt"

lookup_error() {
    clear
    echo "=============================================="
    echo "           ORACLE ERROR LOOKUP TOOL"
    echo "=============================================="
    read -p "Masukkan kode error Oracle (contoh: ORA-16014): " kode

    if [[ $kode =~ ^ORA-[0-9]+$ ]]; then
        if grep -q "^$kode" "$ERROR_DB"; then
            echo -e "\n📌 Hasil pencarian untuk $kode:\n"
            grep -A 3 "^$kode" "$ERROR_DB"
        else
            echo -e "\n❌ Kode ORA $kode tidak ditemukan dalam database lokal."
        fi
    else
        echo -e "\n❌ Format kode tidak valid. Contoh yang benar: ORA-16014"
    fi

    echo -e "\nTekan [ENTER] untuk kembali ke menu utama..."
    read
}

# Eksekusi fungsi
lookup_error

