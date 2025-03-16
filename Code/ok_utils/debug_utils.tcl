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

# Copyright (C) 2005-2006 by Oleg Kosyakovsky

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

namespace eval ::ok_utils:: {

  namespace export \
  ok_msg_set_callback \
  ok_arr_to_string    \
  pri_arr             \
  ok_pri_list_as_list \
  ok_info_msg   \
  ok_trace_msg  \
  ok_err_msg    \
  ok_warn_msg   \
  ok_msg_get_errwarn_cnt \
  ok_assert \
  ok_pause_console \
  ok_finalize_diagnostics       \
  ok_init_diagnostics           \
  ok_is_active_diagnostics_file \
  ok_set_start_time                       \
  ok_pause_and_reset_start_time_if_needed \
  ok_reset_start_time_if_needed           \
  ok_set_loud \
  ok_loud_mode

  variable LOUD_MODE 0

  variable _CNT_ERR_WARN  0;  # counter of problems
  variable _MSG_CALLBACK  0;  # for  proc _cb {msg} {}

  variable _LOG0          0;  # index of the default diagnostics log
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS  0; # {idx::{PATH::,HANDLE::}}

  variable _PENDING_LOG_H  0;  # means this log is in the process of creation
  variable _CLOSED_LOG_H  -1;  # means this log is was closed (finalized)

  variable _WORK_START_TIMESTAMP      -1;  # global timer start time (sec)
  variable _MAX_WORKTIME            3600;  # max time (sec) of continuous work
  variable _PAUSE_DURATION            60;  # time to RELAX (sec)
}


# this file is reread from multiple files; don't override LOUD_MODE
### ? is setting LOUD_MODE in the below way is needed when it's in a namespace ?
#if { 0 == [info exists ::ok_utils::LOUD_MODE] }  {  set ::ok_utils::LOUD_MODE 1 }



proc ::ok_utils::ok_msg_set_callback {cb}  {
  variable _MSG_CALLBACK
  set _MSG_CALLBACK $cb
}


proc ::ok_utils::ok_set_loud {toPriTraceMsgs} {
    variable LOUD_MODE
    set LOUD_MODE [expr ($toPriTraceMsgs == 0)? 0 : 1]
}
proc ::ok_utils::ok_loud_mode {} {
    variable LOUD_MODE
    return $LOUD_MODE
}

proc ::ok_utils::ok_arr_to_string {theArr} {
    upvar $theArr arrName
    set arrStr ""
    foreach {name value} [array get arrName] {
	append arrStr " $theArr\[\"$name\"\]=\"$value\""
    }
    return  $arrStr
}

proc ::ok_utils::pri_arr {theArr} {
    upvar $theArr arrName
    foreach {name value} [array get arrName] {
	puts "$theArr\[\"$name\"\] = \"$value\""
    }
}

proc ::ok_utils::ok_pri_list_as_list {theList} {
    set length [llength $theList]
    for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $theList $i]
	puts -nonewline " ELEM\[$i\]='$elem'"
    }
    puts ""
}

