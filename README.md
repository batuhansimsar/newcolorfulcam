# iRAYPLE AH5200CG000E — Kurulum & Kullanım Kılavuzu

## Dosya Yapısı

```
camKurulum/
├── setup.ps1              ← Ana kurulum scripti (PowerShell)
├── camera_capture.py      ← Python ile canlı görüntü
└── CameraCapture/
    └── CameraCapture/
        ├── CameraCapture.csproj
        └── Program.cs     ← C# / .NET 8 ile canlı görüntü
```

---

## 1. Windows'ta Kurulum (`setup.ps1`)

**Powershell'i YÖNETİCİ olarak aç**, sonra sırayla:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
cd C:\camKurulum          # dosyaları buraya kopyaladıysan
.\setup.ps1
```

Script otomatik olarak şunları yapar:
| Adım | İşlem |
|------|-------|
| 1 | MV Viewer SDK'yı indirir (başaramazsa sana indirme sayfasını açar) |
| 2 | SDK kurulum sihirbazını başlatır |
| 3 | GigE Vision UDP portlarını firewall'a ekler |
| 4 | Seçtiğin Ethernet adaptörüne statik IP atar |
| 5 | Kameraya ping atar |
| 6 | Python paketlerini yükler (harvesters, numpy, opencv) |

### Parametreler

```powershell
# Kameranın IP'si farklıysa:
.\setup.ps1 -CameraIP 192.168.0.10 -HostIP 192.168.0.100

# SDK zaten indirilmişse indirmeyi atla:
.\setup.ps1 -SkipDownload

# Ağ ayarını elle yapacaksan atla:
.\setup.ps1 -SkipNetwork
```

---

## 2. Python ile Görüntü Alma

```bash
# Önce paketleri kur (setup.ps1 zaten kuruyor ama elle de yapabilirsin)
pip install harvesters numpy opencv-python

# Çalıştır
python camera_capture.py
```

**Klavye kısayolları:**
- `Q` — Çıkış
- `S` — Anlık görüntü kaydet (`snapshot_<timestamp>.png`)

---

## 3. C# / .NET ile Görüntü Alma

```powershell
# .NET 8 SDK kur: https://dotnet.microsoft.com/download
cd CameraCapture
dotnet restore    # NuGet paketlerini indirir
dotnet run        # Derleme + çalıştırma
```

**Klavye kısayolları:**
- `ESC` — Çıkış
- `S` — Anlık görüntü kaydet

---

## 4. Sorun Giderme

| Belirti | Çözüm |
|---------|-------|
| Kamera bulunamıyor | PoE enjektör/switch kontrol et; sürücüyü yeniden kur |
| IP uyuşmuyor | MV Viewer → Enumerate ile kameranın gerçek IP'sini bul |
| Siyah ekran | Lens kapağını aç; Exposure Time'ı artır |
| Görüntü donuyor | Jumbo Frame'i etkinleştir (MTU 9000); Firewall kurallarını kontrol et |
| SDK DLL bulunamıyor (C#) | `CameraCapture.csproj` içindeki `HintPath`'i SDK kurulum klasörüne göre düzenle |
| .cti bulunamıyor (Python) | `camera_capture.py` içindeki `GENTL_CTI_PATHS` listesine gerçek yolu ekle |

---

## 5. Bağlantı Şeması

```
[iRAYPLE AH5200CG000E]
        │
   GigE Ethernet
        │
  [PoE Enjektör/Switch]
        │
   GigE Ethernet
        │
  [Windows PC Ethernet Adaptörü]
  IP: 192.168.1.100 / 255.255.255.0
```

> **Not:** Kameranın fabrika IP adresi bilinmiyorsa MV Viewer → Enumerate → sağ tıkla → "Modify IP" ile öğren ve statik IP ata.

