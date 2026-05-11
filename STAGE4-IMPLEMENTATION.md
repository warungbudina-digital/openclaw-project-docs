# Stage 4 — Webhook/trigger ke agent spesifik + tightening sandbox/security

Tujuan stage 4:
- membuka jalur trigger yang terkontrol untuk agent tertentu, **bukan** ke semua agent
- menjadikan `worker` sebagai target default untuk webhook/background trigger
- memperkecil blast radius lewat sandbox, workspace scoping, dan hardening config
- menutup beberapa warning yang muncul dari audit security saat ini

---

## Ringkasan posture saat dokumen ini dibuat

Dari audit read-only yang sudah dicek, posture saat ini secara singkat:

- `gateway.bind = lan`
- auth mode sudah `token`
- **belum ada** `gateway.auth.rateLimit`
- external webhooks **belum aktif**
- internal hooks aktif
- sandbox masih `off`
- tools profile masih `coding`
- browser CDP profile masih lewat HTTP internal
- ada warning bahwa setup ini mulai terlihat seperti multi-user/prompt-injection-sensitive kalau akses makin dibuka
- update OpenClaw tersedia (`stable`, npm `2026.5.7`)

Temuan audit yang paling relevan untuk stage ini:
- `gateway.auth_no_rate_limit`
- `browser.remote_cdp_http`
- `security.trust_model.multi_user_heuristic`
- `gateway.nodes.deny_commands_ineffective`

Artinya: sebelum webhook dibuka, hardening dasar sebaiknya dikerjakan dulu.

---

## Prinsip stage 4

### 1) Webhook jangan langsung boleh ke semua agent
Paling aman mulai dari:
- webhook hanya boleh menuju `worker`
- jangan buka trigger langsung ke `main`
- jangan beri caller hak memilih session key sembarangan

### 2) Untuk automation, `worker` + `isolated` tetap default
Kalau trigger datang dari webhook, pola dasarnya tetap:
- agent = `worker`
- session = isolated / fixed hook session
- context dibuat ringan

### 3) Hardening dilakukan bertahap
Urutan aman:
1. backup config
2. tambah rate limit auth gateway
3. aktifkan webhook minimal untuk `worker`
4. kencangkan sandbox + workspace scope
5. re-audit

---

## 0) Backup config dulu

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.stage4.$(date +%Y%m%d-%H%M%S)
```

Verifikasi:
```bash
ls -lt ~/.openclaw/openclaw.json.bak.stage4.* | head
```

---

## 1) Audit baseline sebelum perubahan

```bash
openclaw security audit --deep
openclaw update status
openclaw status
```

Catatan:
- `openclaw security audit --fix` aman untuk safe defaults/perms, tapi **tidak** akan mengubah bind/auth/webhook/sandbox policy besar
- karena stage 4 ini menyentuh exposure, tetap lebih baik review manual daripada berharap `--fix` menyelesaikan semuanya

---

## 2) Tambah rate limit untuk gateway auth

Ini salah satu warning utama yang sekarang muncul.

Command:
```bash
openclaw config set gateway.auth.rateLimit '{"maxAttempts":10,"windowMs":60000,"lockoutMs":300000}' --strict-json
```

Verifikasi:
```bash
openclaw config get gateway.auth
```

Hasil yang diharapkan:
- token auth tetap aktif
- brute-force auth jadi lebih susah

---

## 3) Aktifkan webhook minimal dan khusus `worker`

### Kenapa mulai dari mode ini
Kita **tidak** membuka webhook ke semua agent.
Kita mulai dari pola paling aman yang masih berguna:
- hooks aktif
- token hook khusus (beda dari gateway token)
- `allowedAgentIds` hanya `worker`
- `allowRequestSessionKey = false`
- route pakai endpoint resmi `/hooks/agent`

### 3a) Generate token hook yang terpisah

```bash
HOOK_TOKEN=$(python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
)

echo "$HOOK_TOKEN"
```

Catatan penting:
- **jangan** pakai token gateway untuk webhook
- simpan token ini baik-baik
- `hooks.token` memang sensitif; setelah set, pastikan izin file config tetap ketat

### 3b) Set config webhook dasar

```bash
openclaw config set hooks.enabled true --strict-json
openclaw config set hooks.token "$HOOK_TOKEN"
openclaw config set hooks.path "/hooks"
openclaw config set hooks.maxBodyBytes 262144 --strict-json
openclaw config set hooks.allowedAgentIds '["worker"]' --strict-json
openclaw config set hooks.defaultSessionKey "hook:worker"
openclaw config set hooks.allowRequestSessionKey false --strict-json
```

Verifikasi:
```bash
openclaw config get hooks --json
```

Catatan:
- dengan ini caller **tidak** boleh memilih session key sendiri
- caller juga tidak boleh menargetkan `main` atau `lab`
- kalau nanti butuh route lain, tambahkan dengan sadar dan sempit

---

## 4) Test webhook ke `worker`

### Smoke test lokal

Kalau gateway di host yang sama dan port default masih dipakai:

```bash
curl -X POST http://127.0.0.1:18789/hooks/agent \
  -H "Authorization: Bearer $HOOK_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "message": "Reply with exactly WEBHOOK-WORKER-OK.",
    "agentId": "worker",
    "name": "Worker webhook smoke test",
    "deliver": false
  }'
