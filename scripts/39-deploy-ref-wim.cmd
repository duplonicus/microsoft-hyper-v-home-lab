@echo off
rem 39 - Deploy ref.wim to this PC's disk 0. Run INSIDE the target VM at Windows Setup's command prompt (Shift+F10):
rem    <Images letter>:\Deploy\39-deploy-ref-wim.cmd      (find the letter with: diskpart > list volume > exit)
rem It finds its own disk (%~d0), shows the disks, asks before erasing disk 0, then: partition (37, Microsoft's UEFI layout),
rem apply the image (dism /Apply-Image), write boot files (bcdboot). Same flow as Microsoft's ApplyImage.bat sample
rem (Learn "Capture and apply Windows using a WIM file"), minus the Windows RE copy (left for later).
set SRC=%~d0
echo Images disk (this script's drive): %SRC%
if not exist %SRC%\ref.wim (echo ref.wim not found on %SRC% & exit /b 1)

echo list disk> X:\listdisk.txt
diskpart /s X:\listdisk.txt
echo.
echo Disk 0 must be the BLANK disk. Disk 0 will be ERASED.
set /p OK=Type YES to continue: 
if /i not "%OK%"=="YES" (echo Stopped, nothing changed. & exit /b 1)

diskpart /s %SRC%\Deploy\37-pc01-partition-uefi.txt
if not exist W:\ (echo Partitioning failed: no W: drive. & exit /b 1)

rem High-performance power plan speeds up the apply (from Microsoft's ApplyImage.bat)
powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
dism /Apply-Image /ImageFile:%SRC%\ref.wim /Index:1 /ApplyDir:W:\
if errorlevel 1 (echo DISM apply failed. & exit /b 1)

rem bcdboot from INSIDE the applied image, so the boot files match that Windows version (as Microsoft's sample does)
W:\Windows\System32\bcdboot W:\Windows /s S:
if errorlevel 1 (echo bcdboot failed. & exit /b 1)

echo.
echo Done. Now type:  wpeutil shutdown   then on the host remove the ISO and start the VM normally.
