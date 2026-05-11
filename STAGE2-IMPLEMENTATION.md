# Stage 2 — Tambah agent `lab` + `worker` (manual, minim risiko)

Tujuan stage 2:
- menambah pemisahan agent tanpa memutus alur chat utama
- membuat ruang kerja terpisah untuk eksperimen teknis (`lab`)
- membuat agent disposable untuk cron / background job (`worker`)
- belum menyentuh binding channel tambahan
- belum memindahkan job cron; itu lebih cocok di stage 3

---

## Prinsip stage 2

Di tahap ini kita **hanya menambah agent**.

Yang **tetap dipertahankan**:
- `main` tetap jadi agent utama untuk chat Ayang
- routing DM Telegram yang sekarang tidak dipindah
- belum ada binding account/channel baru ke `lab` atau `worker`

Artinya stage ini relatif aman karena tidak mengganggu jalur percakapan yang sudah jalan.

---

## 0) Backup config dulu

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.stage2.$(date +%Y%m%d-%H%M%S)
```

Verifikasi:
```bash
ls -lt ~/.openclaw/openclaw.json.bak.stage2.* | head
```

---

## 1) Tambah agent `lab`

Agent ini dipakai untuk:
- eksperimen teknis
- Docker
- browser / audit / dokumentasi
- pekerjaan shell yang lebih berat daripada chat biasa

Command:
```bash
openclaw agents add lab \
  --workspace ~/.openclaw/workspace-lab \
  --model codex-cli/gpt-5.4 \
  --non-interactive \
  --json
```

Catatan:
- command ini membuat agent terpisah dengan workspace sendiri
- belum menambahkan binding channel apa pun
- `lab` tidak akan mengambil alih DM yang sekarang dipakai `main`

---

## 2) Tambah agent `worker`

Agent ini dipakai untuk:
- cron job isolated
- housekeeping
- webhook / background automation
- task murah/cepat yang tidak butuh persona penuh

Command:
```bash
openclaw agents add worker \
  --workspace ~/.openclaw/workspace-worker \
  --model ollama/qwen2.5-coder:1.5b \
  --non-interactive \
  --json
```

Catatan:
- `worker` sengaja diarahkan ke model kecil/hemat
- belum ada binding channel masuk ke agent ini
- idealnya nanti dipanggil lewat cron isolated atau hook

---

## 3) Cari index agent `lab` dan `worker` di config

Karena `openclaw config set` menargetkan list dengan index, ambil index real dulu dari config aktif.

```bash
python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/'.openclaw'/'openclaw.json'
obj = json.loads(p.read_text())
for i, agent in enumerate(obj.get('agents', {}).get('list', [])):
    print(f"{i}\t{agent.get('id')}\t{agent.get('workspace')}")
PY
```

Kalau mau langsung jadi variable shell:

```bash
IDX_LAB=$(python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/'.openclaw'/'openclaw.json'
obj = json.loads(p.read_text())
for i, agent in enumerate(obj.get('agents', {}).get('list', [])):
    if agent.get('id') == 'lab':
        print(i)
        break
PY
)

IDX_WORKER=$(python3 - <<'PY'
import json, pathlib
p = pathlib.Path.home()/'.openclaw'/'openclaw.json'
obj = json.loads(p.read_text())
for i, agent in enumerate(obj.get('agents', {}).get('list', [])):
    if agent.get('id') == 'worker':
        print(i)
        break
PY
)