###############################################################################
########## Messages/Errors/Warning ################################
proc ::ok_utils::ok_msg {text kind} {
  variable LOUD_MODE
  variable _CNT_ERR_WARN
  variable _MSG_CALLBACK
  variable _LOG0
  set pref ""
  set tags ""
  switch [string toupper $kind] {
    "INFO" { set pref "-I-" }
    "TRACE" {
        set pref [expr {($LOUD_MODE == 1)? "\# [msg_caller_name]:" : "\#"}]
    }
    "ERROR" {
        #set pref [expr {($LOUD_MODE == 1)? "-E- [msg_caller_name]:":"-E-"}]
        set pref "-E-"
        #set tags "boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
    "WARNING" {
        set pref [expr {($LOUD_MODE == 1)? "-W- [msg_caller_name]:":"-W-"}]
        set pref "-W-"
        #set tags "italicline boldline"
        set tags "underline"
        incr _CNT_ERR_WARN 1
    }
  }
  # (DO NOT PRINT HERE, _ok_write_diagnostics does it)     puts "$pref $text"
  _ok_write_diagnostics "$pref $text" $_LOG0
  if { $_MSG_CALLBACK != 0 }  {
    set tclResult [catch { set res [$_MSG_CALLBACK "$pref $text" "$tags"] } \
                          execResult]
    if { $tclResult != 0 } {
      puts "$pref Failed message callback: $execResult!"; #DO NOT USE ok_err_msg
    }
  }
}


proc ::ok_utils::ok_info_msg {text} {
    ok_msg $text "INFO"
}
proc ::ok_utils::ok_trace_msg {text} {
    variable LOUD_MODE
    if { $LOUD_MODE == 1 } {
	ok_msg $text "TRACE"
    }
}
proc ::ok_utils::ok_err_msg {text} {
    ok_msg $text "ERROR"
}
proc ::ok_utils::ok_warn_msg {text} {
    ok_msg $text "WARNING"
}


proc ::ok_utils::ok_msg_get_errwarn_cnt {}  {
  variable _CNT_ERR_WARN
  return  $_CNT_ERR_WARN
}


proc ::ok_utils::msg_caller_name {} {
  #puts "level=[info level]"
  set callerLevel [expr { ([info level] > 3)? -3 : [expr -1*([info level]-1)] }]
    set callerAndArgs [info level $callerLevel]
    return  [lindex $callerAndArgs 0]
}


###############################################################################
########## Assertions ################################

proc ::ok_utils::ok_assert {condExpr {msgText ""}} {
#    ok_trace_msg "ok_assert '$condExpr'"
    if { ![uplevel expr $condExpr] } {
# 	set theMsg [expr ($msgText == "")? "condExpr" : $msgText]
 	set theMsg $msgText
 	ok_err_msg "Assertion failed: '$theMsg' at [info level -1]"
	for {set theLevel [info level]} {$theLevel >= 0} {incr theLevel -1} {
	     ok_err_msg "Stack $theLevel:\t[info level $theLevel]"
	}
	return -code error
    }
}


proc ::ok_utils::ok_pause_console {{message "Press Enter to continue ==> "}} {
  puts -nonewline $message
  flush stdout
  gets stdin
}


proc ::ok_utils::_ok_fail_on_invalid_diagnostics_file_index {fileIdx}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  if { ![dict exists $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx] }  {
    error "Unknown diagnostics' file index '$fileIdx'; valid value: {[dict keys $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS]}"
  }
}


# TODO: after initial debug, return exists/absent instead of exception
proc ::ok_utils::_ok_get_diagnostics_file_data {pathRef handleRef  \
                                                  {fileIdx ""}}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  upvar $pathRef   fPath
  upvar $handleRef fHandle
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  _ok_fail_on_invalid_diagnostics_file_index $fileIdx
  set recDict [dict get $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx]
  set fPath   [dict get $recDict PATH]
  set fHandle [dict get $recDict HANDLE]
}


# Closes one diagnostics stream
proc ::ok_utils::ok_finalize_diagnostics {{fileIdx ""}}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  variable _LOG0
  variable _CLOSED_LOG_H
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  if { ![info exists _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS] ||  \
       ($_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS == 0)         }  {
    return  1;  # diagnostics isn't initialized yet; silently ignore finalization
  }
  _ok_fail_on_invalid_diagnostics_file_index $fileIdx
  _ok_get_diagnostics_file_data fPath fHandle $fileIdx
  set descr "old diagnostics file '$fPath' (#$fileIdx)"
  if { $fHandle != $_LOG0 }  {
    ok_info_msg "Closing $descr"
    set tclExecResult [ catch {
      close $fHandle
      dict update _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx recDict  {
        dict set recDict HANDLE $_CLOSED_LOG_H; #old val must have been $fHandle
        # (handle==0 not the same as fileIdx==0)
      }
      ## DO NOT 'return  1' here - it looks like exception for the check below!
    } execResult]
    if { $tclExecResult != 0 } {
      if { $fileIdx != $_LOG0 }  {;  # otherwise no log to complain to
        ok_err_msg "Failed to close $descr: $execResult"
      } else {
        puts "Failed to close $descr: $execResult!";  # DO NOT USE ok_err_msg
      }
      return  0
    }
  } else {
    ok_info_msg "Ignored repeated closure of already closed $descr"
  }
  return  1
}


