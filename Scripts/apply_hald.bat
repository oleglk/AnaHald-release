@REM apply_hald.bat

@echo off

@REM check num of arguments and print usage help if none given
@if "%1"=="" (
    @echo =======================================================================
    @echo   apply_hald.bat performs conversions of stereopairs
    @echo     to full-color red-cyan anaglyphs with all Anahald sample HALD-CLUTs.
    @echo =======================================================================
    @echo   Directory arrangement:
    @echo ----------------------
    @echo     Place Anahald sample HALD files be under directory ..\SAMPLE_HALDS\
    @echo     relative to location of 'apply_hald.bat':
    @echo      " +---SAMPLE_HALDS                      "
    @echo      " |   |   hald__ahg_oleg_cp__16.TIF     "
    @echo      " |   |   hald__ahg_oleg_ec__16.TIF     "
    @echo      " |   |   hald__ahg_oleg_gp__16.TIF     "
    @echo      " |   |   hald__ahg_oleg_sf__16.TIF     "
    @echo      " |   |                                 "
    @echo      " |   +---ADD                           "
    @echo      " |           hald__ahg_oleg_mc__16.TIF "
    @echo      " |           hald__ahg_oleg_xc__16.TIF "
    @echo      " |                                     "
    @echo      " +---Scripts                           "
    @echo      "         apply_hald.bat                "
    @echo =======================================================================
    @echo Usage from DOS prompt:
    @echo ----------------------
    @echo   set IMAGEMAGICK_CONVERT_OR_MAGICK=Path-Of-ImageMagick-magick-Or-convert-Utility
    @echo   apply_hald.bat  IMAGE1 IMAGE2 ...
    @echo =======================================================================
    @echo Dragging-and-dropping input files onto this script or shortcut to it:
    @echo ---------------------------------------------------------------------
    @echo   Ensure the IMAGEMAGICK_CONVERT_OR_MAGICK environment variable
    @echo     is set to the Path of ImageMagick 'magick' or 'convert' utility
    @echo     - in "Settings" :: "System-Properties"
    @echo   Drag-and-drop input stereopairs onto this script's icon;
    @echo     the output anaglyphs must appear in ANA\ subdirectory
    @echo     under the location of the inputs
    @echo =======================================================================
    @goto :abort
)


VER>NUL
call :Assign_SCRIPT_DIR %0
if ERRORLEVEL 1 (
  echo -E- Apply_Hald failed detecting script source directory
  goto :abort
)
@echo Apply_Hald runs from the source in directory %SCRIPT_DIR%

@REM set IMC="%SCRIPT_DIR%\..\bin\convert.bat"
@REM set IMC="c:\Program Files\ImageMagick_711_3\magick.exe"
@If Not Defined IMAGEMAGICK_CONVERT_OR_MAGICK (
    @REM IMAGEMAGICK_CONVERT_OR_MAGICK undefined; use the new default"
    @set IMC=magick
    @echo -W- Path of ImageMagick convert/magick utility isn't given as IMAGEMAGICK_CONVERT_OR_MAGICK; using default of "%IMC%"
) Else (
    @set IMC=%IMAGEMAGICK_CONVERT_OR_MAGICK%
    @echo -I- Path of ImageMagick convert/magick utility is given explicitly as IMAGEMAGICK_CONVERT_OR_MAGICK: "%IMC%"
)

@set HALD_DIR="%SCRIPT_DIR%\..\SAMPLE_HALDS"
@REM set HALD_DIR=".\INP\HALD"

@echo Apply_Hald assumes ImageMagick convert/magick utility %IMC%
@echo Apply_Hald assumes sample HALDs directory %HALD_DIR%


@REM Assume all input images are in the same directory
set INP_SBS_DIR=%%~dp1

@REM set OUTDIR="%INP_SBS_DIR%\ANA"
@REM set OUTDIR=%INP_SBS_DIR%\ANA
@REM set OUTDIR=%%~dp1\ANA
@set OUTDIR=%~dp1%\ANA
echo OUTDIR == "%OUTDIR%"
md %OUTDIR%

@set COMMON_STEREO_PARAMS=-crop 50%%%%x100%%%% -swap 0,1 -define compose:args=20 -compose stereo -composite
@set COMMON_OUTFILE_PARAMS=-depth 8 -quality 92

@echo on
@for %%f in (%*) DO (
    @rem set INP_SBS=%%f
    @rem set INP_SBS_NOEXT=%%~dpnf
    @rem set INP_SBS_PURENAME=%%~nf

    @REM echo on
    @REM ============== BEGIN: the ultimate commands ============================
    call %IMC%  "%%f"  -gamma 1.0  %HALD_DIR%\hald__ahg_oleg_cp__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_cp HALD, gamma=1.00"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_cp.JPG

    call %IMC%  "%%f"  -gamma 1.0  %HALD_DIR%\ADD\hald__ahg_oleg_mc__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_mc HALD, gamma=1.00"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_mc.JPG

    call %IMC%  "%%f"  -gamma 1.0  %HALD_DIR%\hald__ahg_oleg_gp__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_gp HALD, gamma=1.00"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_gp.JPG

    call %IMC%  "%%f"  -gamma 0.95  %HALD_DIR%\hald__ahg_oleg_ec__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_ec HALD, gamma=0.90"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_ec.JPG

    call %IMC%  "%%f"  -gamma 0.88  %HALD_DIR%\ADD\hald__ahg_oleg_xc__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_xc HALD, gamma=0.88"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_xc.JPG

    call %IMC%  "%%f"  -gamma 0.88  %HALD_DIR%\hald__ahg_oleg_sf__16.TIF -hald-clut   %COMMON_STEREO_PARAMS%  -set comment "Processed with ahg_oleg_sf HALD, gamma=0.88"  %COMMON_OUTFILE_PARAMS%  %OUTDIR%\%%~nf_ahg_oleg_sf.JPG
    @echo off
    @REM ============== END:   the ultimate commands ============================
)

@REM goto :finish


@REM  "$IMC"  "$1"  -gamma $_gm  $_haldParam  -crop 50%x100% -swap 0,1 -define compose:args=20 -compose stereo -composite  -set comment "$_comment"  -depth 8 $OUT_PROP  "$2"

:finish
pause
@echo on
@exit /B 0
:abort
pause
@echo on
@exit /B 1
@REM ============== Subroutines =======================


@REM Subroutine that assigns SCRIPT_DIR to full dir path of the script source code
@REM Invocation:  call :assign_SCRIPT_DIR %0
:Assign_SCRIPT_DIR
  if (%1)==() (
   echo -E- :assign_SCRIPT_DIR requires script full path as the 1-st parameter
   exit /B 1
  )
  set SCRIPT_PATH=%1
  for %%f in (%SCRIPT_PATH%) do set SCRIPT_FULL_PATH=%%~ff
  for %%f in (%SCRIPT_FULL_PATH%) do set SCRIPT_DIR=%%~dpf
  set SCRIPT_PATH=
  set SCRIPT_FULL_PATH=
  echo -I- Script source code located in "%SCRIPT_DIR%"
exit /B 0
