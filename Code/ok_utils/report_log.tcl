#################################################################################
## Copyright 2025 Oleg Kosyakovsky
##
## Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
##
## 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
##
## 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
##
## THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS “AS IS” AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#################################################################################

# report_log.tcl - maintains textual log with tagged records
# Copyright (C) 2024 by Oleg Kosyakovsky

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

namespace eval ::ok_utils:: {

  namespace export        \
  ok_report_for_cmdline  

  variable REPORT_COMMAND_HEADER "\n====BEGIN-COMMAND========"
  variable REPORT_COMMAND_FOOTER "";  # "\n======END-COMMAND========"
  variable REPORT_RECORD_HEADER  "==";  # "==BEGIN-RECORD=="
  variable REPORT_RECORD_FOOTER  "";  # "\n==END-RECORD===="

  variable REPORT_SUCCESS_KEYWORD  "Success"
  variable REPORT_FAILURE_KEYWORD  "Failure"
}

############### BEGIN: global variables #########################################
############### END:   global variables #########################################


# Example-1:  ok_report_for_cmdline   "dUMMy"  "<TestCmdLine1>"  "<TestCmd1>"  "TestResult1"  0  $ok_utils::_LOG0
# Example-2:  _log_open;    ok_report_for_cmdline  "dUMMy"  "<TestCmdLine2>"  "<TestCmd2>"  "TestResult2"  0  [_log_i];    _log_close
# Example-3:  proc _QQCB {} {return [dict create "TestKey31" "TestRecord31" "TestKey32" "TestRecord32"]};    _log_open; puts "\n\n";    ok_report_for_cmdline  "dUMMy"  "<TestCmdLine3>"  "<TestCmd3>"  "TestResult3"  _QQCB  [_log_i];    puts "\n\n"; _log_close
proc ::ok_utils::ok_report_for_cmdline {UNUSEDcmdDescr cmdLineStr cmdStr \
                               cmdResultStr customReportCbOrZero {fileIdx ""}}  {
  variable REPORT_COMMAND_HEADER
  variable REPORT_COMMAND_FOOTER
  variable REPORT_RECORD_HEADER
  variable REPORT_RECORD_FOOTER
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  set cmdDescr "[string range $cmdStr 0 30] ..."
  set descr "report for '$cmdDescr'"
  if { ![ok_is_active_diagnostics_file $fileIdx] }  { ;  # not log0 for sure
    ok_err_msg "Attempted write of $descr into invalid log file #$fileIdx"
    return  0
  }
                                        # ==== mandatory part of the report ====
  set wRes1 [expr {
                 [_ok_write_diagnostics $REPORT_COMMAND_HEADER  $fileIdx]   &&  \
                 [_ok_write_diagnostics "(COMMAND-LINE):"       $fileIdx]   &&  \
                 [_ok_write_diagnostics $cmdLineStr             $fileIdx]   &&  \
                 [_ok_write_diagnostics "(COMMAND):"            $fileIdx]   &&  \
                 [_ok_write_diagnostics $cmdStr                 $fileIdx]   &&  \
                 [_ok_write_diagnostics "(RESULT):"             $fileIdx]   &&  \
                 [_ok_write_diagnostics $cmdResultStr           $fileIdx]      }]
  
  set wRes2 1;                          # ==== optional part of the report ==== 
  if { ($wRes1 != 0) && ($customReportCbOrZero != 0) } {
    set tclResult [catch { set headersToRecordsDict [$customReportCbOrZero] }  \
                                                                    execResult]
    if { $tclResult != 0 } {
      set err "Failed custom callback for $descr: $execResult!"
      ok_err_msg $err;  _ok_write_diagnostics $err $fileIdx
      set wRes2 0
    } else {
      dict for {hdr rec} $headersToRecordsDict  {
        set wRes2 [expr {$wRes2                                            &&  \
                 [_ok_write_diagnostics $REPORT_RECORD_HEADER    $fileIdx] &&  \
                 [_ok_write_diagnostics $hdr       $fileIdx]               &&  \
                 [_ok_write_diagnostics $rec       $fileIdx]                  }]
        #puts "@@@@ wRes2('$hdr', '$rec') = $wRes2"
      }
    }
  }

  set wRes [expr {$wRes1 && $wRes2}]
  set resStr "printing $descr into log file '[_ok_find_diagnostics_file $fileIdx]' (#$fileIdx)"
  if { $wRes != 0 }  { ok_trace_msg "Success $resStr"
  }          else    { ok_err_msg   "Failed $resStr" }
  return  $wRes
}
