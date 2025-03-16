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

# backup_one_file.tcl
# Copyright (C) 2024 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "debug_utils.tcl"]
source [file join $UTIL_DIR "common.tcl"]

########## TODO: CONFIRMATION CALLBACK AS GLOBAL VARIABLE ###################

namespace eval ::ok_utils:: {

  namespace export                      \
  ok_get_backup_dirpath_for_filepath    \
  ok_provide_backup_dir_for_filepath    \
  ok_list_backup_files_of_filepath      \
  ok_find_last_backup_file_of_filepath  \
  ok_push_backup_of_filepath            \
  ok_discard_last_backup_of_filepath    \
  ok_pop_last_backup_of_filepath        \
  ok_file_equal_to_its_backup           \
  ok_format_file_backup_status_report   \
  ok_print_file_backup_status_report    \
  ok_prompt_for_string_tty


variable LOCAL_BACKUP_DIRNAME "BU";   # name for backup subdirectories in files; locations

### OVERRIDE_PROMPT_CB is a proc that receives prompt-string and reference-var for result
#variable OVERRIDE_PROMPT_CB  0;  # this would mean do not prompt
variable OVERRIDE_PROMPT_CB   ok_prompt_for_string_tty;  # console-based proc
}


proc _DummyProcToFixEmacsIdentation {}  {}; # workaround after namespace eval ...


if { !([info procs _ERR_RETURNED] eq "_ERR_RETURNED") }  {
  proc _ERR_RETURNED {retStr}  {
    return  [regexp {^ERROR:} $retStr]
  }
}


proc ::ok_utils::ok_get_backup_dirpath_for_filepath {filePath}  {
  variable LOCAL_BACKUP_DIRNAME
  return  [file join [file dirname $filePath] $LOCAL_BACKUP_DIRNAME]
}


# Returns (normalized) dir-path or 0 on error.
# Verifies physical validity of the file 'filePath'
proc ::ok_utils::ok_provide_backup_dir_for_filepath {filePath {loud 1}}  {
  ok_assert { [ok_filepath_is_readable $filePath] }  \
    "File '$filePath' should be readable for the current user"
  ok_assert { [ok_filepath_is_writable_dir [file dirname $filePath]] }  \
    "Directory of '$filePath' should be writable for the current user"
  set buDirPath [file normalize [ok_get_backup_dirpath_for_filepath $filePath]]
  if { !$loud && [ok_filepath_is_writable_dir $buDirPath] }  {
    return  $buDirPath;  # just to avoid messages by 'ok_create_absdirs_in_list'
  }
  
  set descr [format "%s"  "local backup directory for '$filePath'"]
  if { ![ok_create_absdirs_in_list [list $buDirPath]  [list $descr]] }  {
    return  0;  # error already printed
  }
  return  $buDirPath
}


# Returns list of existent backup files of 'filePath'.
# Returns empty list if no backup files found, 0 on error
proc ::ok_utils::ok_list_backup_files_of_filepath {filePath}  {
  if { [file isdirectory $filePath] }  {
    ok_err_msg "File-backup is not available for directories (got '$filePath')"
    return  0
  }
  if { ![ok_filepath_is_readable_dir [file dirname $filePath]] }  {
    ok_err_msg "Directory of '$filePath' is inexistent or unreadable for the current user"
    return  0
  }
  set buDir [ok_get_backup_dirpath_for_filepath $filePath];  # may not exist
  if { ![ok_filepath_is_readable_dir $buDir] }  {
    ok_err_msg "Backup directory '$buDir' for '$filePath' is inexistent or unreadable for the current user"
    return  0
  }

  set fileNamePattern [_ok_format_file_backup_glob_pattern $filePath]
  set buFileList [glob  -nocomplain  -directory $buDir  --  $fileNamePattern]
  return  $buFileList
}


