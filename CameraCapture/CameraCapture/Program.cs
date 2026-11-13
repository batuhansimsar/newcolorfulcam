// ============================================================
//  iRAYPLE AH5200CG000E — C# / .NET 8 Görüntü Alma
//  Derleme & çalıştırma:
//    cd CameraCapture
//    dotnet run
//
//  Gereksinimler:
//    • .NET 8 SDK  (https://dotnet.microsoft.com/download)
//    • iRAYPLE MV Viewer + SDK kurulu
//    • dotnet restore  (NuGet paketleri indirilir)
// ============================================================

using System;
using System.Runtime.InteropServices;
using OpenCvSharp;

namespace CameraCapture;

// ── iRAYPLE MvCameraControl sarmalayıcı (P/Invoke) ───────────
// SDK'nın kendi .NET wrapper'ı (MvCameraControl.dll) varsa
// doğrudan kullanılır; yoksa aşağıdaki basit P/Invoke ile çalışır.
internal static class MvCamera
{
    private const string DLL = "MvCameraControl.dll";   // PATH'te olmalı

    [DllImport(DLL)] public static extern int MV_CC_EnumDevices(uint nTLayerType, ref MV_CC_DEVICE_INFO_LIST pstDevList);
    [DllImport(DLL)] public static extern int MV_CC_CreateHandle(ref IntPtr handle, ref MV_CC_DEVICE_INFO pstDevInfo);
    [DllImport(DLL)] public static extern int MV_CC_OpenDevice(IntPtr handle, uint nAccessMode, ushort nSwitchoverKey);
    [DllImport(DLL)] public static extern int MV_CC_CloseDevice(IntPtr handle);
    [DllImport(DLL)] public static extern int MV_CC_DestroyHandle(IntPtr handle);
    [DllImport(DLL)] public static extern int MV_CC_StartGrabbing(IntPtr handle);
    [DllImport(DLL)] public static extern int MV_CC_StopGrabbing(IntPtr handle);
    [DllImport(DLL)] public static extern int MV_CC_GetOneFrameTimeout(IntPtr handle, IntPtr pData, uint nDataSize, ref MV_FRAME_OUT_INFO_EX pFrameInfo, int nMsec);
    [DllImport(DLL)] public static extern int MV_CC_SetEnumValue(IntPtr handle, string strKey, uint nValue);
    [DllImport(DLL)] public static extern int MV_CC_SetFloatValue(IntPtr handle, string strKey, float fValue);

    public const uint MV_GIGE_DEVICE = 0x00000001;
    public const uint MV_ACCESS_Exclusive = 1;
    public const int  MV_OK = 0;
}

[StructLayout(LayoutKind.Sequential)]
internal struct MV_CC_DEVICE_INFO_LIST
{
    public uint nDeviceNum;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 256)]
    public IntPtr[] pDeviceInfo;
}

[StructLayout(LayoutKind.Sequential)]
internal struct MV_CC_DEVICE_INFO { /* SDK headers ile doldurun */ }

[StructLayout(LayoutKind.Sequential)]
internal struct MV_FRAME_OUT_INFO_EX
{
    public ushort nWidth;
    public ushort nHeight;
    public uint   enPixelType;
    public uint   nFrameNum;
    public uint   nDevTimeStampHigh;
    public uint   nDevTimeStampLow;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 36)]
    public byte[] nReserved;
    public long   nHostTimeStamp;
    public uint   nFrameLen;
    [MarshalAs(UnmanagedType.ByValArray, SizeConst = 20)]
    public uint[] nReservedInfo;
}

// ── Ana program ───────────────────────────────────────────────
class Program
{
    static void Main(string[] args)
    {
        Console.WriteLine("╔══════════════════════════════════════╗");
        Console.WriteLine("║  iRAYPLE AH5200CG000E — C# Viewer   ║");
        Console.WriteLine("║  Çıkış: ESC | Kaydet: S             ║");
        Console.WriteLine("╚══════════════════════════════════════╝");

        // ── Kamera listesi ─────────────────────────────────────
        var deviceList = new MV_CC_DEVICE_INFO_LIST();
        int ret = MvCamera.MV_CC_EnumDevices(MvCamera.MV_GIGE_DEVICE, ref deviceList);

        if (ret != MvCamera.MV_OK || deviceList.nDeviceNum == 0)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine("[HATA] GigE kamera bulunamadı.");
            Console.WriteLine("       MV Viewer ile kameranın görülebildiğini doğrula.");
            Console.ResetColor();
            return;
        }

