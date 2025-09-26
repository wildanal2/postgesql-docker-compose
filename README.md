# Setup PostgreSQL dengan Docker

Setup ini menyediakan PostgreSQL server dengan pgAdmin4 untuk management database menggunakan Docker Compose.

## Struktur Folder

```
postgresql/
├── docker-compose.yml
├── conf/
│   └── postgresql.conf
├── init/
│   └── 01-init.sql
├── pgadmin/
│   └── servers.json
├── data/                 (akan dibuat otomatis)
└── README.md
```

## Konfigurasi Default

### Database Credentials
- **Database**: `my_database`
- **Superuser**: `postgres` / `postgres_password_123`
- **App User**: `app_user` / `app_password_123`
- **Developer**: `developer` / `dev_password_123`
- **Read Only**: `readonly` / `readonly_password_123`

### pgAdmin4 Credentials
- **Email**: `admin@example.com`
- **Password**: `admin_password_123`

### Ports
- **PostgreSQL**: `5432`
- **pgAdmin4**: `8081`

## Cara Menjalankan

1. **Clone atau buat folder postgresql**
   ```bash
   mkdir postgresql && cd postgresql
   ```

2. **Buat struktur folder**
   ```bash
   mkdir -p conf init pgadmin
   ```

3. **Copy semua file konfigurasi ke folder yang sesuai**
   - `docker-compose.yml` di root folder
   - `postgresql.conf` di folder `conf/`
   - `01-init.sql` di folder `init/`
   - `servers.json` di folder `pgadmin/`

4. **Jalankan container**
   ```bash
   docker compose up -d
   ```

5. **Cek status container**
   ```bash
   docker compose ps
   ```

## Akses Database

### Via psql Client
```bash
psql -h localhost -p 5432 -U app_user -d my_database
# Password: app_password_123
```

### Via pgAdmin4
- Buka browser: `http://localhost:8081`
- Email: `admin@example.com`
- Password: `admin_password_123`
- Server sudah terkonfigurasi otomatis

### Via Docker Exec
```bash
docker exec -it postgres_server psql -U postgres -d my_database
```

## Database yang Tersedia

- **my_database** - Database utama aplikasi
- **development** - Database untuk development
- **test_db** - Database untuk testing
- **postgres** - Database sistem default

## Volume dan Data Persistence

Data PostgreSQL disimpan dalam Docker volume:
- `postgres_data` - Data database PostgreSQL
- `pgadmin_data` - Konfigurasi dan data pgAdmin4

### Backup Database
```bash
# Backup single database
docker exec postgres_server pg_dump -U postgres my_database > backup_my_database.sql

# Backup semua database
docker exec postgres_server pg_dumpall -U postgres > backup_all.sql
```

### Restore Database
```bash
# Restore single database
docker exec -i postgres_server psql -U postgres -d my_database < backup_my_database.sql

# Restore semua database
docker exec -i postgres_server psql -U postgres < backup_all.sql
```

## Extensions yang Tersedia

Setup ini sudah menginstall beberapa extension berguna:
- **uuid-ossp** - Generate UUID
- **pg_stat_statements** - Query statistics
- **pgcrypto** - Cryptographic functions
- **vector** - Vector similarity search (PGVector)

## Commands Berguna

### Menghentikan Services
```bash
docker compose down
```

### Menghentikan dan Menghapus Volume
```bash
docker compose down -v
```

### Melihat Logs
```bash
docker compose logs postgres
docker compose logs pgadmin
```

### Restart Services
```bash
docker compose restart
```

### Update Images
```bash
docker compose pull
docker compose up -d
```

### Akses PostgreSQL Shell
```bash
docker exec -it postgres_server psql -U postgres
```

## Monitoring dan Performance

### Melihat Query Statistics
```sql
-- Connect sebagai superuser
SELECT query, calls, total_time, mean_time 
FROM pg_stat_statements 
ORDER BY total_time DESC 
LIMIT 10;
```

### Melihat Database Size
```sql
SELECT 
    datname as database_name,
    pg_size_pretty(pg_database_size(datname)) as size
FROM pg_database
WHERE datistemplate = false;
```