# Returns path of the last backup for 'filePath', empty string if none.
# On error returns "ERROR: <detailed error info>"
proc ::ok_utils::ok_find_last_backup_file_of_filepath {filePath {loud 0}}  {
  if { 0 == [set allBuFiles [ok_list_backup_files_of_filepath $filePath]] } {
    return  "ERROR: Cannot list backup files of '$filePath'"
  }
  ok_trace_msg "Found [llength $allBuFiles] backup file(s) for '$filePath'"
  set maxTimeSec 0;  set lastBuSoFar ""
  foreach f $allBuFiles {
    if { ![ok_utils::_ok_decode_backup_file_name  $f  fName tSec] }  {
      set err "Cannot read file timestamp of '$f', so cannot find last backup of '$filePath'"
      ok_err_msg "$err"
      return  "ERROR: $err"
    }
    if { $tSec > $maxTimeSec }  {
      set maxTimeSec $tSec;      set lastBuSoFar $f
    }
  }
  if { $loud && ($lastBuSoFar != "") }  {
    ok_info_msg "Last backup file of '$filePath' is '$lastBuSoFar'"
  }
  if { $loud && ($lastBuSoFar == "") }  {
    ok_info_msg "No backup files of '$filePath''"
  }
  return  $lastBuSoFar
}


# Stores a new backup version for 'filePath' UNLESS it's equal to the previous.
# Returns the backup path or "" on error.
proc ::ok_utils::ok_push_backup_of_filepath {filePath {loud 0}}  {
  if { ![file exists $filePath] || ![ok_filepath_is_readable $filePath] }  {
    set msg "Specified path '$filePath' is not an existent readable regular file"
    ok_err_msg $msg;    return "ERROR: $msg"
  }
  set equalBuPath [ok_file_equal_to_its_backup $filePath]
  if { [_ERR_RETURNED $equalBuPath] }  {
    return  "";  # TODO: print message ?
  }
  if { $equalBuPath != "" }  {
    set msg "New version of '$filePath' equals the previous ($equalBuPath); not stored again"
    if { $loud }  { ok_info_msg "$msg" } else  { ok_trace_msg "$msg" }
    return  $equalBuPath
  }
  # previous (backup) version of this file differs from the current version
  set maxAttempts 10
  set secBtwAttempts 1
  for {set i 1}  {$i <= $maxAttempts}  {incr i 1}  {
    set buPath [_ok_get_full_backup_path_for_filepath $filePath $loud]
    if { $buPath == 0 } {
      ok_err_msg "Backup aborted for '$filePath'";    return  ""
    }
    if { ![file exists $buPath] }  {
      if { $loud }  {
        ok_info_msg "File-backup path is unique after $i attempt(s): '$buPath'"
      }
      break
    }
    if { $loud }  { ok_info_msg "Attempt ($i) to pause for $secBtwAttempts second(s) since intended backup path '$buPath' was occupied ..."    }
    after [expr 1000 * $secBtwAttempts]
  }

  if { [file exists $buPath] }  {
    ok_err_msg "Intended backup path ($buPath) for '$filePath' is occupied after $maxAttempts attempt(s). Backup aborted"
    return  ""
  }

  if { 0 == [ok_safe_copy_file $filePath $buPath] }  {
    ok_err_msg "Backup failed for '$filePath'"
    return  ""
  }
  if { $loud }  {
    ok_info_msg "Backup for '$filePath' saved in '$buPath'"
  }
  return  $buPath
}


# Deletes the last backup version of 'filePath' even if 'filePath' doesn't exist.
# Returns 1 if deletion performed, or 0 if not (no backup or an error occurred).
proc ::ok_utils::ok_discard_last_backup_of_filepath {filePath {loud 0}}  {
  return  [_ok_discard_last_backup_of_filepath $filePath 1 $loud]
}