        Console.WriteLine($"[OK] {deviceList.nDeviceNum} kamera bulundu.");

        // ── Handle oluştur ─────────────────────────────────────
        IntPtr camHandle = IntPtr.Zero;
        var devInfo = new MV_CC_DEVICE_INFO();
        ret = MvCamera.MV_CC_CreateHandle(ref camHandle, ref devInfo);
        if (ret != MvCamera.MV_OK) { Console.WriteLine("[HATA] Handle oluşturulamadı."); return; }

        ret = MvCamera.MV_CC_OpenDevice(camHandle, MvCamera.MV_ACCESS_Exclusive, 0);
        if (ret != MvCamera.MV_OK) { Console.WriteLine("[HATA] Kamera açılamadı."); return; }

        Console.WriteLine("[OK] Kamera açıldı.");

        // Trigger Off, sürekli mod
        MvCamera.MV_CC_SetEnumValue(camHandle, "TriggerMode", 0);   // 0 = Off
        MvCamera.MV_CC_SetEnumValue(camHandle, "AcquisitionMode", 2); // 2 = Continuous

        // Exposure ayarı (µs cinsinden, örnek: 10000 µs = 10 ms)
        MvCamera.MV_CC_SetFloatValue(camHandle, "ExposureTime", 10000f);

        ret = MvCamera.MV_CC_StartGrabbing(camHandle);
        if (ret != MvCamera.MV_OK) { Console.WriteLine("[HATA] Grab başlatılamadı."); return; }

        Console.WriteLine("[OK] Görüntü alımı başladı...");

        // ── Frame buffer ───────────────────────────────────────
        int bufSize  = 1624 * 1240 * 3;   // AH5200CG000E maks çözünürlük × RGB
        IntPtr pData = Marshal.AllocHGlobal(bufSize);
        var frameInfo = new MV_FRAME_OUT_INFO_EX();
        int frameCount = 0;

        try
        {
            while (true)
            {
                ret = MvCamera.MV_CC_GetOneFrameTimeout(
                    camHandle, pData, (uint)bufSize, ref frameInfo, 5000);

                if (ret != MvCamera.MV_OK)
                {
                    Console.WriteLine("[WARN] Frame alınamadı. Yeniden deneniyor...");
                    continue;
                }

                int w = frameInfo.nWidth;
                int h = frameInfo.nHeight;
                frameCount++;

                // Byte array'e kopyala
                byte[] imgBytes = new byte[w * h * 3];
                Marshal.Copy(pData, imgBytes, 0, imgBytes.Length);

                // OpenCvSharp Mat oluştur
                using var mat = new Mat(h, w, MatType.CV_8UC3);
                mat.SetArray(imgBytes);

                // FPS / frame bilgisi yaz
                Cv2.PutText(mat, $"Frame: {frameCount}  {w}x{h}",
                    new Point(10, 30), HersheyFonts.HersheyDuplex,
                    1.0, Scalar.LimeGreen, 2);

                Cv2.ImShow("iRAYPLE AH5200CG000E", mat);

                int key = Cv2.WaitKey(1);
                if (key == 27) { Console.WriteLine("[INFO] ESC → çıkılıyor."); break; }
                if (key == 's' || key == 'S')
                {
                    string fname = $"snapshot_{DateTime.Now:yyyyMMdd_HHmmss}.png";
                    Cv2.ImWrite(fname, mat);
                    Console.WriteLine($"[OK] Kaydedildi: {fname}");
                }
            }
        }
        finally
        {
            Marshal.FreeHGlobal(pData);
            MvCamera.MV_CC_StopGrabbing(camHandle);
            MvCamera.MV_CC_CloseDevice(camHandle);
            MvCamera.MV_CC_DestroyHandle(camHandle);
            Cv2.DestroyAllWindows();
            Console.WriteLine("[OK] Kamera kapatıldı.");
        }
    }
}

