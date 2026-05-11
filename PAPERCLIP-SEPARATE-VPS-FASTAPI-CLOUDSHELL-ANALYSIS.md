# Paperclip on separate VPS + FastAPI + Google Cloud Shell analysis

Dokumen ini menjawab skenario berikut:
- Paperclip diinstal di VPS terpisah
- integrasi ke orkestra Ayang lewat FastAPI
- model/eksekusi banyak diletakkan di Google Cloud Shell gratis
- Cloud Shell diakses lewat tab browser pada container sandbox browser
- Claude belum dimasukkan ke orkestra

## Kesimpulan singkat

### Mungkin?
**Ya, secara teknis mungkin** untuk tahap eksperimen / pilot.

### Baik untuk jangka panjang?
**Tidak, kalau Cloud Shell gratis dijadikan lapisan eksekusi utama untuk semua model dan semua agent.**

### Infinite / terus-menerus 24/7?
**Tidak realistis.**
Cloud Shell gratis bersifat **ephemeral, terbatas, dan tidak cocok** sebagai runtime utama yang harus selalu hidup.

---

## 1. Bagaimana Paperclip sebenarnya bekerja

Paperclip bukan model runner.
Paperclip adalah:
- task system
- heartbeat scheduler
- org chart / role manager
- governance / budget / audit layer
- adapter dispatcher

Artinya Paperclip tidak berpikir sendiri dan tidak menjalankan model langsung.
Dia melakukan ini:

1. ada issue/task/work item
2. task diassign ke agent tertentu
3. heartbeat membangunkan agent
4. adapter agent dipanggil
5. agent bekerja di runtime eksternal
6. hasil/status/log dikirim balik ke Paperclip
7. Paperclip menyimpan run history, cost, task state, audit

Jadi Paperclip = **control plane**.
Bukan execution engine utama.

---

## 2. Kalau dipasang di arsitektur Ayang, posisi teknisnya seperti apa

Arsitektur yang masuk akal untuk skenario Ayang:

```text
Ayang
  -> OpenClaw main
      -> putuskan direct / n8n / Paperclip

Paperclip (VPS terpisah)
  -> heartbeat + task + budgets + governance
  -> panggil agent adapter via HTTP/FastAPI

FastAPI orchestration layer
  -> terima heartbeat job dari Paperclip
  -> route ke runtime yang tepat
  -> panggil OpenClaw / n8n / browser / helper / Cloud Shell
  -> kembalikan hasil ke Paperclip

Runtime layer
  -> OpenClaw worker/lab
  -> n8n
  -> browser sandbox
  -> Cloud Shell helper session
  -> future specialist tools
```

Jadi kalau Ayang ingin pakai FastAPI di tengah, perannya adalah:
- **adapter bridge / execution broker**
- bukan pengganti Paperclip
- bukan pengganti OpenClaw

---

## 3. Detail teknis cara kerja kalau memakai FastAPI bridge

### 3.1 Dari sisi Paperclip
Paperclip akan membangunkan agent melalui adapter.

Kalau Ayang memilih pola HTTP/FastAPI, maka agent di Paperclip bisa berupa:
- `http` adapter
- atau adapter custom yang akhirnya memanggil endpoint FastAPI

Contoh logika heartbeat:
1. Paperclip memilih agent `openclaw_ops`
2. ada task aktif untuk agent itu
3. heartbeat run dibuat
4. Paperclip POST ke FastAPI broker, misalnya:
   - `POST /agent/heartbeat`
5. FastAPI broker menerima:
   - task id
   - company context
   - agent id
   - prompt/task body
   - metadata execution
6. FastAPI broker memutuskan runtime eksekusinya
7. hasil dikembalikan ke Paperclip

### 3.2 Dari sisi FastAPI broker
FastAPI broker idealnya punya modul:
- task intake
- runtime router
- result adapter
- state/log persistence
- timeout/retry control

Contoh internal route:
- task type `automation` -> kirim ke n8n
- task type `tooling` -> kirim ke OpenClaw worker
- task type `browser` -> kirim ke browser sandbox
- task type `cloudshell-helper` -> kirim ke Cloud Shell session

### 3.3 Dari sisi OpenClaw
OpenClaw sebaiknya **tidak** langsung ditaruh sebagai satu-satunya execution target.

Yang lebih sehat:
- OpenClaw `main` tetap human-facing
- FastAPI/Paperclip hanya bicara ke:
  - OpenClaw `lab`
  - OpenClaw `worker`
  - atau endpoint/tool execution yang terkontrol

### 3.4 Dari sisi n8n
n8n tetap menjadi workflow engine.

FastAPI broker bisa:
- memanggil webhook n8n
- menunggu callback
- atau hanya enqueue kerja ke n8n

### 3.5 Dari sisi Cloud Shell
Cloud Shell harus diperlakukan sebagai:
- helper runtime
- disposable execution box
- session yang bisa hilang

Bukan sebagai pusat permanen model.

---

## 4. Apakah semua model diletakkan di Cloud Shell gratis itu masuk akal?

## Jawaban jujur: tidak sebagai strategi utama

Ada tiga kemungkinan berbeda, dan nilainya beda jauh.

### A. Cloud Shell hanya dipakai untuk menjalankan helper script / CLI sementara
Ini **masuk akal**.

Contoh:
- scraping ringan
- transform file
- eksperimen kecil
- tool build sesekali

