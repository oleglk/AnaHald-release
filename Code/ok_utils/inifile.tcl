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

# ok_inifile.tcl

set UTIL_DIR [file dirname [info script]]
source [file join $UTIL_DIR "common.tcl"]

namespace eval ::ok_utils:: {

  variable _INI_FILE_KEY_FIELD_NAME      "lINEhDRfLd"
  variable _INI_FILE_IGNORE_EMPTY_LINES  1

  
  namespace export               \
    ini_list_to_ini_arr          \
    ini_arr_to_ini_list          \
    ini_file_to_ini_arr          \
    ini_arr_to_ini_file          \
    ini_key_parse                \
    summarize_ini_files_section  \
}



# Converts 'iniList' into array representation in 'iniArrVarName'.
# 'iniList' format exactly matches the Irfanview INI file:
#    <section1>, <option11>=<val11>, <option12>=<val12>,
#    <section2>, <option21>=<val21>, ... ,
# array representation format:
#   (-<section1>__<option11>) ={<val11>}, (-<section1>__<option12>) ={<val12>},
#   (-<section2>__<option21>) ={<val21>}, ... ,
# Returns 1 on success, 0 on error.
# Example:
#   ::ok_utils::ini_list_to_ini_arr {{[sec1]} {opt11=val11} {opt12=val12} {[sec2]} {opt21=val21}} tryOptArr
proc ::ok_utils::ini_list_to_ini_arr {iniList iniArrVarName {ignoreEmpty 0}} {
  upvar $iniArrVarName iniArr
  set errCnt 0;  set lineNo 0;  set recNo 0
  array unset iniArr
  if { 0 == [llength $iniList] } {	return  1    }; # no options is legal
  set section ""
  foreach elem $iniList {
    incr lineNo 1
    if { $ignoreEmpty && ("" == [string trim $elem]) }  { continue}; # skip empty
    incr recNo 1
    if { 1 == [regexp {\[.*\]} $elem] } { ; # it's a section name
      set section $elem
    } else { ; # it should be "option=val" or "option="
      set opt "";	    set val ""
      if { 0 == [regexp {([^=]+)=([^=]*)} $elem full opt val] } {
        puts "-E- Invalid record '$elem' (#$recNo/$lineNo) in ini-file options list"
        incr errCnt;	continue
      }
      set key "-$section";   append key "__$opt";   set iniArr($key) $val
    }
  }
  return  [expr {$errCnt == 0}]
}


# Converts array 'iniArrVarName' into list representation in 'iniListVar'.
# array representation format:
#    (<section1>__<option11>) ={<val11>}, (<section1>__<option12>) ={<val12>},
#    (<section2>__<option21>) ={<val21>}, ... ,
# 'iniListVar' format exactly matches the Irfanview INI file:
#    <section1>, <option11>=<val11>, <option12>=<val12>,
#    <section2>, <option21>=<val21>, ... ,
# Returns 1 on success, 0 on error.
# Example:
#   array set tryOptArr {{[sec1]__opt12} val12 {[sec2]__opt21} val21 {[sec1]__opt11} val11};  ::ok_utils::ini_arr_to_ini_list tryOptArr tryOptList
proc ::ok_utils::ini_arr_to_ini_list {iniArrVarName iniListVar} {
  upvar $iniArrVarName iniArr
  upvar $iniListVar iniList
  if { ! [array exists iniArr] }  {
    puts "-E- Inexistent ini-settings array"
    return  0
  }
  set errCnt 0
  set iniList [list];    set section "";    set prevSect "";    set option ""
  set keys [lsort [array names iniArr]];    # guarantee groupping by sections
  foreach key $keys { ;	# key should be "<section>__<option>"
    if { 0 == [regexp {\-(.+)__(.+)} $key full section option] } {
      puts "-E- Invalid key '$key' in the option list"
      incr errCnt;	continue
    }
    if { 0 == [string equal $prevSect $section] } { ; #start of new section
      lappend iniList $section;    set prevSect $section
    }
    lappend iniList "$option=$iniArr($key)"
  }
  return  [expr {$errCnt == 0}]
}