echo "IDX_LAB=$IDX_LAB"
echo "IDX_WORKER=$IDX_WORKER"
```

---

## 4) Rapikan konfigurasi agent `lab`

Set nama, thinking default, sandbox mode, dan tools profile agar konsisten dengan blueprint.

```bash
openclaw config set agents.list[$IDX_LAB].name "Lab Ops"
openclaw config set agents.list[$IDX_LAB].thinkingDefault "low"
openclaw config set agents.list[$IDX_LAB].sandbox.mode "off"
openclaw config set agents.list[$IDX_LAB].tools.profile "coding"
```

Opsional, kalau ingin eksplisit ulang model/workspace meski sudah diset saat `agents add`:

```bash
openclaw config set agents.list[$IDX_LAB].workspace "/home/node/.openclaw/workspace-lab"
openclaw config set agents.list[$IDX_LAB].model "codex-cli/gpt-5.4"
```

---

## 5) Rapikan konfigurasi agent `worker`

Set nama, model hemat, thinking minimal, sandbox mode, dan tools profile.

```bash
openclaw config set agents.list[$IDX_WORKER].name "Background Worker"
openclaw config set agents.list[$IDX_WORKER].thinkingDefault "minimal"
openclaw config set agents.list[$IDX_WORKER].sandbox.mode "off"
openclaw config set agents.list[$IDX_WORKER].tools.profile "coding"
openclaw config set agents.list[$IDX_WORKER].model "ollama/qwen2.5-coder:1.5b"
```

Opsional, pastikan workspace benar:

```bash
openclaw config set agents.list[$IDX_WORKER].workspace "/home/node/.openclaw/workspace-worker"
```

---

## 6) (Opsional tapi bagus) Set identity ringan untuk tiap agent

Ini bukan keharusan, tapi membantu saat nanti agent list makin banyak.

### Untuk `lab`
```bash
openclaw agents set-identity --agent lab --name "Lab Ops" --emoji "🧪"
```

### Untuk `worker`
```bash
openclaw agents set-identity --agent worker --name "Background Worker" --emoji "⚙️"
```

Catatan:
- ini hanya membantu identitas agent
- tidak mengubah routing chat
- bisa dilewati kalau mau tetap minimal dulu

---

## 7) Validasi hasil stage 2

### Lihat agent + binding
```bash
openclaw agents list --bindings
```

Yang diharapkan:
- ada `main`
- ada `lab`
- ada `worker`
- binding DM lama tetap menuju `main`
- `lab` dan `worker` belum punya binding masuk kalau memang belum dibuat

### Lihat config agent
```bash
openclaw config get agents.list --json
```

### Cek workspace agent baru
```bash
ls -la ~/.openclaw/workspace-lab
ls -la ~/.openclaw/workspace-worker
```

### Validasi config total
```bash
openclaw config validate
openclaw status
```

---

## 8) Jika gateway perlu restart

Kalau agent baru belum langsung terlihat di runtime:

```bash
openclaw gateway restart
```

Lalu cek lagi:

```bash
openclaw agents list --bindings
openclaw status
```

---

## 9) Hasil yang diharapkan setelah stage 2

- `main` tetap khusus chat personal
- `lab` sudah siap dipakai untuk kerja teknis / eksperimen
- `worker` sudah siap dipakai untuk cron isolated / background job
- workspace terpisah sudah tersedia
- routing chat lama tetap aman
- fondasi multi-agent sudah ada tanpa harus langsung memindahkan traffic

---

## 10) Batas stage 2

Stage 2 **belum** mencakup:
- binding Telegram/account baru ke `lab` atau `worker`
- migrasi cron job ke `worker`
- hook/webhook routing ke agent spesifik
- pengetatan sandbox/security lebih lanjut

Itu lebih cocok masuk stage 3.

---

## 11) Rollback cepat kalau tidak cocok

### Hapus agent `worker`
```bash
openclaw agents delete worker --force
```

### Hapus agent `lab`
```bash
openclaw agents delete lab --force
```

Catatan:
- sesuai perilaku CLI, workspace/state/session agent akan dipindah ke Trash, bukan hard-delete

### Atau rollback penuh dari backup config
```bash
cp ~/.openclaw/openclaw.json.bak.stage2.YYYYMMDD-HHMMSS ~/.openclaw/openclaw.json
```

Lalu restart bila perlu:
```bash
openclaw gateway restart
```

---

## 12) Next step yang paling natural sesudah ini

Setelah stage 2 selesai dan stabil, stage 3 yang cocok adalah:

1. pilih job mana yang pindah ke `worker`
2. ubah cron jadi `--session isolated`
3. kalau perlu, tambahkan hook / webhook ke agent yang tepat
4. kalau nanti ingin akun/channel teknis terpisah, baru buat binding ke `lab`
