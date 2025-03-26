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

# disk_info.tcl

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "debug_utils.tcl"]

namespace eval ::ok_utils:: {

  namespace export                \
    ok_get_free_disk_space_kb     \
    ok_try_get_free_disk_space_kb \
    ok_get_filelist_disk_space_kb \
    ok_dir_list_size              \
    ok_dir_size                   \
    ok_read_all_files_stat_in_dir \
    ok_monitor_file_save
}

# Copied from "proc df-k" at http://wiki.tcl.tk/526#pagetoc071ae01c
# Returns free disk space in kilobytes
proc ::ok_utils::ok_get_free_disk_space_kb {{dirNative .}} {
    switch $::tcl_platform(os) {
    FreeBSD -
    Linux -
    OSF1 -
    SunOS {
        # Use end-2 instead of 3 because long mountpoints can 
        # make the output to appear in two lines. There is df -k -P
        # to avoid this, but -P is Linux specific afaict
        return  [lindex [lindex [split [exec df -k $dirNative] \n] end] end-2]
    }
    HP-UX {return  [lindex [lindex [split [exec bdf   $dirNative] \n] end] 3]}
    {Windows NT} {
      set numPos 2;  # Oleg: was 0
      set tclExecResult [catch {
        set dosStr [exec cmd /c dir /-c $dirNative]} execResult]
      if { $tclExecResult != 0 } {
        #puts "@@ Destination disk could be empty:\n$execResult!"
        set dosStr $execResult
      }
      set lastLine [lindex [split $dosStr \n] end]
      if { $lastLine == {File Not Found} }  {
        # the whole disk could be empty; create dummy directory on it and retry"
        #ok_trace_msg "The disk could be empty; create dummy file and retry"
        set tmpDir [file join [file normalize $dirNative]  \
                      "_tMPsUBdIRfORsPACEcHECK_"]
        if { [file exists $tmpDir]} {error "* '$dirNative' appears messed-up..."}
        file mkdir $tmpDir
        set res [ok_get_free_disk_space_kb $dirNative] ;  # retry recursively
        file delete $tmpDir
        return  $res
      }
      return  [expr {round([lindex $lastLine $numPos] / 1024.0)}]
      # CL notes that, someday when we want a bit more
      #    sophistication in this region, we can try
      #    something like
      #       secpercluster,bytespersector, \
        #       freeclusters,noclusters = \
        #            win32api.GetDiskFreeSpace(drive)
      #    Then multiply long(freeclusters), secpercluster,
      #    and bytespersector to get a total number of
      #    effective free bytes for the drive.
      # CL further notes that
      #http://developer.apple.com/techpubs/mac/Files/Files-96.html
      #    explains use of PBHGetVInfo() to do something analogous
      #    for MacOS.
    }
    default {error "don't know how to measure free disk space on '$::tcl_platform(os)'"}
    }
} ;#RS


# If possible, returns free disk space on the disk of path '$dir'.
# On error returns -1
proc ::ok_utils::ok_try_get_free_disk_space_kb {{dir .}} {
  set dirN [file nativename $dir]
  set tclExecResult [catch {set n [ok_get_free_disk_space_kb $dirN]} execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot check free space for '$dir' ($dirN)."
    return  -1
  }
  return $n
}


# Calculates and returns total disk space consumed by files in 'filePathsList'.
# On error returns -1 * <number-of-unreadable-files>
proc ::ok_utils::ok_get_filelist_disk_space_kb {filePathsList {priErr 1}}  {
  set size 0;    set noaccess [list]
  foreach filePath $filePathsList {
    if { [file exists $filePath] && [file readable $filePath] } {
      incr size [file size $filePath]
    } else {
      lappend noaccess $filePath
    }
  }
  if { 0 != [llength $noaccess] }  {
    if { $priErr }  {
      ok_err_msg "Measuring used disk space encountered [llength $noaccess] inexistent and/or unreadable file(s)"
    }
    return  [expr -1 * [llength $noaccess]]
  }
  return  [expr {round($size / 1024.0)}]
}


# Calculates the total size in bytes of (parent) directories in 'dirPathList'
# including all their (child) sub-directories and files.
# Returns this size in Kb.
#  - dirPathList - list of full paths of the target directories - TCL convention
proc ::ok_utils::ok_dir_list_size {dirPathList {priErr 1}} {
  set totalsizeKBytes 0.0
  foreach dir $dirPathList {
    set totalsizeKBytes [expr {$totalsizeKBytes + [ok_dir_size $dir $priErr]}]
  }
  return  $totalsizeKBytes
}


# Calculates the total size in bytes of a (parent) directory
# including all its (child) sub-directories and files.
# Returns this size in Kb.
#    dirPath          the full path of the target directory - TCL convention
proc ::ok_utils::ok_dir_size {dirPath {priErr 1}} {
  set totalsizeBytes 0;  set noaccessList [list]
  if { ![file exists $dirPath] || ![file readable $dirPath] || \
       ![file isdirectory $dirPath] } {
    ##lappend noaccess $dirPath
    ok_err_msg "Measuring disk space requested in inexistent or invalid directory '$dirPath'"
    return  0
  }
  set sizeKb [_ok_dir_size $dirPath totalsizeBytes noaccessList]
  if { 0 != [llength $noaccessList] }  {
    if { $priErr }  {
      ok_err_msg "Measuring disk space used by '$dirPath' encountered [llength $noaccessList] unreadable file(s)"
    }
  }
  return  $sizeKb
}


