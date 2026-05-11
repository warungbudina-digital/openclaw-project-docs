# Viral Editor Production Contract

Dokumen ini mendefinisikan payload contract final antara `n8n-worker` dan service `viral_editor` untuk mode produksi.

## Tujuan

Contract ini dibuat supaya:
- payload dari `n8n-worker` konsisten
- `viral_editor` bisa divalidasi dengan schema yang stabil
- retry, audit, dan observability lebih mudah
- path file, preset, dan hasil render tidak ambigu

## Prinsip operasi

- `n8n-main` tidak memanggil `viral_editor` secara langsung
- `n8n-worker` adalah satu-satunya dispatcher render
- request dibagi menjadi 2 tahap:
  1. `/plan`
  2. `/render`
- file media tidak dikirim sebagai binary inline
- `source_video_path` dan `output_path` harus valid di host render
- semua request harus punya `job_id` dan `trace_id`

---

## 1. Endpoint contract

### `POST /plan`
Membangun edit plan tanpa render.

### `POST /render`
Menjalankan render berdasarkan analyzer output + preset + plan.

### `GET /healthz`
Health check service.

---

## 2. Production envelope

Semua request dari `n8n-worker` sebaiknya memakai envelope berikut:

```json
{
  "job_id": "render_20260511_001",
  "trace_id": "wf_abc123_exec_456",
  "requested_by": "n8n-worker",
  "request_version": "2026-05-11.v1",
  "source_video_path": "/data/input/source.mp4",
  "analysis": {},
  "preset": {},
  "plan": null,
  "dry_run": false,
  "output_path": "/data/output/render_20260511_001/final.mp4"
}
```

### Field envelope
- `job_id`: id unik render job
- `trace_id`: id yang mengikat job ke execution n8n
- `requested_by`: harus `n8n-worker`
- `request_version`: versi contract/payload
- `source_video_path`: path input video di host render
- `analysis`: hasil dari `viral_analyzer`
- `preset`: aturan edit
- `plan`: hasil endpoint `/plan` bila sudah ada
- `dry_run`: `true` untuk simulasi tanpa render
- `output_path`: path output final di host render

Catatan:
- versi FastAPI `viral_editor` saat ini belum memvalidasi `job_id`, `trace_id`, `requested_by`, dan `request_version`
- untuk produksi, field itu tetap harus disiapkan di sisi `n8n-worker`
- bila perlu, `n8n-worker` bisa menyimpan envelope penuh di DB/log lalu hanya mengirim subset field yang diminta API saat ini

---

## 3. Contract untuk `/plan`

### Request minimal `/plan`

```json
{
  "source_video_path": "/data/input/source.mp4",
  "analysis": {
    "video": "source.mp4",
    "bpm": 123.046875,
    "subtitle_style": {
      "speed": "medium",
      "word_count_avg": 6.16
    },
    "subtitle_segments": [
      {
        "text": "Kripto dari nol di tahun 2026.",
        "start": 0.47,
        "end": 2.47
      }
    ],
    "scene_analysis": [
      {
        "start": 0.0,
        "end": 11.93,
        "duration": 11.93,
        "semantic": "youtube talking head",
        "emotion": "neutral face",
        "meme": "reaction meme",
        "motion": 12.66,
        "camera_movement": "static",
        "transition": "cut",
        "beat_sync": true,
        "framing": {
          "faces": [],
          "speaker_position": "unknown"
        },
        "hook_strength": "medium_hook"
      }
    ]
  },
  "preset": {
    "platform": "tiktok",
    "target_aspect_ratio": "9:16",
    "target_duration_sec": 45,
    "max_scenes": 8,
    "prefer_hook_strength": true,
    "prefer_beat_sync": true,
    "allow_reorder": false,
    "caption_mode": "plan_only",
    "add_cta": true,
    "title_text": "Belajar kripto dari nol",
    "cta_text": "Save video ini"
  }
}
```

### Response `/plan`

```json
{
  "plan_id": "plan_xxx",
  "source_video_path": "/data/input/source.mp4",
  "selected_scenes": [
    {
      "index": 0,
      "source_start": 0.0,
      "source_end": 11.93,
      "duration": 11.93,
      "score": 0.82,
      "reason": ["beat_sync", "medium_hook", "high_motion"]
    }
  ],
  "estimated_duration_sec": 38.5,
  "subtitle_plan": {},
  "render_profile": {},
  "warnings": []
}
```

### Aturan `/plan`
- `n8n-worker` wajib menyimpan response `/plan`
- response `/plan` menjadi input render final
- kalau `warnings` terlalu banyak, workflow sebaiknya berhenti atau pindah ke human review

---

## 4. Contract untuk `/render`

### Request `/render`

