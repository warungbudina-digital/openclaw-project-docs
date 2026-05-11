# viral_media_pipeline_prod

File:
- `viral_media_pipeline_prod_workflow.json`
- `viral_media_pipeline_error_handler.json`

## Yang ditambahkan
### Retry
Node kritis sekarang diberi retry:
- `Download Source To Shared Input`
- `HTTP Analyze`
- `HTTP Plan`
- `HTTP Render`
- `Verify Output Saved`

### Logging
Workflow utama sekarang menulis file log sukses ke:
- `{{$json.log_dir}}/run-success.json`

Workflow error handler menulis file log gagal ke:
- `/data/output/error/failure_*.json`

### Notification
Ada node webhook notifikasi:
- `HTTP Notify Success`
- `HTTP Notify Failure`

Ganti `notify_webhook_url` sesuai endpoint notification Ayang.

## Catatan penting
- workflow error handler harus di-import sebagai workflow terpisah
- workflow utama tetap dijalankan di `n8n-worker`
- kalau Ayang belum punya webhook notification, node notify bisa didisable dulu
- logging file mengasumsikan `n8n-worker` bisa menulis ke `/data/output`
