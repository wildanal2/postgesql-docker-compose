#!/bin/bash

# Script untuk migrasi data dari PostgreSQL 15 ke PostgreSQL 17
# Dengan dukungan PGVector

set -e  # Exit jika ada error

echo "=== Migrasi Data dari PostgreSQL 15 ke PostgreSQL 17 ==="
echo ""

# Cek apakah docker compose sedang berjalan
if [ "$(docker compose ps -q)" ]; then
    echo "Menghentikan container yang sedang berjalan..."
    docker compose down
fi

# Backup data dari volume PostgreSQL 15 (jika volume lama masih ada)
echo "Membuat backup dari data PostgreSQL 15 (jika tersedia)..."
VOLUME_NAME="postgesql-docker-compose_postgres_data"

# Cek apakah volume sudah ada
if docker volume ls | grep -q "$VOLUME_NAME"; then
    echo "Volume $VOLUME_NAME ditemukan. Membuat backup..."
    
    # Jalankan container sementara dengan PostgreSQL 15 untuk backup
    echo "Menjalankan container PostgreSQL 15 sementara untuk backup..."
    docker run --rm \
        -v "$VOLUME_NAME:/var/lib/postgresql/data" \
        -v "$(pwd)/backup:/backup" \
        -e PGPASSWORD=postgres_password_123 \
        postgres:15 \
        bash -c "pg_dump -U postgres -d my_database > /backup/my_database.sql && pg_dumpall -U postgres > /backup/all_databases.sql"
    
    echo "Backup berhasil disimpan di folder backup/"
else
    echo "Volume PostgreSQL lama tidak ditemukan, memulai dengan data kosong."
fi

# Hapus volume lama (karena tidak kompatibel dengan PostgreSQL 17)
echo "Menghapus volume lama yang tidak kompatibel..."
docker volume rm "$VOLUME_NAME" 2>/dev/null || echo "Volume lama tidak ditemukan atau sudah dihapus"

# Jalankan PostgreSQL 17 dengan PGVector
echo "Menjalankan PostgreSQL 17 dengan PGVector..."
docker compose up -d postgres

# Tunggu beberapa detik sampai PostgreSQL siap
echo "Menunggu PostgreSQL 17 siap..."
sleep 15

# Cek apakah PostgreSQL 17 sudah siap
if docker exec postgres_server pg_isready > /dev/null 2>&1; then
    echo "PostgreSQL 17 siap!"
else
    echo "Error: PostgreSQL 17 tidak siap setelah 15 detik. Mencoba lagi..."
    sleep 15
    if docker exec postgres_server pg_isready > /dev/null 2>&1; then
        echo "PostgreSQL 17 siap!"
    else
        echo "Error: PostgreSQL 17 tidak bisa diakses. Silakan cek log:"
        docker logs postgres_server
        exit 1
    fi
fi

# Jika backup ada, restore data
if [ -f "backup/all_databases.sql" ]; then
    echo "Merestore data dari backup..."
    docker exec -i postgres_server psql -U postgres < backup/all_databases.sql
    
    echo "Verifikasi data yang di-restore..."
    docker exec postgres_server psql -U postgres -d my_database -c "\dt"
    
    echo "Migrasi berhasil! PostgreSQL 17 dengan PGVector sekarang berjalan."
    echo "Database yang tersedia:"
    docker exec postgres_server psql -U postgres -c "\l"
else
    echo "Tidak ada backup ditemukan, PostgreSQL 17 dengan PGVector siap digunakan dari awal."
fi

# Jalankan pgadmin juga
echo "Menjalankan pgAdmin..."
docker compose up -d pgadmin

echo ""
echo "=== Migrasi Selesai ==="
echo "PostgreSQL 17 dengan PGVector sekarang berjalan!"
echo "Port PostgreSQL: 5432"
echo "Port pgAdmin: 8081"
echo ""
echo "Untuk mengakses PostgreSQL:"
echo "  psql -h localhost -p 5432 -U postgres -d my_database"
echo ""
echo "Untuk menguji PGVector:"
echo " docker exec -it postgres_server psql -U postgres -d my_database -c \"CREATE TABLE test_vector (id SERIAL PRIMARY KEY, embedding vector(3));\""