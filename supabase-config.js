/**
 * ============================================================================
 * KONFIGURASI SUPABASE - MAFIKOM NAMETAG
 * Fakultas Ilmu Komputer - Institut Teknologi Garut (ITG)
 * ============================================================================
 * 
 * PANDUAN PENGISIAN:
 * 1. Buat project baru di https://supabase.com/dashboard
 * 2. Buka Project Settings -> API
 * 3. Salin "Project URL" dan "Project API Keys (anon public)" ke variabel di bawah:
 */

const SUPABASE_CONFIG = {
    // Project URL Supabase
    url: 'https://xlmhmkronjatrychvwjv.supabase.co',

    // Anon / Publishable Public Key Supabase
    anonKey: 'sb_publishable_jRE-MYvG7rtBjEo3KvG5OA_ab0LEcu1',

    // Nama bucket storage di Supabase
    fotoBucket: 'foto-peserta',
    nametagBucket: 'hasil-nametag',

    // Nama tabel database
    tableName: 'peserta_nametag'
};

// Variable instance client Supabase
let _supabaseClient = null;

/**
 * Cek apakah kredensial Supabase sudah diisi dengan benar
 */
function isSupabaseConfigured() {
    return Boolean(
        SUPABASE_CONFIG.url &&
        SUPABASE_CONFIG.anonKey &&
        !SUPABASE_CONFIG.url.includes('YOUR_SUPABASE_PROJECT_URL') &&
        !SUPABASE_CONFIG.anonKey.includes('YOUR_SUPABASE_ANON_KEY')
    );
}

/**
 * Inisialisasi atau ambil instance client Supabase
 */
function getSupabaseClient() {
    if (_supabaseClient) return _supabaseClient;

    if (!isSupabaseConfigured()) {
        console.warn("[Supabase] URL atau Anon Key belum dikonfigurasi di supabase-config.js. Fitur cloud sync dalam mode simulasi.");
        return null;
    }

    if (typeof window.supabase === 'undefined' || !window.supabase.createClient) {
        console.error("[Supabase] Library @supabase/supabase-js belum dimuat di HTML.");
        return null;
    }

    _supabaseClient = window.supabase.createClient(SUPABASE_CONFIG.url, SUPABASE_CONFIG.anonKey);
    return _supabaseClient;
}

/**
 * Mengunggah data peserta, foto formal, dan hasil nametag ke Supabase
 * @param {Object} params
 * @param {string} params.nim - NIM Mahasiswa
 * @param {string} params.nama - Nama Lengkap Mahasiswa
 * @param {string} [params.kelompok] - Kelompok Mahasiswa
 * @param {string} [params.prodi] - Alias kelompok
 * @param {string} params.moto - Moto Hidup
 * @param {Blob} params.fotoBlob - Blob Foto Formal hasil crop
 * @param {Blob} params.nametagBlob - Blob Gambar Nametag PNG hasil generate
 * @returns {Promise<{success: boolean, message: string, data?: any}>}
 */
