# Runbook implementasi teknis untuk tiap opsi

Dokumen ini memecah implementasi teknis untuk opsi berikut:
- Opsi 1: Cloud Shell helper only
- Opsi 2A: dedicated small VPS worker
- Opsi 2B: isolated worker container di VPS sekarang
- Opsi 2C: scheduled burst workers
- Opsi 2D: stable model host + helper host murah

Format tiap opsi:
- tujuan
- komponen
- langkah implementasi
- verifikasi
- red flags

---

# Opsi 1 — Cloud Shell helper only

## Tujuan
Memakai Cloud Shell hanya untuk helper task pendek dan disposable.

## Komponen
- OpenClaw main
- Paperclip atau FastAPI broker
- shared/object storage
- Cloud Shell helper account/session

## Langkah implementasi

### Step 1 — definisikan jenis task yang boleh ke Cloud Shell
Boleh:
- helper script
- transform file kecil
- eksperimen ringan
- fetch/scrape ringan

Tidak boleh:
- render berat
- model utama
- task > 40 menit
- daemon/background loop

### Step 2 — buat endpoint broker khusus helper
Buat endpoint FastAPI misalnya:
- `POST /helpers/cloudshell/run`
- `GET /helpers/cloudshell/status/{job_id}`

Broker menerima:
- `job_id`
- `task_type`
- `input_ref`
- `timeout_sec`
- `result_target`

### Step 3 — gunakan storage eksternal untuk input/output
Semua input/output harus di luar Cloud Shell.

Contoh:
- input file di VPS/shared storage
- Cloud Shell hanya ambil artefak yang dibutuhkan
- hasil dikirim kembali ke storage eksternal

### Step 4 — enforce timeout keras
Set policy broker:
- default timeout 20 menit
- hard max 30 menit

### Step 5 — log semua helper run
Simpan:
- job id
- start/end time
- task type
- account/session target
- status
- result location
- error detail

## Verifikasi
- task helper selesai < 30 menit
- hasil kembali ke storage eksternal
- Cloud Shell failure tidak mematikan orkestra utama

## Red flags
- task mulai butuh state lama
- output besar
- banyak retry
- session Cloud Shell jadi dependency utama

---

# Opsi 2A — Dedicated small VPS worker

## Tujuan
Menyediakan worker stabil 24/7 untuk task background dan execution yang lebih serius.

## Komponen
- VPS worker terpisah
- FastAPI worker/broker
- optional Docker
- optional viral tools / ffmpeg / helper services
- private network/Tailscale/VPN/internal route

## Langkah implementasi

### Step 1 — siapkan VPS worker
Minimum realistis:
- 2 vCPU
- 2–4 GB RAM
- storage cukup untuk artefak worker

### Step 2 — deploy FastAPI broker/worker
Service inti:
- intake job
- dispatch runtime
- status endpoint
- health endpoint

Minimal endpoint:
- `GET /healthz`
- `POST /jobs`
- `GET /jobs/{id}`
- `POST /jobs/{id}/cancel`

### Step 3 — mount/logging layout yang jelas
Contoh host path:
- `/opt/worker/input`
- `/opt/worker/output`
- `/opt/worker/logs`

### Step 4 — hubungkan ke OpenClaw / Paperclip / n8n
Arah integrasi:
- OpenClaw worker/lab -> panggil broker
- n8n-worker -> panggil broker
- Paperclip HTTP/process adapter -> panggil broker

### Step 5 — tambahkan queue discipline
Mulai dari:
- concurrency 1
- retry terbatas
- idempotent job id

### Step 6 — observability dasar
Minimal punya:
- healthcheck
- per-job log
- request/response log ringkas
- metrics sederhana (success/fail/duration)

## Verifikasi
- worker hidup 24/7
- job bisa di-submit dari n8n/OpenClaw
- output tersimpan stabil
- restart service tidak merusak state penting

## Red flags
- semua task dilempar ke satu worker tanpa klasifikasi
- tidak ada timeout
- tidak ada per-job log

---

# Opsi 2B — Isolated worker container di VPS sekarang

## Tujuan
Menguji worker stabil tanpa tambah VPS baru.

## Komponen
- VPS yang sekarang
- container worker terpisah
- network internal Docker
- mount input/output khusus

## Langkah implementasi

### Step 1 — tentukan worker service terpisah
Contoh service:
- `ops_worker`
- `viral_editor`
- `helper_broker`

### Step 2 — beri resource limit
Contoh awal:
- CPU limit rendah-sedang
- mem limit ketat
- concurrency 1