# Builds and retuns a dict  pureName :: list-of-file-stat-params
proc ::ok_utils::ok_read_all_files_stat_in_dir {dirPath namePattern {priErr 1}} {
  if { ![file exists $dirPath] || ![file isdirectory $dirPath] }  {
    if { $priErr }  { ok_err_msg "Invalid or inexistent directory '$dirPath'" }
    return [dict create]
  }
  set fileList [glob -nocomplain -directory $dirPath -- $namePattern]
  if { $priErr && (0 == [llength $fileList]) }  {
    ok_err_msg "No files matching '$namePattern' found in directory '$dirPath'"
    return  [dict create]
  }
  set filenameToStat [dict create]
  foreach fPath $fileList {
    array unset stArr;    file stat $fPath stArr;
    set stList [array get stArr]
    dict set filenameToStat [file rootname [file tail $fPath]] $stList
  }
  return  $filenameToStat
}

# Takes dict {pureName :: list-of-file-stat-params} - by value(!)
# and changes specified time parameter (ctime, atime or mtime) to 'newTimeSec'
# Returns the new dict or 0 on error.
## Example:  set inpStats [ok_utils::ok_read_all_files_stat_in_dir "." "*.JPG" 1];   set newStats [ok_utils::ok_override_files_stat_time $inpStats mtime 121]
proc ::ok_utils::ok_override_files_stat_time {filenameToStat timeParamKey \
                                                                  newTimeSec}  {
  if { 0 > [lsearch -exact {ctime atime mtime} $timeParamKey] }   {
    puts "-E- Invalid timestamp-key '$timeParamKey'; should be ctime, atime or mtime"
    return  0
  }
  set newStatDict [dict create];  set cnt 0
  dict for {fName fStat} $filenameToStat {
    dict set fStat $timeParamKey $newTimeSec
    dict set newStatDict $fName $fStat
    incr cnt
  }
  puts "-D- Timestamp '$timeParamKey' overriden to $newTimeSec on $cnt image(s)"
  return  $newStatDict
}



# (Based on: http://www.fundza.com/tcl/examples/file/dirsize.html)
# Calculates the total size in bytes of a (parent) directory
# including all its (child) sub-directories and files.
# Returns this size in Kb.
#    dir          the full path of the target directory - TCL convention
#    totalsize    a variable that keeps a running total of byte count ie. size
#    noaccessList a variable that keeps a running list of unreadable files
proc ::ok_utils::_ok_dir_size {dirPath totalsizeBytes noaccessList} {
  upvar $totalsizeBytes bytes
  upvar $noaccessList   noaccess
  
  if { 0 == [info exists bytes] }  { set bytes 0 }; # for sure top-level frame
  if { 0 == [info exists noaccess] } { set noaccess [list]};# sure top-level frame

  set contents [glob -nocomplain -directory $dirPath *]
  foreach item $contents {
    if { [file readable $item] } {
      #puts "[format "%32s %f" $item [file size $item]]"
      incr bytes [file size $item]
    } else {
      lappend noaccess $item
    }

    if { [file isdirectory $item] } {
      _ok_dir_size $item bytes noaccess; # RECURSE ie. call ourself
    } elseif { [file isfile $item]} {
      # nothing to do
    }
  };#foreach_item
  return [expr {$bytes / 1000.0}]
}


# Returns 1 if file 'outPath' is fully saved on disk during <= 'maxWaitSec'
# 'oldFileSize' is size of pre-existent file or -1 - to track old file override
# Considers saving process stuck if current size _stays_ equal to 'oldFileSize'
#    - returns -1 if considered stuck
proc ::ok_utils::ok_monitor_file_save {outPath oldFileSize \
                                      minSizeKb maxWaitSec maxWaitIfStuckSec}  {
  set descr "Saving file '$outPath'"
  set maxWaitSec [expr ceil($maxWaitSec)]
  if { $maxWaitSec < (2+1) }  {
    puts "-E- minimal value for 'maxWaitSec' is [expr 2+1]";   return  -1
  }
  set sizeEverChanged 0
  set prevSize $oldFileSize;  set prevChangeTime 0
  for {set tm 0}  {$tm <= $maxWaitSec}  {incr tm 1}  {
    if { ![file exists $outPath] }  {
      set sz -1
      if { $oldFileSize > 0 }   { set sizeEverChanged 1 }
    }  else  {
      set sz [expr {round([file size $outPath] / 1024.0)}]
    }
    if { $sz != $prevSize }  {  ;   # size change detected
      set prevSize $sz;   set prevChangeTime $tm;   set sizeEverChanged 1
    } elseif { $sizeEverChanged && \
                  ($tm >= ($prevChangeTime + 2)) && ($sz >= $minSizeKb) }  {
      puts "-I- $descr considered finished after $tm second(s); size $sz kb"
      return  1
    }
    if { !$sizeEverChanged && ($tm >= $maxWaitIfStuckSec) }  {
      puts "-D- $descr considered stuck after $tm second(s); aborted for now"
      return  -1
    }
    if { $tm < $maxWaitSec }  {
      puts "-D- $descr NOT finished after $tm second(s); size $sz kb"
      after 1000
    }
  }
  puts "-E- $descr considered failed after $tm second(s); size $sz kb"
  return  0
}