proc ::ok_utils::ok_init_diagnostics {outFilePath {fileIdx ""}}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  variable _PENDING_LOG_H
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  if { [ok_is_active_diagnostics_file $fileIdx] }  {
    error "Repeated initialization of diagnostics file #$fileIdx (path: '$outFilePath')"
  }
  if { ![info exists _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS] ||  \
       ($_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS == 0)         }  {
    set _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS [dict create]
  }
  # check for repeated usage of the same file path
  dict for {fIdx fRec} $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS  {
    if { [file normalize [dict get $fRec PATH]] ==
         [file normalize $outFilePath] }  {
      if { [ok_is_active_diagnostics_file $fIdx] }  {; # path in active use
        error "Repeated use of the same diagnostics file '$outFilePath' for #$fileIdx and #$fIdx"
      } else { ;  # this path was used previously in this session; now closed
        if { [file exists $outFilePath] }  {
          error "Reuse of pre-existent diagnostics file '$outFilePath' for #$fileIdx would override data in the file  TODO: decide on policy"
        }
      }
    }
  }
    
  dict set _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx  \
    [dict create  PATH $outFilePath  HANDLE $_PENDING_LOG_H]; # e.g not yet open
  # (handle==0 not the same as fileIdx==0)

  if { 0 == [ok_create_absdirs_in_list [list [file dirname $outFilePath]] \
               [list "directory for log-file '[file tail $outFilePath]'"]] }  {
    error "Failed creating directory of '$outFilePath'"
  }
  
  # file will be opened at 1st write (and handle in the record assigned)
  puts "@@@ Calling _ok_write_diagnostics ... $fileIdx"
  _ok_write_diagnostics "Diagnostics log file #$fileIdx set to '$outFilePath'" \
                        $fileIdx
}


proc ::ok_utils::ok_is_active_diagnostics_file {fileIdx}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  variable _PENDING_LOG_H
  variable _CLOSED_LOG_H
  variable _LOG0
  if { $fileIdx == $_LOG0 }  { return  1 }
  # TODO: ??? How to deal with the defaut index $_LOG0 ???
  if { ![info exists _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS]}   { return  0 }
  if { ![dict exists $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx] } {
    return  0
  }
  _ok_get_diagnostics_file_data fPath fHandle $fileIdx
  return  [expr {($fHandle != $_PENDING_LOG_H) && ($fHandle != $_CLOSED_LOG_H)}]
}
    


################################################################################
## The mechanism of "global timer" intended to allow the system to rest 
## after long periods of intensive computing/storage activity
################################################################################

# Sets global timer to the currrent time
proc ::ok_utils::ok_set_start_time {} {
  variable _WORK_START_TIMESTAMP
  set _WORK_START_TIMESTAMP [clock seconds]
}


# If time from the global-timer start exceeds '_MAX_WORKTIME',
# waits for '_PAUSE_DURATION' sec, then resets start time and resumes the work
proc ::ok_utils::ok_pause_and_reset_start_time_if_needed {} {
  variable _WORK_START_TIMESTAMP
  variable _MAX_WORKTIME
  variable _PAUSE_DURATION
  set elapsedSec [expr {[clock seconds] - $_WORK_START_TIMESTAMP}]
  if { $elapsedSec > $_MAX_WORKTIME } {
    ok_info_msg "Relaxing for $_PAUSE_DURATION sec after $elapsedSec sec of continuous work"
    after [expr 1000 * $_PAUSE_DURATION]
    ok_set_start_time
  }
}


