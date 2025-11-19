@echo off
setlocal enabledelayedexpansion
echo ================================
echo   Building TrackingRTF Project
echo ================================

set OUTPUT_DIR=.\publish

REM Danh sách các project cần build (thêm project mới vào đây)
set PROJECTS=DataSphere

REM Tạo thư mục output nếu chưa có
if not exist "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)

REM Xóa các file exe cũ
echo Cleaning old executables...
for %%P in (%PROJECTS%) do (
    if exist "%OUTPUT_DIR%\%%P.exe" (
        echo Removing old exe: %%P.exe
        del /q "%OUTPUT_DIR%\%%P.exe"
    )
)

REM Build từng project
echo.
echo Starting build process...
echo.

for %%P in (%PROJECTS%) do (
    echo [%%P] Building...
    
    dotnet publish .\%%P\%%P.csproj -c Release -r win-x64 ^
        -o "%OUTPUT_DIR%"
    
    if !errorlevel! neq 0 (
        echo [%%P] Build FAILED!
        pause
        exit /b !errorlevel!
    )
    
    echo [%%P] Build successful!
    echo.
)

echo ================================
echo   All builds completed!
echo   Output: %OUTPUT_DIR%
echo ================================
pause