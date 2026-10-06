-- ============================================================================
-- DATABASE SCHEMA: MAFIKOM NAMETAG (SQLite)
-- Sangat cocok untuk backend lokal, testing, atau aplikasi mandiri (Node.js/Python)
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- 1. TABEL MASTER: PROGRAM STUDI
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS program_studi (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    kode_prodi TEXT UNIQUE NOT NULL,
    nama_prodi TEXT UNIQUE NOT NULL,
    jenjang TEXT NOT NULL DEFAULT 'S1',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- 2. TABEL UTAMA: PESERTA NAMETAG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS peserta_nametag (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nim TEXT UNIQUE NOT NULL,
    nama_lengkap TEXT NOT NULL,
    program_studi_id INTEGER,
    nama_prodi_text TEXT NOT NULL,
    moto_hidup TEXT NOT NULL,
    foto_formal_url TEXT NOT NULL,
    nametag_result_url TEXT,
    status_wajah_valid INTEGER DEFAULT 1,
    download_count INTEGER DEFAULT 1,
    ip_address TEXT,
    user_agent TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (program_studi_id) REFERENCES program_studi(id) ON DELETE SET NULL
);

-- Indexing
CREATE INDEX IF NOT EXISTS idx_peserta_nim ON peserta_nametag(nim);
CREATE INDEX IF NOT EXISTS idx_peserta_nama ON peserta_nametag(nama_lengkap);
CREATE INDEX IF NOT EXISTS idx_peserta_prodi ON peserta_nametag(nama_prodi_text);
CREATE INDEX IF NOT EXISTS idx_peserta_created ON peserta_nametag(created_at DESC);

-- Trigger untuk updated_at pada SQLite
CREATE TRIGGER IF NOT EXISTS trigger_update_peserta_updated_at
AFTER UPDATE ON peserta_nametag
FOR EACH ROW
BEGIN
    UPDATE peserta_nametag SET updated_at = CURRENT_TIMESTAMP WHERE id = OLD.id;
END;

-- ----------------------------------------------------------------------------
-- 3. VIEW REKAP PESERTA
-- ----------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_rekap_peserta_nametag AS
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