### Step 3 — pisahkan mount kerja
Contoh:
- `/srv/worker/input:/data/input`
- `/srv/worker/output:/data/output`

### Step 4 — jangan campurkan dengan main services
`n8n-main` dan `openclaw main` tidak boleh mengerjakan task berat langsung.

Semua job berat -> container worker.

### Step 5 — tambahkan queue/backpressure
Kalau sudah ada job aktif, job baru harus:
- menunggu
- atau ditolak sementara

## Verifikasi
- stack utama tetap responsif saat worker berjalan
- load host tidak melonjak liar
- tidak ada swap thrashing

## Red flags
- browser mulai lag berat
- OpenClaw delay
- n8n-main ikut melambat
- worker dan main rebut resource

---

# Opsi 2C — Scheduled burst workers

## Tujuan
Worker tidak hidup terus, tapi menyala saat perlu.

## Komponen
- scheduler
- job trigger
- short-lived worker instance/container
- storage/logging persist outside worker lifecycle

## Langkah implementasi

### Step 1 — definisikan event pemicu
Contoh:
- cron tertentu
- webhook tertentu
- queue length tertentu

### Step 2 — siapkan template worker start/stop
Worker harus bisa:
- start dengan config yang jelas
- menerima satu batch job
- stop setelah selesai

### Step 3 — pisahkan state dari worker runtime
State tidak boleh disimpan hanya di container yang nanti mati.

Simpan state di:
- DB
- storage
- queue

### Step 4 — tambahkan cold-start tolerance
Workflow upstream harus tahu bahwa worker tidak selalu ready seketika.

### Step 5 — siapkan cleanup routine
Setelah job selesai:
- cleanup temp files
- archive logs
- stop worker

## Verifikasi
- worker bisa start dari nol
- job batch selesai
- worker berhenti rapi
- state tidak hilang

## Red flags
- startup terlalu lama
- hasil job bergantung pada state local sebelumnya
- banyak task kecil jadi mahal karena cold start

---

# Opsi 2D — Stable model host + helper host murah

## Tujuan
Memisahkan runtime utama yang stabil dari helper runtime yang disposable.

## Komponen
- host stabil untuk model/runtime utama
- helper host murah/disposable
- broker/routing layer
- storage/logging bersama

## Langkah implementasi

### Step 1 — tentukan kelas runtime
#### Stable host
Untuk:
- Ollama utama
- OpenClaw worker penting
- n8n integration tasks
- reasoning yang harus stabil

#### Helper host
Untuk:
- helper scripts
- scrape ringan
- transform sekali jalan
- eksperimen

### Step 2 — broker harus punya routing policy
Contoh aturan:
- `reasoning`, `stateful`, `long-running` -> stable host
- `helper`, `short`, `stateless` -> helper host

### Step 3 — standardkan payload contract
Semua job harus punya:
- job id
- task type
- timeout
- input refs
- output target
- retry policy

### Step 4 — logging harus lintas-host
Log minimal:
- broker log
- host target
- duration
- output ref
- failure reason

### Step 5 — siapkan fallback
Jika helper host gagal:
- retry ringan
- atau fallback ke stable host jika task kecil

## Verifikasi
- routing task benar
- helper host gagal tidak mematikan stable host
- reasoning utama tetap stabil walau helper bermasalah

## Red flags
- helper host mulai jadi dependency utama
- task penting masuk helper host tanpa policy
- semua workload tetap menumpuk di stable host

---

# Rekomendasi implementasi bertahap

Kalau Ayang mau jalur paling waras:

## Tahap 1
Mulai dari:
- Opsi 2B jika ingin cepat uji di VPS sekarang
atau
- Opsi 2A jika ingin langsung fondasi yang benar

## Tahap 2
Tambahkan discipline dari Opsi 2D:
- bedakan stable vs helper workloads

## Tahap 3
Baru pakai Opsi 1 untuk Cloud Shell helper-only bila benar-benar ada task yang cocok.

## Tahap 4
Pakai Opsi 2C hanya kalau burst/scheduled workers memang dibutuhkan.

---

# Putusan pragmatis

Kalau prioritas Ayang adalah:
- stabil
- bisa tumbuh
- biaya tetap cukup hemat

maka urutan terbaik adalah:
1. **2A** dedicated worker VPS
2. **2D** stable + helper split
3. **1** Cloud Shell helper-only

Sedangkan:
- **2B** cocok untuk pilot cepat
- **2C** cocok untuk optimasi fase berikutnya
