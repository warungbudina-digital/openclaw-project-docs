# Viral Editor Render Worker Architecture

Tujuan utama:
- `n8n-main` tetap ringan
- render video berat tidak berjalan di host/control plane utama
- job render dipindah ke worker khusus
- alur tetap rapi dan bisa diotomasi oleh n8n

## Prinsip desain

- `n8n-main` = orchestration/UI/webhook
- `n8n-worker` = automation logic dan queue consumer
- `render-worker` = host khusus video rendering
- `viral_editor` = service FastAPI di dalam `render-worker`
- `shared storage` / object storage = tempat asset masuk dan output keluar

---

## Arsitektur yang direkomendasikan

## Host 1 — Main Automation Host
Komponen:
- `n8n-main`
- `n8n-worker`
- `postgres`
- `redis`
- optional `openclaw`

Peran:
- menerima trigger
- menyusun plan
- memanggil analyzer jika perlu
- membuat render job
- mengirim job ke render worker
- memantau status dan hasil

## Host 2 — Render Worker Host
Komponen:
- `viral_editor`
- optional `cloudflared` (kalau perlu akses eksternal)
- optional local media cache

Peran:
- menerima render request
- mengambil source asset
- melakukan cut/concat/crop/subtitle burn
- menyimpan output
- mengembalikan status/manifest

---

## Alur data ideal

### Step 1 — Ingest
`n8n-main` menerima request / trigger.

### Step 2 — Analysis
- source video dianalisis oleh `viral_analyzer`
- hasil JSON disimpan ke storage / database / object store

### Step 3 — Job creation
`n8n-worker` membuat payload render:
- source video path/url
- analyzer JSON
- preset editing
- target output path
- job_id

### Step 4 — Dispatch ke render worker
`n8n-worker` memanggil:
- `POST /render`
  pada `viral_editor`

### Step 5 — Rendering
`viral_editor` di host render:
- download/mount input bila perlu
- render video
- simpan output + manifest

### Step 6 — Callback / polling
`n8n-worker`:
- polling status
- atau menerima callback selesai
- lalu simpan hasil / kirim ke step berikutnya

---

## Rekomendasi integrasi antar host

## Opsi terbaik: shared object storage
Pakai salah satu:
- S3-compatible bucket
- Cloudflare R2
- MinIO
- Google Drive / rclone bridge (lebih lambat, tapi bisa)

### Kenapa bagus
- `n8n-main` tidak perlu kirim file video lewat request body besar
- `render-worker` cukup ambil file dari URL/path
- hasil render juga tinggal disimpan balik ke storage

### Pola payload
`n8n-worker` kirim ke `viral_editor`:
- `source_video_url`
- `analysis_json_url`
- `output_target`
- `preset`

## Opsi kedua: shared filesystem
Kalau dua host masih satu environment privat:
- NFS
- Samba
- mounted volume bersama

Ini bisa, tapi lebih rapuh dibanding object storage.

---

## Endpoint service yang saya sarankan untuk render-worker

### `GET /healthz`
- cek service hidup

### `POST /plan`
- opsional, jika worker juga boleh generate plan

### `POST /render`
- buat job render langsung

### `GET /jobs/{job_id}`
- cek status job

### `POST /jobs/{job_id}/cancel`
- batalkan job jika perlu

### `GET /jobs/{job_id}/manifest`
- ambil manifest hasil render

Untuk v1 minimal, `POST /render` + `GET /healthz` sudah cukup. Tapi untuk arsitektur worker jangka menengah, status endpoint lebih sehat.

---

## Model operasi yang saya sarankan

## Jangan pakai `n8n-main` untuk render
`n8n-main` harus tetap fokus ke:
- editor/UI
- trigger
- webhook
- orchestration

## Gunakan `n8n-worker` untuk dispatch
Semua render job dibuat dari `n8n-worker`, bukan `n8n-main`.

## Render concurrency dibatasi
Di host render:
- mulai dengan **1 job sekaligus**
- jangan paralel dulu
- baru naik setelah ada bukti stabil

---

## Resource profile yang saya sarankan

## Main host
Untuk host utama:
- prioritaskan stabilitas n8n + OpenClaw
- jangan tambahkan ffmpeg render berat di sini

## Render worker host
Minimal realistis untuk awal:
- **2–4 vCPU**
- **4–8 GB RAM**
- storage terpisah untuk media/temp/output

Kalau source video pendek dan render ringan, 2 vCPU / 4 GB masih bisa mulai. Tapi kalau subtitle burn + crop + concat sering, saya lebih percaya 4 vCPU / 8 GB.

---

## Pola deployment yang sehat

## Main host compose
Service utama saja:
- `n8n-main`
- `n8n-worker`
- `postgres`
- `redis`

## Render host compose
Service render saja:
- `viral_editor`
- optional `cloudflared`

Ini memisahkan failure domain.
Kalau render crash, `n8n-main` tetap hidup.

---

## Queue / orchestration style

## Simple mode
`n8n-worker` langsung HTTP call ke `viral_editor`.

Cocok untuk:
- volume kecil
- concurrency 1
- tidak butuh banyak status detail

## Better mode
Pakai job queue semu:
- `n8n-worker` create `job_id`
- kirim request async
- status disimpan di DB / storage
- `viral_editor` update status

Cocok untuk:
- retry
- observability
- render job lebih panjang

---

## Hal yang jangan dilakukan

- jangan render di `n8n-main`
- jangan campur `viral_editor` dengan browser sandbox di host sempit
- jangan kirim file video besar langsung lewat body HTTP jika ada storage URL option
- jangan mulai concurrency >1 di host kecil
- jangan campur too many roles dalam satu VPS kecil

---

## Rekomendasi implementasi nyata

### Tahap 1 — paling cepat
- `viral_editor` di VPS render terpisah
- `n8n-worker` memanggil `POST /render`
- source path masih sederhana
- concurrency = 1

### Tahap 2
- tambahkan storage object / shared path
- tambah `job_id` + status endpoint
- tambah manifest endpoint

### Tahap 3
- callback completion
- retry policy
- queue discipline
- cleanup media otomatis

---

## Kesimpulan

Arsitektur yang paling waras untuk Ayang:

- **Host utama**: `n8n-main` + `n8n-worker` + DB/Redis
- **Host render**: `viral_editor`
- **Storage terpisah**: untuk video input/output

Dengan pola ini:
- `n8n-main` tetap ringan
- render berat tidak mengganggu control plane
- scaling render bisa dilakukan terpisah
- debugging juga jauh lebih jelas
