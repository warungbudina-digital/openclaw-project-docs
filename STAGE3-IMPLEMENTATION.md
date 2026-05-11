# Stage 3 — Pindahkan cron/job ke `worker` + pola isolated session

Tujuan stage 3:
- memindahkan pekerjaan terjadwal dari pola berat di `main` ke agent `worker`
- menjadikan job background lebih stateless, murah, dan aman
- memakai `isolated session` sebagai default untuk automation yang tidak butuh history chat utama
- menjaga `main` tetap fokus untuk percakapan manusia

---

## Kondisi saat dokumen ini dibuat

Hasil cek saat ini:
- belum ada cron job aktif

Artinya stage 3 ini berfungsi sebagai:
- fondasi pola job yang benar
- template command siap pakai
- panduan kalau nanti job mulai ditambahkan atau dipindahkan

---

## Prinsip stage 3

### Gunakan `worker` untuk job backend
Cocok untuk:
- housekeeping
- report rutin
- audit ringan
- sinkronisasi
- sweep task periodik
- webhook/trigger background

### Gunakan `isolated` untuk job yang tidak perlu history chat
Ini pola default terbaik untuk:
- pekerjaan berulang
- task disposable
- task yang tidak perlu mengotori session `main`

### Gunakan `main` hanya bila konteks chat manusia benar-benar penting
Contoh:
- reminder yang sengaja ingin menempel ke ritme chat personal
- follow-up yang perlu kesinambungan konteks DM aktif

Kalau ragu, pilih:
- `--agent worker`
- `--session isolated`

---

## Pola default yang direkomendasikan

Untuk job background standar, gunakan pola ini:

```bash
openclaw cron add \
  --name "NAMA_JOB" \
  --cron "0 * * * *" \
  --agent worker \
  --session isolated \
  --message "INSTRUKSI_JOB" \
  --light-context \
  --no-deliver
```

Maknanya:
- `--agent worker` → job jalan di agent worker
- `--session isolated` → session khusus per-run, tidak nempel ke `main`
- `--light-context` → bootstrap dibuat ringan, hemat token
- `--no-deliver` → hasil tidak otomatis diumumkan ke chat kecuali memang perlu

Ini bagus untuk mayoritas automasi backend.

---

## 0) Backup definisi cron sebelum mulai

Walau saat ini belum ada job aktif, biasakan backup store cron dulu.

```bash
cp ~/.openclaw/cron/jobs.json ~/.openclaw/cron/jobs.json.bak.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
cp ~/.openclaw/cron/jobs-state.json ~/.openclaw/cron/jobs-state.json.bak.$(date +%Y%m%d-%H%M%S) 2>/dev/null || true
```

Verifikasi:
```bash
ls -lt ~/.openclaw/cron/jobs*.bak.* 2>/dev/null | head
```

---

## 1) Audit cron yang ada

Kalau nanti sudah ada job, mulai dari sini.

```bash
openclaw cron list
```

Untuk lihat detail satu job:

```bash
openclaw cron show <job-id>
```

Fokus audit:
- apakah job masih jalan di `main`
- apakah job butuh history chat atau tidak
- apakah output perlu diumumkan ke chat atau cukup internal
- apakah model yang dipakai terlalu mahal untuk tugas rutin

---

## 2) Kategori migrasi job

### A. Job internal / backend
Contoh:
- cleanup
- health sweep
- ringkasan log
- polling ringan
- housekeeping

Pola target:
- `--agent worker`
- `--session isolated`
- `--light-context`
- `--no-deliver`

### B. Job report yang hasilnya perlu dikirim
Contoh:
- morning brief
- daily report
- status summary
- alert terjadwal

Pola target:
- `--agent worker`
- `--session isolated`
- `--light-context`
- `--announce`
- plus `--channel` dan `--to` bila ingin route eksplisit

### C. Reminder personal yang sengaja menempel ke chat
Contoh:
- pengingat ngobrol personal
- follow-up yang sangat terkait sesi manusia saat ini

Pola:
- bisa tetap `--session main`
- atau isolated kalau hanya butuh output, bukan continuity

Jadi tidak semua hal wajib dipaksa ke `worker`; tapi mayoritas backend job memang sebaiknya pindah.

---

## 3) Template job baru untuk `worker`

### Contoh 1 — housekeeping internal tiap 6 jam
```bash
openclaw cron add \
  --name "Worker housekeeping" \
  --every "6h" \
  --agent worker \
  --session isolated \
  --message "Lakukan housekeeping ringan pada workspace/operasional yang aman, lalu tulis hasil ringkas. Jangan kirim pesan keluar bila tidak perlu." \
  --light-context \
  --no-deliver
```

### Contoh 2 — daily brief yang diumumkan
```bash
openclaw cron add \
  --name "Daily brief" \
  --cron "0 7 * * *" \
  --tz "Asia/Makassar" \
  --agent worker \
  --session isolated \
  --message "Buat ringkasan singkat hal penting untuk hari ini. Fokus pada output yang ringkas dan jelas." \
  --light-context \
  --announce
```

