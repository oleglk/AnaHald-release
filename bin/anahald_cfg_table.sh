#! /bin/sh
# anahald_cfg_table.sh

# the next line restarts using wish8.4 on unix \
exec tclsh "$0" ${1+"$@"}

set env(OK_NO_TCL_CODE_LOAD_DEBUG) Yes
#unset of env(OK_NO_TCL_CODE_LOAD_DEBUG) must occur in TCL code below!

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
  
  anahald_cmd__cfg_table ".sh" $argc $argv

  unset env(OK_NO_TCL_CODE_LOAD_DEBUG)
#------------------------------------------end Tcl\
