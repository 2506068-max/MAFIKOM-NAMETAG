/**
 * CONTOH IMPLEMENTASI BACKEND SEDERHANA (Node.js + Express)
 * Untuk menerima data formulir dari index.html MAFIKOM NAMETAG
 * 
 * Dependensi yang dibutuhkan:
 * npm install express multer cors sqlite3
 */

const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const sqlite3 = require('sqlite3').verbose();

const app = express();
const PORT = process.env.PORT || 3000;

// Konfigurasi Penyimpanan File Foto
const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) {
    fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, uploadDir),
    filename: (req, file, cb) => {
        const nim = req.body.nim || 'unknown';
        const ext = path.extname(file.originalname) || '.png';
        cb(null, `foto_${nim}_${Date.now()}${ext}`);
    }
});

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 } // Maksimal 5MB
});

// Database SQLite
const db = new sqlite3.Database(path.join(__dirname, 'mafikom.db'), (err) => {
    if (err) console.error("Gagal koneksi database:", err.message);
    else console.log("Terhubung ke database SQLite.");
});

// Buat tabel jika belum ada
db.run(`
    CREATE TABLE IF NOT EXISTS peserta_nametag (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nim TEXT UNIQUE NOT NULL,
        nama_lengkap TEXT NOT NULL,
        nama_prodi_text TEXT NOT NULL,
        moto_hidup TEXT NOT NULL,
        foto_formal_url TEXT NOT NULL,
        download_count INTEGER DEFAULT 1,
        ip_address TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
`);

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/uploads', express.static(uploadDir));

// Endpoint POST: Simpan atau Perbarui Data Peserta
app.post('/api/peserta', upload.single('foto'), (req, res) => {
    try {
        const { nim, nama, prodi, moto } = req.body;

        if (!nim || !nama || !prodi || !moto) {
            return res.status(400).json({ success: false, message: 'Semua field wajib diisi!' });
        }

        const fotoUrl = req.file ? `/uploads/${req.file.filename}` : '';
        const ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;

        const query = `
            INSERT INTO peserta_nametag (nim, nama_lengkap, nama_prodi_text, moto_hidup, foto_formal_url, ip_address)
            VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(nim) DO UPDATE SET
                nama_lengkap = excluded.nama_lengkap,
                nama_prodi_text = excluded.nama_prodi_text,
                moto_hidup = excluded.moto_hidup,
                foto_formal_url = COALESCE(NULLIF(excluded.foto_formal_url, ''), peserta_nametag.foto_formal_url),
                download_count = peserta_nametag.download_count + 1,
                updated_at = CURRENT_TIMESTAMP
        `;

        db.run(query, [nim, nama, prodi, moto, fotoUrl, ip], function(err) {
            if (err) {
                console.error("Database error:", err.message);
                return res.status(500).json({ success: false, message: 'Gagal menyimpan ke database' });
            }
            res.json({
                success: true,
                message: 'Data berhasil disimpan!',
                data: { id: this.lastID, nim, nama, prodi, fotoUrl }
            });
        });
    } catch (e) {
        res.status(500).json({ success: false, message: e.message });
    }
});

// Endpoint GET: Rekap Peserta untuk Panitia
app.get('/api/peserta', (req, res) => {
    db.all(`SELECT * FROM peserta_nametag ORDER BY created_at DESC`, [], (err, rows) => {
        if (err) return res.status(500).json({ success: false, message: err.message });
        res.json({ success: true, total: rows.length, data: rows });
    });
});

app.listen(PORT, () => {
    console.log(`Server API MAFIKOM berjalan di http://localhost:${PORT}`);
});
