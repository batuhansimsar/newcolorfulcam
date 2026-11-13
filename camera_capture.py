"""
iRAYPLE AH5200CG000E — Python Görüntü Alma Scripti
Gerekli: pip install harvesters numpy opencv-python

Harvesters kütüphanesi, iRAYPLE SDK ile gelen GenTL (*.cti) üreticisini kullanır.
iRAYPLE SDK genellikle şu yola kurar:
  C:\\Program Files\\iRAYPLE\\MVViewer\\genicam\\bin\\Win64\\MvGigEVisionSDK.cti
"""

import sys
import time
import cv2
import numpy as np

# ── GenTL producer yolu ──────────────────────────────────────
GENTL_CTI_PATHS = [
    r"C:\Program Files\iRAYPLE\MVViewer\genicam\bin\Win64\MvGigEVisionSDK.cti",
    r"C:\Program Files (x86)\iRAYPLE\MVViewer\genicam\bin\Win32\MvGigEVisionSDK.cti",
    r"C:\Program Files\irayple\MVViewer\genicam\bin\Win64\MvGigEVisionSDK.cti",
]

def find_cti():
    import os
    for p in GENTL_CTI_PATHS:
        if os.path.exists(p):
            return p
    return None

def run_camera(cti_path: str, num_frames: int = 100):
    from harvesters.core import Harvester

    h = Harvester()
    h.add_file(cti_path)
    h.update()

    if not h.device_info_list:
        print("[HATA] Hiç kamera bulunamadı.")
        print("       MV Viewer ile kameranın görülebildiğini doğrula.")
        return

    print(f"[OK] {len(h.device_info_list)} kamera bulundu.")
    for i, dev in enumerate(h.device_info_list):
        print(f"  [{i}] {dev}")

    # İlk kamerayı seç
    with h.create(0) as ia:
        # Parametreler
        ia.remote_device.node_map.TriggerMode.value = "Off"
        ia.remote_device.node_map.AcquisitionMode.value = "Continuous"

        # Exposure otomatik veya manuel
        try:
            ia.remote_device.node_map.ExposureAuto.value = "Continuous"
        except Exception:
            pass

        ia.start()
        print("[OK] Görüntü alımı başladı. 'q' tuşuna bas çıkmak için.")

        frame_count = 0
        while frame_count < num_frames:
            with ia.fetch(timeout=5.0) as buffer:
                component = buffer.payload.components[0]
                width  = component.width
                height = component.height
                data   = component.data.reshape(height, width, -1) if component.num_components_per_pixel > 1 \
                         else component.data.reshape(height, width)

                # Bayered formatsa renk dönüşümü
                if component.data_format == "BayerRG8":
                    frame = cv2.cvtColor(data, cv2.COLOR_BayerRG2BGR)
                elif component.data_format == "BayerGR8":
                    frame = cv2.cvtColor(data, cv2.COLOR_BayerGR2BGR)
                elif component.data_format == "BayerGB8":
                    frame = cv2.cvtColor(data, cv2.COLOR_BayerGB2BGR)
                elif component.data_format == "BayerBG8":
                    frame = cv2.cvtColor(data, cv2.COLOR_BayerBG2BGR)
                elif component.data_format in ("RGB8", "BGR8"):
                    frame = data
                else:
                    frame = data  # Mono veya bilinmeyen

                # FPS bilgisi
                frame_count += 1
                cv2.putText(frame, f"Frame: {frame_count}", (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

                cv2.imshow("iRAYPLE AH5200CG000E", frame)

                key = cv2.waitKey(1) & 0xFF
                if key == ord('q'):
                    print("[INFO] Çıkılıyor...")
                    break
                elif key == ord('s'):
                    fname = f"snapshot_{int(time.time())}.png"
                    cv2.imwrite(fname, frame)
                    print(f"[OK] Kaydedildi: {fname}")

        ia.stop()
    h.reset()
    cv2.destroyAllWindows()
    print("[OK] Kamera kapatıldı.")


if __name__ == "__main__":
    cti = find_cti()
    if not cti:
        print("[HATA] GenTL producer (.cti) bulunamadı.")
        print("       iRAYPLE SDK'nın kurulu olduğundan emin ol.")
        print("       Yolu elle belirtmek için: GENTL_CTI_PATHS listesini düzenle.")
        sys.exit(1)

    print(f"[OK] GenTL producer: {cti}")
    run_camera(cti)

