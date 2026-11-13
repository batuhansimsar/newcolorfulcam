# ============================================================
#  iRAYPLE AH5200CG000E — Windows Kurulum Scripti
#  Çalıştırma: PowerShell'i YÖNETİCİ olarak aç ve yaz:
#    Set-ExecutionPolicy Bypass -Scope Process -Force
#    .\setup.ps1
# ============================================================

param (
    [switch]$SkipDownload,   # SDK zaten indirilmişse kullan
    [switch]$SkipNetwork,    # Ağ ayarını atla
    [string]$CameraIP  = "192.168.1.10",
    [string]$HostIP    = "192.168.1.100",
    [string]$SubnetMask = "255.255.255.0"
)

$ErrorActionPreference = "Stop"

# ── Renkli log fonksiyonları ─────────────────────────────────
function Log-Info  { param($m) Write-Host "[INFO]  $m" -ForegroundColor Cyan   }
function Log-Ok    { param($m) Write-Host "[ OK ]  $m" -ForegroundColor Green  }
function Log-Warn  { param($m) Write-Host "[WARN]  $m" -ForegroundColor Yellow }
function Log-Error { param($m) Write-Host "[ERR ]  $m" -ForegroundColor Red    }

# ── Yönetici kontrolü ───────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal]
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log-Error "Bu scripti YÖNETİCİ (Administrator) olarak çalıştır!"
    Log-Warn  "PowerShell'e sağ tıkla → 'Yönetici olarak çalıştır'"
    exit 1
}

Log-Info "====================================================="
Log-Info " iRAYPLE AH5200CG000E — Otomatik Kurulum Başlıyor"
Log-Info "====================================================="

# ── Çalışma klasörü ─────────────────────────────────────────
$WorkDir = "$env:USERPROFILE\iRAYPLE_Setup"
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Set-Location $WorkDir
Log-Ok "Çalışma klasörü: $WorkDir"

# ============================================================
# ADIM 1 — MV Viewer + SDK İndirme
# ============================================================
if (-not $SkipDownload) {
    Log-Info "-------- ADIM 1: SDK İndiriliyor --------"

    # iRAYPLE resmi indirme sayfası (linx.jp)
    # Sayfa JS ile listeliyor; doğrudan bilinen paket URL'sini dene,
    # bulunamazsa kullanıcıya yönlendir.
    $SDKUrl  = "https://linx.jp/?download_cat=irayple_camera&post_type=download&product_name=iRAYPLE&s&type_name"
    $SDKFile = "$WorkDir\iRAYPLE_MV_SDK_Setup.exe"

    # Önce gerçek indirme linkini almayı dene (SDK zip/exe dosyası)
    # Üretici CDN linkleri değişebileceğinden manuel indirme kılavuzu da ekliyoruz.
    $KnownDirectURLs = @(
        # Linx JP dağıtım (güncelleme durumunda değişebilir)
        "https://linx.jp/wp-content/uploads/iRAYPLE_SDK_Windows_v2.5.1.36.exe",
        "https://linx.jp/wp-content/uploads/iRAYPLE_MVViewer_SDK_Win_v2.5.1.36.zip"
    )

    $Downloaded = $false
    foreach ($url in $KnownDirectURLs) {
        try {
            Log-Info "Deneniyor: $url"
            Invoke-WebRequest -Uri $url -OutFile $SDKFile -TimeoutSec 30 -UseBasicParsing
            Log-Ok "İndirme başarılı: $SDKFile"
            $Downloaded = $true
            break
        } catch {
            Log-Warn "Bu URL çalışmadı, sonraki deneniyor..."
        }
    }

    if (-not $Downloaded) {
        Log-Warn "Otomatik indirme başarısız oldu."
        Log-Warn "Lütfen şu sayfadan 'MV Viewer / SDK for Windows' paketini manuel indir:"
        Log-Warn "  $SDKUrl"
        Log-Warn "İndirdiğin dosyayı buraya koy: $WorkDir"
        Log-Warn ""
        Log-Warn "İndirdikten sonra bu scripti tekrar şu parametreyle çalıştır:"
        Log-Warn "  .\setup.ps1 -SkipDownload"
        
        # Tarayıcıyı aç
        Start-Process $SDKUrl
        
        $ans = Read-Host "Dosyayı indirip $WorkDir klasörüne koydun mu? (e/h)"
        if ($ans -ne "e") {
            Log-Error "Kurulum iptal edildi. Dosyayı indirip tekrar dene."
            exit 1
        }
    }
} else {
    Log-Info "İndirme atlandı (-SkipDownload). Mevcut dosya kullanılacak."
}

