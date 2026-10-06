-- ============================================================================
-- SETUP LENGKAP SUPABASE: MAFIKOM NAMETAG
-- Fakultas Ilmu Komputer - Institut Teknologi Garut (ITG)
-- 
-- CARA PENGGUNAAN:
-- 1. Buka Dashboard Supabase Anda (https://supabase.com/dashboard)
-- 2. Pilih Project Anda -> Buka menu "SQL Editor" di bilah kiri
-- 3. Tempel (Paste) seluruh isi script ini dan klik tombol "Run"
-- ============================================================================

-- Ekstensi UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ----------------------------------------------------------------------------
-- 1. TABEL UTAMA: PESERTA NAMETAG
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.peserta_nametag (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nim VARCHAR(20) NOT NULL UNIQUE,
    nama_lengkap VARCHAR(150) NOT NULL,
    kelompok VARCHAR(100) NOT NULL,
    moto_hidup TEXT NOT NULL,
    
    -- URL Aset di Supabase Storage
    foto_formal_url TEXT NOT NULL,
    nametag_result_url TEXT,
    
    -- Status & Metadata
    status_wajah_valid BOOLEAN DEFAULT TRUE,
    download_count INT DEFAULT 1,
    ip_address VARCHAR(45),
    user_agent TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Migrasi aman jika tabel sebelumnya dibuat dengan nama_prodi_text
ALTER TABLE public.peserta_nametag ADD COLUMN IF NOT EXISTS kelompok VARCHAR(100);

-- Indexing
CREATE INDEX IF NOT EXISTS idx_peserta_nim ON public.peserta_nametag(nim);
CREATE INDEX IF NOT EXISTS idx_peserta_nama ON public.peserta_nametag(nama_lengkap);
CREATE INDEX IF NOT EXISTS idx_peserta_kelompok ON public.peserta_nametag(kelompok);
CREATE INDEX IF NOT EXISTS idx_peserta_created ON public.peserta_nametag(created_at DESC);

-- Trigger auto update updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_peserta_updated_at ON public.peserta_nametag;
CREATE TRIGGER trigger_peserta_updated_at
BEFORE UPDATE ON public.peserta_nametag
FOR EACH ROW
EXECUTE FUNCTION public.handle_updated_at();

-- ----------------------------------------------------------------------------
-- 2. KONFIGURASI STORAGE BUCKETS (Foto & Hasil Nametag)
-- ----------------------------------------------------------------------------
-- Buat bucket 'foto-peserta' (publik agar bisa diakses langsung lewat URL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('foto-peserta', 'foto-peserta', true)
ON CONFLICT (id) DO NOTHING;

-- Buat bucket 'hasil-nametag' (publik untuk arsip hasil generate)
INSERT INTO storage.buckets (id, name, public)
VALUES ('hasil-nametag', 'hasil-nametag', true)
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) POLICIES
-- Agar aplikasi web di browser (pengunjung umum/anon) bisa upload & simpan
-- ----------------------------------------------------------------------------

-- A. RLS Tabel peserta_nametag
ALTER TABLE public.peserta_nametag ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow anon read" ON public.peserta_nametag;
CREATE POLICY "Allow anon read"
ON public.peserta_nametag FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "Allow anon insert" ON public.peserta_nametag;
CREATE POLICY "Allow anon insert"
ON public.peserta_nametag FOR INSERT
TO anon, authenticated
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow anon update" ON public.peserta_nametag;
CREATE POLICY "Allow anon update"
ON public.peserta_nametag FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- B. RLS Storage 'foto-peserta'
DROP POLICY IF EXISTS "Public Read Foto" ON storage.objects;
CREATE POLICY "Public Read Foto"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'foto-peserta');

DROP POLICY IF EXISTS "Public Upload Foto" ON storage.objects;
CREATE POLICY "Public Upload Foto"
ON storage.objects FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'foto-peserta');

DROP POLICY IF EXISTS "Public Update Foto" ON storage.objects;
CREATE POLICY "Public Update Foto"
ON storage.objects FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'foto-peserta');

-- C. RLS Storage 'hasil-nametag'
DROP POLICY IF EXISTS "Public Read Nametag" ON storage.objects;
CREATE POLICY "Public Read Nametag"
ON storage.objects FOR SELECT
TO anon, authenticated
USING (bucket_id = 'hasil-nametag');

DROP POLICY IF EXISTS "Public Upload Nametag" ON storage.objects;
CREATE POLICY "Public Upload Nametag"
ON storage.objects FOR INSERT
TO anon, authenticated
WITH CHECK (bucket_id = 'hasil-nametag');

DROP POLICY IF EXISTS "Public Update Nametag" ON storage.objects;
CREATE POLICY "Public Update Nametag"
ON storage.objects FOR UPDATE
TO anon, authenticated
USING (bucket_id = 'hasil-nametag');

-- ----------------------------------------------------------------------------
-- 4. VIEW REKAPITULASI DATA UNTUK PANITIA
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.view_rekap_peserta AS
SELECT 
    id,
    nim,
    nama_lengkap,
    COALESCE(kelompok, nama_prodi_text) AS kelompok,
    moto_hidup,
    foto_formal_url,
    nametag_result_url,
    download_count,
    created_at,
    updated_at
FROM public.peserta_nametag
ORDER BY created_at DESC;

-- Statistik per kelompok
CREATE OR REPLACE VIEW public.view_statistik_kelompok AS
SELECT 
    COALESCE(kelompok, nama_prodi_text) AS kelompok,
    COUNT(*) AS total_peserta,
    SUM(download_count) AS total_download
FROM public.peserta_nametag
GROUP BY COALESCE(kelompok, nama_prodi_text)
ORDER BY total_peserta DESC;