```json
{
  "source_video_path": "/data/input/source.mp4",
  "analysis": {
    "video": "source.mp4",
    "bpm": 123.046875,
    "subtitle_style": {
      "speed": "medium",
      "word_count_avg": 6.16
    },
    "subtitle_segments": [],
    "scene_analysis": []
  },
  "preset": {
    "platform": "tiktok",
    "target_aspect_ratio": "9:16",
    "target_duration_sec": 45,
    "max_scenes": 8,
    "prefer_hook_strength": true,
    "prefer_beat_sync": true,
    "allow_reorder": false,
    "caption_mode": "plan_only",
    "add_cta": true,
    "title_text": "Belajar kripto dari nol",
    "cta_text": "Save video ini"
  },
  "plan": {
    "plan_id": "plan_xxx",
    "source_video_path": "/data/input/source.mp4",
    "selected_scenes": [],
    "estimated_duration_sec": 38.5,
    "subtitle_plan": {},
    "render_profile": {},
    "warnings": []
  },
  "dry_run": false,
  "output_path": "/data/output/render_20260511_001/final.mp4"
}
```

### Response sukses `/render`

```json
{
  "status": "rendered",
  "output_path": "/data/output/render_20260511_001/final.mp4",
  "plan": {
    "plan_id": "plan_xxx"
  },
  "manifest": {
    "engine": "ffmpeg",
    "steps": ["cut", "concat", "crop", "burn_subtitles"],
    "segments_rendered": 6,
    "captions_applied": true,
    "aspect_ratio": "9:16"
  }
}
```

### Response dry-run `/render`

```json
{
  "status": "dry_run",
  "output_path": "/data/output/render_20260511_001/final.mp4",
  "plan": {
    "plan_id": "plan_xxx"
  },
  "manifest": {
    "engine": "ffmpeg",
    "steps": ["cut", "concat"],
    "captions_applied": false
  }
}
```

### Response error `/render`

```json
{
  "detail": {
    "error": "render_failed",
    "message": "..."
  }
}
```

---

## 5. Aturan path dan storage

### `source_video_path`
Harus menunjuk ke file yang benar-benar ada di host render, contoh:
- `/data/input/source.mp4`
- `/data/input/jobs/render_20260511_001/source.mp4`

### `output_path`
Harus deterministic, contoh:
- `/data/output/render_20260511_001/final.mp4`
- `/data/output/{{job_id}}/final.mp4`

### Jangan gunakan
- path lokal host n8n yang tidak dimount ke render host
- path random tanpa job folder
- binary file inline di payload JSON

---

## 6. Aturan retry dan idempotency

Supaya aman di produksi:
- `job_id` tidak boleh berubah saat retry job yang sama
- `trace_id` harus mengarah ke execution n8n yang sama
- `output_path` boleh sama untuk retry overwrite
- sebelum retry, `n8n-worker` harus cek:
  - file source masih ada
  - plan masih valid
  - host render sehat

Disarankan `n8n-worker` menyimpan status job:
- `queued`
- `planned`
- `rendering`
- `rendered`
- `failed`
- `needs_review`

---

## 7. Logging yang wajib disimpan oleh n8n-worker

Minimal simpan:
- `job_id`
- `trace_id`
- request `/plan`
- response `/plan`
- request `/render`
- response `/render`
- error detail jika gagal
- `output_path`
- waktu mulai dan selesai

Ini penting untuk:
- retry
- audit
- observability
- evaluasi kualitas output

---

## 8. Guardrails produksi

- `n8n-main` tidak render langsung
- render hanya dijalankan dari `n8n-worker`
- default `dry_run=true` di environment test
- concurrency render mulai dari `1`
- gunakan private IP antar host bila tersedia
- `cloudflared` hanya fallback bila private route tidak ada
- asset besar harus dibersihkan rutin

---

## 9. Contract subset untuk API saat ini

Karena API `viral_editor` v1 saat ini baru menerima field inti, maka payload yang benar-benar dikirim ke API sekarang cukup subset ini:

### `/plan`
```json
{
  "source_video_path": "...",
  "analysis": {},
  "preset": {}
}
```

### `/render`
```json
{
  "source_video_path": "...",
  "analysis": {},
  "preset": {},
  "plan": {},
  "dry_run": false,
  "output_path": "..."
}
```

Envelope produksi tetap harus ada di sisi workflow/logging, walau belum semua field dikirim ke API.

---

## 10. Kesimpulan

Contract produksi finalnya adalah:
- `n8n-worker` memegang envelope penuh
- `viral_editor` menerima subset field yang dibutuhkan endpoint saat ini
- `/plan` dan `/render` dipisah
- path input/output harus deterministic
- semua request/response harus dilog untuk retry dan audit