# ============================================================
# ADIM 2 — SDK / MV Viewer Kurulumu
# ============================================================
Log-Info "-------- ADIM 2: SDK Kuruluyor --------"

# Klasördeki kurulum dosyasını bul (.exe veya .zip)
$SetupExe = Get-ChildItem -Path $WorkDir -Filter "*.exe" | Select-Object -First 1
$SetupZip = Get-ChildItem -Path $WorkDir -Filter "*.zip" | Select-Object -First 1

if ($SetupExe) {
    Log-Info "Kurulum başlatılıyor: $($SetupExe.FullName)"
    Log-Warn "Kurulum sihirbazını takip et. 'GigE Vision Driver' seçeneğini İŞARETLE!"
    Start-Process -FilePath $SetupExe.FullName -Wait
    Log-Ok "SDK kurulumu tamamlandı."
}
elseif ($SetupZip) {
    Log-Info "ZIP açılıyor: $($SetupZip.FullName)"
    $ExtractPath = "$WorkDir\SDK_Extracted"
    Expand-Archive -Path $SetupZip.FullName -DestinationPath $ExtractPath -Force
    
    $InnerExe = Get-ChildItem -Path $ExtractPath -Filter "*.exe" -Recurse | Select-Object -First 1
    if ($InnerExe) {
        Log-Info "İçerideki kurulum dosyası: $($InnerExe.FullName)"
        Log-Warn "Kurulum sihirbazını takip et. 'GigE Vision Driver' seçeneğini İŞARETLE!"
        Start-Process -FilePath $InnerExe.FullName -Wait
        Log-Ok "SDK kurulumu tamamlandı."
    } else {
        Log-Error "ZIP içinde .exe bulunamadı. Manuel kurulum gerekiyor."
    }
}
else {
    Log-Error "$WorkDir içinde kurulum dosyası bulunamadı."
    Log-Warn "Dosyayı indirip $WorkDir klasörüne koy ve tekrar çalıştır."
    exit 1
}

# ============================================================
# ADIM 3 — Windows Firewall — Kamera İçin Kurallar
# ============================================================
Log-Info "-------- ADIM 3: Firewall Kuralları Ayarlanıyor --------"

$FwRules = @(
    @{ Name="iRAYPLE GigE Discovery UDP 3956"; Protocol="UDP"; Port=3956 },
    @{ Name="iRAYPLE GigE GVCP UDP 3956";      Protocol="UDP"; Port=3956 },
    @{ Name="iRAYPLE GigE GVSP UDP 50000";     Protocol="UDP"; Port=50000 }
)

foreach ($rule in $FwRules) {
    $exists = Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue
    if (-not $exists) {
        New-NetFirewallRule -DisplayName $rule.Name `
            -Direction Inbound -Protocol $rule.Protocol `
            -LocalPort $rule.Port -Action Allow | Out-Null
        Log-Ok "Firewall kuralı eklendi: $($rule.Name)"
    } else {
        Log-Ok "Firewall kuralı zaten mevcut: $($rule.Name)"
    }
}

