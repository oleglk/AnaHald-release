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

# common.tcl - common utils
# Copyright (C) 2005-2006 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "debug_utils.tcl"]


namespace eval ::ok_utils:: {

  namespace export \
    pause  \
    ok_ladd  \
    ok_list_to_set \
    ok_list_to_dict_set \
    ok_unordered_lists_are_equal \
    ok_compare_ordered_lists \
    ok_compare_files_as_ordered_lists \
    ok_lremove_in_place \
    ok_lremove \
    ok_name_in_array \
    ok_discard_empty_list_elements \
    ok_group_repeated_elements_in_list \
    ok_split_string_by_whitespace \
    ok_split_string_by_substring \
    ok_subtract_list_from_list \
    ok_copy_array \
    ok_list_to_array \
    ok_list_of_lists_to_array \
    ok_build_dest_filepath \
    ok_insert_suffix_into_filename \
    ok_insert_io_filenames_into_list \
    ok_insert_name_into_list_at_placeholder \
    ok_write_list_into_file \
    ok_read_list_from_file \
    ok_read_commented_list_from_file \
    ok_create_absdirs_in_list \
    ok_get_abs_directories_from_filelist \
    ok_get_purenames_list_from_pathlist \
    ok_override_list \
    ok_rename_file_add_suffix \
    ok_safe_copy_file \
    ok_copy_file_if_target_inexistent \
    ok_move_file_if_target_inexistent \
    ok_filepath_is_writable \
    ok_filepath_is_readable \
    ok_filepath_is_existent_dir \
    ok_filepath_is_readable_dir \
    ok_filepath_is_writable_dir \
    ok_format_filepath_for_regexp \
    ok_delete_file \
    ok_force_delete_dir \
    ok_mkdir \
    ok_is_underlying_filepath \
    ok_dirpath_equal  \
    ok_find_filepaths_common_prefix        \
    ok_strip_prefix_from_filepaths_in_list \
    ok_strip_prefix_from_filepath          \
    ok_truncate_text \
    ok_validate_string_by_given_format \
    ok_isnumeric \
    ok_arrange_proc_args \
    ok_make_argspec_for_proc \
    ok_exec_under_catch \
    ok_run_silent_os_cmd \
    ok_run_loud_os_cmd \
    ok_detect_os_type  \
    ok_get_file_timestamp_format          \
    ok_seconds_to_timestamp               \
    ok_timestamp_to_seconds               \
    ok_format_current_timestamp           \
    ok_is_tty_available
}


proc ::ok_utils::pause {{message "Hit <Enter> to continue, Q<Enter> to quit ==> "}} {
  puts -nonewline $message
  flush stdout
  if { "Q" == [gets stdin] }  { return -code error }
  return
}

# Sums elements of list 'L'.
## (Copied from  https://wiki.tcl-lang.org/page/Summing+a+list)
proc ::ok_utils::ok_ladd {L} {
  expr [join $L +]+0
}


# Converts list 'theList' into array 'setName' of {elem->"+"} mappings.
# Returns number of elements in 'theList'
proc ::ok_utils::ok_list_to_set {theList setName} {
    upvar $setName theArray
    array unset theArray
    set cnt 0
    foreach el $theList {
	set theArray($el) "+"
	incr cnt
    }
    return $cnt
}


# Converts list 'theList' into dictionary of {elem->"+"} mappings.
# Returns the dictionary.
proc ::ok_utils::ok_list_to_dict_set {theList} {
  set theDict [dict create]
  foreach el $theList {
    dict set theDict $el "+"
  }
  return $theDict
}


#### TODO: an option to print diff details using something like:
####    for {set i 0} {$i < [expr {min([llength $lstOld], [llength $lstNew])}]} {incr i}  { set elO [lindex $lstOld $i];  set elN [lindex $lstNew $i];  if {$elN != $elO}  {puts ">>DIFF-$i-old: =={$elO}==\n>>DIFF-$i-new: =={$elN}=="} }
proc ::ok_utils::ok_unordered_lists_are_equal {list1 list2}  {
  return [expr {[lsort $list1] == [lsort $list2]}]
}


proc ::ok_utils::_ok_print_list_element_diff {idx el1 el2 {printCB "puts"}}  {
  $printCB ">>DIFF-$idx-(1): =={$el1}==\n>>DIFF-$idx-(2): =={$el2}=="
}


# Returns list of unequal element indices
proc ::ok_utils::ok_compare_ordered_lists {list1 list2                          \
                                    {diffPrintCB _ok_print_list_element_diff}}  {
  set resList [list]
  set len1 [llength $list1];  set len2 [llength $list2]
  set minLen [expr {min($len1, $len2)}]
  set maxLen [expr {max($len1, $len2)}]
  for {set i 0}  {$i < $maxLen} {incr i}  {
    set el1 [expr {($i < $len1)? [lindex $list1 $i] : "<MISSING>"}]
    set el2 [expr {($i < $len2)? [lindex $list2 $i] : "<MISSING>"}]
    if {$el2 != $el1}  { ;  # unequal
      ###ok_trace_msg ">>DIFF-$i-(1): =={$el1}==\n>>DIFF-$i-(2): =={$el2}=="
      if { $diffPrintCB != 0 }  {
        #puts ">>DIFF-$i-(1): =={$el1}==\n>>DIFF-$i-(2): =={$el2}=="
        $diffPrintCB $i $el1 $el2
      }
      lappend resList $i
    }; ###else { ok_trace_msg ">>EQU--$i: =={$el2}==" }
  }
  return  $resList
}


