@REM choose_hald_for_image.bat
@setlocal

@REM set IMAGEMAGICK_CONVERT_OR_MAGICK=c:\ANY\Tools\ImageMagick-7.1.1-34\magick.exe

@REM set "PYTHON_DIR=c:\ANY\Tools\WPy64-31241\python-3.12.4.amd64"
@REM Anaconda won't work!          set "PYTHON_DIR=C:\Oleg\Tools\anaconda3"
@REM set "PYTHON_DIR=C:\Oleg\Tools\WPy64-31241\python-3.12.4.amd64"


@VER>NUL
@call :Assign_SCRIPT_DIR %0
@if ERRORLEVEL 1 (
  @echo -E- choose_hald_for_image failed detecting script source directory
  @goto :abort
)
@REM @echo -I- choose_hald_for_image runs from the source in directory %SCRIPT_DIR%


@if exist %SCRIPT_DIR%\python.bat (
   @set PYTHON_EXE=%SCRIPT_DIR%\python.bat
) else (
   @echo -E- Missing %SCRIPT_DIR%\python.bat; it must contain path of Python interpreter
   @goto abort
)


@set "PYTHON_CODE_DIR=%SCRIPT_DIR%"
@set "PYSCRIPT=%PYTHON_CODE_DIR%\choose_hald_for_image.py"

@REM Pass all arguments to choose_hald_for_image.py
@echo off
@%PYTHON_EXE%  %PYSCRIPT%  %*
@echo on


:finish
@endlocal
pause
@echo on
@exit /B 0
:abort
@endlocal
pause
@echo on
@exit /B 1
@REM ============== Subroutines =======================


@REM Subroutine that assigns SCRIPT_DIR to full dir path of the script source code
@REM Invocation:  call :assign_SCRIPT_DIR %0
:Assign_SCRIPT_DIR
  @if (%1)==() (
   @echo -E- :assign_SCRIPT_DIR requires script full path as the 1-st parameter
   @exit /B 1
  )
  @set SCRIPT_PATH=%1
  @for %%f in (%SCRIPT_PATH%) do @set SCRIPT_FULL_PATH=%%~ff
  @for %%f in (%SCRIPT_FULL_PATH%) do @set SCRIPT_DIR=%%~dpf
  @set SCRIPT_PATH=
  @set SCRIPT_FULL_PATH=
  @echo -I- Script source code located in "%SCRIPT_DIR%"
@exit /B 0
