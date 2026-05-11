# OpenClaw Blueprint untuk Personal Assistant + Lab + Worker 24/7

Dokumen ini merangkum:
1. Arsitektur target yang direkomendasikan
2. Audit setup saat ini
3. Langkah implementasi manual dan command yang dipakai
4. Urutan migrasi ke VPS lain

---

## 1) Target arsitektur yang direkomendasikan

### Tujuan
Pisahkan tiga mode kerja agar context, cost, dan risk tidak bercampur:

- **main**: personal assistant untuk chat langsung dengan user
- **lab**: agent teknis untuk eksperimen, Docker, browser, audit, dokumentasi
- **worker**: agent backend untuk cron/webhook/task yang lebih otomatis dan lebih disposable

### Kenapa dipisah

#### `main`
- continuity tinggi
- session manusiawi
- jangan dibebani job berat
- heartbeat ringan saja atau bahkan off

#### `lab`
- untuk kerja investigasi dan iterasi teknis
- boleh punya tool lebih kuat
- cocok untuk isolated cron dan proyek yang banyak file

#### `worker`
- untuk tugas presisi / background
- idealnya jalan di isolated session
- bisa pakai model lebih murah/cepat
- tidak perlu persona kaya `main`

---

## 2) Bentuk sistem yang sehat

```text
Telegram / WhatsApp / WebChat
            |
            v
        OpenClaw Gateway
            |
   +--------+--------+
   |        |        |
   v        v        v
 main      lab     worker
   |        |        |
   |        |        +--> cron jobs (isolated)
   |        |        +--> hooks/webhooks
   |        |
   |        +--> docker / browser / shell / audit / docs
   |
   +--> personal replies / reminders / light heartbeat
```

---

## 3) Prinsip desain operasional

### A. Gunakan main session hanya untuk manusia
Jangan jadikan `main` sebagai tempat semua automasi berjalan.

### B. Gunakan cron untuk kerja nyata
Cron lebih tepat untuk:
- reminder
- report
- daily/weekly job
- health check
- background sweep

### C. Gunakan heartbeat untuk awareness, bukan eksekusi berat
Contoh cocok:
- cek apakah ada email penting
- cek agenda dekat
- cek notifikasi ringan

### D. Isolated session untuk pekerjaan berat
Kalau sebuah job tidak perlu history chat user, jangan pakai main session.

### E. Workspace harus pendek dan disiplin
File yang diinjeksi ke prompt (`AGENTS.md`, `SOUL.md`, `USER.md`, dll.) harus ringkas.

---

## 4) Audit setup yang sedang aktif

Berdasarkan `openclaw status`, `openclaw channels status --probe`, `openclaw agents list --bindings`, dan pembacaan `~/.openclaw/openclaw.json`:

### Yang sudah bagus
- Gateway aktif dan reachable
- Telegram aktif dan connected
- `session.dmScope = per-channel-peer` -> aman untuk isolasi DM per user/channel
- Browser plugin aktif
- Provider Ollama via OpenAI-compatible bridge sudah terpasang
- Model tambahan Ollama sudah terdaftar
- Tools profile `coding` cocok untuk eksperimen teknis

### Yang masih lemah / perlu dirapikan

#### 1. Hanya ada satu agent: `main`
Konsekuensi:
- personal chat, eksperimen, heartbeat, dan automasi masih berpotensi bercampur

#### 2. Heartbeat masih default
Tidak ada `agents.defaults.heartbeat` eksplisit di config, jadi default OpenClaw berlaku:
- every ~30m
- session utama (`main`)
- non-isolated
- non-light-context

#### 3. Sandbox off
Konsekuensi:
- boundary host longgar
- cocok untuk lab internal
- kurang ideal jika nanti ada automasi yang makin luas atau ada multi-user/multi-agent sensitif

#### 4. Gateway bind di `lan`
Konsekuensi:
- bisa diakses dari jaringan lokal/container network
- perlu rate limiting dan boundary auth yang lebih ketat untuk mode 24/7 produksi

#### 5. Secret masih plain di config file
Saat ini file config berisi:
- Telegram bot token
- gateway token
- Ollama bridge API key

Untuk migrasi/produksi, lebih baik pindah ke env/secrets reference.

#### 6. `BOOTSTRAP.md` masih ada
Padahal ini hanya untuk first-run ritual. Kalau dibiarkan, dia tetap ikut jadi potensi bootstrap context tambahan.

---

## 5) Arsitektur target yang disarankan untuk Ayang

