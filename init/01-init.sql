-- Script inisialisasi PostgreSQL
-- File ini akan dijalankan otomatis saat container pertama kali dibuat

-- Membuat extension yang berguna
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Membuat database tambahan
CREATE DATABASE test_db;
CREATE DATABASE development;

-- Membuat role/user tambahan
CREATE ROLE app_user WITH LOGIN PASSWORD 'app_password_123';
CREATE ROLE developer WITH LOGIN PASSWORD 'dev_password_123';
CREATE ROLE readonly WITH LOGIN PASSWORD 'readonly_password_123';

-- Grant privileges
GRANT CONNECT ON DATABASE my_database TO app_user;
GRANT CONNECT ON DATABASE development TO developer;
GRANT CONNECT ON DATABASE test_db TO developer;
GRANT CONNECT ON DATABASE my_database TO readonly;

-- Connect to my_database untuk membuat tabel
\c my_database;

-- Grant schema privileges
GRANT USAGE ON SCHEMA public TO app_user;
GRANT CREATE ON SCHEMA public TO app_user;
GRANT USAGE ON SCHEMA public TO developer;
GRANT CREATE ON SCHEMA public TO developer;
GRANT USAGE ON SCHEMA public TO readonly;

-- Membuat tabel contoh
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    slug VARCHAR(200) UNIQUE,
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    published_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS post_categories (
    post_id UUID REFERENCES posts(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (post_id, category_id)
);

-- Membuat index untuk performa
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status);
CREATE INDEX IF NOT EXISTS idx_posts_published_at ON posts(published_at);
CREATE INDEX IF NOT EXISTS idx_posts_slug ON posts(slug);

-- Membuat function untuk update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Membuat trigger untuk auto update timestamp
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_posts_updated_at 
    BEFORE UPDATE ON posts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Insert data contoh
INSERT INTO users (username, email, password_hash, first_name, last_name) VALUES 
('admin', 'admin@example.com', crypt('admin123', gen_salt('bf')), 'Admin', 'User'),
('john_doe', 'john@example.com', crypt('user123', gen_salt('bf')), 'John', 'Doe'),
('jane_smith', 'jane@example.com', crypt('user123', gen_salt('bf')), 'Jane', 'Smith')
ON CONFLICT (username) DO NOTHING;

INSERT INTO categories (name, description) VALUES 
('Technology', 'Posts about technology and programming'),
('Lifestyle', 'Posts about lifestyle and daily life'),
('Business', 'Posts about business and entrepreneurship')
ON CONFLICT (name) DO NOTHING;

-- Insert posts dengan referensi ke user yang ada
WITH admin_user AS (
    SELECT id FROM users WHERE username = 'admin' LIMIT 1
),
john_user AS (
    SELECT id FROM users WHERE username = 'john_doe' LIMIT 1
)
INSERT INTO posts (user_id, title, content, slug, status, published_at) 
SELECT 
    admin_user.id,
    'Welcome to Our Platform',
    'This is a welcome post from the admin. We are excited to have you here!',
    'welcome-to-our-platform',
    'published',
    CURRENT_TIMESTAMP
FROM admin_user
UNION ALL
SELECT 
    john_user.id,
    'My First Blog Post',
    'This is my first blog post. I am excited to share my thoughts with everyone.',
    'my-first-blog-post',
    'published',
    CURRENT_TIMESTAMP
FROM john_user
UNION ALL
SELECT 
    john_user.id,
    'Draft Post',
    'This is still a work in progress...',
    'draft-post',
    'draft',
    NULL
FROM john_user
ON CONFLICT (slug) DO NOTHING;

-- Grant table privileges
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO developer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO developer;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- Grant default privileges untuk tabel yang akan dibuat di masa depan
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO developer;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO developer;

ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;