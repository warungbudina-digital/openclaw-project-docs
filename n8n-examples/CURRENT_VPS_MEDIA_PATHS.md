# Current VPS media path mapping

Dokumen ini menyesuaikan workflow produksi ke struktur VPS yang sebelumnya kita pakai.

## Host path yang direkomendasikan
Gunakan root berikut di host VPS:
- `/home/warungbudina/partner-terbaru/openclaw/media_jobs`

Turunannya:
- `/home/warungbudina/partner-terbaru/openclaw/media_jobs/input`
- `/home/warungbudina/partner-terbaru/openclaw/media_jobs/output`

## Container path
Mount ke semua service terkait sebagai:
- host `.../media_jobs/input` -> container `/data/input`
- host `.../media_jobs/output` -> container `/data/output`

Service yang harus melihat mount yang sama:
- `n8n-worker`
- `viral_analyzer`
- `viral_editor`

## URL internal service
Karena targetnya current VPS dengan Docker network internal, workflow saya set ke:
- analyzer: `http://viral_analyzer:9010/analyze`
- planner: `http://viral_editor:9020/plan`
- renderer: `http://viral_editor:9020/render`

Ini mengasumsikan semua service ada di network Docker yang sama.

## File workflow yang sudah disesuaikan
- `n8n-examples/viral_media_pipeline_current_vps.json`

## Hal yang tetap harus Ayang ganti
- `source_url`
- `source_filename`
- `notify_webhook_url`

## Catatan teknis
Workflow ini memang saya sesuaikan untuk current VPS, tapi tetap lebih cocok untuk:
- test
- pilot run
- volume kecil

Kalau render makin sering, host render tetap sebaiknya dipisah.
