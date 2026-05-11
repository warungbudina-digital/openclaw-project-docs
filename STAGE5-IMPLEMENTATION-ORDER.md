# Stage 5 — Pilot implementation order (urutan eksekusi paling aman)

Tujuan stage 5:
- menyatukan Stage 1 sampai 4 menjadi urutan kerja yang mudah diikuti
- mengurangi risiko salah langkah atau lompat tahap
- memberi checkpoint jelas: kapan lanjut, kapan berhenti, kapan rollback
- membuat implementasi terasa seperti pilot bertahap, bukan big-bang change

---

## Prinsip utama pilot

Jangan eksekusi semua stage sekaligus.

Urutan aman adalah:
1. hematkan dan rapikan fondasi dulu
2. tambahkan struktur agent baru tanpa routing besar
3. baru pindahkan automation ke jalur yang lebih sehat
4. terakhir buka webhook dan tightening security tambahan

Dengan pola ini, kalau ada masalah, area rusaknya kecil dan gampang dilacak.

---

## Dokumen yang dipakai

Urutan dokumen kerja:

1. `STAGE1-IMPLEMENTATION.md`
2. `STAGE2-IMPLEMENTATION.md`
3. `STAGE3-IMPLEMENTATION.md`
4. `STAGE4-IMPLEMENTATION.md`

Dokumen ini (`STAGE5-IMPLEMENTATION-ORDER.md`) adalah pemandu jalannya.

---

## Ringkasan eksekusi paling aman

### Fase A — rapikan fondasi
Jalankan:
- Stage 1

Target hasil:
- secret pindah dari plaintext ke ref/env
- heartbeat lebih hemat
- BOOTSTRAP tidak membebani prompt lagi
- sistem tetap single-agent secara perilaku

### Fase B — tambah struktur agent
Jalankan:
- Stage 2

Target hasil:
- `lab` dan `worker` sudah ada
- belum ada routing yang mengganggu `main`
- workspace terpisah sudah siap

### Fase C — aktifkan pola automation yang sehat
Jalankan:
- Stage 3

Target hasil:
- job baru diarahkan ke `worker`
- pattern `isolated session` jadi default untuk backend task
- `main` tetap fokus buat percakapan

### Fase D — buka trigger terkontrol + hardening
Jalankan:
- Stage 4

Target hasil:
- webhook hanya menuju `worker`
- sandbox mulai aktif minimal untuk non-main
- blast radius automation mengecil
- posture security lebih sehat

---

## Urutan eksekusi detail

## Step 0 — sebelum mulai apa pun

Lakukan ini dulu:

```bash
openclaw status
openclaw channels status --probe
openclaw agents list --bindings
openclaw cron list
openclaw security audit --deep
```

Tujuannya:
- tahu baseline sekarang
- tahu kalau ada error yang sudah ada dari awal
- jangan sampai nanti error lama dikira akibat stage baru

Kalau hasil baseline sudah aneh dari awal:
- **stop dulu**
- catat error-nya
- jangan lanjut implementasi berantai

---

## Step 1 — jalankan Stage 1 dulu, full

Ikuti file:
- `STAGE1-IMPLEMENTATION.md`

Fokus stage ini:
- backup config
- secret → env ref
- heartbeat hemat
- archive `BOOTSTRAP.md`
- validasi config

### Lanjut ke tahap berikutnya hanya kalau:
- `openclaw config validate` sukses
- `openclaw status` normal
- `openclaw channels status --probe` normal
- chat utama masih berjalan normal

### Jangan lanjut kalau:
- gateway gagal start
- channel putus
- secret ref tidak terbaca
- config validate error

Kalau gagal di sini, **rollback Stage 1 dulu**. Jangan loncat ke Stage 2.

---

## Step 2 — diamkan sebentar dan observasi singkat

Setelah Stage 1 selesai, jangan langsung gas Stage 2.

Lakukan observasi singkat:
- kirim 1–2 pesan test ke chat utama
- cek apakah heartbeat/flow masih normal
- cek apakah ada warning aneh di `openclaw status`

Kalau semua normal, baru lanjut.

Rekomendasi jeda aman:
- minimal beberapa menit
- idealnya sampai Ayang merasa alur chat utama tetap normal

