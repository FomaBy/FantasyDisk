; NSIS installer for FantasyDisk (Windows x86_64).
; Build: makensis -DVERSION=0.1.0 -DSRC_EXE=... -DOUT_FILE=... tools/windows_installer.nsi

!ifndef VERSION
  !define VERSION "0.1.0"
!endif
!ifndef SRC_EXE
  !define SRC_EXE "build\\FantasyDisk-Windows.exe"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "FantasyDisk-${VERSION}-windows-setup.exe"
!endif

!define APP_NAME "FantasyDisk"
!define UNINSTALL_KEY "Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\${APP_NAME}"

Unicode true
CRCCheck on

Name "${APP_NAME} ${VERSION}"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\\${APP_NAME}"
RequestExecutionLevel admin
; solid lzma от кросс-собранного makensis (Rosetta) — подозреваемый в
; «integrity check failed» на реальной Windows; zlib-поток проще и надежнее.
SetCompressor zlib

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  File "/oname=${APP_NAME}.exe" "${SRC_EXE}"
  WriteUninstaller "$INSTDIR\\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\\${APP_NAME}\\${APP_NAME}.lnk" "$INSTDIR\\${APP_NAME}.exe"
  CreateShortcut "$SMPROGRAMS\\${APP_NAME}\\Uninstall.lnk" "$INSTDIR\\Uninstall.exe"
  CreateShortcut "$DESKTOP\\${APP_NAME}.lnk" "$INSTDIR\\${APP_NAME}.exe"

  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "Publisher" "FantasyDisk"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "UninstallString" "$INSTDIR\\Uninstall.exe"
  WriteRegStr HKLM "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\\${APP_NAME}.exe"
  Delete "$INSTDIR\\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\\${APP_NAME}\\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\\${APP_NAME}\\Uninstall.lnk"
  RMDir "$SMPROGRAMS\\${APP_NAME}"
  Delete "$DESKTOP\\${APP_NAME}.lnk"
  DeleteRegKey HKLM "${UNINSTALL_KEY}"
SectionEnd
