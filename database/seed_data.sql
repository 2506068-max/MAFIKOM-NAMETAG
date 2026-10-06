-- ============================================================================
-- SEED DATA CONTOH: PROGRAM STUDI & PESERTA MAFIKOM
-- ============================================================================

-- 1. Insert Data Master Program Studi Fakultas Ilmu Komputer ITG
INSERT INTO program_studi (kode_prodi, nama_prodi, jenjang, is_active) VALUES
('IF', 'Teknik Informatika', 'S1', 1),
('SI', 'Sistem Informasi', 'S1', 1),
('BD', 'Bisnis Digital', 'S1', 1);

-- 2. Insert Contoh Data Peserta Nametag
INSERT INTO peserta_nametag (
    nim, 
    nama_lengkap, 
    program_studi_id, 
    nama_prodi_text, 
    moto_hidup, 
    foto_formal_url, 
    nametag_result_url, 
    status_wajah_valid, 
    download_count
) VALUES
(
    '2406001', 
    'AHMAD FAUZI', 
    1, 
    'TEKNIK INFORMATIKA', 
    '"Pantang Menyerah, Raih Prestasi"', 
    'https://storage.example.com/mafikom/uploads/2406001_formal.png', 
    'https://storage.example.com/mafikom/results/MAFIKOM-NAMETAG-AHMAD-FAUZI.png', 
    1, 
    1
),
(
    '2406002', 
    'SITI NURHALIZA', 
    2, 
    'SISTEM INFORMASI', 
    '"Belajar Tiada Henti Demi Masa Depan"', 
    'https://storage.example.com/mafikom/uploads/2406002_formal.png', 
    'https://storage.example.com/mafikom/results/MAFIKOM-NAMETAG-SITI-NURHALIZA.png', 
    1, 
    2
);