### B. Cloud Shell dipakai untuk memanggil API model remote
Ini **mungkin**, tapi Cloud Shell tidak memberi banyak manfaat selain jadi jumpbox.

Karena model sebenarnya tetap di luar.

### C. Cloud Shell dijadikan tempat semua model hidup / semua agent berjalan terus
Ini **tidak realistis**.

Karena Cloud Shell gratis punya karakter:
- ephemeral
- quota waktu mingguan
- storage kecil
- session bisa mati
- tidak cocok untuk daemon stabil
- tidak cocok untuk banyak proses berat

Dan jika aksesnya bergantung pada tab browser di sandbox container, ada tambahan masalah:
- browser session bisa logout
- tab bisa crash
- websocket/terminal bisa putus
- automation state rapuh
- observability buruk

---

## 5. Tentang ide “Cloud Shell dibuka di tab browser container-sandbox-browser”

Secara teknis itu mungkin.
Tapi itu adalah **jalur paling rapuh** kalau dijadikan runtime inti.

Kenapa:

### 5.1 Bergantung pada browser state
- tab harus tetap hidup
- login harus tetap valid
- terminal web harus tidak disconnect
- page structure tidak boleh berubah drastis

### 5.2 Sulit di-scale
Kalau satu Cloud Shell tab dipakai banyak task:
- task akan saling tabrak
- concurrency buruk
- recovery susah

### 5.3 Sulit diaudit
Paperclip bagus di audit task.
Tapi kalau execution real-nya tersembunyi di tab browser interaktif, jejak run jadi lemah.

### 5.4 Tidak infinite
Browser tab + Cloud Shell gratis = **bukan sistem 24/7**.

---

## 6. Maka arsitektur yang benar untuk skenario ini apa?

Saya sarankan arsitektur berikut.

## Layer A — Human/control plane
- Ayang -> OpenClaw main

## Layer B — Company orchestration
- Paperclip di VPS terpisah
- mode authenticated/private

## Layer C — Execution broker
- FastAPI broker di VPS yang sama dengan Paperclip atau dekat dengannya

## Layer D — Execution targets
- OpenClaw worker/lab
- n8n
- browser tools
- Cloud Shell helper session
- future specialist endpoints

## Layer E — Persistence/logging
- Paperclip DB + logs
- OpenClaw logs
- broker logs
- n8n logs

---

## 7. Pembagian tanggung jawab yang saya rekomendasikan

### Paperclip menangani
- task lifecycle
- org structure
- budget/governance
- heartbeats
- approvals
- audit trail

### FastAPI broker menangani
- menerima job dari Paperclip
- validasi payload
- route ke runtime tepat
- timeout/retry policy
- normalisasi result/error

### OpenClaw menangani
- human-facing control
- direct actions
- tool orchestration tertentu
- specialist coordination dari sisi assistant

### n8n menangani
- repeatable workflow
- webhook pipelines
- retry dan branching
- integration-heavy automation

### Cloud Shell menangani
- helper compute ringan dan sementara
- bukan control plane
- bukan primary runtime untuk semua model

---

## 8. Apakah skenario ini tetap bisa berguna?

**Ya, kalau diposisikan dengan benar.**

Contoh penggunaan yang masuk akal:
- Paperclip membuat task research
- FastAPI broker menugaskan OpenClaw worker
- OpenClaw worker butuh helper script kecil
- helper script jalan sebentar di Cloud Shell
- hasil dikembalikan ke worker
- worker update Paperclip

Di sini Cloud Shell berguna.
Tapi Cloud Shell **bukan** tempat seluruh perusahaan AI hidup.

---

## 9. Desain minimal yang saya sarankan sekarang

Kalau Ayang mau mulai realistis dan tidak terlalu rapuh:

### Company orchestration
- Paperclip di VPS terpisah

### Execution bridge
- FastAPI broker sederhana

### Agents awal
- `openclaw_ops` -> HTTP/OpenClaw bridge
- `n8n_dispatcher` -> HTTP/webhook bridge
- `cloudshell_helper` -> helper agent terbatas

### Aturan
- Cloud Shell hanya untuk helper task
- tidak ada model utama yang bergantung penuh pada browser tab Cloud Shell
- model utama tetap:
  - local Ollama
  - CLI backend lokal
  - atau API model yang lebih stabil

---

## 10. Putusan arsitektural

### Mungkin?
Ya.

### Layak untuk eksperimen?
Ya.

### Layak untuk jadi tulang punggung 24/7 semua model dan semua agent?
Tidak.

### Nilai terbaik Paperclip di sistem Ayang
Paperclip paling kuat kalau dipakai untuk:
- task governance
- multi-agent orchestration
- heartbeats
- approval/cost control
- audit trail

Bukan untuk menyulap Cloud Shell gratis menjadi data center permanen.

---

## 11. Rekomendasi paling pragmatis

Kalau Ayang tetap ingin melangkah dengan pendekatan ini, lakukan dalam urutan ini:

1. deploy Paperclip private di VPS terpisah
2. buat FastAPI broker minimal
3. integrasikan satu agent HTTP dulu
4. gunakan Cloud Shell hanya untuk helper task ringan
5. pertahankan model utama di jalur yang lebih stabil
6. baru tambahkan orchestration complexity secara bertahap

Jangan mulai dari:
- semua model di Cloud Shell
- semua agent jalan via browser tab
- autonomous 24/7 loops penuh

Itu akan rapuh dan sulit di-debug.