## Mode 1 — Personal Assistant (`main`)

### Fungsi
- chat pribadi
- reminders ringan
- check-in
- memory personal

### Konfigurasi yang disarankan
- model utama tetap model terbaik yang nyaman untuk ngobrol
- heartbeat minimal atau dimatikan dulu
- jika heartbeat dipakai:
  - `isolatedSession: true`
  - `lightContext: true`
  - frekuensi diperjarang

---

## Mode 2 — Lab Ops (`lab`)

### Fungsi
- Docker
- browser sandbox
- audit host
- dokumentasi proyek
- eksperimen model/tool
- reproduksi bug

### Konfigurasi yang disarankan
- workspace terpisah
- agent terpisah
- tools lebih kuat boleh tetap ada
- cron isolated untuk job teknis
- bisa pakai model berbeda dari `main`

---

## Mode 3 — Worker (`worker`)

### Fungsi
- job terjadwal
- hook/webhook trigger
- report rutin
- background processing
- sinkronisasi atau housekeeping

### Karakter
- stateless atau low-context
- isolated by default
- lebih murah dan cepat
- jangan diberi persona kompleks

---

## 6) Command yang dipakai untuk audit saat ini

### Status runtime
```bash
openclaw status
```

### Status channel live
```bash
openclaw channels status --probe
```

### Daftar agent + binding
```bash
openclaw agents list --bindings
```

### Ambil config utama
```bash
python3 - <<'PY'
import json, pathlib
p=pathlib.Path('/home/node/.openclaw/openclaw.json')
obj=json.loads(p.read_text())
print(json.dumps(obj, indent=2))
PY
```

### Baca docs lokal
```bash
sed -n '1,220p' /app/docs/start/openclaw.md
sed -n '1,240p' /app/docs/concepts/system-prompt.md
sed -n '1,240p' /app/docs/gateway/heartbeat.md
sed -n '1,260p' /app/docs/automation/cron-jobs.md
sed -n '1,260p' /app/docs/concepts/session.md
sed -n '1,240p' /app/docs/concepts/agent-workspace.md
sed -n '1,240p' /app/docs/concepts/multi-agent.md
sed -n '1,220p' /app/docs/automation/index.md
sed -n '1,220p' /app/docs/concepts/agent.md
```

---

## 7) Command implementasi manual untuk VPS baru

## Langkah 1 — Setup dasar
```bash
openclaw setup
openclaw status
```

## Langkah 2 — Set workspace default
```bash
openclaw config set agents.defaults.workspace '"/home/node/.openclaw/workspace"' --strict-json
```

## Langkah 3 — Isolasi DM
```bash
openclaw config set session.dmScope '"per-channel-peer"' --strict-json
```

## Langkah 4 — Set model utama
```bash
openclaw config set agents.defaults.model.primary '"codex-cli/gpt-5.4"' --strict-json
```

---

## 8) Hardening minimum yang direkomendasikan

### Atur heartbeat agar murah
Kalau tetap mau heartbeat:
```bash
openclaw config set agents.defaults.heartbeat.every '"2h"' --strict-json
openclaw config set agents.defaults.heartbeat.isolatedSession 'true' --strict-json
openclaw config set agents.defaults.heartbeat.lightContext 'true' --strict-json
openclaw config set agents.defaults.heartbeat.includeSystemPromptSection 'false' --strict-json
```

Kalau mau dimatikan dulu:
```bash
openclaw config set agents.defaults.heartbeat.every '"0m"' --strict-json
```

### Rate limit auth gateway
Tambahkan nanti di config sesuai kebutuhan. Intinya jangan biarkan bind `lan` tanpa pembatas brute-force.

### Simpan secret via env ref
Contoh token Telegram:
```bash
openclaw config set channels.telegram.botToken --ref-provider default --ref-source env --ref-id TELEGRAM_BOT_TOKEN
```

Contoh saat menjalankan service/shell:
```bash
export TELEGRAM_BOT_TOKEN='...'
```

---

## 9) Tambah agent `lab`

### Buat agent baru
```bash
openclaw agents add lab
```

### Verifikasi
```bash
openclaw agents list --bindings
```

### Setelah dibuat, biasanya perlu rapikan:
- workspace agent lab
- model default agent lab
- binding channel bila dibutuhkan

Jika ingin benar-benar dipisah per channel/account, tambahkan binding dan/atau account baru.

---

## 10) Tambah agent `worker`

### Buat agent baru
```bash
openclaw agents add worker
```

