-- ============================================================================
-- DATABASE SCHEMA: MAFIKOM NAMETAG (MySQL / MariaDB / phpMyAdmin / XAMPP)
-- Fakultas Ilmu Komputer - Institut Teknologi Garut (ITG)
-- ============================================================================

CREATE DATABASE IF NOT EXISTS db_mafikom_nametag
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE db_mafikom_nametag;

-- ----------------------------------------------------------------------------
-- 1. TABEL MASTER: PROGRAM STUDI
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS program_studi (
    id INT AUTO_INCREMENT PRIMARY KEY,
    kode_prodi VARCHAR(10) NOT NULL UNIQUE,
    nama_prodi VARCHAR(100) NOT NULL UNIQUE,
    jenjang VARCHAR(10) NOT NULL DEFAULT 'S1',
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 2. TABEL UTAMA: PESERTA NAMETAG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS peserta_nametag (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nim VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    program_studi_id INT NULL,
    nama_prodi_text VARCHAR(100) NOT NULL,
    moto_hidup TEXT NOT NULL,
    
    -- URL / Path File (Foto formal & Hasil generate PNG)
    foto_formal_url VARCHAR(500) NOT NULL,
    nametag_result_url VARCHAR(500) NULL,
    
    -- Status & Audit Log
    status_wajah_valid TINYINT(1) DEFAULT 1,
    download_count INT DEFAULT 1,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    
    -- Timestamp
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- Relasi & Index
    CONSTRAINT fk_peserta_prodi FOREIGN KEY (program_studi_id) 
        REFERENCES program_studi(id) ON DELETE SET NULL,
    INDEX idx_peserta_nim (nim),
    INDEX idx_peserta_nama (nama_lengkap),
    INDEX idx_peserta_prodi (nama_prodi_text),
    INDEX idx_peserta_created (created_at DESC)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ----------------------------------------------------------------------------
-- 3. VIEW LAPORAN REKAP PESERTA UNTUK PANITIA
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

-- Statistik Peserta per Jurusan / Prodi
CREATE OR REPLACE VIEW view_statistik_prodi AS
SELECT 
    COALESCE(ps.nama_prodi, p.nama_prodi_text) AS program_studi,
    COUNT(*) AS total_peserta,
    SUM(p.download_count) AS total_download
FROM peserta_nametag p
LEFT JOIN program_studi ps ON p.program_studi_id = ps.id
GROUP BY COALESCE(ps.nama_prodi, p.nama_prodi_text)
ORDER BY total_peserta DESC;
