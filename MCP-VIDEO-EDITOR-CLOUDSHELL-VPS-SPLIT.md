# MCP Video Editor: Cloud Shell vs VPS Split

Dokumen ini memecah komponen `mcp-video-editor` menjadi dua zona:
- apa yang aman / realistis dijalankan di Google Cloud Shell gratis
- apa yang sebaiknya dipindah ke VPS

Fokusnya pragmatis: stabilitas runtime lebih penting daripada memaksakan semuanya hidup di Cloud Shell.

## Kesimpulan cepat

### Aman di Cloud Shell
- edit repo
- patch script
- generate config / compose / env template
- validasi syntax shell/python ringan
- test dry-run logic non-Docker
- commit / push / orchestration ringan

### Harus di VPS
- Docker runtime
- `custom-n8n:latest`
- `viral_analyzer` FastAPI service
- `ffmpeg` runtime
- `torch` / `open_clip_torch`
- `cloudflared` long-running tunnel
- video processing nyata
- image loading (`n8n.tar`) dan container build

---

## 1) Komponen yang aman di Cloud Shell

## A. Repo + source control
Cocok di Cloud Shell:
- clone repo
- edit `n8n-script.sh`
- edit `scripts/v2/*`
- edit `docker-compose.yml` generator
- edit README / config / prompt / docs

Kenapa aman:
- ringan
- file teks kecil
- tidak butuh service jangka panjang

## B. Static validation
Cocok di Cloud Shell:
- `bash -n`
- `python -m py_compile`
- generate file output dari shell modules
- diff dan audit

Kenapa aman:
- murah resource
- tidak perlu GPU/CPU besar
- tidak perlu storage besar

## C. Control plane ringan
Cocok di Cloud Shell:
- jalankan helper script untuk generate file
- prepare `.env.example`
- routing / orchestration kecil
- commit/push perubahan repo

Kenapa aman:
- lebih seperti workstation ringan, bukan host produksi

---

## 2) Komponen yang sebaiknya di VPS

## A. Docker dan image runtime
Pindahkan ke VPS:
- `docker load -i n8n.tar`
- `docker build -f Dockerfile.extend`
- `docker compose up -d --build`

Kenapa:
- image, layer, cache, dan volume cepat makan storage
- Cloud Shell gratis tidak cocok untuk runtime container berat yang lama hidup

## B. `viral_analyzer`
Pindahkan ke VPS:
- FastAPI service
- analyzer.py
- dependency Python besar
- `opencv`, `torch`, `open_clip`, `librosa`, `ffmpeg`

Kenapa:
- dependency besar
- memory dan CPU intensif
- inference video tidak cocok untuk Cloud Shell free

## C. `cloudflared`
Pindahkan ke VPS:
- long-running tunnel service

Kenapa:
- Cloud Shell bukan host daemon yang stabil
- sesi bisa berakhir
- tunnel butuh uptime

## D. n8n runtime
Pindahkan ke VPS:
- `custom-n8n:latest`
- workflow execution
- ffmpeg/yt-dlp runtime

Kenapa:
- service perlu stabil
- file runtime dan execution data perlu lebih durable

## E. Volume kerja video/audio/subtitle
Pindahkan ke VPS:
- `workspace/raw_video`
- `workspace/raw_audio`
- `workspace/raw_transkrip`
- `workspace/output`

Kenapa:
- file media cepat makan storage
- Cloud Shell free tidak cocok untuk media workspace aktif

---

## 3) Split architecture yang saya rekomendasikan

## Cloud Shell = control / dev box
Gunakan untuk:
- edit repo
- generate file deploy
- test syntax
- prepare config
- push update
- kirim perubahan ke VPS

## VPS = runtime / execution box
Gunakan untuk:
- pull repo
- export env secret
- run deploy v2
- run Docker services
- process video
- expose endpoint via cloudflared

---

## 4) Alur kerja ideal

### Step 1 — di Cloud Shell
- update repo `mcp-video-editor`
- test `bash -n` dan `py_compile`
- review diff
- commit / push

### Step 2 — di VPS
- pull repo terbaru
- siapkan `token.json` lokal
- export `TUNNEL_TOKEN`
- jalankan `bash n8n-script-v2.sh`

### Step 3 — di VPS setelah deploy
- cek `docker compose ps`
- cek log `viral_analyzer`
- cek endpoint health
- jalankan sample analysis

---

## 5) Komponen yang sebaiknya jangan ada di Cloud Shell

Hindari di Cloud Shell gratis:
- file video besar
- audio/subtitle batch besar
- Docker image cache besar
- model/inference runtime berat
- service yang harus hidup lama
- artifact `n8n.tar`
- build container berulang

---

## 6) Bentuk pembagian file yang sehat

## Tetap di repo / Cloud Shell
- `n8n-script.sh`
- `n8n-script-v2.sh`
- `scripts/v2/*`
- README
- `.env.example`
- compose generator
- analyzer generator source

## Hanya ada di VPS runtime
- `token.json` nyata
- `n8n.tar`
- `vendor/yt-dlp`
- `workspace/raw_*`
- `workspace/output`
- container images
- volume Docker
- tunnel process

---

## 7) Rekomendasi operasional akhir

### Cloud Shell dipakai untuk:
- build logic
- audit
- patching
- orchestration ringan

### VPS dipakai untuk:
- heavy runtime
- Docker
- video analyzer
- n8n execution
- tunnel

Kalau dipaksa semua ke Cloud Shell gratis, yang pertama bermasalah biasanya bukan repo-nya, tapi runtime: storage, image cache, dependency berat, dan uptime.
