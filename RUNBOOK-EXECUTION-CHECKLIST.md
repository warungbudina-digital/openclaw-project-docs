# RUNBOOK-EXECUTION-CHECKLIST

Checklist super singkat untuk eksekusi nyata Stage 1 → 4.

---

## 0) Baseline sebelum mulai

- [ ] `openclaw status`
- [ ] `openclaw channels status --probe`
- [ ] `openclaw agents list --bindings`
- [ ] `openclaw cron list`
- [ ] `openclaw security audit --deep`
- [ ] Kalau baseline sudah aneh, **stop dulu**

---

## 1) Stage 1 — fondasi

Pakai file:
- `STAGE1-IMPLEMENTATION.md`

Checklist:
- [ ] backup config dibuat
- [ ] secret dipindah ke env ref
- [ ] heartbeat hemat diterapkan
- [ ] `BOOTSTRAP.md` diarsipkan
- [ ] `openclaw config validate` sukses
- [ ] `openclaw status` normal
- [ ] `openclaw channels status --probe` normal
- [ ] chat utama masih normal

Kalau gagal:
- [ ] rollback Stage 1
- [ ] **jangan lanjut** ke Stage 2

---

## 2) Quick test setelah Stage 1

- [ ] kirim 1–2 pesan test ke chat utama
- [ ] pastikan balasan normal
- [ ] tidak ada warning aneh di status
- [ ] kalau aman, lanjut Stage 2

---

## 3) Stage 2 — tambah agent structure

Pakai file:
- `STAGE2-IMPLEMENTATION.md`

Checklist:
- [ ] agent `lab` ditambahkan
- [ ] agent `worker` ditambahkan
- [ ] config per-agent dirapikan
- [ ] `openclaw agents list --bindings` menampilkan `main`, `lab`, `worker`
- [ ] binding lama tetap ke `main`
- [ ] `openclaw config validate` sukses
- [ ] `openclaw status` normal
- [ ] `workspace-lab` dan `workspace-worker` terbentuk

Kalau gagal:
- [ ] rollback Stage 2
- [ ] **jangan lanjut** ke Stage 3

---

## 4) Quick test setelah Stage 2

- [ ] `main` masih jawab chat normal
- [ ] `lab` muncul di daftar agent
- [ ] `worker` muncul di daftar agent
- [ ] belum ada route liar ke agent baru

---

## 5) Stage 3 — pilot cron kecil

Pakai file:
- `STAGE3-IMPLEMENTATION.md`

Checklist:
- [ ] buat **1 job kecil** dulu
- [ ] pakai `--agent worker`
- [ ] pakai `--session isolated`
- [ ] pakai `--light-context`
- [ ] pakai `--no-deliver`
- [ ] `openclaw cron list` normal
- [ ] `openclaw cron run <job-id>` sukses
- [ ] `openclaw cron runs --id <job-id> --limit 20` aman
- [ ] job tidak mengganggu `main`

Kalau gagal:
- [ ] hapus / edit job pilot
- [ ] perbaiki Stage 3 dulu
- [ ] **jangan lanjut** ke Stage 4

---

## 6) Stage 4 — minimal hardening dulu

Pakai file:
- `STAGE4-IMPLEMENTATION.md`

Urutan pendeknya:
- [ ] tambah `gateway.auth.rateLimit`
- [ ] aktifkan webhook hanya untuk `worker`
- [ ] smoke test webhook 1x
- [ ] aktifkan sandbox `non-main`
- [ ] pertimbangkan `tools.fs.workspaceOnly=true`

Checklist validasi:
- [ ] `openclaw config validate` sukses
- [ ] `openclaw hooks check` normal
- [ ] `openclaw security audit --deep` membaik
- [ ] `openclaw status` normal
- [ ] `main` tetap aman untuk chat
- [ ] webhook tidak bisa menyentuh agent selain `worker`

Kalau gagal:
- [ ] matikan webhook dulu
- [ ] rollback sandbox/hardening terakhir
- [ ] cek lagi sebelum ubah hal lain

---

## 7) Stop points yang aman

- [ ] boleh stop setelah Stage 1
- [ ] boleh stop setelah Stage 2
- [ ] boleh stop setelah Stage 3 pilot
- [ ] Stage 4 hanya kalau memang butuh webhook/hardening lanjut

---

## 8) Red flags

Kalau ini muncul, berhenti dulu:

- [ ] `openclaw config validate` gagal
- [ ] gateway tidak sehat setelah restart
- [ ] channel utama disconnect
- [ ] binding DM pindah ke agent salah
- [ ] cron pilot gagal berulang
- [ ] webhook terlalu longgar
- [ ] sandbox bikin workflow utama rusak

---

## 9) Finish line

Checklist akhir:
- [ ] `main` tetap nyaman untuk chat
- [ ] `lab` siap untuk kerja teknis
- [ ] `worker` siap untuk cron / webhook
- [ ] cron tidak membebani `main`
- [ ] webhook hanya ke agent spesifik
- [ ] security posture lebih sehat dari awal
