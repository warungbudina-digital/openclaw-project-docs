# viral_media_pipeline_full

Workflow ini adalah contoh alur n8n yang lebih lengkap untuk:
- download source
- panggil analyzer
- panggil planner
- panggil renderer
- verifikasi hasil tersimpan

## File
- `viral_media_pipeline_workflow.json`

## Asumsi penting
Workflow ini mengasumsikan:
1. `n8n-worker` punya akses tulis ke shared path `/data/input` dan `/data/output`
2. `viral_analyzer` membaca source dari shared path yang sama
3. `viral_editor` juga membaca source dari shared path yang sama
4. analyzer dan renderer dapat dijangkau via private IP / host internal

Kalau shared storage belum ada, workflow ini perlu diubah. Itu bukan bug workflow; itu gap arsitektur.

## Node flow
1. `Set Job Config`
   - bentuk `job_id`, `trace_id`, `source_url`, `source_video_path`, `output_path`
2. `Download Source To Shared Input`
   - download video ke `/data/input`
3. `HTTP Analyze`
   - panggil analyzer
4. `Set Envelope After Analysis`
   - gabungkan hasil analyzer + preset + metadata job
5. `HTTP Plan`
   - panggil `/plan` di `viral_editor`
6. `Set Render Payload`
   - susun payload final render
7. `HTTP Render`
   - panggil `/render`
8. `Verify Output Saved`
   - cek output file benar-benar ada
9. `Set Final Result`
   - bentuk hasil akhir yang rapi untuk node lanjutan

## Field yang wajib Ayang ganti setelah import
- `source_url`
- `source_filename`
- `source_video_path`
- `output_path`
- host analyzer
- host renderer

## Rekomendasi
- jalankan ini di `n8n-worker`, bukan `n8n-main`
- mulai dari 1 job dulu
- kalau sudah stabil, baru tambahkan retry, DB logging, dan notification node