### Melihat Table Size
```sql
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

## Troubleshooting

### Port 5432 sudah digunakan
Edit `docker-compose.yml` dan ubah port:
```yaml
ports:
  - "5433:5432"  # Gunakan port 5433 di host
```

### Permission Issues
```bash
docker compose down
docker volume rm postgresql_postgres_data postgresql_pgadmin_data
docker compose up -d
```

### Connection Issues
1. Pastikan container berjalan: `docker compose ps`
2. Check logs: `docker compose logs postgres`
3. Test connection: `docker exec postgres_server pg_isready`

### pgAdmin4 tidak bisa connect
1. Pastikan menggunakan hostname `postgres` bukan `localhost`
2. Check network: `docker network ls`
3. Reset pgAdmin data jika perlu

## Security Notes

- Ganti semua password default sebelum production
- Gunakan `.env` file untuk menyimpan credentials
- Aktifkan SSL untuk koneksi production
- Regular backup data penting
- Monitor query performance dengan pg_stat_statements

## Environment Variables

Untuk keamanan yang lebih baik, buat file `.env`:

```env
POSTGRES_DB=your_database_name
POSTGRES_USER=postgres
POSTGRES_PASSWORD=your_secure_password
PGADMIN_DEFAULT_EMAIL=your_email@example.com
PGADMIN_DEFAULT_PASSWORD=your_secure_admin_password
```

Kemudian update `docker-compose.yml` untuk menggunakan variables ini.

## Advanced Configuration

### Connection Pooling dengan PgBouncer
Untuk production, pertimbangkan menambahkan PgBouncer untuk connection pooling.

### Replication Setup
PostgreSQL mendukung streaming replication untuk high availability.

### Monitoring dengan pg_stat_monitor
Extension tambahan untuk monitoring yang lebih detail.

## Upgrade ke PostgreSQL 17 dengan Vector Support

Setup ini telah diperbarui ke PostgreSQL 17 dengan dukungan PGVector untuk similarity search berbasis vektor.

### Fitur Vector
PGVector menyediakan tipe data dan fungsi untuk menyimpan dan mencari vektor embedding, berguna untuk:
- Semantic search
- Similarity search
- Machine learning applications
- Recommendation systems

Contoh penggunaan:
```sql
-- Membuat tabel dengan kolom vektor
CREATE TABLE items (
  id SERIAL PRIMARY KEY,
  embedding vector(3);  -- vektor dengan 3 dimensi
);

-- Menambahkan data
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');

-- Melakukan cosine similarity search
SELECT * FROM items ORDER BY embedding <=> '[3,3,3]' LIMIT 5;
```

### Upgrade dari Versi Sebelumnya
Karena kita upgrade dari PostgreSQL 15 ke 17, kita perlu melakukan migrasi data karena versi major berbeda. Data lama tidak bisa langsung digunakan.

Untuk melakukan upgrade dari PostgreSQL 15 ke 17 dengan tetap mempertahankan data:

1. Stop container lama:
   ```bash
   docker compose down
   ```

2. Backup semua database:
   ```bash
   # Jika container masih bisa diakses sebelum upgrade:
   docker exec postgres_server pg_dumpall -U postgres > backup.sql
   ```
   
   Jika container tidak bisa dijalankan karena inkompatibilitas, Anda bisa membuat container sementara dengan PostgreSQL 15 image untuk mengambil backup:
   ```bash
   # Buat container sementara dengan PostgreSQL 15
   docker run --rm -v postgresql_postgres_data:/var/lib/postgresql/data -e POSTGRES_DB=postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres_password_123 postgres:15
   # Tapi cara ini lebih kompleks, jadi lebih baik backup sebelum upgrade
   ```

3. Remove volume lama (ini akan menghapus data PostgreSQL 15):
   ```bash
   docker volume rm postgresql_postgres_data
   ```

4. Update docker-compose.yml ke PostgreSQL 17 (sudah dilakukan)

5. Jalankan container baru:
   ```bash
   docker compose up -d
   ```

6. Restore data dari backup:
   ```bash
   docker exec -i postgres_server psql -U postgres < backup.sql
   ```

Catatan: Proses upgrade major version PostgreSQL memerlukan dump dan restore karena struktur file internal berbeda antar versi major.