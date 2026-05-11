# Rclone host mount + union manual for OpenClaw and n8n

Dokumen ini menjelaskan desain yang lebih sehat:
- `rclone mount` dijalankan di **host VPS**
- beberapa Google Drive account di-mount sebagai remote terpisah
- lalu digabung sebagai **union**
- hasil mount di-bind ke container seperti:
  - `openclaw-openclaw-gateway-1`
  - `n8n-worker`
  - service lain yang perlu storage bersama

## Target

Tujuan akhirnya:
- host punya mount lokal yang stabil
- container cukup membaca mount itu sebagai volume biasa
- OpenClaw / n8n tidak perlu mengurus FUSE di dalam container

---

## 1. Arsitektur yang dipakai

```text
Google Drive account 1..5
   -> rclone remotes
   -> rclone union backend
   -> host mount: /srv/rclone/union
   -> bind mount ke container
      - /data/storage
      - atau path lain yang konsisten
```

### Kenapa ini lebih baik
- FUSE hanya hidup di host
- container tetap sederhana
- debugging jauh lebih mudah
- restart container tidak memutus logika mount host

---

## 2. Struktur direktori host yang saya rekomendasikan

```bash
/srv/rclone/
  config/
  cache/
  logs/
  mounts/
    gdrive1/
    gdrive2/
    gdrive3/
    gdrive4/
    gdrive5/
    union/
```

Buat dulu:

```bash
sudo mkdir -p /srv/rclone/config
sudo mkdir -p /srv/rclone/cache
sudo mkdir -p /srv/rclone/logs
sudo mkdir -p /srv/rclone/mounts/gdrive1
sudo mkdir -p /srv/rclone/mounts/gdrive2
sudo mkdir -p /srv/rclone/mounts/gdrive3
sudo mkdir -p /srv/rclone/mounts/gdrive4
sudo mkdir -p /srv/rclone/mounts/gdrive5
sudo mkdir -p /srv/rclone/mounts/union
```

---

## 3. Install rclone latest di host

### Opsi cepat

```bash
curl -fsSL https://rclone.org/install.sh | sudo bash
```

Verifikasi:

```bash
rclone version
```

Kalau Ayang ingin lebih ketat, download release dulu lalu install manual.

---

## 4. Konfigurasi 5 Google Drive remote

Jalankan:

```bash
rclone config
```

Buat remote misalnya:
- `gdrive1`
- `gdrive2`
- `gdrive3`
- `gdrive4`
- `gdrive5`

Untuk tiap remote:
- type: `drive`
- lakukan OAuth login sesuai akun Google yang dipakai

File config biasanya berada di:
- `~/.config/rclone/rclone.conf`

Saya sarankan pindahkan ke path eksplisit host ini:

```bash
sudo mkdir -p /srv/rclone/config
sudo cp ~/.config/rclone/rclone.conf /srv/rclone/config/rclone.conf
sudo chmod 600 /srv/rclone/config/rclone.conf
```

Dan nanti semua command gunakan:

```bash
--config /srv/rclone/config/rclone.conf
```

---

## 5. Test masing-masing remote dulu

Contoh:

```bash
rclone --config /srv/rclone/config/rclone.conf lsd gdrive1:
rclone --config /srv/rclone/config/rclone.conf lsd gdrive2:
rclone --config /srv/rclone/config/rclone.conf lsd gdrive3:
rclone --config /srv/rclone/config/rclone.conf lsd gdrive4:
rclone --config /srv/rclone/config/rclone.conf lsd gdrive5:
```

Kalau satu saja belum benar, jangan lanjut ke union.

---

## 6. Tambahkan remote union

Edit config:

```bash
rclone --config /srv/rclone/config/rclone.conf config
```

Buat remote baru:
- name: `gdrive_union`
- type: `union`

Contoh konsep upstreams:
- `gdrive1:`
- `gdrive2:`
- `gdrive3:`
- `gdrive4:`
- `gdrive5:`

Pilih kebijakan create/search sesuai kebutuhan.

### Rekomendasi awal yang aman
Gunakan union untuk:
- **read/search gabungan**
- write tetap hati-hati

Untuk tahap awal, saya sarankan jangan langsung menganggap union sebagai storage tulis bebas untuk semua workload berat.

---

## 7. Test union sebelum mount

```bash
rclone --config /srv/rclone/config/rclone.conf lsd gdrive_union:
```

Kalau daftar folder muncul, baru lanjut.

---

## 8. Mount host untuk union

Contoh command manual:

```bash
rclone mount gdrive_union: /srv/rclone/mounts/union \
  --config /srv/rclone/config/rclone.conf \
  --allow-other \
  --dir-cache-time 1000h \
  --poll-interval 1m \
  --vfs-cache-mode full \
  --vfs-cache-max-age 24h \
  --vfs-cache-max-size 20G \
  --cache-dir /srv/rclone/cache \
  --log-file /srv/rclone/logs/rclone-union.log \
  --log-level INFO \
  --daemon
```

