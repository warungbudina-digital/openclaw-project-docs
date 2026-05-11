# Partner Ollama Model Matrix

Dokumen ini dipakai untuk menentukan kapan OpenClaw / n8n harus memakai:
- `phi3:mini`
- `qwen2.5-coder:1.5b`
- `gemma:2b`
- atau harus naik ke model yang lebih kuat

Fokus matrix ini adalah penggunaan pragmatis untuk workflow Ayang:
- OpenClaw sebagai control plane
- n8n sebagai automation plane
- model kecil untuk pekerjaan murah dan cepat
- escalation hanya saat memang dibutuhkan

## 1) Ringkasan cepat

### Pakai `phi3:mini` jika:
- tugasnya klasifikasi cepat
- output yang dibutuhkan pendek dan terstruktur
- pekerjaan hanya butuh ekstraksi field / tag / label
- ingin first-pass murah sebelum model lain
- ingin routing task di n8n

### Pakai `qwen2.5-coder:1.5b` jika:
- tugasnya menyusun kode kecil
- butuh JS untuk Code node n8n
- butuh transform JSON / regex / mapping / parser kecil
- butuh edit atau patch snippet yang sempit
- butuh output teknis yang lebih presisi daripada phi3

### Pakai `gemma:2b` jika:
- tugasnya drafting teks
- butuh rewrite / merapikan tulisan
- butuh outline, rangkuman, atau niche documentation
- butuh tone lebih halus daripada model kecil teknis
- butuh content prep untuk blogger / clipper / notes

### Escalate ke model lebih kuat jika:
- konteks panjang
- reasoning bercabang dan multi-langkah
- kode melibatkan banyak file atau arsitektur
- keputusan high-stakes / ambiguity tinggi
- output kecil berulang kali gagal memenuhi schema/quality

## 2) Matrix per kategori

## A. Routing / Classification / Guardrails

### Gunakan `phi3:mini`
Contoh:
- klasifikasi intent user
- memilih jalur workflow n8n
- tag sentiment ringan
- ekstraksi field ke JSON
- cek apakah task perlu naik kelas

Kenapa:
- murah
- cepat
- cukup untuk tugas sempit

Jangan pakai jika:
- konteks panjang dan noisy
- instruksi butuh banyak pengecualian
- hasil harus sangat presisi secara domain

Escalate ke:
- `qwen2.5-coder:1.5b` jika task routing sekaligus butuh transform teknis
- model lebih kuat jika routing tergantung reasoning panjang / domain nuance besar

## B. Code / Transform / n8n Code Node

### Gunakan `qwen2.5-coder:1.5b`
Contoh:
- menulis JS kecil untuk Code node n8n
- parsing response API
- mapping payload antar node
- regex extractor
- normalisasi JSON
- membuat snippet validator / formatter

Kenapa:
- lebih cocok untuk syntax dan struktur kode
- lebih stabil untuk snippet kecil dibanding model umum kecil

Jangan pakai jika:
- refactor lintas file besar
- debugging sistem penuh
- butuh arsitektur software besar
- output lebih berupa editorial daripada kode

Escalate ke:
- model lebih kuat jika task coding melibatkan banyak file, debugging kompleks, test reasoning panjang, atau patch besar
- `gemma:2b` jika output akhirnya adalah dokumentasi / penjelasan yang lebih editorial

## C. Drafting / Rewrite / Content Preparation

### Gunakan `gemma:2b`
Contoh:
- rewrite text agar lebih rapi
- bikin outline blog / note / niche doc
- merapikan ringkasan riset
- mengubah catatan kasar jadi draft enak dibaca
- menyiapkan content handoff ke blogger pipeline

Kenapa:
- lebih cocok untuk teks natural
- lebih pas untuk tone dan struktur narasi ringan

Jangan pakai jika:
- harus hasil JSON ketat tanpa toleransi
- butuh kode yang presisi
- reasoning teknis jadi inti tugas

