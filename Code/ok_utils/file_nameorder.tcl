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

# file_nameorder.tcl -  making creation order match name order

namespace eval ::ok_utils:: {

  namespace export                \
    ok_list_files_in_nameorder    \
    ok_flat_copy_in_nameorder     \
    ok_find_place_in_nameorder
}


# Returns list of filenames in 'dirPath' in lexicographic name order.
# On error returns "ERROR"
proc ::ok_utils::ok_list_files_in_nameorder {dirPath} {
  set lst [glob -nocomplain -tails -directory $dirPath *]
  return [lsort -ascii -nocase -increasing $lst]
}


# Copies regular files from 'srcDir' into 'dstDir' in name order.
# If 'fileNameRegexPattern' given, copies only files that match the pattern.
# Returns number of files copied or -1 on error.
proc ::ok_utils::ok_flat_copy_in_nameorder {srcDir dstDir \
                      {fileNameRegexPattern ""}}  {
  if { 0 == [ok_filepath_is_existent_dir $srcDir] }  {
    ok_err_msg "Inexistent source directory '$srcDir'"
    return  0
  }
  if { 0 == [ok_create_absdirs_in_list \
              [list $dstDir] [list "Destination directory"]] }  {
    return  0;  # error already printed
  }
  set allFilenames [ok_list_files_in_nameorder $srcDir]
  ok_info_msg "Found [llength $allFilenames] file(s) of any type under '$srcDir'"
  set filteredFilenames [list]
  foreach fName $allFilenames {
    set fPath [file join $srcDir $fName]
    if { ![ok_filepath_is_readable $fPath] }  {
      ok_info_msg "'$fName' (directory or special-type) will not be copied"
      continue;
    }
    if { ($fileNameRegexPattern != "") && \
          (0 == [regexp -- $fileNameGlobPattern $fName]) } {
      ok_info_msg "'$fName' (not matching pattern) will not be copied"
      continue;
    }
    lappend filteredFilenames $fName
  }
  set nFiles [llength $filteredFilenames];  set cnt 0;  set badCnt 0
  set actionDescr " copying $nFiles file(s) in name-order from '$srcDir' into '$dstDir'"
  ok_info_msg "Start $actionDescr"
  foreach fName $filteredFilenames {
    incr cnt 1
    set fPath [file join $srcDir $fName]
    set descr "copying file '$fName' ($cnt out of $nFiles) from '$srcDir' into '$dstDir'"
    if { 1 == [ok_safe_copy_file $fPath $dstDir] }  {
      ok_info_msg "Success $descr"
    } else {
      ok_info_msg "Failed $descr";    incr badCnt 1
    }
  }
  set resultDescr "Done $actionDescr; $badCnt error(s) occured"
  if { $badCnt == 0 } {
    ok_info_msg "$resultDescr" } else { ok_err_msg "$resultDescr"
  }
  return  [expr {($badCnt == 0)? $cnt : -1}]
}


# Returns index fot 'name' if it was inserted into 'nameList'
proc ::ok_utils::ok_find_place_in_nameorder {name nameList} {
  # TODO
}
