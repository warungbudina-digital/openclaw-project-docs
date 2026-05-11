# Viral Editor Container Blueprint

## Tujuan
Membangun container tool yang menerima:
- source media
- output JSON dari `viral_analyzer`
- preset style / rule

Lalu menghasilkan:
- video re-cut / rebuilt versi viral
- subtitle burn-in
- optional overlay / CTA / lower-third
- manifest edit untuk audit / retry

## Jawaban singkat
Bisa dibangun.

Tapi output `viral_analyzer` saat ini lebih cocok untuk:
- **MVP re-cut berbasis aturan**
- **semi-automatic viral remake**

Belum cukup untuk:
- **rebuild 1:1 yang presisi tinggi**

## Apa yang sudah cukup dari JSON sekarang
Contoh JSON yang Ayang kirim sudah memberi sinyal penting:
- `bpm`
- `subtitle_style`
- `subtitle_segments`
- `scene_analysis[].start/end/duration`
- `scene_analysis[].hook_strength`
- `scene_analysis[].motion`
- `scene_analysis[].beat_sync`
- `scene_analysis[].semantic`
- `scene_analysis[].transition`

Dengan ini kita sudah bisa bikin:
- smart cutting
- hook-first scene ranking
- beat-aware trimming
- subtitle timing
- pacing heuristic

## Apa yang masih kurang untuk rebuild lebih presisi
Untuk hasil yang lebih kuat, sebaiknya tambah field ini di masa depan:
- `source_video_path`
- `source_audio_path`
- `target_aspect_ratio` (9:16, 1:1, 16:9)
- `target_duration`
- `face_boxes_per_scene`
- `ocr_text_regions`
- `dominant_subject_region`
- `speech_energy_per_segment`
- `music_presence`
- `brand_style_preset`
- `cta_slots`
- `broll_slots`
- `overlay_assets`

Tanpa field tambahan itu, editor masih bisa bekerja, tapi dengan heuristic/fallback.

## Rekomendasi arsitektur

### Service terpisah
Buat service/container baru:
- `viral_editor`

Bukan dicampur ke `viral_analyzer`.

### Alasan
- analyzer = observasi
- editor = generasi/render
- lifecycle beda
- logging beda
- resource profile beda

## Hubungan dengan n8n
- `n8n-main`
- `n8n-worker`
- `viral_analyzer`
- `viral_editor`

Alur:
1. n8n kirim media ke `viral_analyzer`
2. analyzer hasilkan JSON
3. n8n teruskan JSON + source asset + preset ke `viral_editor`
4. `viral_editor` render output
5. n8n simpan / kirim / publish

## Endpoint yang saya sarankan

### `POST /plan`
Input:
- analyzer JSON
- preset style
- target platform

Output:
- edit decision list (EDL)
- ranked scene picks
- subtitle plan
- overlay plan

### `POST /render`
Input:
- source media path/url
- analyzer JSON
- edit plan
- preset

Output:
- rendered file path
- manifest JSON
- debug artifacts optional

### `GET /healthz`
- service health

### `POST /preview`
- render sample pendek 10-20 detik

## Komponen di dalam container

### Wajib
- `ffmpeg`
- `ffprobe`
- FastAPI
- Python 3

### Python libs yang realistis
- `ffmpeg-python` atau langsung subprocess ffmpeg
- `pydantic`
- `python-multipart`
- `orjson`
- `Pillow`
- `numpy`
- `opencv-python-headless` (opsional, kalau butuh crop assist)
- `pysubs2` / `srt`

### Opsional
- `moviepy` (kalau butuh compositing sederhana)
- `librosa` (kalau mau beat refinement)
- `scenedetect` tambahan (kalau mau re-check cut)

## Desain pipeline render

### Step 1 — Load inputs
Input minimal:
- source video
- analyzer JSON
- target preset

### Step 2 — Build edit plan
Gunakan rule seperti:
- prioritaskan `strong_hook` lalu `medium_hook`
- penalti scene terlalu panjang
- prioritaskan `beat_sync=true`
- scene dengan `motion` tinggi diberi bobot tambahan
- `semantic` tertentu bisa diberi prioritas per niche

### Step 3 — Cut strategy
Contoh rule awal:
- hook pertama ambil 0-3 detik terbaik
- scene presentasi panjang dipotong lebih agresif
- talking head dipertahankan jika subtitle padat dan relevan
- section lemah dipotong atau dipercepat

### Step 4 — Subtitle strategy
Dari `subtitle_segments`:
- burn-in subtitle otomatis
- style ikut `subtitle_style.speed`
- segment panjang dipecah 2 baris
- fokus ke readability mobile 9:16

### Step 5 — Visual enhancement
Bisa tambahkan:
- zoom-in untuk talking head
- dynamic crop ke 9:16
- punch-in pada hook
- CTA overlay
- headline overlay
- keyword emphasis

### Step 6 — Audio finishing
- loudness normalize
- ducking kalau ada music overlay
- keep speech clarity

### Step 7 — Render + manifest
Output:
- final mp4
- EDL JSON
- render manifest
- optional debug preview

## Apa yang bisa dibuat sekarang dengan sample JSON ini
Dengan data yang Ayang kirim, MVP yang realistis adalah:
- pilih scene terbaik berdasarkan `hook_strength`, `motion`, `beat_sync`
- susun ulang jadi versi lebih padat
- burn subtitle otomatis
- crop jadi 9:16
- tambah intro hook / CTA / lower-third
- render final video versi clipper

## Apa yang belum saya anggap aman untuk otomatis penuh
Tanpa field tambahan, saya tidak akan menjanjikan otomatis penuh untuk:
- memilih wajah/speaker yang benar di semua scene
- menempatkan crop presisi tinggi
- mendeteksi chart / slide / text region secara akurat
- menyusun ulang dengan kualitas editor manusia top-tier

## Kesimpulan teknis

### Bisa dibangun?
Ya.

### Dengan data sekarang bisa jadi apa?
- tool **re-cut viral berbasis analyzer JSON**
- bukan 1:1 perfect recreation engine

### Bentuk terbaiknya?
- container FastAPI terpisah bernama `viral_editor`
- dipanggil internal oleh `n8n-main` dan `n8n-worker`
- pakai `ffmpeg` sebagai engine utama
- rule engine + preset style di atas analyzer JSON