# Deletes the last backup version of 'filePath' even if 'filePath' doesn't exist.
# Returns 1 if deletion performed, or 0 if not (no backup or an error occurred).
# 'doPrompt' tells whether confirmation prompt desired; will do if CB defined.
proc ::ok_utils::_ok_discard_last_backup_of_filepath {filePath doPrompt loud}  {
  variable OVERRIDE_PROMPT_CB
  set existStr [expr {[file exists $filePath]? "existent" : "inexistent"}]
  set _silent 0
  set lastBuPath [ok_find_last_backup_file_of_filepath $filePath $_silent]
  if { [_ERR_RETURNED $lastBuPath] }  {
    return  $lastBuPath;  # in reality it returns _the_ error message
  }
  if { $lastBuPath == "" }  {
    if { $loud }  {
      ok_info_msg "File '$filePath' ($existStr) has no backup so far"
    }
    return  0;  # no backup at all
  }

  if { $doPrompt && ($OVERRIDE_PROMPT_CB != 0) }  {
    set response ""
    set promptOK [$OVERRIDE_PROMPT_CB  \
                    "Discard the last backup of '$filePath' (y/N)? "  response]
    if { !$promptOK }  {
      ok_err_msg "Prompt to confirm backup-discard failed. Nothing done"
      return  0
    }
    if { ![string equal -nocase $response "Y"] }  {
      ok_err_msg "Confirmation for backup-discard rejected. Nothing done"
      return  0
    }
  }
  
  set descr "deleting backup of ($existStr) file '$filePath'"
  if { 1 == [set delRes [ok_delete_file $lastBuPath]] }  {
    if { $loud }  { ok_info_msg "Success $descr" }
  } else          { ok_err_msg  "Failed $descr"  }
  
  return  $delRes
}


# Overrides file 'filePath' by its last backup version
#      even if 'filePath' doesn't exist.
# Returns 1 if action performed, 0 if not (no or equal backup, an error occured).
proc ::ok_utils::ok_pop_last_backup_of_filepath {filePath {loud 0}}  {
  variable OVERRIDE_PROMPT_CB
  set existStr [expr {[file exists $filePath]? "existent" : "inexistent"}]
  set descr "version pop of ($existStr) file '$filePath'"
  set _silent 0
  set lastBuPath [ok_find_last_backup_file_of_filepath $filePath $_silent]
  if { [_ERR_RETURNED $lastBuPath] }  {
    ok_err_msg "Failed $descr"
    return  0;  # nothing done anyway
  }
  if { $lastBuPath == "" }  {
    if { $loud }  {
      ok_info_msg "File '$filePath' ($existStr) has no backup so far"
    }
    return  0;  # no backup, so no action
  }

  if { $OVERRIDE_PROMPT_CB != 0 }  {
    set response ""
    set promptOK [$OVERRIDE_PROMPT_CB  \
                    "Override '$filePath' by its last backup (y/N)? "  response]
    if { !$promptOK }  {
      ok_err_msg "Prompt to confirm backup-pop failed. Nothing done"
      return  0
    }
    if { ![string equal -nocase $response "Y"] }  {
      ok_err_msg "Confirmation for backup discard rejected. Nothing done"
      return  0
    }
  }

  set copyDescr "copying into the current version for $descr; source: '$lastBuPath'"
  if { ![ok_safe_copy_file $lastBuPath $filePath] }  {
    ok_err_msg "Failed $descr at copying the backup into current"
    return  0;  # nothing done - backup NOT deleted
  }
  if { $loud }  { ok_info_msg  "Performed $copyDescr"
  } else        { ok_trace_msg "Performed $copyDescr" }

  set delDescr "deleting the last version of backup for ($existStr) file '$filePath'"
  if { [_ok_discard_last_backup_of_filepath $filePath 0 $_silent] }  {
    if { $loud }  { ok_info_msg  "Performed $delDescr"
    } else        { ok_trace_msg "Performed $delDescr" }
  } else {}  ;  # error, if any, already reported; otherwise no action performed

  if { $loud }  { ok_info_msg  "Performed $descr"
  } else        { ok_trace_msg "Performed $descr" }
  return  1
}


