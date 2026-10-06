-- ============================================================================
-- DATABASE SCHEMA: MAFIKOM NAMETAG (PostgreSQL / Supabase)
-- Fakultas Ilmu Komputer - Institut Teknologi Garut (ITG)
-- ============================================================================

-- Ekstensi UUID (bawaan Supabase / PostgreSQL)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. TABEL MASTER: PROGRAM STUDI
-- Menyimpan daftar program studi resmi di lingkungan FIKOM ITG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS program_studi (
    id SERIAL PRIMARY KEY,
    kode_prodi VARCHAR(10) UNIQUE NOT NULL,
    nama_prodi VARCHAR(100) UNIQUE NOT NULL,
    jenjang VARCHAR(10) NOT NULL DEFAULT 'S1',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. TABEL UTAMA: PESERTA NAMETAG
-- Menyimpan data input nametag tiap mahasiswa
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS peserta_nametag (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nim VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    program_studi_id INT REFERENCES program_studi(id) ON DELETE SET NULL,
    nama_prodi_text VARCHAR(100) NOT NULL, -- Menyimpan input asli teks prodi dari form
    moto_hidup TEXT NOT NULL,
    
    -- Penyimpanan URL/path aset (bukan binary langsung di database)
    foto_formal_url TEXT NOT NULL,
    nametag_result_url TEXT,
    
    -- Status & Metadata
    status_wajah_valid BOOLEAN DEFAULT TRUE,
    download_count INT DEFAULT 1,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Timestamp Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 3. INDEXING UNTUK OPTIMASI QUERY CEPAT
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_peserta_nim ON peserta_nametag(nim);
CREATE INDEX IF NOT EXISTS idx_peserta_nama ON peserta_nametag(nama_lengkap);
CREATE INDEX IF NOT EXISTS idx_peserta_prodi ON peserta_nametag(nama_prodi_text);
CREATE INDEX IF NOT EXISTS idx_peserta_created ON peserta_nametag(created_at DESC);

-- ----------------------------------------------------------------------------
-- 4. TRIGGER: AUTO-UPDATE FIELD updated_at
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_peserta_updated_at ON peserta_nametag;
CREATE TRIGGER trigger_update_peserta_updated_at
BEFORE UPDATE ON peserta_nametag
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ----------------------------------------------------------------------------
-- 5. VIEW LAPORAN REKAP UNTUK PANITIA
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW view_rekap_peserta_nametag AS
SELECT 
    p.id,
    p.nim,
    p.nama_lengkap,
    COALESCE(ps.nama_prodi, p.nama_prodi_text) AS program_studi,
    p.moto_hidup,
    p.foto_formal_url,
    p.download_count,
    p.created_at,
    p.updated_at
FROM peserta_nametag p
LEFT JOIN program_studi ps ON p.program_studi_id = ps.id
ORDER BY p.created_at DESC;

-- Statistik per program studi
CREATE OR REPLACE VIEW view_statistik_prodi AS
SELECT 
    COALESCE(ps.nama_prodi, p.nama_prodi_text) AS program_studi,
    COUNT(*) AS total_peserta,
    SUM(p.download_count) AS total_download
FROM peserta_nametag p
LEFT JOIN program_studi ps ON p.program_studi_id = ps.id
GROUP BY COALESCE(ps.nama_prodi, p.nama_prodi_text)
ORDER BY total_peserta DESC;