Catatan:
- kalau target pengiriman perlu eksplisit, tambahkan `--channel` dan `--to`
- kalau tidak ditentukan, delivery mengikuti mekanisme route/fallback yang tersedia

### Contoh 3 — one-shot job 20 menit lagi
```bash
openclaw cron add \
  --name "Follow-up 20 menit" \
  --at "20m" \
  --agent worker \
  --session isolated \
  --message "Ingatkan follow-up tugas yang tertunda dengan nada singkat." \
  --light-context \
  --announce
```

---

## 4) Cara memigrasikan job lama ke `worker`

Kalau nanti ada job lama yang masih menempel ke `main`, edit satu per satu.

### Ubah agent jadi `worker`
```bash
openclaw cron edit <job-id> --agent worker
```

### Ubah session jadi isolated
```bash
openclaw cron edit <job-id> --session isolated
```

### Ringankan context
```bash
openclaw cron edit <job-id> --light-context
```

### Matikan fallback delivery jika job internal
```bash
openclaw cron edit <job-id> --no-deliver
```

Kalau job memang perlu kirim hasil ke chat:
```bash
openclaw cron edit <job-id> --announce
```

Kalau perlu channel/tujuan eksplisit:
```bash
openclaw cron edit <job-id> --announce --channel telegram --to "<chat-id>"
```

---

## 5) Model policy yang masuk akal untuk `worker`

Sesuai blueprint saat ini, `worker` cocok memakai:
- `ollama/qwen2.5-coder:1.5b`

Untuk banyak task rutin, itu sudah cukup.

Kalau ada satu job tertentu yang perlu model berbeda, override per job:

```bash
openclaw cron add \
  --name "Deep weekly report" \
  --cron "0 6 * * 1" \
  --tz "Asia/Makassar" \
  --agent worker \
  --session isolated \
  --message "Buat analisis mingguan yang lebih dalam." \
  --model "codex-cli/gpt-5.4" \
  --thinking low \
  --light-context \
  --announce
```

Jadi default hemat, override hanya saat perlu.

---

## 6) Kapan pakai `--no-deliver` vs `--announce`

### Pakai `--no-deliver` bila:
- job murni backend
- hasil hanya untuk maintenance/log internal
- tidak perlu mengganggu chat manusia

### Pakai `--announce` bila:
- hasil job memang harus muncul ke user/chat
- job adalah brief, laporan, atau alert
- hasilnya punya nilai langsung untuk dibaca manusia

Rekomendasi praktis:
- default backend → `--no-deliver`
- default report/reminder → `--announce`

---

## 7) Validasi hasil setelah menambah atau memigrasikan job

### Lihat daftar job
```bash
openclaw cron list
```

### Lihat detail job
```bash
openclaw cron show <job-id>
```

Yang perlu dipastikan:
- `agent` = `worker`
- `session` = `isolated`
- `light-context` aktif untuk job yang memang ringan
- delivery mode sesuai tujuan job

### Test run manual
```bash
openclaw cron run <job-id>
```

### Lihat histori run
```bash
openclaw cron runs --id <job-id> --limit 20
```

Kalau perlu cek runtime umum:
```bash
openclaw status
```

---

## 8) Checklist migrasi aman

Untuk tiap job, cek ini:

- apakah job butuh history chat `main`?
- apakah job cocok dipindah ke `worker`?
- apakah output perlu delivery atau cukup internal?
- apakah model default `worker` sudah cukup?
- apakah `light-context` aman dipakai?

Kalau semua jawabannya aman, job itu kandidat bagus untuk stage 3.

---

## 9) Hasil yang diharapkan setelah stage 3

- job background tidak lagi membebani `main`
- cron lebih murah dan lebih rapi
- session utama tetap fokus untuk percakapan manusia
- automation berjalan lewat `worker` yang disposable
- pola isolated jadi standar untuk pekerjaan backend

---

## 10) Rollback cepat

### Hapus job yang baru dibuat
```bash
openclaw cron remove <job-id>
```

### Kembalikan job ke agent default
```bash
openclaw cron edit <job-id> --clear-agent
```

### Kembalikan ke main session
```bash
openclaw cron edit <job-id> --session main
```

### Aktifkan delivery lagi bila sebelumnya dimatikan
```bash
openclaw cron edit <job-id> --announce
```

---

## 11) Next step setelah stage 3

Setelah pola cron `worker` stabil, next step yang natural adalah:

1. pilih 1–2 job kecil dulu sebagai pilot
2. amati hasil run dan token/cost profile
3. baru tambah job rutin lain
4. kalau perlu, lanjut ke stage 4:
   - webhook/trigger ke agent spesifik
   - sandbox/security tightening
   - route account/channel teknis terpisah ke `lab`

