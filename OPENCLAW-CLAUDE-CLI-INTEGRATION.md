# OpenClaw + Claude CLI integration manual

Dokumen ini menjelaskan integrasi OpenClaw dengan Anthropic Claude CLI pada host gateway yang sekarang.

## Tujuan

Membuat OpenClaw bisa memakai Claude CLI sebagai backend model Anthropic, baik:
- sebagai model utama
- atau sebagai fallback
- atau hanya untuk agent tertentu

## Yang harus diubah

Ada 4 area utama:
1. instalasi/auth Claude CLI di host
2. auth OpenClaw ke metode `cli`
3. model config OpenClaw
4. optional backend override dan per-agent routing

---

## 1. Syarat awal di host gateway

Claude CLI harus terpasang di host yang menjalankan OpenClaw Gateway.

Cek:

```bash
claude --version
claude auth status --text
```

Kalau belum login:

```bash
claude auth login
```

Kalau binary `claude` tidak ada di `PATH`, itu harus dibereskan dulu.

---

## 2. Hubungkan OpenClaw ke auth Claude CLI

Jalankan di host gateway:

```bash
openclaw models auth login --provider anthropic --method cli --set-default
```

Efeknya:
- OpenClaw menyimpan auth profile Anthropic metode CLI
- jalur Anthropic diarahkan ke reuse Claude CLI lokal
- default model Anthropic bisa langsung dipakai

Verifikasi:

```bash
openclaw models status --probe
openclaw models list --provider anthropic
```

---

## 3. Config minimum yang perlu diubah

### Opsi A — Claude CLI jadi model utama

Kalau Ayang ingin default utama pindah ke Claude CLI, ubah:

```bash
openclaw config set agents.defaults.model.primary "claude-cli/claude-sonnet-4-6"
```

Kalau pakai allowlist `agents.defaults.models`, tambahkan juga entry-nya:

```bash
openclaw config set agents.defaults.models '{"claude-cli/claude-sonnet-4-6":{},"claude-cli/claude-opus-4-6":{},"codex-cli/gpt-5.4":{}}' --strict-json --merge
```

### Opsi B — Claude CLI hanya fallback

Kalau Ayang ingin OpenClaw tetap pakai model sekarang, tapi Claude CLI jadi fallback:

```bash
openclaw config set agents.defaults.model.fallbacks '["claude-cli/claude-sonnet-4-6"]' --strict-json
```

### Opsi C — Claude CLI hanya untuk agent tertentu

Contoh:
- `main` pakai Claude
- `lab` tetap Codex
- `worker` tetap kecil/hemat

Secara konsep config-nya jadi seperti ini:

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "codex-cli/gpt-5.4",
        fallbacks: ["claude-cli/claude-sonnet-4-6"]
      },
      models: {
        "codex-cli/gpt-5.4": {},
        "claude-cli/claude-sonnet-4-6": {},
        "claude-cli/claude-opus-4-6": {}
      }
    },
    list: [
      { id: "main", model: "claude-cli/claude-sonnet-4-6" },
      { id: "lab", model: "codex-cli/gpt-5.4" },
      { id: "worker", model: "ollama/qwen2.5-coder:1.5b" }
    ]
  }
}
```

Untuk OpenClaw Ayang, ini justru opsi yang paling sehat.

---

## 4. Kalau binary `claude` tidak ada di PATH

Set path explicit:

```bash
openclaw config set agents.defaults.cliBackends.claude-cli.command "/full/path/to/claude"
```

Contoh umum:
- `/usr/local/bin/claude`
- `/opt/homebrew/bin/claude`

---

## 5. Kalau Ayang pakai model allowlist

Kalau `agents.defaults.models` aktif, model Claude CLI **wajib** masuk allowlist.

Kalau tidak, OpenClaw akan tahu backend-nya ada, tapi modelnya tetap tidak bisa dipilih.

Minimal:

```bash
openclaw config set agents.defaults.models '{
  "claude-cli/claude-sonnet-4-6": {},
  "claude-cli/claude-opus-4-6": {},
  "codex-cli/gpt-5.4": {}
}' --strict-json --merge
```

---

## 6. Permission mode yang perlu dipahami

Claude CLI punya permission mode sendiri. OpenClaw memetakan ini dari exec policy.

Artinya:
- kalau exec policy OpenClaw sangat longgar / YOLO, OpenClaw bisa menambahkan:
  - `--permission-mode bypassPermissions`
- kalau Ayang ingin mode Claude tertentu secara eksplisit, set raw args backend:

```bash
openclaw config set agents.defaults.cliBackends.claude-cli.args '["--permission-mode","acceptEdits"]' --strict-json
```

Gunakan ini hanya kalau memang perlu override. Kalau tidak, biarkan default mapping OpenClaw bekerja.

---

## 7. Setting yang saya rekomendasikan untuk VPS Ayang

Karena Ayang sekarang sudah punya kombinasi:
- OpenClaw main session
- lab/worker pattern
- n8n
- Ollama
- Codex CLI

Maka saya rekomendasikan **bukan mengganti semua ke Claude CLI**, tapi pakai pembagian ini:

### Rekomendasi praktis
- `main` -> `claude-cli/claude-sonnet-4-6`
- `lab` -> `codex-cli/gpt-5.4`
- `worker` -> model kecil / Ollama

Kenapa:
- Claude CLI bagus untuk reasoning dan percakapan utama
- Codex tetap lebih cocok untuk kerja teknis yang sangat tool-heavy
- worker tetap harus murah dan stabil

---

## 8. Snippet config yang paling masuk akal

```json5
{
  agents: {
    defaults: {
      model: {
        primary: "codex-cli/gpt-5.4",
        fallbacks: ["claude-cli/claude-sonnet-4-6"]
      },
      models: {
        "codex-cli/gpt-5.4": {},
        "claude-cli/claude-sonnet-4-6": {},
        "claude-cli/claude-opus-4-6": {}
      }
    },
    list: [
      {
        id: "main",
        model: "claude-cli/claude-sonnet-4-6"
      },
      {
        id: "lab",
        model: "codex-cli/gpt-5.4"
      }
    ]
  }
}
```

Kalau Ayang ingin `main` tetap model sekarang, cukup jangan set override di agent `main`.

---

## 9. Langkah verifikasi setelah ubah config

Jalankan:

```bash
openclaw config validate
openclaw models status --probe
openclaw models list
openclaw status
```

Lalu test langsung:

```bash
openclaw agent --message "tes singkat" --model claude-cli/claude-sonnet-4-6
```

Kalau sukses, backend Claude CLI sudah hidup.

---

## 10. Apa yang tidak perlu diubah

Biasanya Ayang **tidak perlu** mengubah ini hanya untuk integrasi Claude CLI:
- heartbeat config
- channel Telegram
- workspace memory
- browser containers
- n8n

Perubahan utamanya memang hanya di:
- auth provider
- default model / fallback model
- optional per-agent model override
- optional CLI backend command/args

---

## 11. Keputusan yang paling waras

Untuk setup Ayang sekarang, keputusan paling waras adalah:

1. aktifkan Claude CLI auth di host
2. masukkan model `claude-cli/*` ke allowlist
3. jadikan `claude-cli/claude-sonnet-4-6` untuk `main`
4. biarkan `lab` tetap Codex
5. biarkan `worker` tetap hemat

Itu memberi manfaat Claude tanpa merusak arsitektur yang sudah Ayang bangun.