proc ::ok_utils::ini_file_to_ini_arr {iniFile iniArrVarName {failIfNoFile 0}} {
  variable _INI_FILE_IGNORE_EMPTY_LINES
  upvar $iniArrVarName iniArr
  set errCnt 0
  array unset iniArr
  if { [file exists $iniFile] } {
    if { 0 == [ok_read_list_from_file iniList $iniFile] } {
      puts "-E- Failed reading ini-file '$iniFile'"
      return  0
    }
  } else {
    set iniList [list]
    if { !$failIfNoFile }  {
      puts "-W- Inexistent ini-file '$iniFile'"
    } else {
      puts "-E- Inexistent ini-file '$iniFile'"
      return  0
    }
  }
  # 'iniArr' <- pre-existing options
  if { 0 == [ini_list_to_ini_arr $iniList iniArr  \
                                 $_INI_FILE_IGNORE_EMPTY_LINES] } {
    puts "-E- Failed recognizing options read from '$iniFile'"
    return  0
  }
  # puts ">>> Options read from '$iniFile':";  pri_arr iniArr
  return  1
}


# Creates .ini file for Irfanview in directory 'iniDir'.
# 'optionsList' looks like:
#  -<section_name>__<option_name> <val>
#  ...
#  -<section_name>__<option_name> <val>
# The 'optionsList' is not necessarily sorted.
# Irfanview .ini file looks like: TODO
# Returns 1 on success, 0 on error.
# Example (irfanview):
#   array unset newArr;  array set newArr {{-[Copy-Move]__CopyDir1} e:/tcl/Work/Run/ {-[Copy-Move]__MoveDir1} e:/tcl/Work/Run/};   ok_utils::ini_arr_to_ini_file  newArr  D:/DC_TMP/TRY_AUTO/SPM_SETTINGS/try1.ini  1
proc ::ok_utils::ini_arr_to_ini_file {newOptArrVarName iniFile dropOld} {
  upvar $newOptArrVarName newOptArr
  if { [file exists $iniFile] && ![file writable $iniFile] }  {
    puts "-E- Cannot write into file '$iniFile'"
    return  0
  }
  set iniDir [file dirname $iniFile]
  if { ! ([file exists $iniDir] && [file writable $iniDir]) }  {
    puts "-E- Cannot write into directory '$iniDir'"
    return  0
  }
  if { ![file exists $iniDir] } {
    if { ![file writable [file dirname $iniDir]] }  {
      puts "-E- Parent directory of '$iniDir' is unwritable"
      return  0
    }
    if { 0 == [ok_mkdir $iniDir] } {
      puts "-E- Failed creating ini-file directory '$iniDir'"
      return  0
    }
  }
  # at this point we have existing writable directory 'iniDir'
  if { !$dropOld && ([file exists $iniFile]) } {
    if { 0 == [ok_read_list_from_file iniList $iniFile] } {
      puts "-E- Failed reading ini-file '$iniFile'"
      return  0
    }
  } else {	set iniList [list]    };  # no pre-existing options or commanded to drop
  # 'iniArr' <- pre-existing options; 'newOptArr' <- new options ('optionsList')
  array unset iniArr
  if { 0 == [ini_list_to_ini_arr $iniList iniArr 0] } {
    puts "-E- Failed recognizing options read from '$iniFile'"
    return  0
  }
  puts ">>> Options read from '$iniFile':";  pri_arr iniArr
  puts ">>> New options:";  pri_arr newOptArr
  # insert new options or override existing
  foreach optName [array names newOptArr] {
    set iniArr($optName) $newOptArr($optName)
  }
  # puts ">>> Resulting options:"; pri_arr iniArr
  if { 0 == [ini_arr_to_ini_list iniArr iniList] } {
    puts "-E- Failed formatting resulting INI options {[array get iniArr]}"
    return  0
  }
  if { [llength $iniList] <= 0 }  {
    puts "-E- No options assembled"
    return  0
  }
  puts "-D- Options to be written into '$iniFile': {$iniList}"
  if { 0 == [ok_write_list_into_file $iniList $iniFile] } {
    puts "-E- Failed writting ini-file '$iniFile'"
    return  0
  }
  puts "-I- ini-file written into '$iniFile'"
  return  1
}