# On success returns list of unequal element indices.
# On error, returns string "ERROR: <details>"
proc ::ok_utils::ok_compare_files_as_ordered_lists {  \
                        filePath1 encodingOrEmpty1  filePath2 encodingOrEmpty2  \
                        {diffPrintCB _ok_print_list_element_diff}}             {
  if { 0 == [ok_read_list_from_file lst1 $filePath1  $encodingOrEmpty1] }  {
    return "ERROR: failed reading list from file '$filePath1' (encoding: '$encodingOrEmpty1')"
  }
  if { 0 == [ok_read_list_from_file lst2 $filePath2  $encodingOrEmpty2] }  {
    return "ERROR: failed reading list from file '$filePath2' (encoding: '$encodingOrEmpty2')"
  }
  return  [ok_compare_ordered_lists $lst1 $lst2 $diffPrintCB]
}


# A procedure to delete a given element from a list
# copied from http://docs.activestate.com/activetcl/8.5/tcl/TclCmd/lreplace.htm
proc ::ok_utils::ok_lremove_in_place {listVariable value} {
    upvar 1 $listVariable var
    set idx [lsearch -exact $var $value]
    set var [lreplace $var $idx $idx]
}


# A procedure to delete a given element from a list
proc ::ok_utils::ok_lremove {listValue valuesToremove} {
  set newList $listValue
  foreach value $valuesToremove {
    set idx [lsearch -exact $newList $value]
    set newList [lreplace $newList $idx $idx]
  }
  return  $newList
}


