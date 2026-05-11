# n8n HTTP Request example for viral_editor

File utama:
- `viral_editor_http_nodes.json`

## Isi contoh
Workflow minimal ini berisi node:
- `Manual Trigger`
- `Set Production Envelope`
- `HTTP Plan`
- `Set Render Payload`
- `HTTP Render`

## Tujuan
- membangun envelope produksi di sisi n8n-worker
- memanggil `/plan`
- menyusun payload final render
- memanggil `/render`

## Cara pakai
1. import `viral_editor_http_nodes.json` ke n8n
2. ganti URL host render bila perlu
3. pastikan item input punya field `analysis`
4. sesuaikan `source_video_path`
5. sesuaikan `output_path`

## Catatan penting
- contoh ini untuk `n8n-worker`, bukan `n8n-main`
- contoh ini mengasumsikan host render bisa diakses lewat private IP
- field envelope seperti `job_id` dan `trace_id` dibentuk di workflow, walau API `viral_editor` saat ini hanya menerima subset field inti
