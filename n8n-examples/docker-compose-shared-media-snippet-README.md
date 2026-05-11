# Shared media mount snippet

File:
- `docker-compose-shared-media-snippet.yml`

## Tujuan
Menjaga agar ketiga service ini melihat path yang sama:
- `n8n-worker`
- `viral_analyzer`
- `viral_editor`

## Mapping yang dipakai
Host path:
- `/home/warungbudina/partner-terbaru/openclaw/media_jobs/input`
- `/home/warungbudina/partner-terbaru/openclaw/media_jobs/output`

Container path:
- `/data/input`
- `/data/output`

## Kenapa ini penting
Kalau mapping tidak identik, workflow akan rusak di titik ini:
- `n8n-worker` download file tapi analyzer tidak melihat file itu
- analyzer selesai tapi renderer membaca path lain
- output render tersimpan di lokasi yang tidak terlihat worker

## Cara pakai
Tempel snippet ini ke compose yang relevan, lalu pastikan ketiga service join ke network yang sama:
- `media_net`

## Catatan
- `media_net` di snippet ini diset `external: true`
- kalau network Ayang namanya beda, ganti sesuai network aktual
- folder host sebaiknya dibuat dulu:
  - `/home/warungbudina/partner-terbaru/openclaw/media_jobs/input`
  - `/home/warungbudina/partner-terbaru/openclaw/media_jobs/output`
