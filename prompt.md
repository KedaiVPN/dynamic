# Prompt Pengembangan License Manager API (Vercel)

Anda (AI) diminta untuk membuat sebuah proyek **REST API License Manager** terpisah yang akan di-deploy ke **Vercel** menggunakan **Node.js (Express atau Next.js API Routes)**. Sistem lisensi ini akan menggunakan arsitektur **Event-Driven (Webhook)** untuk melakukan sinkronisasi dengan server VPN (VPS) klien.

## Spesifikasi Teknis

1. **Database (Wajib menggunakan Turso / libSQL):**
   - Gunakan database **Turso** karena gratis, tidak ada masa pause/sleep, dan sangat cepat (Edge SQLite).
   - Package npm yang digunakan: `@libsql/client`
   - Skema tabel utama SQLite (`CREATE TABLE licenses (...)`):
     - `ip_address` TEXT PRIMARY KEY
     - `client_name` TEXT NOT NULL
     - `expired_date` TEXT NOT NULL (Format: YYYY-MM-DD)
     - `status` TEXT DEFAULT 'active' (Isi: 'active' atau 'banned')
     - `auth_key` TEXT NOT NULL (Key rahasia yang di-generate unik per VPS)

2. **Endpoints Internal (Admin Panel / CLI):**
   - Buat endpoint untuk menambah (Create), memperbarui (Update), dan menghapus (Delete) lisensi berdasarkan IP (wajib menyertakan parameter/body `auth_key` saat Create).
   - Saat lisensi ditambahkan, diubah masa aktifnya, atau dibanned, **sistem harus memicu (trigger) Webhook** secara otomatis ke IP VPS yang bersangkutan.

3. **Mekanisme Webhook (Push to VPS):**
   - Format Webhook Target URL: `http://<IP_ADDRESS>:5888/callback/licence?auth=<AUTH_KEY_DARI_DATABASE>`
   - Method: `POST`
   - Payload JSON yang harus dikirim ke VPS:
     ```json
     {
       "action": "update",
       "client_name": "Nama Klien",
       "expired_date": "YYYY-MM-DD",
       "status": "active" // atau "banned"
     }
     ```
   - Catatan: Jika `action` adalah delete atau `status` diubah menjadi `banned`, API di Vercel harus mengirim `expired_date` ke masa lalu (misalnya "2000-01-01") agar VPS target langsung terblokir secara otomatis.
   - Sistem harus memiliki fitur 'Retry' sederhana atau log jika webhook ke VPS gagal terkirim (misalnya saat VPS sedang offline).

4. **Endpoint Pengecekan / Sinkronisasi Awal (Fallback):**
   - Meskipun sistem utama menggunakan Webhook, buat satu endpoint `GET /api/check?ip=<IP_ADDRESS>` (atau deteksi IP otomatis dari header `x-forwarded-for`).
   - Endpoint ini berguna jika VPS baru saja direstart dan ingin melakukan sinkronisasi satu kali untuk memastikan ia tidak melewatkan webhook apa pun saat sedang offline.

5. **Keamanan:**
   - Gunakan Environment Variable (`process.env.SECRET_API_KEY`) untuk memvalidasi request dari/ke VPS dan dari panel admin.

## Keluaran yang Diharapkan
1. Struktur folder project yang siap di-push ke GitHub dan di-deploy ke Vercel.
2. File `package.json` beserta dependencies yang dibutuhkan.
3. Source code inti untuk rute API dan pemrosesan Webhook (`axios` / `fetch`).
4. Panduan langkah demi langkah (`README.md`) cara men-deploy proyek ini ke Vercel dan mengatur Environment Variables.