---

## Step 3 — jalankan Stage 2

Ikuti file:
- `STAGE2-IMPLEMENTATION.md`

Fokus stage ini:
- tambah `lab`
- tambah `worker`
- rapikan config per-agent
- validasi tanpa mengubah routing utama

### Lanjut ke tahap berikutnya hanya kalau:
- `openclaw agents list --bindings` menampilkan `main`, `lab`, `worker`
- binding lama tetap aman ke `main`
- `openclaw config validate` sukses
- `openclaw status` normal
- workspace `workspace-lab` dan `workspace-worker` terbentuk

### Jangan lanjut kalau:
- `main` hilang / terganti default secara tidak sengaja
- binding DM berubah ke agent yang salah
- agent baru tidak muncul setelah restart

Kalau gagal di sini, rollback Stage 2 dulu. Jangan lanjut Stage 3.

---

## Step 4 — smoke test agent structure

Sebelum masuk cron/webhook, cek struktur agent dulu.

Checklist:
- `main` tetap jawab chat seperti biasa
- `lab` sudah terdaftar
- `worker` sudah terdaftar
- belum ada route liar ke agent baru

Kalau perlu:
```bash
openclaw agents list --bindings
openclaw status
```

Ini titik aman untuk berhenti kalau Ayang cuma ingin struktur multi-agent dulu tanpa automation.

---

## Step 5 — jalankan Stage 3 secara kecil dulu

Ikuti file:
- `STAGE3-IMPLEMENTATION.md`

**Penting:** karena saat ini belum ada cron job aktif, Stage 3 paling aman dilakukan sebagai **pilot kecil**, bukan langsung bikin banyak job.

Rekomendasi:
- buat **1 job internal kecil** dulu
- arahkan ke `worker`
- pakai `--session isolated`
- pakai `--light-context`
- pakai `--no-deliver`

Contoh pilot paling aman:
- housekeeping ringan
- sweep sederhana
- job test yang tidak kirim pesan ke user

### Lanjut ke tahap berikutnya hanya kalau:
- `openclaw cron list` menampilkan job dengan benar
- `openclaw cron run <job-id>` sukses
- `openclaw cron runs --id <job-id>` tidak menunjukkan kegagalan aneh
- job tidak mengganggu `main`

### Jangan lanjut kalau:
- job isolated gagal terus
- worker tidak bisa dipakai
- output job kacau / tidak sesuai target

Kalau gagal di sini, perbaiki dulu Stage 3. Tidak usah buka webhook dulu.

---

## Step 6 — observasi hasil pilot cron

Setelah pilot job pertama dibuat:
- jalankan manual 1–2 kali
- lihat hasil run log
- pastikan worker memang terasa cocok untuk job backend

Kalau pilot ini stabil, baru artinya fondasi automation sudah layak masuk Stage 4.

Kalau belum stabil:
- tahan dulu Stage 4
- tetap pakai sistem sampai pola Stage 3 matang

---

## Step 7 — jalankan Stage 4 secara minimal dulu

Ikuti file:
- `STAGE4-IMPLEMENTATION.md`

Tapi jangan ambil semua tightening sekaligus. Urutan minimal yang aman:

### 7A. Tambah `gateway.auth.rateLimit`
Ini paling aman dan paling jelas nilainya.

### 7B. Aktifkan webhook **khusus `worker`**
Bukan ke semua agent.

### 7C. Lakukan smoke test webhook
Test 1 kali dengan payload sederhana.

### 7D. Baru aktifkan sandbox `non-main`
Jangan langsung `all` kalau belum yakin.

### 7E. Baru pertimbangkan `tools.fs.workspaceOnly=true`
Ini aman tapi bisa berdampak ke workflow path tertentu, jadi taruh setelah smoke test webhook/sandbox.

---

## Step 8 — checkpoint setelah Stage 4

Setelah Stage 4 minimal selesai, cek:

```bash
openclaw config validate
openclaw security audit --deep
openclaw hooks check
openclaw status
```

### Kondisi ideal sesudah Stage 4:
- webhook aktif dan hanya ke `worker`
- auth rate limit aktif
- sandbox `non-main` aktif
- `main` tetap aman untuk chat
- tidak ada error startup/runtime baru

