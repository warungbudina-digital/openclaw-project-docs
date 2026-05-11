# Cloud Shell helper-only architecture and stable worker alternatives

Dokumen ini menjawab dua hal:
1. desain arsitektur yang aman untuk memanfaatkan Google Cloud Shell sebagai helper only
2. desain worker alternatif yang lebih stabil untuk menggantikan ide rotasi `9 jam on / 1 jam off`

---

# Opsi 1 — Cloud Shell sebagai helper only

## Prinsip utama

Cloud Shell dipakai hanya sebagai:
- burst compute sementara
- helper script runner
- sandbox eksperimen
- one-shot task pendek

Cloud Shell **bukan**:
- model host utama
- daemon utama
- worker 24/7
- tempat state jangka panjang

---

## Arsitektur yang aman

```text
Ayang
  -> OpenClaw main
      -> Paperclip / n8n / FastAPI broker

FastAPI broker
  -> pilih runtime
     - local worker
     - n8n
     - OpenClaw worker
     - Cloud Shell helper (hanya untuk task pendek)

Cloud Shell helper
  -> jalankan helper script
  -> hasil disimpan ke object/shared storage
  -> selesai
  -> session boleh mati
```

---

## Kapan Cloud Shell dipakai

### Cocok untuk
- fetch data sekali jalan
- cleanup/transform file kecil
- scrape ringan
- generate artefak kecil
- test tool/CLI tertentu
- eksperimen build ringan

### Jangan dipakai untuk
- render video berat
- inference model utama
- job yang harus hidup berjam-jam
- stateful background worker
- pipeline yang bergantung pada session browser

---

## Komponen yang diperlukan

### 1. FastAPI broker
FastAPI broker bertugas:
- menerima task dari Paperclip/OpenClaw/n8n
- menilai apakah task layak dikirim ke Cloud Shell
- membatasi durasi dan ukuran kerja
- menunggu hasil atau timeout

### 2. Shared/object storage
Karena Cloud Shell tidak boleh jadi sumber state utama, hasil kerja harus keluar ke storage lain:
- object storage
- bucket
- atau shared storage milik VPS

### 3. Task policy ketat
Cloud Shell helper task harus punya policy seperti:
- max duration 20–30 menit
- max size artefak tertentu
- no persistent daemon
- no dependency on browser tab continuity

---

## Alur kerja yang saya sarankan

1. OpenClaw/Paperclip membuat task
2. FastAPI broker klasifikasikan task
3. jika task cocok untuk helper-only:
   - kirim ke Cloud Shell
4. Cloud Shell menjalankan script pendek
5. hasil ditulis ke storage eksternal
6. broker ambil hasil
7. Paperclip/OpenClaw update status

---

## Guardrails wajib

- timeout keras < 40 menit
- tidak ada session continuity assumption
- tidak ada long-running loop
- storage hasil harus di luar Cloud Shell
- setiap task idempotent kalau bisa
- kalau gagal, fallback ke worker stabil

---

## Verdict untuk opsi 1

Ini **masuk akal** kalau Cloud Shell diperlakukan sebagai:
- disposable helper
- low-trust burst compute
- bukan rumah utama agent

Itu batas aman yang realistis.

---

# Opsi 2 — Worker alternatif yang lebih stabil

Kalau tujuan Ayang sebenarnya adalah:
- punya worker yang bisa hidup lama
- biaya serendah mungkin
- lebih stabil daripada Cloud Shell gratis

maka ada beberapa desain yang lebih sehat.

---

## Opsi 2A — Dedicated small VPS worker

### Bentuk
- satu VPS kecil khusus worker
- jalankan:
  - FastAPI broker/worker
  - helper tools
  - ringan ffmpeg/scripting jika perlu

### Kelebihan
- paling stabil
- bisa 24/7
- observability jelas
- tidak tergantung browser/tab
- mudah diintegrasikan ke Paperclip/OpenClaw/n8n

### Kekurangan
- ada biaya bulanan

### Cocok untuk
- worker utama jangka panjang
- orchestration serius
- task background berulang

---

## Opsi 2B — Hybrid: main VPS + isolated worker container

### Bentuk
- tetap di VPS yang sekarang
- tapi worker dipisah ketat secara service/container
- concurrency rendah
- hanya untuk task non-render atau render sangat ringan

### Kelebihan
- tidak perlu infra baru dulu
- cepat diuji

### Kekurangan
- tetap berbagi resource dengan OpenClaw, browser, n8n, postgres, redis
- bukan jalur ideal untuk scale

### Cocok untuk
- pilot
- beban kecil
- transisi sebelum worker VPS terpisah

---

## Opsi 2C — Scheduled burst workers

### Bentuk
- bukan 24/7 single worker
- worker hidup saat ada job atau jadwal tertentu
- selesai kerja lalu stop

### Kelebihan
- lebih hemat resource
- tetap lebih stabil dari Cloud Shell browser-based

### Kekurangan
- ada cold start
- orchestration lebih kompleks

### Cocok untuk
- job batch
- job periodik
- heavy task sesekali

---

## Opsi 2D — Model host stabil + helper host murah

### Bentuk
Pisahkan dua kelas runtime:
- model host stabil
- helper host murah/disposable

Contoh:
- Ollama/API/CLI model tetap di host stabil
- helper scripts atau task sementara boleh ke host lebih murah

### Kelebihan
- model routing tetap stabil
- helper task tetap fleksibel
- tidak mencampur reasoning utama dengan runtime rapuh

### Kekurangan
- perlu orkestrasi lebih disiplin

### Cocok untuk
- arsitektur jangka menengah Ayang

---

## Opsi yang paling saya rekomendasikan

Untuk tujuan Ayang sekarang, urutan rekomendasinya:

### Terbaik untuk jangka menengah
**Opsi 2D**
- model host stabil
- helper host disposable
- Cloud Shell hanya helper jika benar-benar perlu

### Paling pragmatis untuk segera jalan
**Opsi 2A**
- dedicated small VPS worker

### Paling cepat untuk uji tanpa infra baru
**Opsi 2B**
- isolated worker container di VPS yang sekarang

---

## Desain worker yang saya anggap paling sehat

```text
OpenClaw main
  -> Paperclip / FastAPI broker
      -> stable worker host
          -> tool execution
          -> light model helpers
          -> task processing
      -> n8n
      -> optional Cloud Shell helper
```

Prinsipnya:
- worker stabil jadi tulang punggung
- Cloud Shell hanya cadangan/helper

---

## Jika Ayang ingin biaya tetap sangat hemat

Strategi hemat yang tetap waras:
- pertahankan VPS utama sekarang untuk OpenClaw + n8n
- tambahkan worker kecil/terpisah hanya untuk background execution
- pakai model kecil lokal/Ollama untuk triage
- pakai Cloud Shell hanya untuk eksperimen/helper pendek

Ini jauh lebih masuk akal daripada membuat banyak akun Cloud Shell menjadi pseudo-cluster.

---

## Putusan akhir

### Untuk Cloud Shell helper-only
Saya setuju, **asal**:
- task pendek
- stateless
- hasil keluar ke storage lain
- ada fallback ke worker stabil

### Untuk pengganti pola `9 jam on / 1 jam off`
Yang benar bukan rotasi akun Cloud Shell, tetapi:
- worker stabil sendiri
- atau worker burst yang dikendalikan dengan benar
- atau hybrid stable + helper

### Rekomendasi saya
Kalau Ayang ingin fondasi yang bisa benar-benar tumbuh:
- gunakan **worker stabil** sebagai tulang punggung
- gunakan **Cloud Shell hanya sebagai helper khusus**