### Verifikasi
```bash
openclaw agents list --bindings
```

Worker tidak harus punya channel inbound sendiri. Dia bisa dipakai oleh cron/hook/webhook.

---

## 11) Contoh pola cron yang sehat

### Reminder sederhana di main session
```bash
openclaw cron add \
  --name "Reminder test" \
  --at "20m" \
  --session main \
  --system-event "Reminder: cek pekerjaan yang tadi." \
  --wake now
```

### Job isolated harian untuk agent worker
```bash
openclaw cron add \
  --name "Daily ops sweep" \
  --cron "0 7 * * *" \
  --session isolated \
  --agent worker \
  --message "Check system status, summarize anything actionable." \
  --announce \
  --channel telegram \
  --to "<chat-id>"
```

### Job isolated mingguan untuk analisa berat
```bash
openclaw cron add \
  --name "Weekly deep review" \
  --cron "0 6 * * 1" \
  --session isolated \
  --agent lab \
  --message "Review lab state, summarize project health, pending risks, and next actions." \
  --thinking high \
  --announce
```

---

## 12) Contoh pola webhook yang sehat

Kalau ingin trigger dari luar:

### Enable hooks
Contoh konsep config:
```json5
{
  "hooks": {
    "enabled": true,
    "token": "shared-secret",
    "path": "/hooks"
  }
}
```

### Wake main session
```bash
curl -X POST http://127.0.0.1:18789/hooks/wake \
  -H 'Authorization: Bearer SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"text":"New external event","mode":"now"}'
```

### Run isolated agent turn
```bash
curl -X POST http://127.0.0.1:18789/hooks/agent \
  -H 'Authorization: Bearer SECRET' \
  -H 'Content-Type: application/json' \
  -d '{"message":"Summarize new event","agentId":"worker"}'
```

---

## 13) Model strategy yang direkomendasikan

### `main`
- model terbaik untuk percakapan dan steering manusia
- continuity penting

### `lab`
- model teknis/coding yang lebih kuat
- bisa hybrid dengan Ollama untuk tugas ringan

### `worker`
- model murah/cepat
- jangan boros di model premium untuk pekerjaan rutin yang deterministic

---

## 14) Rekomendasi perubahan konfigurasi prioritas

### Prioritas 1
- hapus `BOOTSTRAP.md`
- atur heartbeat eksplisit
- pindahkan secret ke env ref

### Prioritas 2
- tambah agent `lab`
- tambah agent `worker`
- pindahkan pekerjaan non-chat ke cron isolated

### Prioritas 3
- pertimbangkan sandbox untuk worker tertentu
- audit gateway auth/rate limit
- rapikan workspace per agent dan git backup privat

---

## 15) Langkah migrasi manual ke VPS lain

### Fase A — install dan hidupkan gateway
1. install OpenClaw
2. `openclaw setup`
3. `openclaw status`

### Fase B — pulihkan workspace
1. copy/git clone workspace
2. cek file:
   - `AGENTS.md`
   - `SOUL.md`
   - `USER.md`
   - `IDENTITY.md`
   - `TOOLS.md`
   - `HEARTBEAT.md`
3. jangan ikut commit/copy secret dari `~/.openclaw/`

### Fase C — apply config
1. set workspace
2. set dmScope
3. set model
4. set heartbeat
5. set channel token via env ref
6. set provider tambahan (mis. Ollama bridge)

### Fase D — tambah agent opsional
1. `openclaw agents add lab`
2. `openclaw agents add worker`
3. tambahkan binding bila perlu

### Fase E — uji
```bash
openclaw status
openclaw channels status --probe
openclaw agents list --bindings
openclaw cron list
```

---

## 16) Checklist operasional 24/7

### Harian
- cek `openclaw status`
- cek channel connected
- cek cron run history bila ada job penting

### Mingguan
- compact/reset session panjang jika perlu
- review ukuran file bootstrap
- review workspace memory
- review cron job yang tidak lagi relevan

### Bulanan
- audit secret/config
- audit token burn
- review apakah job tertentu harus pindah dari heartbeat ke cron
- backup workspace dan state penting

---

## 17) Bottom line

Kalau ingin OpenClaw maksimal untuk lab + automasi + asisten 24/7:

- jadikan **Gateway** sebagai control plane
- pisahkan **main / lab / worker**
- pakai **heartbeat tipis**
- pakai **cron isolated** untuk kerja nyata
- jaga **workspace tetap ringkas**
- treat **session design** sebagai desain sistem, bukan detail kecil

