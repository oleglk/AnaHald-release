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

# csv_utils.tcl - utilities for reading/writting CSV files

# Copyright (C) 2014-2016 by Oleg Kosyakovsky

namespace eval ::ok_utils:: {

  namespace export                      \
  ok_csv2list                           \
  ok_list2csv                           \
  ok_list2csv_1line                     \
  ok_write_array_of_lists_into_csv_file \
  ok_write_list_of_lists_into_csv_file  \
  ok_read_csv_file_into_array_of_lists  \
  ok_read_csv_file_into_list_of_lists   \
  ok_check_list_of_lists_lengths        \
  ok_read_csv_file_keys                 \
  ok_read_csv_file_column               \
  ok_read_variable_values_from_csv      \
  ok_discard_empty_list_elements
}

if { "" == [info procs ::ok_utils::ok_err_msg] } {
    proc ::ok_utils::ok_err_msg  {text}  {	puts "-E- $text" }
    proc ::ok_utils::ok_info_msg {text}  {	puts "-I- $text" }
}


proc ::ok_utils::ok_csv2list {str {sepChar ,}} {
  regsub -all {(\A\"|\"\Z)} $str \0 str
  set str [string map [list $sepChar\"\"\" $sepChar\0\" 		\"\"\"$sepChar \"\0$sepChar 		\"\" \" \" \0 ] $str]
  set end 0
  while {[regexp -indices -start $end {(\0)[^\0]*(\0)} $str fullMatch start end]} {
    set start [lindex $start 0]
    set end   [lindex $end 0]
    set range [string range $str $start $end]
    set first [string first $sepChar $range]
    if {$first >= 0} {
	    set str [string replace $str $start $end 		[string map [list $sepChar \1] $range]]
    }
    incr end
  }
  set str [string map [list $sepChar \0 \1 $sepChar \0 {} ] $str] 
  return [split $str \0]
}


proc ::ok_utils::ok_list2csv {list {sepChar ,}} {
  set out ""
  foreach l $list {
    set sep {}
    foreach val $l {
	    if {[string match "*\[\"$sepChar\]*" $val]} {
        append out $sep\"[string map [list \" \"\"] $val]\"
      } else {
        append out $sep$val
	    }
	    set sep $sepChar
    }
    append out "$sepChar\n"
  }
  return $out
}


## Oleg's code

proc ::ok_utils::ok_list2csv_1line {list {sepChar ,}} {
  set out ""
  set sep {}
  foreach val $list {
    if {[string match "*\[\"$sepChar\]*" $val]} {
      append out $sep\"[string map [list \" \"\"] $val]\"
    } else {
      append out $sep$val
    }
    set sep $sepChar
  }
  append out $sepChar
  return $out
}

# Stores lists from 'arrName' one-at-a-line in file 'fullPath';
# each list prepended by its key
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_write_array_of_lists_into_csv_file {arrName fullPath headerPattern \
                                            {sepChar ,}} {
  upvar $arrName theArr
  set goodCnt 0
  set tclExecResult [catch {
    if { ![string equal $fullPath "stdout"] } {
      set outF [open $fullPath w]
    } else {
      set outF stdout
    }
    # find and print the header
    foreach name [array names theArr] {
      if { 1 == [regexp $headerPattern $name] } {
        puts $outF [format "%s%s%s" \
                    $name $sepChar [ok_list2csv_1line $theArr($name) $sepChar]]
        break
      }
    }
    # print the body (everything other than the header)
    foreach name [lsort [array names theArr]] {
      if { 0 == [regexp $headerPattern $name] } {
        puts $outF [format "%s%s%s" \
                     $name $sepChar [ok_list2csv_1line $theArr($name) $sepChar]]
        incr goodCnt
      }
    }
    if { ![string equal $fullPath "stdout"] } {    close $outF	}
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  ok_info_msg "Wrote $goodCnt record(s) into '$fullPath'"
  return  1
}


# Stores lists from 'topList' one-at-a-line in file 'fullPath'
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_write_list_of_lists_into_csv_file {topList fullPath {sepChar ,}} {
  set goodCnt 0
  set tclExecResult [catch {
    if { ![string equal $fullPath "stdout"] } {
      set outF [open $fullPath w]
    } else {
      set outF stdout
    }
    puts $outF [ok_list2csv $topList $sepChar]
    incr goodCnt [llength $topList]
    #~ foreach rec $topList {
      #~ puts $outF [ok_list2csv $rec $sepChar]
      #~ incr goodCnt
    #~ }
    if { ![string equal $fullPath "stdout"] } {    close $outF	}
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  ok_info_msg "Wrote $goodCnt record(s) into '$fullPath'"
  return  1
}

# Reads lists from file 'fullPath' into array 'arrName';
# each first list element used as array key.
# If 'requireEqualLength'==1, aborts if not all lines have equal num of fields
# If 'LineCheckCB' callback supplied, it's called on each line except the header;
#   if 'LineCheckCB' returns non-empty string, error reported and reading stopped.
#   String returned by 'LineCheckCB' provides basis of error message.
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_read_csv_file_into_array_of_lists {arrName fullPath sepChar \
                                          requireEqualLength {LineCheckCB 0}} {
  upvar $arrName theArr
  set descr "data-file '$fullPath'"
  set goodCnt 0
  set prevLst {};  # to compare lengths of subsequent lines (after header)
  set tclExecResult [catch {
  set inF [open $fullPath r]
  	while { [gets $inF line] >= 0 } {
      set lst [ok_discard_empty_list_elements [ok_csv2list $line $sepChar]]
      if { [llength $lst] == 0 }  { continue } ;  # skip empty lines
      if { ($requireEqualLength != 0) && ($prevLst != {}) && ($goodCnt > 1) && \
            ([llength $lst] != [llength $prevLst]) }  {
        ok_err_msg "Line length mismatch in $descr: {$prevLst} vs {$lst}" 
        return  0
      }
      if { ($LineCheckCB != 0) && ($goodCnt >= 1) && \
                                      ("" != [set err [$LineCheckCB $lst]]) }  {
        ok_err_msg "Error in a line of $descr ([lindex $lst 0]): $err"
        return  0
      }
      set prevLst $lst
      set name [lindex $lst 0]
      if { $name == "" }  { continue } ;  # skip empty lines
      set theArr($name) [lrange $lst 1 end]
      incr goodCnt
    }
   close $inF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  #~ # convert into list-of-lists and check lengths
  #~ set listOfLists {}
  #~ foreach ix [lsort [array names theArr]]   { lappend listOfLists $theArr($ix) }
  #~ if { 0== [ok_check_list_of_lists_lengths $listOfLists "data file '$fullPath'"] } {
    #~ return  0;  # error already printed
  #~ }
  ok_info_msg "Read $goodCnt record(s) from $descr"
  return  1
}


# Reads lists from file 'fullPath' into a list and returns it
# If 'requireEqualLength'==1, aborts if not all lines have equal num of fields
# Returns 0 on error.
proc ::ok_utils::ok_read_csv_file_into_list_of_lists {fullPath sepChar \
                              commentStart requireEqualLength {LineCheckCB 0}} {
  set descr "data-file '$fullPath'"
  set goodCnt 0
  set fullList [list ]
  set prevLst {};  # to compare lengths of subsequent lines (after header)
  set tclExecResult [catch {
  set inF [open $fullPath r]
  	while { [gets $inF line] >= 0 } {
      if { $commentStart == [string index $line 0] }   { continue }
      set oneLineList [ok_discard_empty_list_elements [ok_csv2list $line $sepChar]]
      if { [llength $oneLineList] == 0 }  { continue } ;  # skip empty lines
      if { ($requireEqualLength != 0) && ($prevLst != {}) && ($goodCnt > 1) && \
           ([llength $oneLineList] != [llength $prevLst]) }  {
        ok_err_msg "Line length mismatch in $descr: {$prevLst} vs {$oneLineList}" 
        return  0
      }
      if { ($LineCheckCB != 0) && ($goodCnt >= 1) && \
                              ("" != [set err [$LineCheckCB $oneLineList]]) } {
        ok_err_msg "Error in a line of $descr  ([lindex $oneLineList 0]): $err"
        return  0
      }
      set prevLst $oneLineList
      lappend fullList $oneLineList
      incr goodCnt
    }
   close $inF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  #~ if { 0 == [ok_check_list_of_lists_lengths $fullList "data file '$fullPath'"] } {
    #~ return  0;  # error already printed
  #~ }
  ok_info_msg "Read $goodCnt record(s) from $descr"
  return  $fullList
}


### Empty elements are discarded, thus cannot compare with header
#~ # Returns 1 if lengths of all lists in 'listOfLists' are equal; otherwise - 0
#~ proc ::ok_utils::ok_check_list_of_lists_lengths {listOfLists descr {priErr 1}}  {
  #~ if { 1 >= [llength $listOfLists] }  { return 1 };  # nothing to check
  #~ set lng [llength [lindex $listOfLists 0]]
  #~ foreach lst [lrange $listOfLists 1 end]  {
    #~ if { [llength $lst] != $lng }  {
      #~ if { $priErr }  {
        #~ ok_err_msg "Line length mismatch in $descr: {[lindex $listOfLists 0]} vs {$lst}" 
      #~ }
      #~ return  0
    #~ }
  #~ }
  #~ return  1
#~ }


proc ::ok_utils::ok_read_csv_file_keys {fullPath sepChar {commentStart "#"}} {
  return  [ok_read_csv_file_column $fullPath 0 $sepChar $commentStart]
}

proc ::ok_utils::ok_read_csv_file_column {fullPath iColumn sepChar \
                                          {commentStart "#"}} {
  set listOfLists [ok_read_csv_file_into_list_of_lists $fullPath \
                                                    $sepChar $commentStart 1 0]
  set res [list]
  # comments dropped; do skip header
  for {set i 1} {$i < [llength $listOfLists]} {incr i} {
    set lnL [lindex $listOfLists $i]
    if { $iColumn >= [llength $lnL] } {
      ok_err_msg "Invalid field index $iColumn in '$fullPath'";  return  ""
    }
    lappend res [lindex $lnL $iColumn]
  }
  return  $res
}




# A generic function to read global-variable values from 'csvPath'
proc ::ok_utils::ok_read_variable_values_from_csv {csvPath descr}  {
  # TODO: supply line-check CB
  set listOfPairs [ok_read_csv_file_into_list_of_lists $csvPath "," "#" 1 0]
  if { $listOfPairs == 0 }  {
    ok_err_msg "[info script] failed reading $descr from '$csvPath'"
    return  0
  }
  ok_info_msg "Read [llength $listOfPairs] $descr from '$csvPath'"
  foreach line [lrange $listOfPairs 1 end] {
    set varName [lindex $line 0];   set varVal [lindex $line 1]
    global $varName
    set $varName $varVal
    ok_info_msg "Reader of $descr assigned '$varName' to '$varVal'"
  }
  return  1
}



# Returns a list that is a copy of 'inpList' but without empty ("") elements
proc ::ok_utils::ok_discard_empty_list_elements {inpList} {
  set length [llength $inpList]
  set outList [list]
  for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $inpList $i]
	if { $elem != "" } {
	    lappend outList $elem
	}
    }
    return  $outList
}


# Sorts records of 'csvPath' by column 'columnIndex'.
# First line is the header.
# Returns resulting list on success, 0 on error.
proc sort_csv_file_by_numeric_column {csvPath columnIndex descr} {
  if { 0 == [file exists $csvPath] } {
    ok_err_msg "Inexistent $descr file '$csvPath'"
    return  0
  }
  set fullList [ok_read_csv_file_into_list_of_lists $csvPath " " "#" 1 0]
  if { $fullList == 0 } {
    ok_err_msg "Failed reading $descr file '$csvPath'";    return  0
  }
  set sortedList [lsort -real -index $columnIndex [lrange $fullList 1 end]]
  set header [list [lindex $fullList 0]];  # wrapped to prepare for "concat" 
  set sortedListWithHeader [list ]
  set sortedListWithHeader [concat $header $sortedList]
  return  $sortedListWithHeader
}