# If backup for file 'filePath' has equal contents to that of 'filePath',
#    returns path of this backup file.
# If backup for file 'filePath' is absent or its content differs, returns "".
# On error returns string "ERROR: <error-details>".
proc ::ok_utils::ok_file_equal_to_its_backup {filePath {priResult 0}}  {
  set _silent 0
  set lastBuPath [ok_find_last_backup_file_of_filepath $filePath $_silent]
  if { [_ERR_RETURNED $lastBuPath] }  {
    return  $lastBuPath;  # in reality it returns _the_ error message
  }
  if { $lastBuPath == "" }  {
    if { $priResult }  {
      ok_info_msg "File '$filePath' has no backup so far"
    }
    return  "";  # no backup at all
  }
  if { [_ERR_RETURNED [set res [_cmp_files_chunked $filePath $lastBuPath]]] }  {
    return  $lastBuPath;  # in reality it returns _the_ error message
  }
  if { $res == 0 }  {
    if { $priResult }  {
      ok_info_msg "File '$filePath' is equal to its backup in '$lastBuPath'"
    }
    return  $lastBuPath;  # equal - return the backup path
  }
  if { $priResult }  {
    ok_info_msg "File '$filePath' differs from its backup in '$lastBuPath'"
  }
  return  "";  # the backup is present, but its contents differs
}


# If 'logIdx' given, attempts to duplicate message into pre-open(!) log #'_LOG0';
#     throws exception if the additional log isn't ready
proc ::ok_utils::ok_print_file_backup_status_report {descr filePath  \
                                                             {logIdx $_LOG0}}  {
  variable _LOG0
  set msgWithPrefix [ok_format_file_backup_status_report $descr $filePath]
  if { $msgWithPrefix == 0 }  {
    return  0;  # error already printed
  }
  if { $logIdx != $_LOG0 }  {
    _ok_write_diagnostics $msgWithPrefix $logIdx
  }
  return  1
}


# Returns formatted message with proper prefix;
#  errors reported as message contents
## Example-1:  ok_format_file_backup_status_report  "-outf"  {OUT/K400_2__ORIG_SET1__eng_esp.csv}
## Example-2:  ok_format_file_backup_status_report  "-outf"  {INEXISTENT.csv}
proc ::ok_utils::ok_format_file_backup_status_report {descr filePath}  {
  set fullDescr "'$filePath' (as $descr)"
  if { 0 == [set buList [ok_list_backup_files_of_filepath $filePath]] }  {
    set msg "Failed listing backup files for $fullDescr"
    ok_err_msg $msg;    return  "-E- $msg"
  }
  if { [llength $buList] == 0 }  {
    set msg "No backup files for $fullDescr"
    ok_info_msg $msg;    return  "-I- $msg"
  }
  ok_trace_msg "Found [llength $buList] backup file(s) for '$filePath'"
  if { [_ERR_RETURNED [set cmpRes [ok_file_equal_to_its_backup $filePath]]] }  {
    set msg "Failed comparing $fullDescr with backup: $cmpRes"
    ok_err_msg $msg;    return  "-E- $msg"
  }
  set verdictStr [expr {($cmpRes == "")?  "differs from"  :  "equals to"}]
  set msg "File $fullDescr $verdictStr its backup"
  ok_info_msg $msg;  return  "-I- $msg"
}


proc ::ok_utils::ok_prompt_for_string_tty {promptStr destBuff}  {
  upvar $destBuff dest
  puts -nonewline stdout $promptStr
  flush stdout
  set dest [gets stdin]
  return  1
}


############ Begin: various utilities ###########################################

proc ::ok_utils::_ok_get_full_backup_path_for_filepath {filePath {loud 0}}  {
  if { 0 == [set buDir [ok_provide_backup_dir_for_filepath $filePath $loud]] }  {
    return  0;  # error already printed
  }
  set timeNowStr [ok_format_current_timestamp];  # always OK
  set buName [_ok_format_file_backup_name $filePath  $timeNowStr];  # always OK
  return  [file join $buDir $buName]
}


