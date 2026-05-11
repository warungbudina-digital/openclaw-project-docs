# Paperclip manual aligned to OpenClaw Master Architecture

Dokumen ini menjelaskan bagaimana Paperclip diposisikan dan diintegrasikan ke arsitektur pada `OPENCLAW-MASTER-ARCHITECTURE.md`.

## Ringkasan keputusan

Paperclip **tidak** saya rekomendasikan menggantikan OpenClaw.

Untuk target Ayang, posisi yang benar adalah:
- **OpenClaw** tetap jadi human-facing control plane
- **n8n** tetap jadi workflow engine
- **Ollama / model routing** tetap jadi inference layer
- **Paperclip** masuk sebagai **Agent Orchestration Layer + Governance Layer**

Dengan kata lain:
- OpenClaw = operator utama yang berinteraksi dengan Ayang
- Paperclip = manajer perusahaan / task control plane untuk banyak agent

---

## 1. Mapping ke OpenClaw Master Architecture

### 1.1 Human Interface Layer
Tetap:
- Telegram -> OpenClaw `main`

Paperclip **bukan** pengganti chat utama Ayang.

### 1.2 Control Plane Layer
Tetap:
- OpenClaw `main` = koordinator yang dekat ke user

Perubahan:
- OpenClaw `main` bisa memutuskan kapan pekerjaan dikelola lewat Paperclip

### 1.3 Automation Plane Layer
Tetap:
- n8n = scheduler, webhook, retry, pipeline

Perubahan:
- workflow n8n bisa diperlakukan sebagai execution system yang dipicu oleh OpenClaw atau oleh task dari Paperclip

### 1.4 Inference Layer
Tetap:
- Ollama + model routing per tugas

Paperclip tidak menggantikan model routing; dia hanya mengatur agent dan tugas.

### 1.5 Tool Execution Layer
Tetap:
- shell
- browser
- custom CLIs
- Cloud Shell helper

Paperclip tidak menjalankan tool secara langsung; adapter agent-lah yang menjalankan.

### 1.6 Agent Orchestration Layer
Di sinilah Paperclip paling cocok.

Paperclip memberi:
- org chart agent
- heartbeats
- task assignment
- run history
- budget/cost awareness
- audit trail
- governance / approval

Ini cocok persis dengan slot `future paper@clip-style manager/orchestrator` di arsitektur Ayang.

### 1.7 Persistence and Observability Layer
Paperclip kuat di:
- task/ticket history
- audit log
- run status
- cost history
- agent activity view

Artinya Paperclip bisa menutup gap observability antar banyak agent.

---

## 2. Posisi arsitektur yang saya rekomendasikan

```text
Ayang
  -> Telegram
  -> OpenClaw main
      -> n8n
      -> local tools / browser / shell
      -> Paperclip (task + governance + org chart)

Paperclip
  -> OpenClaw gateway agent(s)
  -> Codex agent(s)
  -> Claude agent(s)
  -> future specialist agents
```

### Prinsip penting
Paperclip berada **di atas layer kerja multi-agent**, bukan di atas Ayang.

Ayang tetap bicara ke OpenClaw.
OpenClaw yang memutuskan kapan:
- bertindak langsung
- menyerahkan ke n8n
- menyerahkan ke Paperclip

---

## 3. Yang harus diubah kalau ingin integrasi nyata

### 3.1 Jangan mulai dari banyak agent sekaligus
Mulai dari **1 company** dan **2-3 agent** saja.

Rekomendasi awal:
- `openclaw_ops` -> adapter `openclaw_gateway`
- `codex_builder` -> adapter Codex local
- `claude_research` -> adapter Claude local/CLI

Belum perlu forecasting agent, content swarm, atau market swarm di tahap awal.

### 3.2 OpenClaw harus punya gateway yang stabil
Paperclip membutuhkan OpenClaw melalui adapter `openclaw_gateway`.

Jadi yang harus stabil di OpenClaw:
- gateway URL
- gateway auth token yang benar
- device auth/pairing yang benar
- agent dapat dihubungi dari Paperclip

### 3.3 Pisahkan peran OpenClaw
Untuk integrasi awal, jangan masukkan semua role OpenClaw sebagai satu agent Paperclip.

Rekomendasi:
- **jangan** pakai `main` sebagai worker Paperclip utama
- buat role OpenClaw yang lebih operasional, misalnya:
  - `openclaw_ops`
  - atau gunakan `worker` / `lab` sebagai target gateway task

Alasannya:
- `main` harus tetap fokus ke interaksi Ayang
- Paperclip cenderung memicu autonomous loops / heartbeats
- itu tidak cocok kalau langsung menabrak sesi human-facing utama

### 3.4 n8n jangan dipindah ke Paperclip
n8n tetap di tempatnya.

Yang benar:
- Paperclip membuat tugas atau memicu agent
- agent atau OpenClaw memanggil n8n bila perlu

Yang salah:
- memindahkan logika workflow n8n menjadi task manager Paperclip

Paperclip bukan pengganti n8n.

---

## 4. Deployment mode yang saya sarankan

Dari docs Paperclip, ada dua mode besar:
- `local_trusted`
- `authenticated`

Untuk VPS Ayang, saya sarankan:
- **`authenticated + private`**

Bukan `public` dulu.

### Kenapa
- lebih aman
- tetap ada login/human auth
- cocok untuk VPN/Tailscale/LAN/private route
- belum perlu menambah hardening internet-facing yang berat

Kalau nanti mau production cloud exposure penuh, baru naik ke `authenticated + public`.

---

## 5. Urutan implementasi yang benar

