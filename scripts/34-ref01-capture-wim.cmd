@rem 34 - Capture REF01's generalized Windows into ref.wim. Typed INSIDE REF01 at Windows Setup's command prompt (Shift+F10),
@rem after 32-boot-from-dvd.ps1 REF01. Not PowerShell: Setup's WinPE has only cmd. This file is the record of what was typed.
@rem Letters are from Setup's own "diskpart > list volume" on 2026-11-05 (they differ from inside Windows):
@rem   C: = Windows (NTFS, 62 GB, no label)   D: = Images (NTFS, 39 GB)   E: = the DVD   + hidden 200 MB FAT32 (EFI) and 892 MB NTFS (recovery)
@rem A .wim holds ONE partition; the EFI/boot files are rebuilt from inside the image at apply time (bcdboot), so only C: is captured.
@rem Command from Learn "Capture and apply Windows using a WIM file" (read 2026-11-05). /Compress:max = smallest file, slower.
dism /Capture-Image /ImageFile:D:\ref.wim /CaptureDir:C:\ /Name:"Win11-Ref-v1" /Description:"Win11 Ent 26H2 + Chrome, 7-Zip, VLC; 2026-11-05" /Compress:max
dism /Get-ImageInfo /ImageFile:D:\ref.wim
dir D:\ref.wim
@rem Then power off from the prompt (don't let it boot Windows):
@rem wpeutil shutdown
