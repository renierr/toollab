@echo off
REM Launch the standalone single-tool builder.
REM   standalone.bat                    - interactive menu (pick tool + platform)
REM   standalone.bat <tool-id> [target] - direct build, e.g. standalone.bat notes android-apk
REM   standalone.bat --restore          - revert any leftover workspace patches
cd /d "%~dp0"
dart run tool/build_standalone.dart %*
pause