### Phase 1 — deploy Paperclip sendiri dulu
Tujuan:
- Paperclip hidup
- login jalan
- UI bisa diakses
- DB/runtime stabil

Checklist:
- server jalan
- login board/admin jalan
- company bisa dibuat
- task/issue bisa dibuat manual

### Phase 2 — onboard satu OpenClaw agent
Gunakan docs onboarding OpenClaw dari repo Paperclip.

Target awal:
- 1 agent `openclaw_gateway`
- bisa menerima task
- bisa memberi comment/update
- bisa menyelesaikan task sederhana

Jangan lanjut sebelum ini stabil.

### Phase 3 — tambahkan satu coding agent
Tambahkan salah satu dulu:
- `codex_local`
- atau `claude_local`

Tujuannya untuk melihat:
- assignment
- heartbeat
- resume
- run history
- cost/logging

### Phase 4 — mapping ke arsitektur Ayang
Baru setelah itu petakan:
- OpenClaw ops agent
- coding agent
- research agent
- future specialist agents

### Phase 5 — baru hubungkan ke n8n dan specialist workflows
Setelah Paperclip stabil sebagai orchestration plane, baru pakai dia untuk:
- mengeluarkan task yang nanti memicu n8n
- mengoordinasikan agent lintas domain
- mengelola escalation dan approval

---

## 6. Topologi agent awal yang saya rekomendasikan

### Minimal viable topology

#### Company: `Ayang Ops`

Agents:
1. `openclaw_ops`
   - adapter: `openclaw_gateway`
   - tugas: ops, coordination, messaging-adjacent, tool dispatch ringan

2. `codex_builder`
   - adapter: `codex_local`
   - tugas: coding, patch, implementation, repo work

3. `claude_research`
   - adapter: `claude_local`
   - tugas: research, synthesis, strategy drafts

### Yang jangan dulu ditambahkan
- agent market/trading otomatis
- content swarm banyak agent
- multi-company
- loop heartbeats agresif
- banyak specialist agent sekaligus

Itu tahap kedua setelah basic orchestration terbukti stabil.

---

## 7. Manual teknis integrasi nyata

## Step A — hidupkan Paperclip
Deploy Paperclip pada VPS atau host terpisah.

Rekomendasi awal:
- mode: `authenticated + private`
- bind: private/VPN/Tailscale atau loopback + reverse proxy privat

## Step B — verifikasi OpenClaw gateway
Sebelum onboarding ke Paperclip, OpenClaw harus lolos ini:
- gateway hidup
- token valid
- pair/device auth valid
- agent bisa merespons task sederhana

## Step C — onboard OpenClaw ke Paperclip
Ikuti flow docs `doc/OPENCLAW_ONBOARDING.md` dari repo Paperclip.

Tujuan awal hanya satu:
- Paperclip dapat membuat agent `openclaw_gateway` yang benar-benar usable

## Step D — buat company kecil dan task test
Buat test cases seperti:
- task comment marker
- kirim pesan balik
- buat issue baru

Kalau ini belum stabil, jangan naik ke workflow kompleks.

## Step E — tambah coding/research agents
Setelah OpenClaw agent stabil, baru tambah:
- Codex
- Claude

## Step F — integrasikan dengan arsitektur Ayang
Setelah semua agent dasar stabil, barulah:
- OpenClaw main mengirim tugas ke Paperclip
- Paperclip mengelola agent execution
- n8n tetap jadi workflow engine

---

## 8. Apa yang perlu diubah di OpenClaw

Untuk integrasi Paperclip, perubahan di OpenClaw fokus pada:

### wajib
- gateway stabil
- token auth valid
- pairing/device auth benar
- role agent yang akan di-onboard jelas

### disarankan
- jangan pakai `main` sebagai agent heartbeat Paperclip utama
- siapkan role operational sendiri
- pastikan tools/permissions role itu sesuai tugasnya

### tidak perlu diubah dulu
- semua browser
- semua n8n workflow
- semua model routing
- semua specialist agent

---

## 9. Apa yang perlu diubah di cara kerja Ayang

Kalau pakai Paperclip, pola kerjanya berubah sedikit:

### Sebelumnya
Ayang -> OpenClaw -> langsung eksekusi

### Setelah ada Paperclip
Ayang -> OpenClaw -> pilih:
- direct execution
- n8n workflow
- Paperclip managed task

Artinya Paperclip dipakai saat:
- tugas harus ditrack
- banyak agent harus dikoordinasikan
- biaya dan governance harus diawasi
- run history harus jelas

Bukan untuk semua hal kecil.

---

## 10. Rekomendasi paling praktis

Kalau disederhanakan, saya sarankan begini:

### Tahap sekarang
- pelajari Paperclip
- deploy private
- onboard satu OpenClaw agent
- test basic task lifecycle

### Tahap sesudah stabil
- tambah Codex/Claude agent
- mulai gunakan Paperclip untuk task yang berat, panjang, dan lintas-agent

### Tahap lanjut
- hubungkan ke n8n
- hubungkan ke specialist agents
- baru bangun company-level orchestration penuh

---

## 11. Kesimpulan

Untuk tujuan dari `OPENCLAW-MASTER-ARCHITECTURE.md`, Paperclip sangat cocok **bukan sebagai pengganti OpenClaw**, tapi sebagai:
- orchestrator
- governance layer
- multi-agent company control plane

Posisi yang benar:
- OpenClaw tetap jadi assistant utama Ayang
- Paperclip jadi manajer kerja multi-agent
- n8n tetap jadi workflow engine
- Ollama/model routing tetap jadi inference layer