proc ::ok_utils::ini_key_parse {iniKey sectionName optionName}  {
  upvar $sectionName section
  upvar $optionName  option
  if { 0 == [regexp {\-(.+)__(.+)} $iniKey full sec opt] } {
    puts "-E- Invalid key '$iniKey' in the option list"
    return  0
  }
  set section $sec
  set option  $opt
  return  1
}


# Puts into 'summaryTableListVar' a list of formatted summary-table lines
#    for files in 'filePathList'.
# Returns 1 on success, 0 on error.
## Example-01:  summarize_ini_files_section  {CFG/rma_ba02.ini CFG/rma_ba06.ini}  {[Original_User_Specified]}  5  "|"  0  tableLines;  foreach x $tableLines {puts "$x"}
## Example-02:  summarize_ini_files_section  [glob -nocomplain {CFG/rma_*.ini}]  {[Original_User_Specified]}  5  "|"  0  tableLines;  foreach x $tableLines {puts "$x"}
## Example-03:  summarize_ini_files_section  [glob -nocomplain {CFG/*.ini}]  {[Original_User_Specified]}  5  "|"  {GreenToBlueBiasMultWhenMinor MinBndBalancedMajorToMaxMinorRatio MaxBalancedMajorToMaxMinorRatio}  tableLines;  foreach x $tableLines {puts "$x"}
proc ::ok_utils::summarize_ini_files_section {filePathList sectionName          \
             dataColumnWidth fldSeparator fldNamesOrZero summaryTableListVar}  {
  upvar $summaryTableListVar summaryList
  set summaryList [list]
  if { [llength $filePathList] < 1 }  {
    ok_warn_msg "No INI files to summarize provided"
    return  0
  }

  # determine the maximum filename length
  set allNameLen [lmap fPath $filePathList  \
		    {string length [file rootname [file tail $fPath]]}]
  set maxLen -1;  foreach l $allNameLen { if { $l > $maxLen } { set maxLen $l } }

  set hdrLines  0;  # will be a list; 0 tells it's not yet made
  set dataLines [list]
  set fldToLength 0;  # will be a dict-compatible list for data fields only
  foreach fPath $filePathList  {
    array unset arr;  # clen data from previous file
    if { ![ini_file_to_ini_arr $fPath arr 1] }  {
      return  0;  # error already printed
    }
    ok_trace_msg "Processing ini file '$fPath' - [array size arr] line(s); section: '$sectionName'"
    if { $hdrLines == 0 }  { ;  # header not built prior to 1st file processing
      # Take field names and assemble the header from given names or the 1st file
      if { $fldNamesOrZero != 0 }  {; # fieldnames given - build header from them
        # since actual keys taken from ini-arr, need to fake suitable array
        set keys $fldNamesOrZero
        _fake_ini_arr $sectionName $fldNamesOrZero arrForHdr
        # if { ![_ini_arr_to_section_field_names fakeHdrArr  "DUMMYsect"  keys] } {
        #   return  0;  # error already printed
        # }
      } else { ; # fieldnames not given - build header from the 1st file
        if { ![_ini_arr_to_section_field_names  arr  $sectionName  keys] }  {
          return  0;  # error already printed
        }
        array set arrForHdr [array get arr]
      }
      set fldToLength [split [join \
          [lmap key $keys {list $key $dataColumnWidth}] " "]]; # data fields only
      set fldToLengthInclKey [linsert $fldToLength 0  \
                                $ok_utils::_INI_FILE_KEY_FIELD_NAME  $maxLen]
      if { ![_ini_arr_to_section_header_lines arrForHdr  $sectionName  \
	       $fldToLengthInclKey  $fldSeparator  hdrLines] }   {
        return  0;  # error already printed
      }
    };#__done_with_header
    
    set fileId [file rootname [file tail $fPath]]
    if { ![_ini_arr_to_section_lines arr $fileId  $sectionName   \
	     $fldToLengthInclKey  $fldSeparator oneFileLines] }  {
      return  0;  # error already printed
    }
    lappend dataLines $oneFileLines; # appended element is list of one file lines
  }
  #lappend summaryList {*}$hdrLines {*}$dataLines
  set summaryList $hdrLines
  foreach dl $dataLines  { lappend summaryList {*}$dl }; # append line by line

  return  1
}