async function syncParticipantToSupabase({ nim, nama, kelompok, prodi, moto, fotoBlob, nametagBlob }) {
    if (!isSupabaseConfigured()) {
        return {
            success: false,
            configured: false,
            message: 'Supabase belum dikonfigurasi. Masukkan URL dan Anon Key di supabase-config.js.'
        };
    }

    const client = getSupabaseClient();
    if (!client) {
        return {
            success: false,
            configured: false,
            message: 'Gagal menginisialisasi client Supabase.'
        };
    }

    try {
        const cleanNIM = nim.replace(/[^a-zA-Z0-9]/g, '');
        const timestamp = Date.now();

        // 1. UPLOAD FOTO FORMAL KE STORAGE BUCKET 'foto-peserta'
        let fotoPublicUrl = '';
        if (fotoBlob) {
            const fotoPath = `foto_${cleanNIM}_${timestamp}.png`;
            const { error: uploadFotoErr } = await client.storage
                .from(SUPABASE_CONFIG.fotoBucket)
                .upload(fotoPath, fotoBlob, {
                    contentType: 'image/png',
                    upsert: true
                });

            if (uploadFotoErr) {
                console.error("[Supabase] Upload foto formal gagal:", uploadFotoErr);
                throw new Error("Gagal mengunggah foto formal ke storage: " + uploadFotoErr.message);
            }

            const { data: fotoUrlData } = client.storage
                .from(SUPABASE_CONFIG.fotoBucket)
                .getPublicUrl(fotoPath);

            fotoPublicUrl = fotoUrlData.publicUrl;
        }

        // 2. UPLOAD HASIL NAMETAG KE STORAGE BUCKET 'hasil-nametag' (OPSIONAL)
        let nametagPublicUrl = '';
        if (nametagBlob) {
            const nametagPath = `nametag_${cleanNIM}_${timestamp}.png`;
            const { error: uploadNametagErr } = await client.storage
                .from(SUPABASE_CONFIG.nametagBucket)
                .upload(nametagPath, nametagBlob, {
                    contentType: 'image/png',
                    upsert: true
                });

            if (!uploadNametagErr) {
                const { data: nametagUrlData } = client.storage
                    .from(SUPABASE_CONFIG.nametagBucket)
                    .getPublicUrl(nametagPath);
                nametagPublicUrl = nametagUrlData.publicUrl;
            } else {
                console.warn("[Supabase] Upload nametag ke bucket gagal (namun data peserta tetap diproses):", uploadNametagErr);
            }
        }

        // 3. CEK APAKAH MAHASISWA DENGAN NIM INI SUDAH PERNAH MEMBUAT (UNTUK INCREMENT DOWNLOAD COUNT)
        let downloadCount = 1;
        const { data: existingData } = await client
            .from(SUPABASE_CONFIG.tableName)
            .select('download_count, foto_formal_url')
            .eq('nim', nim)
            .maybeSingle();

        if (existingData) {
            downloadCount = (existingData.download_count || 1) + 1;
            // Jika foto baru gagal/kosong, gunakan foto yang sudah ada sebelumnya
            if (!fotoPublicUrl && existingData.foto_formal_url) {
                fotoPublicUrl = existingData.foto_formal_url;
            }
        }

        const kelompokVal = (kelompok || prodi || '').trim().toUpperCase();

        // 4. UPSERT KE TABEL peserta_nametag BERDASARKAN NIM
        const baseRecord = {
            nim: nim.trim(),
            nama_lengkap: nama.trim().toUpperCase(),
            moto_hidup: moto.trim(),
            foto_formal_url: fotoPublicUrl,
            nametag_result_url: nametagPublicUrl || null,
            status_wajah_valid: true,
            download_count: downloadCount,
            user_agent: navigator.userAgent,
            updated_at: new Date().toISOString()
        };

        // Coba simpan dengan kolom 'kelompok'
        let { data: insertedData, error: dbError } = await client
            .from(SUPABASE_CONFIG.tableName)
            .upsert({ ...baseRecord, kelompok: kelompokVal }, { onConflict: 'nim' })
            .select();

        // Fallback jika kolom di tabel DB masih bernama 'nama_prodi_text'
        if (dbError && dbError.message && dbError.message.toLowerCase().includes('kelompok')) {
            console.warn("[Supabase] Kolom 'kelompok' belum ada di DB, mencoba fallback ke 'nama_prodi_text'...");
            const fallbackRes = await client
                .from(SUPABASE_CONFIG.tableName)
                .upsert({ ...baseRecord, nama_prodi_text: kelompokVal }, { onConflict: 'nim' })
                .select();
            insertedData = fallbackRes.data;
            dbError = fallbackRes.error;
        }

        if (dbError) {
            console.error("[Supabase] Gagal menyimpan ke tabel peserta_nametag:", dbError);
            throw new Error("Gagal menyimpan data ke database: " + dbError.message);
        }

        console.log("✓ [Supabase] Data peserta berhasil disinkronkan:", insertedData);
        return {
            success: true,
            configured: true,
            message: 'Data berhasil disimpan ke cloud database Supabase!',
            data: insertedData ? insertedData[0] : record
        };

    } catch (err) {
        console.error("[Supabase Exception]:", err);
        return {
            success: false,
            configured: true,
            message: err.message || 'Terjadi kesalahan saat menyinkronkan data.'
        };
    }
}

// Ekspor ke window agar bisa diakses langsung dari index.html
window.SUPABASE_CONFIG = SUPABASE_CONFIG;
window.isSupabaseConfigured = isSupabaseConfigured;
window.getSupabaseClient = getSupabaseClient;
window.syncParticipantToSupabase = syncParticipantToSupabase;
