-- ============================================================================
-- SCRIPT RESET DATA: MAFIKOM NAMETAG
-- Menghapus seluruh data peserta dan file foto di Supabase
-- 
-- CARA PENGGUNAAN:
-- 1. Buka Dashboard Supabase: https://supabase.com/dashboard/project/xlmhmkronjatrychvwjv/sql
-- 2. Klik "New Query", tempel script ini lalu klik "Run"
-- ============================================================================

-- 1. Kosongkan seluruh data tabel peserta_nametag
TRUNCATE TABLE public.peserta_nametag RESTART IDENTITY CASCADE;

-- 2. Kosongkan seluruh file foto formal dan hasil nametag di Storage
DELETE FROM storage.objects 
WHERE bucket_id IN ('foto-peserta', 'hasil-nametag');

-- Selesai! Seluruh database dan storage kini bersih kembali.