```

Kalau target remote, sesuaikan URL host-nya.

### Yang perlu dicek setelah test
```bash
openclaw status
```

Kalau nanti ingin lihat jejak session/hasil run, cek session/cron/task sesuai workflow yang dipakai.

---

## 5) Tighten sandbox untuk agent non-main

Ini langkah penting supaya `lab` dan `worker` tidak lagi jalan selebar `main`.

### Rekomendasi balanced
Gunakan sandbox untuk **non-main** dulu.

```bash
openclaw config set agents.defaults.sandbox.mode "non-main"
openclaw config set agents.defaults.sandbox.scope "agent"
openclaw config set agents.defaults.sandbox.workspaceAccess "rw"
openclaw config set agents.defaults.sandbox.browser.enabled true --strict-json
```

Verifikasi:
```bash
openclaw sandbox explain
openclaw sandbox explain --agent lab
openclaw sandbox explain --agent worker
```

Maknanya:
- `main` tetap fleksibel
- `lab` dan `worker` mulai dapat isolasi tambahan
- cocok untuk transisi tanpa terlalu mengganggu chat utama

### Kalau ingin lebih ketat lagi
Kalau nanti Ayang benar-benar ingin semua agent tersandbox:

```bash
openclaw config set agents.defaults.sandbox.mode "all"
```

Tapi ini sebaiknya dilakukan setelah `non-main` terbukti stabil.

---

## 6) Batasi filesystem ke workspace

Ini langkah yang cukup kuat untuk mengurangi blast radius path/file.

```bash
openclaw config set tools.fs.workspaceOnly true --strict-json
```

Verifikasi:
```bash
openclaw config get tools.fs --json
```

Catatan:
- ini membantu membatasi file tools ke workspace yang relevan
- bagus dipakai kalau automation mulai banyak
- bila ada workflow lama yang butuh absolute path host, uji dulu setelah perubahan ini

---

## 7) Pilihan exposure gateway yang lebih sehat

### Opsi A — paling aman: loopback only
Kalau tidak butuh akses LAN langsung ke gateway:

```bash
openclaw config set gateway.bind loopback
```

Ini pilihan paling aman untuk Control UI/API lokal.

### Opsi B — tetap remote, tapi jangan longgar
Kalau memang perlu akses remote:
- pertahankan auth yang valid
- jangan buka webhook tanpa token khusus
- lebih baik lewat Tailscale Serve / private ingress yang terkontrol
- **jangan** pindah ke `trusted-proxy` kecuali benar-benar pakai reverse proxy identitas-aware yang non-loopback

Catatan penting:
- same-host loopback reverse proxy **bukan** kandidat valid untuk `trusted-proxy`
- kalau bind non-loopback tetap dipakai, rate limit + hardening webhook jadi makin penting

---

## 8) Tentang warning `gateway.nodes.denyCommands`

Audit sekarang menandai daftar `gateway.nodes.denyCommands` yang ada sebagai **sebagian tidak efektif**, karena pencocokan memakai **nama command exact**, bukan teks shell.

Rekomendasi stage 4:
- **jangan** merasa aman palsu dengan deny list yang tidak valid
- review daftar command node yang benar-benar ingin diblok
- kalau belum yakin nama command exact-nya, lebih aman tunda perubahan ini daripada menulis deny list yang salah

Artinya item ini masuk backlog hardening, tapi bukan langkah yang harus ditebak sekarang.

---

## 9) Safe re-audit setelah perubahan

```bash
openclaw config validate
openclaw security audit --deep
openclaw hooks check
openclaw status
```

Hal yang diharapkan membaik:
- warning `gateway.auth_no_rate_limit` hilang
- exposure webhook jadi sempit dan terarah ke `worker`
- warning multi-user/tool exposure berkurang setelah sandbox + workspaceOnly diterapkan

Yang mungkin masih tersisa:
- `browser.remote_cdp_http`
- warning sekitar node command deny list
- warning exposure lain jika bind tetap `lan`

---

## 10) Kalau perlu restart gateway

Kalau runtime belum langsung memuat perubahan:

```bash
openclaw gateway restart
```

Lalu cek lagi:

```bash
openclaw status
openclaw hooks check
openclaw security audit --deep
```

---

## 11) Hasil yang diharapkan setelah stage 4

- webhook ingress sudah aktif tapi **hanya** untuk `worker`
- webhook tidak memakai token gateway yang sama
- gateway auth punya rate limit
- `lab` dan `worker` sudah tersandbox (minimal mode `non-main`)
- file tools lebih terikat ke workspace
- blast radius automation lebih kecil
- fondasi untuk webhook-driven jobs jadi jauh lebih sehat

---

## 12) Rollback cepat

### Nonaktifkan webhook eksternal
```bash
openclaw config set hooks.enabled false --strict-json
```

### Hapus field webhook yang ditambahkan
```bash
openclaw config unset hooks.token
openclaw config unset hooks.path
openclaw config unset hooks.maxBodyBytes
openclaw config unset hooks.allowedAgentIds
openclaw config unset hooks.defaultSessionKey
openclaw config unset hooks.allowRequestSessionKey
```

### Matikan kembali sandbox default
```bash
openclaw config set agents.defaults.sandbox.mode "off"
```

### Kembalikan workspaceOnly ke semula bila perlu
```bash
openclaw config set tools.fs.workspaceOnly false --strict-json
```

### Atau rollback penuh dari backup config
```bash
cp ~/.openclaw/openclaw.json.bak.stage4.YYYYMMDD-HHMMSS ~/.openclaw/openclaw.json
```

Lalu restart bila perlu:
```bash
openclaw gateway restart
```

---

## 13) Next step yang paling natural sesudah stage 4

Kalau stage 4 sudah stabil, next step yang enak adalah:

1. tambah 1 webhook use-case nyata ke `worker`
2. pindahkan 1 automation kecil dari manual trigger ke webhook/cron
3. audit lagi setelah 1–2 hari pemakaian
4. baru pertimbangkan tightening lanjutan:
   - bind `loopback` / tailnet-only
   - sandbox `all`
   - model/tool policy lebih ketat per-agent
   - browser/CDP transport yang lebih aman