# Example-1:  ok_utils::_ok_format_file_backup_name  "/tmp/a.b"  [ok_utils::ok_seconds_to_timestamp 200]
# Example-2:  ok_utils::_ok_format_file_backup_name  "/tmp/a.b"  {*}
proc ::ok_utils::_ok_format_file_backup_name {fileNameOrPath timeStampStr}  {
  set newName [ok_insert_suffix_into_filename  [file tail $fileNameOrPath]  \
                                               "__AT_$timeStampStr"]
  return  $newName
}


# TODO: ? maybe need to encode original subdirectory into backup-file name ?
## Example:  if {[ok_utils::_ok_decode_backup_file_name  "name__AT_[ok_utils::ok_seconds_to_timestamp 6789].ext"  fName tSec]}  {puts "$fName ... $tSec"}
proc ::ok_utils::_ok_decode_backup_file_name {fileNameOrPath  \
                                                origFileName  buTimeSec}  {
  upvar $origFileName origNameNoDir
  upvar $buTimeSec    globalTimeSec
  # timestamp comes just before extension and has fixed length
  set nameNoExt [file rootname [file tail $fileNameOrPath]]
  set tsLen [string length [ok_seconds_to_timestamp 0]];  # fixed length anyway
  set tsStartIdx [expr {[string length $nameNoExt] - $tsLen}]
  set origNameEndIdx [expr {$tsStartIdx - [string length "__AT_"]}]
  ##puts "@@@ '$nameNoExt':  len=[string length $nameNoExt] tsLen=$tsLen tsStartIdx=$tsStartIdx origNameEndIdx=$origNameEndIdx";  # OK_TMP
  if { $origNameEndIdx < 0 }  {
    ok_err_msg "Invalid backup-file name '$fileNameOrPath' - missing original name(?)"
    return  0
  }
  set timeStampSubStr [string range $nameNoExt $tsStartIdx end]
  if { -1 == [set globalTimeSec [ok_timestamp_to_seconds $timeStampSubStr]] }  {
    ok_err_msg "Invalid backup-file name '$fileNameOrPath' - missing or wrongly formatted timestamp"
  }
  set origNameNoDir [format {%s%s}  [string range $nameNoExt 0 $origNameEndIdx] \
                                    [file extension $fileNameOrPath]]
  return  1
}


proc ::ok_utils::_ok_format_file_backup_glob_pattern {fileNameOrPath}  {
  # sample timestamp string:  "1970-01-01_02-00-00"
  set timeStampGlob {[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]}
  return  [_ok_format_file_backup_name $fileNameOrPath $timeStampGlob]
}
############ End:   various utilities ##########################################



############ Begin: file-comparison utilities ###################################
# Binary file comparison
# (Adapted from: https://wiki.tcl-lang.org/page/Comparing+files+in+Tcl)
# Returns 0 if files are equal, non-zero difference if unequal.
# On error returns string "ERROR: <error-details>"
proc ::ok_utils::_cmp_files_chunked {file1 file2 {chunksize 16384}} {
  foreach filePath [list $file1 $file2]  {
    if {  ![file exists $filePath] || ![ok_filepath_is_readable $filePath] }  {
      set msg "Specified path '$filePath' is not an existent readable regular file"
      ok_err_msg $msg;    return "ERROR: $msg"                               }
  }
  set f1 -1;  set f2 -1
  set tclExecResult [catch {
    set f1 [open $file1];  fconfigure $f1 -translation binary
    set f2 [open $file2];  fconfigure $f2 -translation binary
    while {1} {
      set d1 [read $f1 $chunksize]
      set d2 [read $f2 $chunksize]
      set diff [string compare $d1 $d2]
      if {$diff != 0 || [eof $f1] || [eof $f2]} {
        break
      }
    }
    close $f1;  set f1 -1
    close $f2;  set f2 -1
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    if { $f1 != -1}  { close $f1;  set f1 -1 }
    if { $f2 != -1}  { close $f2;  set f2 -1 }
    return  "ERROR: $execResult"
  }
  return  $diff
}
############ End:   file-comparison utilities ###################################
