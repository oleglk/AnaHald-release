::catch {};#\
@echo off
::catch {};#\
:start
::catch {};#\
@set TCLSH=C:\ANY\Tools\TCL\tclsh_fw.exe
::catch {};#\
@REM @set TCLSH=C:\Oleg\Tools\TCL\freewrap_tclsh.exe
::catch {};#\
@echo off
::catch {};#\
set OK_NO_TCL_CODE_LOAD_DEBUG=Yes
::catch {};#\
set script=%0
::catch {};#\
if exist %script%.bat set script=%script%.bat
::catch {};#\
@echo script=='%script%'
::catch {};#\
if exist %~dp0\tclsh.bat  @echo Found %~dp0\tclsh.bat; using it as Tcl interpreter
::catch {};#\
if not exist %~dp0\tclsh.bat  @echo Missing %~dp0\tclsh.bat; reverting to default '%TCLSH%' as Tcl interpreter
::catch {};#\
if exist %~dp0\tclsh.bat  set TCLSH=%~dp0\tclsh.bat
::catch {};#\
@echo TCLSH=='%TCLSH%'
::catch {};#\
%TCLSH% %script% %1 %2 %3 %4
::catch {};#\
set OK_NO_TCL_CODE_LOAD_DEBUG=
::catch {};#\
@goto eof
#--------- TCL code begin ------------------
  set BATCH_DIR [file dirname [info script]]

  ############################################################################
  # OK_ANAHALD_TCLSRC_ROOT <- root directory for TCL source code
  set OK_ANAHALD_TCLSRC_ROOT    [file join $BATCH_DIR  ".."  "Code"]
  ## # OK_TCLSTDEXT_ROOT <- root directory for TCL standard extension libraries
  ## set OK_TCLSTDEXT_ROOT [file join $BATCH_DIR/../Libs_TCL
  ##############################################################################

  puts "... Begin loading TCL code ..."
  source $OK_ANAHALD_TCLSRC_ROOT/setup_anahald.tcl;    arrange_anahald;    ok_set_loud 0
  source $OK_ANAHALD_TCLSRC_ROOT/cmdline_anahald.tcl
  puts "... Done  loading TCL code ..."

  anahald_cmd__r2c_histogram ".bat" $argc $argv

  unset env(OK_NO_TCL_CODE_LOAD_DEBUG)
#------------------------------------------end Tcl\
:eof