# Checks whether 'name' appears in 'arrayName'
proc ::ok_utils::ok_name_in_array {name arrayName} {
    upvar $arrayName theArray
#    set result [expr {[llength [array names theArray -exact $name]] >= 1} ]
    set result [info exists theArray($name)]
    # puts "ok_name_in_array -> $result"
    return  $result
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


# Returns a list that is a copy of 'inpList' but with each repeating element
# appearing only once in the head/tail - if 'headOrTail' == 0/1
proc ::ok_utils::ok_group_repeated_elements_in_list {inpList headOrTail} {
  set countDict [dict create]
  foreach element $inpList {  dict set  countDict $element 0  }
  foreach element $inpList {  dict incr countDict $element 1  }
  set repKeys [list];   set uniKeys [list]
  dict for {key count} $countDict {
    ok_trace_msg "Checking occurences of key '$key'"
    if { $count == 1 }  { lappend uniKeys $key } else {
      lappend repKeys $key
      ok_trace_msg "Key '$key' appeared $count times"
    }
  }
  if { $headOrTail == 0 } { return  [concat $repKeys $uniKeys]
  } else                  { return  [concat $uniKeys $repKeys] }
}


# Returns a list with words from 'inpStr'
proc ::ok_utils::ok_split_string_by_whitespace {inpStr} {
  return  [regexp -all -inline {\S+} $inpStr]
}


# Returns a list with substrings from 'inpStr' that were separated by 'sepStr'
# Derived from 'wsplit' at http://wiki.tcl.tk/1499
proc ::ok_utils::ok_split_string_by_substring {inpStr sepStr} {
  set first [string first $sepStr $inpStr]
  if {$first == -1} {
    return [list $inpStr]
  } else {
    set l [string length $sepStr]
    set left [string range $inpStr 0 [expr {$first-1}]]
    set right [string range $inpStr [expr {$first+$l}] end]
    return  [concat [list $left] [ok_split_string_by_substring $right $sepStr]]
  }
}


# Returns list of elements of 'list1' that don't appear in 'list2'.
# The order in resulting list doesn't match that of 'list1'.
proc ::ok_utils::ok_subtract_list_from_list {list1 list2} {
    set result [list]
    set list1S [lsort $list1]
    set list2S [lsort $list2]
    # lsearch shoud be fast if always looking from specified pos in sorted list
    set startPos 0
    foreach el $list1S {
	set ind [lsearch -exact -start $startPos $list2S $el]
	if { $ind == -1 } {
	    lappend result $el
	}
    }
    return  $result
}


# Copies contents of array 'srcArrName' into array 'dstArrName'
proc ::ok_utils::ok_copy_array {srcArrName dstArrName} {
    upvar $srcArrName srcArr
    upvar $dstArrName dstArr
    ok_assert {[array exists srcArr]} ""
    set aList [array get srcArr]
    array set dstArr $aList
}


# Inserts mapping-pairs from list 'srcList' into array 'dstArrName'.
# Returns 1 on success, 0 on failure.
proc ::ok_utils::ok_list_to_array {srcList dstArrName} {
    upvar $dstArrName dstArr
    set tclExecResult [catch {
	array set dstArr $srcList } evalExecResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$evalExecResult!"
	return  0
    }
    return  1
}


# Inserts mapping-pairs from nested list-of-pairs 'srcList' into array 'dstArrName'.
# Returns 1 on success, 0 on failure.
proc ::ok_utils::ok_list_of_lists_to_array {srcList dstArrName} {
  upvar $dstArrName dstArr
  array unset dstArr
  set errCnt 0
  foreach pair $srcList {
    if { 2 != [llength $pair] }   {
      incr errCnt 1;  continue
    }
    set dstArr([lindex $pair 0])  [lindex $pair 1]
  }
  return  [expr $errCnt == 0]
}


# Builds and returns "destination" filepath obtained from 'srcFilePath' by
# replacing extension with 'dstExt' and directory path with 'dstDir'.
# Warning: 'ok_build_dest_filepath a.b c' returns './a.c'
proc ::ok_utils::ok_build_dest_filepath {srcFilePath dstExt {dstDir ""}} {
    set fName [file tail $srcFilePath]
    set fNameNoExt [file rootname $fName]
    set srcDir [file dirname $srcFilePath]
    # set ext [file extension $srcFilePath]
    # regsub -nocase "$ext\$" $fName "" fNameNoExt
    if { $dstDir == "" } {
	set dstDir [file dirname $srcFilePath]
    }
    if { $dstExt != "" } {
	set dstFName "$fNameNoExt$dstExt"
    } else {
	set dstFName $fNameNoExt
    }
    if { $dstDir != "" } {
	set dstPath "$dstDir/$dstFName"
    } else {
	set dstPath "$srcDir/$dstFName"
    }
    return $dstPath
}

# For {A/b/name.ext SUFF} returns A/b/nameSUFF.ext
proc ::ok_utils::ok_insert_suffix_into_filename {origFilePath outNameSuffix} {
    set pathNoExt [file rootname $origFilePath]
    set ext       [file extension $origFilePath]
    set newPath "$pathNoExt$outNameSuffix$ext"
    return  $newPath
}

# Replaces two elements of the list in 'listVarName':
# - the one called "@iName@" by 'inpFileName',
# - the one called "@oName@" by 'outFileName'.
# To skip either 'inpFileName' or 'outFileName', provide appropriate arg as "".
# Returns number of substitutions performed or -1 on error.
#### Usage sample:
# % set argList {a @iName@ b @oName@ c}
# % ::ok_utils::ok_insert_io_filenames_into_list argList INAME ONAME
# % puts $argList
# a INAME b ONAME c
###################
proc ::ok_utils::ok_insert_io_filenames_into_list {listVarName \
						   inpFileName outFileName} {
    # TODO: check that there are exactly 3 arguments
    upvar $listVarName theList
    if { [llength $theList] == 0 } {
	ok_err_msg "ok_insert_io_filenames_into_list{EmptyList $inpFileName $outFileName}"
	return  -1
    }
    set substCnt 0
    set iPos [lsearch -exact $theList "@iName@"]
    if { $iPos >= 0 } {
	set theList [lreplace $theList $iPos $iPos $inpFileName]
	incr substCnt 1
    } elseif { $inpFileName != "" } {
	ok_err_msg "ok_insert_io_filenames_into_list{$theList $inpFileName $outFileName}: no placeholder for input file name"
	return  -1
    }
    set oPos [lsearch -exact $theList "@oName@"]
    if { $oPos >= 0 } {
	set theList [lreplace $theList $oPos $oPos $outFileName]
	incr substCnt 1
    } elseif { $outFileName != "" } {
	ok_err_msg "ok_insert_io_filenames_into_list{$theList $inpFileName $outFileName}: no placeholder for output file name"
	return  -1
    }
    return  $substCnt
}

###################
# Replaces element named 'placeHolderName' of the list in 'listVarName'
# by 'nameToInsert'.
# Returns 1 if substitution performed, 0 otherwise. Throws exception on error.
proc ::ok_utils::ok_insert_name_into_list_at_placeholder { \
				listVarName nameToInsert placeHolderName} {
    upvar $listVarName theList
    if { [llength $theList] == 0 } {
	ok_err_msg "ok_insert_name_into_list_at_placeholder{EmptyList '$nameToInsert' '$placeHolderName'}"
	return  -code error
    }
    set substDone 0
    set pos [lsearch -exact $theList $placeHolderName]
    if { $pos >= 0 } {
	set theList [lreplace $theList $pos $pos $nameToInsert]
	set substDone 1
    } elseif { $nameToInsert != "" } {
	ok_trace_msg "(W) ok_insert_name_into_list_at_placeholder{'$theList' '$nameToInsert' '$placeHolderName'}: no placeholder found"
	return  0
    }
    return  $substDone
}


# Stores strings from 'theList' one-at-a-line in file 'fullPath'
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_write_list_into_file {theList fullPath {encode ""}} {
    set tclExecResult [catch {
	if { ![string equal $fullPath "stdout"] } {
	    set outF [open $fullPath w]
	} else {
	    set outF stdout
	}
        if { $encode != "" }  {
          fconfigure $outF -encoding $encode
        }
	foreach el $theList {    puts $outF $el	}
	if { ![string equal $fullPath "stdout"] } {    close $outF	}
    } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	return  0
    }
    return  1
}


# Reads strings one-at-a-line from file 'fullPath' into 'listVarName'
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_read_list_from_file {listVarName fullPath {encode ""}} {
  upvar $listVarName listVar
  return  [ok_read_commented_list_from_file listVar $fullPath "" $encode]
}


# Reads strings one-at-a-line from file 'fullPath' into 'listVarName'.
# If 'commentPrefOrNone' isn't empty, skips lines starting with it as comments.
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_read_commented_list_from_file {listVarName fullPath  \
                                                commentPrefOrEmpty {encode ""}} {
  upvar $listVarName theList
  set commentGlob [format "%s*" $commentPrefOrEmpty]
  set theList [list]
  set tclExecResult [catch {
    set inF [open $fullPath r]
    if { $encode != "" }  {
      fconfigure $inF -encoding $encode
    }
    while { [gets $inF line] >= 0 } {
      if { ($commentPrefOrEmpty == "") || ![string match $commentGlob $line]} {
        lappend theList $line
      }
    }
    close $inF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  return  1
}


# If a directory in 'absDirList' doesn't exist, creates it.
# Returns 0 if failed creating any of the directories.
proc ::ok_utils::ok_create_absdirs_in_list {absDirList {descrList 0}} {
  if { ($descrList != 0) && ([llength $absDirList] != [llength $descrList]) }  {
    ok_err_msg "Number of requested directories ([llength $absDirList]) differs from number of their descriptions ([llength $descrList])"
    return  0
  }
  for {set i 0} {$i < [llength $absDirList]} {incr i}  {
    set dir [lindex $absDirList $i]
    set descr [expr {($descrList != 0)? [lindex $descrList $i] : "requested"}]
    if { [file exists $dir] == 1 } {
      if { [file isdirectory $dir] == 0 } {
        ok_err_msg "$descr directory path '$dir' is not a directory!"
        return  0
      }
      ok_info_msg "$descr directory path '$dir' pre-existed"
      if { [file readable $dir] == 0 } {
        ok_err_msg "$descr directory path '$dir' is unreadable!"
        return  0
      }
    } else {
      # create the directory
      set tclExecResult [catch { file mkdir $dir } execResult]
      if { $tclExecResult != 0 } {
        ok_err_msg "$execResult!"
        ok_err_msg "Failed creating $descr directory '$dir'."
        return  0
      }
      ok_info_msg "Created $descr directory '$dir'."
    }
  }
  return  1
}


# Returns unique list of normalized absolute directory names
# that occur in 'fullPathList'
proc ::ok_utils::ok_get_abs_directories_from_filelist {fullPathList} {
    set dirList [list]
    foreach f $fullPathList {
	set dir [file normalize [file dirname $f]]
	lappend dirList $dir
    }
    set dirList [lsort -ascii -unique $dirList]
    return  $dirList
}


# Builds and returns list of purenames for fullpath-list 'fullPathList'.
# If 'loud' == 1, prints warning on pure-name dupplications.
proc ::ok_utils::ok_get_purenames_list_from_pathlist {fullPathList {loud 1}} {
    set fNameList [list]
    foreach f $fullPathList {
	set pureName [file tail $f]
	lappend fNameList $pureName
    }
    set numAll [llength $fNameList]
    set fNameListU [lsort -ascii -unique $fNameList]
    set numUniq [llength $fNameListU]
    if { [expr {$loud == 1} && {$numAll != $numUniq}] } {
	ok_warn_msg "ok_get_purenames_list_from_pathlist: there are [expr $numAll-$numUniq] pure-name dupplications in fullpath list {$fullPathList}"
    }
    return  $fNameListU
}


# [ok_override_list [list a b c d] [list "@-@" B "@-@" D]] -> [list a B c D]
# The lists should be of same length, otherwise returns ""
proc ::ok_utils::ok_override_list {origList ovrdList} {
    set sameKey "@-@"
    set leng1 [llength $origList]
    set leng2 [llength $ovrdList]
    if { $leng1 != $leng2 } {
	ok_err_msg "ok_override_list called on different length lists: '$origList' and '$ovrdList' ."
	return  ""
    }
    set resultList [list]
    set ind 0
    foreach el $ovrdList {
	# insert either override- or original list element
	if { $el != $sameKey } {
	    lappend resultList $el
	} else {
	    lappend resultList [lindex $origList $ind]
	}
	incr ind 1
    }
    return  $resultList
}

# [ok_rename_file_add_suffix "file1.jpg" "_N"] -> "file1_N.jpg"
proc ::ok_utils::ok_rename_file_add_suffix {inpFileName suffix} {
    if { ![file exists $inpFileName] } {
	ok_err_msg "ok_rename_file_add_suffix got inexistent filename '$inpFileName'"
	return  0
    }
    # check whether the suffix is already there
    set indOfSuffix [string first $suffix $inpFileName]
    if { $indOfSuffix != -1 } {
	# already renamed - do nothing
	ok_warn_msg "ok_rename_file_add_suffix skipps $inpFileName"
	return  1
    }
    set newFileName [ok_insert_suffix_into_filename $inpFileName $suffix]
    set tclExecResult [catch {
	file rename -- $inpFileName $newFileName } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed renaming image '$inpFileName' into '$newFileName'."
	return  0
    }
    return  1
}


# Safely copies 'inpFilePath' into 'destDirOrFilePath'
proc ::ok_utils::ok_safe_copy_file {inpFilePath destDirOrFilePath} {
  set tclExecResult [catch {
    file copy -force -- $inpFilePath $destDirOrFilePath } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed copying image '$inpFilePath' into '$destDirOrFilePath'."
    return  0
  }
  return  1
}


# Safely copies 'inpFilePath' into 'destDir' unless it already exists there
proc ::ok_utils::ok_copy_file_if_target_inexistent {inpFilePath destDir\
                                                 {complainIfTargetExists 1}} {
  if { $complainIfTargetExists == 0 } {
    set targetPath [file join $destDir [file tail $inpFilePath]]
    if { [file exists $targetPath] }  { return 1 };  # considered OK
  }
  set tclExecResult [catch {
	file copy -- $inpFilePath $destDir } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed copying image '$inpFilePath' into '$destDir'."
	return  0
    }
    return  1
}

# Safely moves 'inpFileName' into 'destDir' unless it already exists there
proc ::ok_utils::ok_move_file_if_target_inexistent {inpFilePath destDir \
                                                 {complainIfTargetExists 1}} {
  if { $complainIfTargetExists == 0 } {
    set targetPath [file join $destDir [file tail $inpFilePath]]
    if { [file exists $targetPath] }  { return 1 };  # considered OK
  }
  set tclExecResult [catch {
	file rename -- $inpFilePath $destDir } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed moving image '$inpFilePath' into '$destDir'."
	return  0
    }
    return  1
}

# Returns 1 if 'fullPath' is writable to the current user as a regular file
proc ::ok_utils::ok_filepath_is_writable { fullPath } {
    if { $fullPath == "" } {	return  0    }
    if { [file isdirectory $fullPath] } {	return  0    }
    set dirPath [file dirname $fullPath]
    if { ![file exists $dirPath] } {	return  0    }
    if { [expr {[file exists $fullPath]} && {[file writable $fullPath]==0}] } {
	return  0
    }
    return  1
}


# Returns 1 if 'fullPath' is readable to the current user as a regular file
proc ::ok_utils::ok_filepath_is_readable { fullPath } {
    if { $fullPath == "" } {	return  0    }
    if { [file isdirectory $fullPath] } {	return  0    }
    set dirPath [file dirname $fullPath]
    if { ![file exists $dirPath] } {	return  0    }
    if { [expr {[file exists $fullPath]} && {[file readable $fullPath]==0}] } {
	return  0
    }
    return  1
}


proc ::ok_utils::ok_filepath_is_existent_dir {fullPath} {
  return  [expr {([file exists $fullPath]) && ([file isdirectory $fullPath])}]
}


proc ::ok_utils::ok_filepath_is_readable_dir {fullPath} {
  return  [expr {[file exists $fullPath] && [file isdirectory $fullPath] &&  \
                                            [file readable $fullPath]}]
}

proc ::ok_utils::ok_filepath_is_writable_dir {fullPath} {
  return  [expr {[file exists $fullPath] && [file isdirectory $fullPath] &&  \
                                            [file writable $fullPath]}]
}


# Replaces both native- and TCL-style separators with "." (match any)
proc ::ok_utils::ok_format_filepath_for_regexp {filePath} {
  set sepList [list "/" "."  [file separator] "."]
  set filePathForRegexp [string map $sepList $filePath]
  return  $filePathForRegexp
}


# Safely deletes 'filePath'
proc ::ok_utils::ok_delete_file {filePath} {
    set tclExecResult [catch {
	file delete -- $filePath } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed deleting file '$filePath'."
	return  0
    }
    return  1
}


# Safely deletes directory 'dirPath'
proc ::ok_utils::ok_force_delete_dir {dirPath} {
    set tclExecResult [catch {
	file delete -force -- $dirPath } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed deleting directory '$dirPath'."
	return  0
    }
    return  1
}


# Safely creates directory 'dirPath'
proc ::ok_utils::ok_mkdir {dirPath} {
    ok_assert {{$dirPath != ""}} ""
    if { [file exists $dirPath] && [file isdirectory $dirPath] } {
	return  1
    }
    set tclExecResult [catch {file mkdir $dirPath} execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	ok_err_msg "Failed creating directory '$dirPath'."
	return  0
    }
    return  1
}

# Returns 1 if (file or directory) 'loPath' located under directory 'hiPath'
proc ::ok_utils::ok_is_underlying_filepath {loPath hiPath} {
    set loPathN [file normalize $loPath]
    set hiPathN [file normalize $hiPath]
    ok_assert {(0 == [file exists $hiPath]) || ([file isdirectory $hiPath])} ""
    # is 'hiPathN' a prefix for 'loPathN'?
    if { 0 != [string first $hiPathN $loPathN] } {
	return  0
    } else {
	return  1
    }
}


proc ::ok_utils::ok_dirpath_equal {dirPath1 dirPath2} {
  set p1N [file normalize $dirPath1]
  set p2N [file normalize $dirPath2]
  return  [string equal $p1N $p2N]
}


proc ::ok_utils::ok_find_filepaths_common_prefix {pathList}  {
  set normPathList [list]
  foreach p $pathList { lappend normPathList [file normalize $p] }
  set normPathList [lsort -unique $normPathList]
  set listOfComponentLists [list] ;  # list of lists of path components
  set minCompNum 999999 ;   # for min num of path components among 'pathList'
  foreach onePath $normPathList {
    set components [file split $onePath]
    if { 0 == [set lng [llength $components]] }  {
      ok_err_msg "Empty/invalid path string '$onePath'"
      return  ""
    }
    lappend listOfComponentLists $components
    if { $minCompNum > $lng } { set minCompNum $lng }
  }
  ok_trace_msg "Start searching for common prefix in {$normPathList}"
  set prefixList [list];  # will contain ordered list of path components
  for {set i 0} {$i < $lng} {incr i 1}  {
    set currComponent [lindex [lindex $listOfComponentLists 0] $i]; # [i] of 1st path
    set matchEnded 0
    foreach onePathCompList [lrange $listOfComponentLists 1 end] {
      set componentToCheck [lindex $onePathCompList $i]
      if { $currComponent != $componentToCheck }  {
        ok_trace_msg "Prefix match ended at '$currComponent' vs '$componentToCheck' in {$onePathCompList}"
        ok_trace_msg "List of matched prefix components: {$prefixList}"
        set matchEnded 1;   break
      }
    }
    if { ! $matchEnded } {
      lappend prefixList $currComponent
      ok_trace_msg "Prefix match continues at '$currComponent'"   
    }
  }
  ok_trace_msg "Done  searching for common prefix in {$normPathList}"
  if { 0 == [llength $prefixList] }  {
    ok_trace_msg "No common prefix found in {$pathList}";    return  ""
  }
  set prefix ""
  foreach component $prefixList { set prefix [file join $prefix $component] }
  ok_trace_msg "Common prefix '$prefix' found in {$pathList}"
  return  $prefix
}


# If a listed filePath lies under 'pathPrefix' directory, 
#   includes in the returned list path equivalent to 'filePath'
#   that's relative to 'pathPrefix'; otherwise includes the original path.
# If 'postProcCallbackOrZero', applies it to list of components of each path.
proc ::ok_utils::ok_strip_prefix_from_filepaths_in_list {pathList dirPathPrefix \
                                                   {postProcCallbackOrZero 0}}  {
  return  [lmap p $pathList  \
       {ok_strip_prefix_from_filepath $p $dirPathPrefix $postProcCallbackOrZero}]
}


# If 'filePath' lies under 'pathPrefix' directory,
#   returns path equivalent to 'filePath' that's relative to 'pathPrefix'.
# Otherwise returns 'filePath'.
# if 'postProcCallbackOrZero', applies it to list of components
# Implementation borrowed from http://wiki.tcl.tk/15925
proc ::ok_utils::ok_strip_prefix_from_filepath {filePath dirPathPrefix \
                          {postProcCallbackOrZero 0}}  {
  #ok_trace_msg "Try to strip '$dirPathPrefix' from '$filePath'"
  set cc [file split [file normalize $dirPathPrefix]]
  set tt [file split [file normalize $filePath]]
  if { 0 == [ok_is_underlying_filepath $filePath $dirPathPrefix] }  {
    if { $postProcCallbackOrZero != 0 }  {
      set tt [eval [list $postProcCallbackOrZero $tt]]
    }
    return  [eval file join $tt]
  }
  # the following check could be redundant; just copied from original
  if {![string equal [lindex $cc 0] [lindex $tt 0]]} {
      # not on *n*x then - ("$filePath not on same volume as $dirPathPrefix")
      return  $filePath
  }
  while {[string equal [lindex $cc 0] [lindex $tt 0]] && [llength $cc] > 0} {
      # discard matching components from the front
      set cc [lreplace $cc 0 0]
      set tt [lreplace $tt 0 0]
  }
  set prefix ""
  # The below code in the original guaranteed path relative to current directory
  # In our case te prefix should have been fully included, so [llength $cc] == 0
##   if {[llength $cc] == 0} {
 #       # just the file name, so filePath is lower down (or in same place)
 #       set prefix "."
 #   }
 #   # step up the tree
 #   for {set i 0} {$i < [llength $cc]} {incr i} {
 #       append prefix " .."
 #   }
 ##
  if { 0 != [llength $cc] } {
    set msg "Error making relative path from {'$filePath' '$dirPathPrefix'}"
    ok_err_msg "$msg";  return -code error $msg
  }

  # process 1st component; it is either 'prefix' or the 1st element of 'tt'
  if { $postProcCallbackOrZero != 0 }  {
    if { $prefix != "" } {
      ok_trace_msg "Postrprocessing path prefix '$prefix'"
      set prefix [eval [list $postProcCallbackOrZero $prefix]]
    } else {
      ok_trace_msg "Postrprocessing path components {$tt}"
      set tt [eval [list $postProcCallbackOrZero $tt]]
    }
  }
  
  # stick it all together (the eval is to flatten the filePath list)
  return [eval file join $prefix $tt]
}


# Returns 1st 'nFirstToKeep' and 'nLastToKeep' lines from 'inpMultilineText'
# On error returns 0.
proc ::ok_utils::ok_truncate_text {inpMultilineText nFirstToKeep nLastToKeep} {
  if { ($nFirstToKeep < 0) || ($nLastToKeep < 0) }  {
    ok_err_msg "ok_truncate_text: negative count(s) - first($nFirstToKeep), last($nLastToKeep)"
    return  0
  }
  set crIdxPairs [regexp -inline -all -indices "\n" $inpMultilineText]
  set nLines [llength $crIdxPairs]
  # find newline #nFirstToKeep from the beginning
  if {        $nFirstToKeep == 0 }  {
    set startCutFrom 0
  } elseif {  $nFirstToKeep < $nLines }  {
    set startCutFrom [expr 1 + \
                        [lindex [lindex $crIdxPairs [expr $nFirstToKeep-1]] 0]]
  } else {
    set startCutFrom end
  }
  # find newline #nLastToKeep from the end
  #TODO: fix last index
  if { $nLastToKeep == 0 }  {
    set lastI end;  set stopCutAt end
  } elseif { $nLastToKeep < $nLines }  {
    set lastI [expr {[llength $crIdxPairs] - $nLastToKeep}]
    set stopCutAt  [expr 0 + [lindex [lindex $crIdxPairs $lastI] 0]]
  } else {
    set lastI 0;  set stopCutAt 0
  }
  set replText [format  \
                    "\n  ... ... ... ... ~ %d line(s) cut ... ... ... ...\n\n" \
                    [expr $nLines - $nFirstToKeep - $nLastToKeep + 1]] 
  ok_trace_msg "crIdxPairs={$crIdxPairs}; lastI=$lastI; stopCutAt=$stopCutAt"
  ok_trace_msg "Cutting: 0...($startCutFrom...$stopCutAt)...[expr {[string length $inpMultilineText]-1}]"
  set res [expr {($startCutFrom < $stopCutAt)?                                \
              [string replace $inpMultilineText $startCutFrom $stopCutAt $replText]  \
              : $inpMultilineText}]
  return  $res
}


proc ::ok_utils::ok_validate_string_by_given_format {formatSpec str} {
  ok_trace_msg "formatSpec='$formatSpec' str='$str'"
  if { $formatSpec == "%s" }  { return  1 };   # any string allowed
  if { $str == "" }  { return  1 }; # empty string allowed not to disturb edit-s
  if { $str == "-" }  { return  1 }; # minus sign allowed for typing negatives
  if { 1 == [scan [string trim $str] "$formatSpec%c" val leftover] }  {
    return  1
  } else  { return  0 }
}


# Determins whether 'value' is numeric,
# including integers expressed in decimal or hexadecimal, and real numbers
# (from: http://wiki.tcl.tk/10166#pagetoc2f716841)
proc ::ok_utils::ok_isnumeric {value} {
    if {![catch {expr {abs($value)}}]} {
        return 1
    }
    set value [string trimleft $value 0]
    if {![catch {expr {abs($value)}}]} {
        return 1
    }
    return 0
}

# Builds and returns an ordered list of run-time arguments
# for (existing!) procedure 'procName'
# out of argument-spec array 'swArgArr' that maps argument name to its value.
# 'procName' Should be fully qualified.
# Exits on error.
# Example:
# Run> proc try_args {a1 {a2 a2Def}} {puts "a1='$a1', a2='$a2'"}
# Run> array unset argsArray;  array set argsArray {-a1 a1Val -a2 a2Val}
# Run> ::ok_utils::ok_arrange_proc_args ::try_args argsArray
# Run> a1Val a2Val
# Run> array unset argsArray;  array set argsArray {-a1 a1Val}
# Run> ::ok_utils::ok_arrange_proc_args ::try_args argsArray
# Run> a1Val a2Def
proc ::ok_utils::ok_arrange_proc_args {procName swArgArr} {
    upvar $swArgArr swArgs
    ok_assert {[llength [info procs $procName]] != 0} \
	"ok_arrange_proc_args called for inexistent procedure '$procName'"
    set errCnt 0
    # browse arguments of 'procName' and look for value of each in 'swArgs'
    set allArgs [info args $procName]
    set procArgValList [list]
    foreach argName $allArgs {
	set hasDefault [info default $procName $argName defVal]
	if { $hasDefault } {    set argVal $defVal
	} else {	        set argVal ""	}
	set keyInArray "-$argName"
	if { [ok_name_in_array $keyInArray swArgs] } {
	    set argVal $swArgs($keyInArray)
	} elseif { 0 == $hasDefault } {
	    ok_err_msg \
		"ok_arrange_proc_args '$procName': no value for '$argName'"
	    incr errCnt
	}
	lappend procArgValList $argVal
    }
    if { $errCnt > 0 } {
	ok_err_msg \
	 "ok_arrange_proc_args '$procName' failed defining $errCnt argument(s)"
	return  -code error
    }
    return  $procArgValList
}


# Builds and returns argument spec for procedure 'procName'.
# Format: {{-arg1_name [arg1_defVal]} {-arg2_name [arg2_defVal]} ... } 
proc ::ok_utils::ok_make_argspec_for_proc {procName} {
    ok_assert {[llength [info procs $procName]] != 0} \
	"ok_make_argspec_for_proc called for inexistent procedure '$procName'"
    set argSpec [list]
    set allArgs [info args $procName]
    foreach argName $allArgs {
	set argAndVal [list "-$argName"]
	set hasDefault [info default $procName $argName defVal]
	if { $hasDefault } {    lappend argAndVal $defVal
	} else {	        lappend argAndVal ""	}
	lappend argSpec $argAndVal
    }
    return  $argSpec
}



# This approach isn't debugged - variables not seen inside 'scriptToExec' scope
proc ::ok_utils::ok_exec_under_catch {scriptToExec scriptResult} {
    upvar $scriptResult result
    set tclExecResult [catch {set result [eval $scriptToExec]} execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	return  0
    }
    return  1
}


# Safely runs OS command 'cmdList' that doesn't print output
# if there are no errors.
# Returns 1 on success, 0 on error.
# This proc did not appear in LazyConv.
proc ::ok_utils::ok_run_silent_os_cmd {cmdList {context ""}}  {
	#ok_pri_list_as_list [concat "(TMP--next-cmd-to-exec==)" $cmdList]
  set tclExecResult [catch {    set result [eval exec $cmdList]
    #if { 1 == [ok_loud_mode] } {	    flush $logFile	}
    if { $result == 0 }  { return 0 } ;  # error already printed
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed executing command: '$cmdList'.";
    set msgPref [expr {($context != "")? "Failed $context: " : ""}]
    ok_err_msg "${msgPref}$evalExecResult!"
    return  0
  }
  return  1
}


# Safely runs OS command 'cmdList' that does print output, maybe meaningful.
# 'outputCheckCB' callback should return 1 on no errors in output, 0 otherwise.
# Returns 1 on success, 0 on error.
# This proc did not appear in LazyConv.
proc ::ok_utils::ok_run_loud_os_cmd {cmdList outputCheckCB}  {
	#ok_pri_list_as_list [concat "(TMP--next-cmd-to-exec==)" $cmdList]
  set tclExecResult1 [catch { set result [eval exec $cmdList] } cmdExecResult]
  # $tclExecResult1 != 0 since the command is expected to print output
  set tclExecResult2 [catch {
    if { 0 == [$outputCheckCB $cmdExecResult] } {
      #cmdExecResult tells how cmd ended
      ok_err_msg "'$cmdExecResult'"
      return  0
    } else { ok_trace_msg "$cmdExecResult!" }
  } chkExecResult]
  if { $tclExecResult2 != 0 } {
    ok_err_msg "Failed running '$outputCheckCB' to verify result of command: '$cmdList'.";
    ok_err_msg "$chkExecResult!"
    return  0
  }
  return  1
}


proc ::ok_utils::ok_detect_os_type {}  {
  set OS [lindex $::tcl_platform(os) 0]
  if { $OS == "Linux" } {
    return  "LINUX"
  } elseif { $OS == "Windows" } {
    return  "WINDOWS"
  } else {
    return  "UNKNOWN"
  }
}


proc ::ok_utils::ok_get_file_timestamp_format {} {return "%Y-%m-%d_%H-%M-%S"}


proc ::ok_utils::ok_seconds_to_timestamp {globalTimeSec}  {
  set timeStr [clock format  $globalTimeSec  \
                                    -format [ok_get_file_timestamp_format]]
  return  $timeStr
}


proc ::ok_utils::ok_timestamp_to_seconds {timeStampStr}  {
  set formatStr [ok_get_file_timestamp_format]
  set tclExecResult [catch {
    set globalTimeSec  [clock scan $timeStampStr -format $formatStr]
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Timestamp '$timeStampStr' doesn't match '$formatStr': $evalExecResult!"
    return  -1
  }
  return  $globalTimeSec
}


proc ::ok_utils::ok_format_current_timestamp {}  {
  set tSec [clock seconds]
  return  [ok_seconds_to_timestamp $tSec]
}


# Adapted from: https://rosettacode.org/wiki/Check_input_device_is_a_terminal#Tcl
## TODO: check concerns about Windows from: https://stackoverflow.com/questions/43660612/how-to-check-if-stdin-stdout-are-connected-to-a-terminal-in-tcl
proc ::ok_utils::ok_is_tty_available {}  {
  if {[catch {fconfigure stdin -mode}]} {
    ok_info_msg "Input doesn't come from tty."
    return  0
  } else {
    ok_info_msg "Input comes from tty."
    return  1
  }
}


#~ proc ::ok_utils::ok_abort_if_key_pressed {singleKeyCharNoModofier}  {
  #~ # Enable non-blocking mode
  #~ fconfigure stdin -blocking 0
  #~ for {set i 1}  {$i <= 5}  {incr i 1}  {
    #~ puts "...... ok_abort_if_key_pressed - at $i ......."
    #~ if { [gets stdin] == $singleKeyCharNoModofier }   {
      #~ set msg "-I- -/-/-/-/- User commanded to abort the script -/-/-/-/"
      #~ puts "[_ok_callstack]"
      #~ fconfigure stdin -blocking 1; # Set it back to normal
      #~ error $msg
    #~ }
    #~ after 100;           # Slow the loop down!
  #~ }

  #~ # Set it back to normal
  #~ fconfigure stdin -blocking 1
#~ }


# Proc callstack copied from: https://wiki.tcl-lang.org/page/List+the+call+stack
proc _ok_callstack {} {
    set stack [list "Stacktrace:"]

    for {set i 1} {$i < [info level]} {incr i} {
        set level [info level -$i]
        set frame [info frame -$i]

        if {[dict exists $frame proc]} {
            set pname [dict get $frame proc]
            set pargs [lrange $level 1 end]
            lappend stack " - $pname"
            foreach arg $pargs {
                lappend stack "   * $arg"
            }
        } else {
            lappend stack " - **unknown stack item**: $level $frame"
        }
    }

    return [join $stack "\n"]
}