# MV Viewer uygulamasına da izin ver
$MVExePaths = @(
    "C:\Program Files\iRAYPLE\MVViewer\MVViewer.exe",
    "C:\Program Files (x86)\iRAYPLE\MVViewer\MVViewer.exe",
    "C:\Program Files\irayple\MVViewer\MVViewer.exe"
)
foreach ($path in $MVExePaths) {
    if (Test-Path $path) {
        $r = Get-NetFirewallRule -DisplayName "iRAYPLE MV Viewer App" -ErrorAction SilentlyContinue
        if (-not $r) {
            New-NetFirewallRule -DisplayName "iRAYPLE MV Viewer App" `
                -Direction Inbound -Program $path -Action Allow | Out-Null
            Log-Ok "MV Viewer uygulaması firewall'a eklendi."
        }
        break
    }
}

# ============================================================
# ADIM 4 — Ethernet Adaptörü IP Ayarı
# ============================================================
if (-not $SkipNetwork) {
    Log-Info "-------- ADIM 4: Ağ Adaptörü IP Ayarı --------"
    Log-Warn "Mevcut Ethernet adaptörleri:"

    $Adapters = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and $_.InterfaceDescription -notmatch "Wi-Fi|Wireless|Virtual|Loopback|Bluetooth"
    }

    if ($Adapters.Count -eq 0) {
        # Bağlı değil, hepsini listele
        $Adapters = Get-NetAdapter | Where-Object {
            $_.InterfaceDescription -notmatch "Virtual|Loopback|Bluetooth"
        }
    }

    $i = 0
    foreach ($a in $Adapters) {
        Write-Host "  [$i] $($a.Name) — $($a.InterfaceDescription) — $($a.Status)"
        $i++
    }

    $sel = Read-Host "`nKameranın bağlı olduğu adaptörün numarasını seç (0-$($Adapters.Count-1))"
    $TargetAdapter = @($Adapters)[[int]$sel]

    Log-Info "Seçilen adaptör: $($TargetAdapter.Name)"
    Log-Info "Ayarlanacak IP: $HostIP / $SubnetMask"
    Log-Info "(Kameranın beklenen IP'si: $CameraIP)"

    # Mevcut IP konfigürasyonu kaldır
    Remove-NetIPAddress -InterfaceIndex $TargetAdapter.ifIndex `
        -Confirm:$false -ErrorAction SilentlyContinue

    Remove-NetRoute -InterfaceIndex $TargetAdapter.ifIndex `
        -Confirm:$false -ErrorAction SilentlyContinue

    # Yeni statik IP ata
    New-NetIPAddress `
        -InterfaceIndex $TargetAdapter.ifIndex `
        -IPAddress $HostIP `
        -PrefixLength 24 `
        -ErrorAction Stop | Out-Null

    Log-Ok "IP atandı: $HostIP/24 → $($TargetAdapter.Name)"

    # DNS temizle (kamera ağında DNS gerekmez)
    Set-DnsClientServerAddress `
        -InterfaceIndex $TargetAdapter.ifIndex `
        -ResetServerAddresses | Out-Null

    Log-Ok "DNS temizlendi."
} else {
    Log-Info "Ağ ayarı atlandı (-SkipNetwork)."
}

# ============================================================
# ADIM 5 — Ping Testi
# ============================================================
Log-Info "-------- ADIM 5: Kamera Ping Testi ($CameraIP) --------"
$ping = Test-Connection -ComputerName $CameraIP -Count 3 -ErrorAction SilentlyContinue
if ($ping) {
    Log-Ok "Kamera yanıt veriyor! ($CameraIP) — Latency: $($ping[0].ResponseTime) ms"
} else {
    Log-Warn "Kamera ping'e yanıt vermedi. Olası nedenler:"
    Log-Warn "  • Kamera henüz bağlı değil veya PoE gücü yok"
    Log-Warn "  • Kameranın fabrika IP'si $CameraIP değil"
    Log-Warn "  • MV Viewer → Enumerate ile kamerayı bul ve IP'yi öğren"
    Log-Warn "  • Öğrendiğin IP ile scripti tekrar çalıştır:"
    Log-Warn "    .\setup.ps1 -SkipDownload -CameraIP <gercek_ip> -HostIP 192.168.X.100"
}

# ============================================================
# ADIM 6 — Python bağımlılıkları (opsiyonel)
# ============================================================
Log-Info "-------- ADIM 6: Python Ortamı (opsiyonel) --------"

$python = Get-Command python -ErrorAction SilentlyContinue
if ($python) {
    Log-Info "Python bulundu: $($python.Source)"
    $ans = Read-Host "Python paketleri yüklensin mi? (harvesters, numpy, opencv) [e/h]"
    if ($ans -eq "e") {
        python -m pip install --upgrade pip
        python -m pip install harvesters numpy opencv-python Pillow
        Log-Ok "Python paketleri yüklendi."
    }
} else {
    Log-Warn "Python kurulu değil. Python scripti kullanmak istersen:"
    Log-Warn "  https://www.python.org/downloads/ adresinden kur (PATH seçeneğini işaretle)"
    Log-Warn "  Sonra: pip install harvesters numpy opencv-python"
}

# ============================================================
# ÖZET
# ============================================================
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "  KURULUM TAMAMLANDI — Sonraki Adımlar" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host " 1. MV Viewer'ı aç (Başlat menüsünde 'MVViewer' ara)" -ForegroundColor White
Write-Host " 2. 'Enumerate' / 'Refresh' ile kamerayı tara" -ForegroundColor White
Write-Host " 3. AH5200CG000E modelini seç → 'Open Device'" -ForegroundColor White
Write-Host " 4. Trigger Mode = Off → Acquisition Start" -ForegroundColor White
Write-Host " 5. Görüntü geliyorsa kamera hazır!" -ForegroundColor Green
Write-Host ""
Write-Host " Python scripti : camera_capture.py" -ForegroundColor Cyan
Write-Host " C# projesi     : CameraCapture/ klasörü" -ForegroundColor Cyan
Write-Host ""