# Reads section into dict-compatible list 'subDictVar'
proc ::ok_utils::_ini_arr_to_section_subdict {arrName sectionName subDictVar}  {
  upvar $arrName arr
  upvar $subDictVar resList
  set resList [list]
  set nLines [array size arr]
  set lineCnt 0
  foreach iniKey [array names arr]  {  
    if { ![ini_key_parse $iniKey section option] }  {
      return  0;  # error already printed
    }
    #puts "@@ Section($iniKey) = '$section'"
    if { [string equal -nocase  $section $sectionName] }  {
      lappend resList  $option $arr($iniKey)
    }
  }
  return  1
}


## Example-01:  ini_file_to_ini_arr CFG/rma_ba02.ini INI 1;    ok_utils::_ini_arr_to_section_lines  INI  "rma_ba02"  {[Original_User_Specified]}  {"SmoothBndBalancedOption"  5}  "|"   lines
## Example-02:  ini_file_to_ini_arr CFG/rma_ba02.ini INI 1;    ok_utils::_ini_arr_to_section_lines  INI  "_very_long_file_name_"  {[Original_User_Specified]}  {"SmoothBndBalancedOption" 2  "MaxRgbVal" 5}  "|"   lines
## Example-03:  set SECT {[Original_User_Specified]};    ini_file_to_ini_arr CFG/rma_ba02.ini INI 1;    ok_utils::_ini_arr_to_section_field_names INI $SECT keys;    set fldToLength [split [join [lmap key $keys {list $key 7}] " "]];    ok_utils::_ini_arr_to_section_lines  INI  "rma_ba02"  $SECT  $fldToLength  "|"   lines
proc ::ok_utils::_ini_arr_to_section_lines {arrName fileIdOrEmpty sectionName  \
                                             fldNameToLengthInOrder            \
                                             fldSeparator linesListVar}        {
  upvar $arrName arr
  upvar $linesListVar resList
  variable _INI_FILE_KEY_FIELD_NAME
  set resList [list]
  set secDict [list];  # in reality it's a dict-compatible list
  set hasKeyField [dict exists $fldNameToLengthInOrder $_INI_FILE_KEY_FIELD_NAME]
  #puts "@@ (in _ini_arr_to_section_lines) hasKeyField=$hasKeyField;  fldNameToLengthInOrder={$fldNameToLengthInOrder};  ini-arr={[array get arr]}"
  if { (!$hasKeyField && ([dict size $fldNameToLengthInOrder] < 1)) ||  \
       ( $hasKeyField && ([dict size $fldNameToLengthInOrder] < 2))}  {
    puts "-E- Line format should include at least one data field"
    return  0
  }
  if { ![_ini_arr_to_section_subdict arr $sectionName secDict] }  {
    return  0;  # error already printed
  }
  if { $fileIdOrEmpty != "" }  {;  # enforce the header
    set secDict [linsert $secDict 0  \
		             $_INI_FILE_KEY_FIELD_NAME  $fileIdOrEmpty]
    if { !$hasKeyField }  {;  # provide default width for the key field
      set fldNameToLengthInOrder [linsert $fldNameToLengthInOrder 0  \
                                    $_INI_FILE_KEY_FIELD_NAME  20]
    }
    ok_trace_msg "Going to build line for {$fldNameToLengthInOrder} from {$secDict}"
  }
  # TODO: ?check key appearance?
  set lastFieldNameIdx [expr {[llength $fldNameToLengthInOrder] -1 -1}]; #n,l,n,l
  set lastLineEmpty 0;  # relying on override placed right after loop entered
  while { !$lastLineEmpty }  {
    set lastLineEmpty 1;  # ... unless otherwise proven
    set currLine "";  # collects whatever left to print for the current line
    for {set fI 0}  {$fI <= $lastFieldNameIdx}  {incr fI 2}  {
      set fldName [lindex $fldNameToLengthInOrder $fI]
      set  fldLen [lindex $fldNameToLengthInOrder [expr $fI + 1]]
      if { 0 != [string length $currLine] }  { append currLine $fldSeparator  }
      if { [dict exists $secDict $fldName] }  {
        set leftBefore [dict get $secDict $fldName]
      } else {
        set leftBefore "?";  # indicate the field is missing in the current file
      }
      set nLeft [string length $leftBefore]
      if { $nLeft == 0 }  { ;  # done with this field
        append currLine [string repeat " " $fldLen];  # fill slot with spaces
      } else {
        set lastLineEmpty 0
        set rangeLen    [expr {min($nLeft, $fldLen)}]
        set lastInRange [expr $rangeLen - 1]
        set rangeStr [string range $leftBefore 0 $lastInRange]
        append currLine [format {%*s} $fldLen $rangeStr]
        set leftAfter [string replace $leftBefore 0 $lastInRange ""];#delete pref
        dict set secDict $fldName $leftAfter
      }
    }
    if { !$lastLineEmpty }  { ;  # not only spaces
      lappend resList $currLine
    }
  }
  return  1
}