Kalau ada masalah setelah sandbox/webhook:
- matikan webhook dulu
- rollback setting sandbox terakhir
- jangan ubah banyak hal lain sebelum source masalah ketemu

---

## Step 9 — urutan pilot yang paling direkomendasikan (super ringkas)

Kalau Ayang mau versi paling simpel, jalannya begini:

1. **Stage 1 penuh**
2. test chat utama
3. **Stage 2 penuh**
4. cek agent list/binding
5. **Stage 3 kecil** → 1 cron internal saja
6. test cron itu
7. **Stage 4 kecil** → rate limit + webhook worker + smoke test
8. aktifkan sandbox `non-main`
9. re-audit
10. baru lanjut hardening tambahan kalau semua stabil

---

## Kapan aman berhenti di tengah

Ayang tidak wajib langsung sampai Stage 4.

Titik berhenti yang aman:

### Stop point 1 — setelah Stage 1
Kalau targetnya baru hemat token + config lebih rapi.

### Stop point 2 — setelah Stage 2
Kalau targetnya baru menyiapkan arsitektur multi-agent.

### Stop point 3 — setelah Stage 3 pilot
Kalau targetnya baru automation internal via `worker`, tanpa webhook dulu.

Stage 4 baru perlu kalau memang Ayang ingin trigger eksternal / webhook dan hardening lebih maju.

---

## Red flags: kalau ini muncul, berhenti dulu

Jangan lanjut ke stage berikutnya kalau ada salah satu ini:

- `openclaw config validate` gagal
- gateway restart tapi service tidak sehat
- channel utama disconnect
- binding DM pindah ke agent yang salah
- cron pilot gagal berulang
- webhook bisa menyentuh agent selain `worker`
- sandbox bikin workflow utama rusak dan belum dipahami sebabnya

Rule sederhananya:
- **1 stage bermasalah = selesaikan dulu stage itu**
- jangan menumpuk perubahan di atas masalah yang belum jelas

---

## Command checklist per fase

## Fase A — selesai Stage 1
```bash
openclaw config validate
openclaw status
openclaw channels status --probe
```

## Fase B — selesai Stage 2
```bash
openclaw agents list --bindings
openclaw config validate
openclaw status
```

## Fase C — selesai Stage 3 pilot
```bash
openclaw cron list
openclaw cron run <job-id>
openclaw cron runs --id <job-id> --limit 20
```

## Fase D — selesai Stage 4 minimal
```bash
openclaw hooks check
openclaw security audit --deep
openclaw sandbox explain --agent worker
openclaw status
```

---

## Rekomendasi implementasi real-world paling masuk akal

Kalau Ayang mau jalur paling kalem dan aman, Pipik saranin begini:

### Hari 1
- kerjakan Stage 1
- test chat utama
- kalau normal, lanjut Stage 2
- stop di sini

### Hari 2
- buat 1 pilot cron kecil dari Stage 3
- test run manual
- observasi hasil

### Hari 3
- jalankan Stage 4 minimal:
  - auth rate limit
  - webhook ke `worker`
  - smoke test
  - sandbox `non-main`

Dengan ritme ini, kalau ada masalah, Ayang masih gampang tahu sumbernya dari hari berapa/perubahan mana.

---

## Hasil akhir yang diincar

Kalau semua stage berhasil dengan urutan ini, hasil akhirnya adalah:

- `main` tetap nyaman untuk chat pribadi
- `lab` siap untuk eksperimen teknis
- `worker` siap untuk automation terjadwal dan trigger eksternal
- cron/job tidak lagi menumpuk di `main`
- webhook tidak liar karena dibatasi ke agent spesifik
- security posture lebih sehat dibanding kondisi awal

---

## Next step setelah Stage 5

Setelah playbook ini siap, langkah paling praktis berikutnya adalah:

1. Ayang pilih mau eksekusi mulai dari Stage 1 sekarang atau nanti
2. kalau mau, Pipik bisa bantu bikin lagi file tambahan:
   - `RUNBOOK-EXECUTION-CHECKLIST.md`
   - versi super singkat, tinggal centang satu-satu saat implementasi nyata

