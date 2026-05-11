# Stage 1 — Implementasi manual OpenClaw (non-disruptive)

Tujuan stage 1:
- hemat token
- rapikan heartbeat
- pindahkan secret ke env ref
- bersihkan sisa first-run
- belum mengubah routing multi-agent

---

## 0) Backup config dulu

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%Y%m%d-%H%M%S)
```

Verifikasi:
```bash
ls -lt ~/.openclaw/openclaw.json.bak.* | head
```

---

## 1) Export env untuk secret yang akan dipindah ke SecretRef

Isi nilainya dengan secret milik host saat ini.

```bash
export GATEWAY_AUTH_TOKEN='ISI_TOKEN_GATEWAY'
export TELEGRAM_BOT_TOKEN='ISI_TOKEN_TELEGRAM'
export OLLAMA_BRIDGE_API_KEY='ISI_API_KEY_OLLAMA_BRIDGE'
```

Cek sudah ada:
```bash
env | grep -E 'GATEWAY_AUTH_TOKEN|TELEGRAM_BOT_TOKEN|OLLAMA_BRIDGE_API_KEY'
```

Catatan:
- kalau gateway jalan sebagai service/daemon, env ini juga harus disediakan di environment service, bukan hanya shell interaktif.
- untuk migrasi VPS, ini lebih baik diletakkan di file env atau service manager.

---

## 2) Tambahkan provider SecretRef default (env)

```bash
openclaw config set secrets.providers.default '{"source":"env"}' --strict-json
```

Verifikasi:
```bash
openclaw config validate
```

---

## 3) Pindahkan secret dari plaintext ke env ref

### Gateway auth token
```bash
openclaw config set gateway.auth.token --ref-provider default --ref-source env --ref-id GATEWAY_AUTH_TOKEN
```

### Telegram bot token
```bash
openclaw config set channels.telegram.botToken --ref-provider default --ref-source env --ref-id TELEGRAM_BOT_TOKEN
```

### Ollama bridge API key
```bash
openclaw config set models.providers.ollama.apiKey --ref-provider default --ref-source env --ref-id OLLAMA_BRIDGE_API_KEY
```

Verifikasi:
```bash
openclaw config validate
```

Opsional inspeksi cepat:
```bash
openclaw config get gateway.auth
openclaw config get channels.telegram
openclaw config get models.providers.ollama
```

---

## 4) Terapkan heartbeat hemat token

### Set interval heartbeat
```bash
openclaw config set agents.defaults.heartbeat.every "2h"
```

### Pakai isolated session
```bash
openclaw config set agents.defaults.heartbeat.isolatedSession true --strict-json
```

### Pakai light context
```bash
openclaw config set agents.defaults.heartbeat.lightContext true --strict-json
```

### Jangan injek section heartbeat ke system prompt biasa
```bash
openclaw config set agents.defaults.heartbeat.includeSystemPromptSection false --strict-json
```

### Blok direct DM delivery dari heartbeat
```bash
openclaw config set agents.defaults.heartbeat.directPolicy "block"
```

### Default target none
```bash
openclaw config set agents.defaults.heartbeat.target "none"
```

### Timeout heartbeat singkat
```bash
openclaw config set agents.defaults.heartbeat.timeoutSeconds 45 --strict-json
```

Verifikasi:
```bash
openclaw config get agents.defaults.heartbeat
openclaw status
```

---

## 5) Bersihkan BOOTSTRAP.md

Sebelum menghapus, arsipkan dulu:

```bash
mv ~/.openclaw/workspace/BOOTSTRAP.md ~/.openclaw/workspace/BOOTSTRAP.md.done
```

Verifikasi:
```bash
ls -l ~/.openclaw/workspace/BOOTSTRAP.md*
```

Catatan:
- ini lebih aman daripada delete langsung.
- nanti kalau benar-benar tidak dibutuhkan, bisa dihapus manual.

---

## 6) Validasi final stage 1

```bash
openclaw config validate
openclaw status
openclaw channels status --probe
```

Kalau ingin cek apakah config benar-benar sudah berupa ref, bukan plaintext:

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/'.openclaw'/'openclaw.json'
obj = json.loads(p.read_text())
print('gateway.auth.token =', obj.get('gateway',{}).get('auth',{}).get('token'))
print('channels.telegram.botToken =', obj.get('channels',{}).get('telegram',{}).get('botToken'))
print('models.providers.ollama.apiKey =', obj.get('models',{}).get('providers',{}).get('ollama',{}).get('apiKey'))
PY
```

---

## 7) Jika gateway perlu restart

Kalau runtime tidak reload otomatis di host target:

```bash
openclaw gateway restart
```

Lalu cek lagi:

```bash
openclaw status
openclaw channels status --probe
```

---

## 8) Hasil yang diharapkan setelah stage 1

- secret tidak lagi hardcoded plaintext
- heartbeat jauh lebih murah
- BOOTSTRAP tidak lagi ikut membebani prompt
- belum ada perubahan multi-agent / routing, jadi aman sebagai tahap awal

---

## 9) Jika ingin rollback cepat

### Rollback config
```bash
cp ~/.openclaw/openclaw.json.bak.YYYYMMDD-HHMMSS ~/.openclaw/openclaw.json
```

### Kembalikan bootstrap file
```bash
mv ~/.openclaw/workspace/BOOTSTRAP.md.done ~/.openclaw/workspace/BOOTSTRAP.md
```

### Restart gateway bila perlu
```bash
openclaw gateway restart
```