# Note, if ID required, it should appear in 'fldNameToLengthInOrder'
## Example-01:  set SECT {[Original_User_Specified]};    ini_file_to_ini_arr CFG/rma_ba02.ini INI 1;    ok_utils::_ini_arr_to_section_field_names INI $SECT keys;    set fldToLength [split [join [lmap key $keys {list $key 5}] " "]];    ok_utils::_ini_arr_to_section_header_lines  INI  $SECT  $fldToLength  "|"   lines
proc ::ok_utils::_ini_arr_to_section_header_lines {arrName sectionName          \
                                                     fldNameToLengthInOrder     \
                                                     fldSeparator linesListVar} {
  upvar $arrName arr
  upvar $linesListVar lines
  array unset keyToKeyArr;  # for fake array that maps field names to themselves
  foreach iniKey [array names arr]  {
    if { ![ini_key_parse $iniKey section option] }  {
      return  0;  # error already printed
    }
    set keyToKeyArr($iniKey) $option
  }
  set idFieldKey [format {-%s__%s}  \
		    $sectionName  $ok_utils::_INI_FILE_KEY_FIELD_NAME]
  set keyToKeyArr($idFieldKey) "-ID-";  # line ID field
  #puts "@@ Call to get header: _ini_arr_to_section_lines([array get keyToKeyArr])"
  return  [_ini_arr_to_section_lines keyToKeyArr "-ID-" $sectionName  \
             $fldNameToLengthInOrder $fldSeparator  lines]
}


## Example: ok_utils::_fake_ini_arr  "DUMMY"  {k1 k2 k3}  qqArr;  parray qqArr
proc ::ok_utils::_fake_ini_arr {sectionName fldNames arrName}  {
  upvar $arrName arr
  array unset arr
  set iniKeys [lmap fl $fldNames {format {-%s__%s} $sectionName $fl}]
  #array set arr [split [join [lmap iniKey $iniKeys {list $iniKey 88}]]]
  set tmpDict [dict create]
  foreach k $iniKeys v [lrepeat [llength $iniKeys] 88] {dict set tmpDict $k $v}
  array set arr $tmpDict
}


# Example:  ini_file_to_ini_arr c:/Oleg/GitWork/RMA/CFG/rma_ba02.ini INI 1;    ok_utils::_ini_arr_to_section_field_names  INI  {[Original_User_Specified]}  keys
proc ::ok_utils::_ini_arr_to_section_field_names {arrName sectionName  \
						    fldNamesListVar}   {
  upvar $arrName arr
  upvar $fldNamesListVar fldNamesList
  set fldNamesList [lmap  iniKey  [array names arr]  {
    expr {([ini_key_parse $iniKey section fldName] &&  \
	   [string equal -nocase  $section $sectionName])? $fldName : [continue]}
  }]
  if { [llength $fldNamesList] == 0 }  {
    puts "-E- No field names for section '$sectionName' found in ini-file array of [array size arr] record(s)"
    return  0
  }
  return  1
}


# proc ::ok_utils::_ini_arr_insert_header_section {inpArrName sectionName \
# 						    outArrName}  {
#   upvar $inpArrName inpArr
#   upvar $outArrName outArr
#   array unset outArr
#   set keyList TODO
# }