Verifikasi:

```bash
mount | grep /srv/rclone/mounts/union
ls -la /srv/rclone/mounts/union
```

---

## 9. Jika `--allow-other` gagal

Edit:

```bash
sudo nano /etc/fuse.conf
```

Pastikan ada:

```text
user_allow_other
```

Lalu restart mount.

---

## 10. Buat systemd service agar mount otomatis hidup

File:

```bash
sudo nano /etc/systemd/system/rclone-gdrive-union.service
```

Isi contoh:

```ini
[Unit]
Description=Rclone Google Drive Union Mount
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/rclone mount gdrive_union: /srv/rclone/mounts/union \
  --config /srv/rclone/config/rclone.conf \
  --allow-other \
  --dir-cache-time 1000h \
  --poll-interval 1m \
  --vfs-cache-mode full \
  --vfs-cache-max-age 24h \
  --vfs-cache-max-size 20G \
  --cache-dir /srv/rclone/cache \
  --log-file /srv/rclone/logs/rclone-union.log \
  --log-level INFO
ExecStop=/bin/fusermount -uz /srv/rclone/mounts/union
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Lalu:

```bash
sudo systemctl daemon-reload
sudo systemctl enable rclone-gdrive-union
sudo systemctl start rclone-gdrive-union
sudo systemctl status rclone-gdrive-union
```

---

## 11. Bind mount ke container OpenClaw dan n8n

## 11.1 Untuk OpenClaw gateway

Di compose/service OpenClaw, tambahkan misalnya:

```yaml
volumes:
  - /srv/rclone/mounts/union:/data/storage
```

## 11.2 Untuk n8n-worker

Tambahkan:

```yaml
volumes:
  - /srv/rclone/mounts/union:/data/storage
```

## 11.3 Untuk service lain

Prinsip yang sama:

```yaml
volumes:
  - /srv/rclone/mounts/union:/data/storage
```

### Kenapa pakai path container yang sama?
Karena nanti semua workflow lebih mudah:
- OpenClaw lihat file di `/data/storage/...`
- n8n-worker lihat file di `/data/storage/...`
- helper service juga lihat file di `/data/storage/...`

Ini mengurangi path translation yang membingungkan.

---

## 12. Rekomendasi teknis penting

### Jangan jadikan union sebagai satu-satunya write path untuk semua hal berat
Union Google Drive itu bagus untuk:
- shared asset
- output ringan
- arsip
- knowledge/docs

Tapi kurang ideal untuk:
- database hidup
- cache intensif
- render scratch besar
- banyak random writes berat

### Pisahkan storage lokal cepat vs remote union
Saya sarankan pola:
- local fast disk untuk kerja sementara
- rclone union untuk sinkron/arsip/share

Contoh:
- local working dir: `/srv/work`
- remote shared/archival: `/srv/rclone/mounts/union`

---

## 13. Desain yang paling sehat untuk project Ayang

### Gunakan rclone union untuk:
- knowledge assets
- content archive
- shared output hasil workflow
- dokumen dan aset yang perlu dibaca banyak container

### Jangan gunakan langsung untuk:
- temp render file besar
- ffmpeg scratch
- ChromaDB persistence utama
- database Postgres/Redis/n8n internals

Untuk itu tetap pakai disk lokal host.

---

## 14. Verifikasi end-to-end

### Host

```bash
rclone --config /srv/rclone/config/rclone.conf lsd gdrive_union:
ls -la /srv/rclone/mounts/union
systemctl status rclone-gdrive-union
```

### Container OpenClaw

```bash
docker exec -it openclaw-openclaw-gateway-1 ls -la /data/storage
```

### Container n8n-worker

```bash
docker exec -it n8n-worker ls -la /data/storage
```

Kalau dua container itu bisa melihat isi yang sama, bind mount sukses.

---

## 15. Red flags

- mount sering disconnect
- OAuth token salah satu akun kadaluarsa
- union dipakai untuk workload tulis berat
- cache rclone terlalu kecil
- semua scratch file besar ditulis langsung ke Google Drive mount

Kalau red flags ini muncul, performa dan stabilitas akan buruk.

---

## 16. Rekomendasi akhir

Untuk project Ayang, pendekatan yang benar adalah:

1. `rclone mount` di host
2. 5 akun Google Drive jadi remote terpisah
3. gabungkan via `union`
4. bind ke container dengan path seragam, misalnya `/data/storage`
5. gunakan mount ini untuk shared storage / archive / asset exchange
6. tetap simpan scratch heavy workload di disk lokal host