Escalate ke:
- `qwen2.5-coder:1.5b` jika konten ternyata berubah jadi tugas teknis/Code node
- model lebih kuat jika butuh long-context synthesis atau kualitas editorial yang lebih tinggi

## D. Multi-step Reasoning / Planning / High Stakes

### Jangan memaksa model kecil
Escalate langsung ke model lebih kuat jika:
- task mencampur reasoning + code + product judgement
- banyak constraint yang harus dipenuhi sekaligus
- keputusan mempengaruhi produksi / eksekusi nyata
- output salah sedikit bisa mahal atau berbahaya
- user minta analisa mendalam, desain besar, atau audit serius

Contoh:
- desain arsitektur sistem besar
- audit n8n stack end-to-end
- debugging distribusi service multi-container
- keputusan trading / risk / execution yang tidak bisa asal
- implementasi fitur lintas banyak modul

## 3) Matrix kualitas vs biaya

### `phi3:mini`
- biaya: paling murah
- latency: paling cepat
- cocok untuk: triage, extraction, first-pass
- lemah di: nuanced reasoning, long context, complex code

### `qwen2.5-coder:1.5b`
- biaya: murah
- latency: cepat
- cocok untuk: code snippet, transforms, n8n JS
- lemah di: arsitektur besar, narasi panjang, heavy debugging

### `gemma:2b`
- biaya: murah-menengah kecil
- latency: cepat-sedang
- cocok untuk: rewrite, summarization, draft text
- lemah di: strict coding precision, schema-heavy technical output

### model lebih kuat
- biaya: paling mahal
- latency: lebih lambat
- cocok untuk: long-context, high-stakes, ambiguity tinggi, multi-step reasoning
- gunakan hanya saat model kecil tidak fit

## 4) Aturan routing praktis untuk OpenClaw / n8n

## Default order
1. mulai dari model termurah yang masih masuk akal
2. validasi output
3. kalau gagal dua kali pada task yang sama, naik kelas
4. jangan terus retry model yang salah fit

## Routing rule sederhana

### Rule 1
Jika task = classify / tag / extract / route
-> `phi3:mini`

### Rule 2
Jika task = code kecil / regex / transform / payload shaping
-> `qwen2.5-coder:1.5b`

### Rule 3
Jika task = rewrite / outline / summarize / content draft
-> `gemma:2b`

### Rule 4
Jika task = long context / high stakes / many constraints / many files
-> escalate ke model lebih kuat

## Retry policy
- retry sekali jika hanya schema formatting yang rusak
- jangan retry berkali-kali jika akar masalahnya salah pilih model
- pindah model lebih cepat lebih murah daripada forcing model kecil

## 5) Tanda bahwa harus escalate

Escalate jika salah satu muncul:
- output sering melanggar format meski prompt sudah jelas
- model kehilangan detail penting dari konteks
- hasil terlalu generik / dangkal
- reasoning terlihat putus atau kontradiktif
- kode tampak benar tapi gagal secara konsep
- tugas menyentuh banyak dependency / file / service
- user minta keputusan yang perlu akurasi tinggi

## 6) Mapping ke repo partner

### `partner-ollama-phi3-mini`
Peran utama:
- classifier
- router
- extractor
- cheap first-pass partner

### `partner-ollama-qwen2.5-coder-1.5b`
Peran utama:
- code helper
- n8n transform partner
- payload normalizer
- regex/parser partner

### `partner-ollama-gemma`
Peran utama:
- drafting partner
- rewrite partner
- editorial prep partner
- knowledge note partner

## 7) Rekomendasi operasional akhir

Kalau ragu:
- mulai `phi3:mini` untuk triage
- pindah ke `qwen2.5-coder:1.5b` untuk tugas teknis kecil
- pindah ke `gemma:2b` untuk teks dan drafting
- langsung pakai model lebih kuat untuk task besar, mahal, atau ambiguity tinggi

Jangan membuat model kecil mengerjakan tugas yang sejak awal bukan domainnya. Itu boros waktu, boros retry, dan kualitasnya tidak stabil.