# If time from the global-timer start exceeds '_MAX_WORKTIME' or is uninitialized,
# resets start time
proc ::ok_utils::ok_reset_start_time_if_needed {} {
  variable _WORK_START_TIMESTAMP
  variable _MAX_WORKTIME
  set elapsedSec [expr {[clock seconds] - $_WORK_START_TIMESTAMP}]
  if { ($_WORK_START_TIMESTAMP < 0) || ($elapsedSec > $_MAX_WORKTIME) } {
    ok_info_msg "Resetting global start time after $elapsedSec sec of continuous work"
    ok_set_start_time
  }
}
################################################################################


################################################################################
# Internal utilities
################################################################################
## Complete example:  _log_open;puts "-";  ok_utils::_ok_write_diagnostics "log-tst" [_log_i];  puts "-";_log_close
proc ::ok_utils::_ok_write_diagnostics {msg {fileIdx ""}}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  variable _LOG0
  variable _PENDING_LOG_H
  variable _CLOSED_LOG_H
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  ##puts "@@@ Called ok_utils::_ok_write_diagnostics '...' #$fileIdx"
  if { $fileIdx == $_LOG0 }  { puts stdout $msg;  return  1 }
  
  set fPath [_ok_find_diagnostics_file $fileIdx];  # only for readiness check
  if { $fPath == "" }  { return  0 };  # not ready yet
  _ok_get_diagnostics_file_data fPath fHandle $fileIdx
  ##puts "@@@ At write(#$fileIdx):  fPath='$fPath', fHandle='$fHandle'";  #OK_TMP
  set fPath [file normalize $fPath]
  set descr "diagnostics file '$fPath' (#$fileIdx)"
  set actStr "open"
  if { $fHandle == $_CLOSED_LOG_H }  {; # attempt to write into finalized log
    error "Attempted write into finalized log #$fileIdx"
  }
  set logWasPendingOpen [expr {$fHandle == $_PENDING_LOG_H}]
  if { $logWasPendingOpen }  {; # 1st attempt to write; avoid recursion
    if { $fileIdx != $_LOG0 }  {;  # otherwise no log to write to
      ok_info_msg "Now will $actStr $descr"
    }
    if { 1 == [file exists $fPath] }  { catch { file delete $fPath }
                                        set actStr "reset"     }
    set tclExecResult [ catch {
      set fHandle [open $fPath a+]
      puts "@@@ 'open {$fPath}'  returned '$fHandle'";  #OK_TMP
      dict update _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx recDict  {
        dict set recDict HANDLE $fHandle
      }
    } evalExecResult]
    if { $tclExecResult != 0 }  {
      if { $fileIdx != $_LOG0 }  {;  # otherwise no log to complain to
        ok_err_msg "Failed to $actStr $descr: $evalExecResult"
      }
      return  0
    }
    if { $fileIdx != $_LOG0 }  {;  # otherwise no log to complain to
      ok_info_msg "Performed $actStr of $descr"
    }
  }
  
  # the actual write
  set tclExecResult [ catch { puts $fHandle $msg } evalExecResult]
  if { $tclExecResult != 0 }  {
    if { $fileIdx != $_LOG0 }  {;  # otherwise no log to complain to
      ok_err_msg "Failed to write into $descr: $evalExecResult"
      puts "[_ok_callstack]";  # OK_TMP
    }
    return  0;  # there will be no log; anyway cannot complain
  }
  if { $logWasPendingOpen }  {
    ok_info_msg "Performed initial write after $actStr into $descr"
  }
  return  1
}


# Returns path of the file if known, orherwise - empty string (no exception)
proc ::ok_utils::_ok_find_diagnostics_file {{fileIdx ""}}  {
  variable _DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS
  if { $fileIdx == "" }  { set fileIdx $_LOG0 }
  if { ($_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS == 0) ||
       ![dict exists $_DIAGNOSTICS_FILE_RECORDS_DICT_OF_DICTS $fileIdx] }  {
    return  "";  # not ready yet
  }
  _ok_get_diagnostics_file_data fPath fHandle $fileIdx
  if { $fPath == "" }  { ;  # should not happen
    ok_warn_msg "No file-path defined for diagnostics file #fileIdx"
    return  "";  # consider not ready yet
  }
  return $fPath
}
