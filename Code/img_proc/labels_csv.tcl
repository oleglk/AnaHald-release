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

# labels_csv.tcl
# Copyright (C) 2023 by Oleg Kosyakovsky


global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


# DO NOT for utils:  set SCRIPT_DIR [file dirname [info script]]
set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
source [file join $UTIL_DIR     "debug_utils.tcl"]
source [file join $UTIL_DIR     "common.tcl"]
#source [file join $UTIL_DIR     "csv_utils.tcl"]

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"
}


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
  variable LABEL_LIST_OF_TRIPLES_HEADER_PREFIX  "Txt1orEmpty"
  variable LABEL_MAP_HEADER_PREFIX              "MapFrom"
  
  namespace export                           \
  MAX_SUPPORTED_LABEL_LIST_OF_TRIPLES_WIDTH  \
  LABEL_LIST_OF_TRIPLES_HEADER_STR           \
  csv_to_label_list_of_triples               \
  label_list_of_triples_to_csv               \
  label_list_of_triples_ok                   \
  label_list_of_triples_width                \
  label_list_of_triples_csv_insert_empty     \
  label_list_of_triples_insert_empty         \
  label_list_of_triples_find_header          \
  label_list_of_triples_has_header           \
  label_list_of_triples_prepend_header       \
  label_list_of_triples_delete_header        \
  label_list_of_triples_element_is_header    \
  label_list_of_triples_element_is_comment   \
  label_list_of_triples_parse_one_label      \
  label_list_of_triples_override_one_triple_text         \
  label_list_of_triples_override_coordinates             \
  label_list_of_triples_check_mapped_sublabels_inclusion \
  label_list_of_triples_to_primary_label_occurences_map  \
  csv_to_labels_map                          \
  label_map_key_is_header                \
  convert_text_file_to_unicode               \
  convert_text_file_from_unicode             \
  repair_unicode_text_file                   \
  show_text_file_as_unicode                  \
  show_text_file_as_default                  \
}


#################################################################################
########## Begin:  Functions manipulating "label list of triples' ###############
#### e.g. - list of 3|4-element lists of lists of:
###### {label-text ("" if none),  xCoordPrc,  yCoordPrc}
#################################################################################


proc ::img_proc::MAX_SUPPORTED_LABEL_LIST_OF_TRIPLES_WIDTH {}  { return  4 }


proc ::img_proc::LABEL_LIST_OF_TRIPLES_HEADER_STR {numSubLabelsInLabel}  {
  set headerLst {Txt1orEmpty X1orZero Y1orZero Txt2orEmpty X2orZero Y2orZero Txt3orEmpty X3orZero Y3orZero Txt4orEmpty X4orZero Y4orZero}
  set maxWidth [img_proc::MAX_SUPPORTED_LABEL_LIST_OF_TRIPLES_WIDTH]
  if { ($numSubLabelsInLabel < 1) || ($numSubLabelsInLabel > $maxWidth) }  {
    error "Invalid num of sublabels $numSubLabelsInLabel; should be (1 ... $numSubLabelsInLabel)"
  }
  return  [lrange $headerLst  0  [expr 3 * $numSubLabelsInLabel - 1]]
}



# Reads and returns list of list of 3|4-element-list of triples
# with label-text and X/Y coordinate values from 'csvPath'.
#### e.g. - list of 3|4-element lists of lists of:
###### {label-text ("" if none),  xCoordPrc,  yCoordPrc}
# Invalid records are ignored.
# On fatal error returns 0.
## Example:  if {0 != [set qqL [img_proc::csv_to_label_list_of_triples OUT/exp_K400_2__ORIG__eng.csv cntBad]]} {foreach el $qqL {puts ":: $el"}} else {puts "ERROR"}
proc ::img_proc::csv_to_label_list_of_triples {csvPath cntInvalid}  {
  upvar $cntInvalid cntBad
  set rawList [list]
  if { 0 == [ok_read_list_from_file rawList $csvPath unicode] }  {
    return  0;  # error already printed
  }
  set numSublabelsInLabel -1; # for number of sublabels common for all lines
  set cntBad 0
  set firstLineWith3 -1;  # will hold index of the 1st 3-triple line
  set firstLineWith4 -1;  # will hold index of the 1st 4-triple line
  set labelsListFlat [list]
  foreach lineStr $rawList {
    set lineStr [string trim $lineStr]
    if { "#" == [string index $lineStr 0] }  { continue };  # comment or invalid
    ##puts $lineStr
    set lineLst [ok_split_string_by_whitespace $lineStr]
    # trailing " " causes empty element at end - ignore it
    lappend labelsListFlat [expr {("" == [lindex $lineLst end])?  \
                                          [lrange $lineLst 0 end-1] : $lineLst}]
  }
  ## {Txt1orEmpty X1orZero Y1orZero Txt2orEmpty X2orZero Y2orZero Txt3orEmpty X3orZero Y3orZero} {{"E_e"} 24 32 {""} 0 0 {""} 0 0} {{"0"} 76 19 {")"} 76 13 {""} 0 0} {{","} 67 77 {"<"} 71 70 {""} 0 0}
  
  set labelsListOfTriples [list];  # will group subelements in triples
  set cntBad 0
  set isHeader 1;  # the 1st non-comment line will be considered a header
  # j - group of 3|4 sublabels of one label
  for {set j 0}  {$j < [llength $labelsListFlat]}  {incr j 1}  {
    set subLabelsFlat [lindex $labelsListFlat $j];  # 3|4 sublabels
    set firstWordInLine [lindex $subLabelsFlat 0]
    if { [string match -nocase "#*" $firstWordInLine] }  {
      continue;  # comments are ignored
    }
    #ok_trace_msg "Label-group #$j = {$subLabelsFlat}"
    if { ([llength $subLabelsFlat] != 9) && ([llength $subLabelsFlat] != 12) }  {
      if { [llength $subLabelsFlat] > 0 }  {
        ok_err_msg "Invalid length of label-group #$j: {$subLabelsFlat}"
      } else {
        ok_err_msg "Zero length of label-group #$j - comes AFTER: {[lindex $labelsListFlat [expr $j-1]]}"
      }
      incr cntBad 1
      continue
    }
    set numSublabels [expr {int([llength $subLabelsFlat] / 3)}] ;  # 3|4
    if { ($numSublabels == 3) && ($firstLineWith3 < 0) }  {
      set firstLineWith3 $j; }
    if { ($numSublabels == 4) && ($firstLineWith4 < 0) }  {
      set firstLineWith4 $j
    }
    if { ($firstLineWith3 >= 0) && ($firstLineWith4 >= 0) }  {
      ok_err_msg "Inconsistent lengths of label-group between lines #$firstLineWith3 ([lindex $labelsListFlat $firstLineWith3]) and #$firstLineWith4 ([lindex $labelsListFlat $firstLineWith4]). Aborting."
      return  0
    }
    if { $isHeader }  {
      set numSublabelsInLabel $numSublabels
      ok_info_msg "Max number of sublabels per a label: $numSublabelsInLabel"
    }
    set subLabelsList [list]
    # {i, i+1, i+2} == {text, x, y} of one sublabel
    for {set i 0}  {$i < [llength $subLabelsFlat]}  {incr i 3}  {
      set subLabel [lrange $subLabelsFlat $i [expr $i + 2]]
      if { !$isHeader && (![string is integer [lindex $subLabel 1]] || \
                            ![string is integer [lindex $subLabel 2]]) }  {
        ok_err_msg "Invalid coordinate(s) in sublabel #$j:$i {$subLabel}"
        incr cntBad 1
        continue
      }
      # remove enclosing quotes, if any, from the label text
      set firstWordInLabel [lindex $subLabel 0]
      ##puts "@@ '$firstWordInLabel' starts '$subLabel'"
      if { [regexp -nocase "\".+\"" $firstWordInLabel] }  {
        set subLabel [lreplace $subLabel 0 0 \
                        [string range $firstWordInLabel 1 end-1]]
        # use "string range" instead of trim to protect quote char itself
      }
      if { $firstWordInLabel == {""} }  {;  # protect from literal "" string
        set subLabel [lreplace $subLabel 0 0 ""]
      }
      lappend subLabelsList $subLabel
    }
    lappend labelsListOfTriples $subLabelsList
    set isHeader 0;  # the 1st non-comment line was considered a header
  }
  set tripOrQuadStr [expr {($numSublabelsInLabel == 3)? "triple" : "quad"}]
  set descr "reading list of [llength $labelsListOfTriples] $tripOrQuadStr-label(s) (including header) from '$csvPath'; count of ignored invalid labels: $cntBad"
  if { ([llength $labelsListOfTriples] > 1) || \
       (([llength $labelsListOfTriples] == 1) && ($cntBad == 0)) }  {
    ok_info_msg "Done $descr"
    return  $labelsListOfTriples
  } else {
    ok_err_msg "Failed $descr"
    return  0
  }
}


# Writes list of list of 3|4-element-list of triples
# with label-text and X/Y coordinate values into 'csvPath'.
# Invalid records are printed as comments.
# Returns 1 on success, O on fatal error.
## Example 1: img_proc::label_list_of_triples_to_csv {{{"E" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}} TMP/try3.csv " "
## Example 2: img_proc::label_list_of_triples_to_csv {{{"E e" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}  {{"," 67 77} {"<" 71 70} {"" 0 0}} {{bad 2 3}}} TMP/bad31.csv " "
## Example 3: img_proc::label_list_of_triples_to_csv {{{"E e" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"BAD" 1 1} {"" 0 0}}  {{"," 67 77} {"<" 71 70} {"" 0 0}}} TMP/bad34.csv " "
## Example 4: img_proc::label_list_of_triples_to_csv {{{"E" 24 32} {"" 0 0} {"" 0 0} {"T41" 4 1}}  {{"0" 76 19} {")" 76 13} {"" 0 0} {"T42" 4 2}}} TMP/try4.csv " "
## Example 5: img_proc::label_list_of_triples_to_csv {{{"E" 24 32} {"" 0 0} {"" 0 0} {"T41" 4 1}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}} TMP/bad43.csv " "
# TODO: option to specify delimeter string!!!
proc ::img_proc::label_list_of_triples_to_csv {labelsListOfTriples csvPath \
                                                 {separator ","}}  {
  set txtFieldIndices {0 3 6}; #indices of Txt*orEmpty in nested per-label list

  # using custom implementation, since ok_list2csv fails at quotes
  if { 0 == [set numSublabelsInLabel \
               [label_list_of_triples_width $labelsListOfTriples]] }  {
    return  0;  # error already printed
  }
  
  if { ![img_proc::label_list_of_triples_has_header $labelsListOfTriples] }  {
    set headerLst {Txt1orEmpty X1orZero Y1orZero Txt2orEmpty X2orZero Y2orZero Txt3orEmpty X3orZero Y3orZero}
    if { $numSublabelsInLabel == 4 }  {
      append headerLst { Txt4orEmpty X4orZero Y4orZero}
      lappend  txtFieldIndices 9
    }
    set headerStr "[join $headerLst $separator]$separator"
    set flatListAsCSV [list $headerStr]
  } else {
    set flatListAsCSV [list]
  }

  set badLabelTriplesList [list];  # for indices of invalid labels
  img_proc::label_list_of_triples_ok $labelsListOfTriples badLabelTriplesList
  for {set j 0} {$j < [llength $labelsListOfTriples]} {incr j 1}  {
    set isBad [expr {\
                [lsearch -exact -integer -sorted $badLabelTriplesList $j] >= 0}]
    set sublabelsList [lindex $labelsListOfTriples $j];  # list of triples
    set flat [concat {*}$sublabelsList]
    if { ![label_list_of_triples_element_is_header $sublabelsList] }  {
      foreach i $txtFieldIndices  {
        set firstWordInLabel [lindex $flat $i]
        # ensure the text is enclosed in double-quotes
        set quoted [expr {([regexp -nocase "\".+\"" $firstWordInLabel])?  \
                          $firstWordInLabel : [format {"%s"} $firstWordInLabel]}]
        set flat [lreplace $flat $i $i $quoted]
      }
    }
    ##puts "@@ #$j ==> {$flat}"
    set commentIfBad [expr {($isBad)? "# " : ""}]
    # TODO: check if it would be OK to remove trailing separator (next line)
    lappend flatListAsCSV "$commentIfBad[join $flat $separator]$separator"
  }
  set descr "storing list of [llength $labelsListOfTriples] sublabel-lists in '$csvPath'; count of invalid labels: [llength $badLabelTriplesList]"
  set res [ok_write_list_into_file $flatListAsCSV $csvPath unicode]
  if { $res == 1 }  {
    ok_info_msg "Success $descr"
  } else {
    ok_err_msg "Failed $descr"
  }
  return  $res
}


# 'badLabelTriplesListRef' will hold list of bad label indices - including header
## Example (good1):  img_proc::label_list_of_triples_ok {{{"E" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}} badLabelIndices
## Example (good2):  img_proc::label_list_of_triples_ok {{{"E" 24 32} {"" 0 0} {"q" 1 2} {"" 0 0}}  {{"0" 76 19} {"w" 2 3} {")" 76 13} {"" 0 0}}} badLabelIndices
## Example (bad-1):  img_proc::label_list_of_triples_ok {{{"E" 24 32} {"" 0 0}         }  {{"0" 76 19} {")" 76 13} {"" 0 0}}} badLabelIndices
## Example (bad-2):  img_proc::label_list_of_triples_ok {{{"E" 24 32} {"" 0 0}         } {{"0" 777 76 19} {")" 76 13} {"" 0 0}}} badLabelIndices
## Example (bad3):  img_proc::label_list_of_triples_ok {{{"E" 24 32} {"" 0 0} {"q" 1 2} {"" 0 0}}  {{"0" 76 19}       {")" 76 13} {"" 0 0}}} badLabelIndices
proc ::img_proc::label_list_of_triples_ok {labelsListOfTriples \
                                            badLabelTriplesListRef}  {
  upvar $badLabelTriplesListRef badLabelTriplesList_j
  set badLabelTriplesList_j [list];  # j-s of invalid labels
  # the 1st record will fix expected number of sublabels
  set expNmOfSublabels [img_proc::label_list_of_triples_width \
                                                           $labelsListOfTriples]
  if { $expNmOfSublabels == 0 }  {
    lappend badLabelTriplesList_j 0;  # dummy - the error is fatal
    return  0;  # error already printed
  }
  for {set j 0}  {$j < [llength $labelsListOfTriples]}  {incr j 1}  {
    set sublabelsList [lindex $labelsListOfTriples $j]
    set firstWordInLine [lindex [lindex $sublabelsList 0] 0]
    if { [string match -nocase "#*" $firstWordInLine] }  { continue }; #comment
    # verify label structure
    set errorsInLabel [list]
    #puts "@Check '$sublabelsList' - length=[llength $sublabelsList]"
    if { [llength $sublabelsList] != $expNmOfSublabels }  {
      lappend errorsInLabel "Inconsistent number of sublabels in record {$sublabelsList} - should be $expNmOfSublabels"
    } else {
      foreach i {0 1 2}  { ;  # txt xPrc yPrc
        #puts "@@Check '[lindex $sublabelsList $i]' - length=[llength [lindex $sublabelsList $i]]"
        if { 3 != [llength [lindex $sublabelsList $i]] }  {
          lappend errorsInLabel "Invalid length of group #$i in sublabel-list record {$sublabelsList}"
        }
      }
    }
    if { 0 != [llength $errorsInLabel] }  {
      foreach err $errorsInLabel {
        ok_err_msg $err
      }
      lappend badLabelTriplesList_j $j
      continue
    }
  }
  return  [expr {0 == [llength $badLabelTriplesList_j]}]
}



# Determines and returns number of sublabels in 'labelsListOfTriples' - 3|4
## according to the 1st non-comment element.
# On error returns 0.
proc img_proc::label_list_of_triples_width {labelsListOfTriples}  {
  set numSubLabelsInLabel 0
  set tclExecResult [catch {
    for {set j 0}  {$j < [llength $labelsListOfTriples]}  {incr j 1}  {
      set sublabelsList [lindex $labelsListOfTriples $j]
      set firstWordInLine [lindex [lindex $sublabelsList 0] 0]
      if { [string match -nocase "#*" $firstWordInLine] }  { continue }; #comment
      # determine the 1st label structure
      set numSubLabelsInLabel [llength $sublabelsList]
      #puts "@Check '$sublabelsList' - length=[llength $sublabelsList]"
      if { ($numSubLabelsInLabel != 3) && ($numSubLabelsInLabel != 4) }  {
        ok_err_msg "Invalid number of sublabels ($numSubLabelsInLabel); should be 3 or 4"
        set numSubLabelsInLabel 0;  # zero indicates error
      }
      break
    }
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failure in label_list_of_triples_width: $evalExecResult!"
    return  0
  }
  return  $numSubLabelsInLabel
}


proc ::img_proc::label_list_of_triples_csv_insert_empty {inpCsvPath outCsvPath  \
                                             indexOrEnd {numToInsertOrNeg -1}}  {
  set inpLabelsListOfTriples [csv_to_label_list_of_triples $inpCsvPath cntBad]
  if { $inpLabelsListOfTriples == 0 }  { return  0 };  # error already printed
  set oldWidth [label_list_of_triples_width $inpLabelsListOfTriples]
  if { $oldWidth == 0   }  { return  0 };  # error already printed
  set descr1 "extending width of labels-list in '$inpCsvPath' from $oldWidth"

  # set-insertion utility requires list with no header
  set noHdrLabelsListOfTriples [label_list_of_triples_delete_header  \
                                                         $inpLabelsListOfTriples]
  set extLabelsListOfTriples [label_list_of_triples_insert_empty  \
                         $noHdrLabelsListOfTriples $indexOrEnd $numToInsertOrNeg]
  if { $extLabelsListOfTriples == 0 }  { return  0 };  # error already printed
  
  # set outLabelsListOfTriples [label_list_of_triples_prepend_header  \
  #                               $extLabelsListOfTriples]
  # puts "@@====== outLabelsListOfTriples = \n$outLabelsListOfTriples\n@@========"
  if { [label_list_of_triples_to_csv $extLabelsListOfTriples $outCsvPath " "] } {
    set newWidth [label_list_of_triples_width $extLabelsListOfTriples]
    if { $newWidth > 0 }  {
      ok_info_msg "Success $descr1 to $newWidth; result written into '$outCsvPath'"
      return  1
    }
  }
  ok_err_msg "Failed $descr1"
}

  
# Extends the spec by ''numToInsertOrNeg' sublabels-in-a-label - up to max width
# 'inpLabelsListOfTriples' may imclude comments but no header
# Returns the new label-list or 0 on error
## Example 1:  img_proc::label_list_of_triples_insert_empty {{#begin}  {{"a" 11 11} {"b" 12 12} {"c" 13 13}}  {{"d" 21 21} {"e" 22 22} {"f" 23 23}}  {#end}}  0 0
## Example 2: foreach pos {-1 0 1 2 3 "end"}  {puts ">> $pos >> [img_proc::label_list_of_triples_insert_empty {{#begin}  {{"a" 11 11} {"b" 12 12} {"c" 13 13}}  {{"d" 21 21} {"e" 22 22} {"f" 23 23}}  {#end}}  $pos  1]"}
## Example 3:  img_proc::label_list_of_triples_insert_empty {{#begin}  {{"a" 11 11} {"b" 12 12} {"c" 13 13} {"d" 21 21}}  {{"e" 21 21} {"f" 22 22} {"g" 23 23} {"h" 24 24}}  {#end}}  "end" 1
## Example 4:  img_proc::label_list_of_triples_insert_empty {{#begin}  {{"a" 11 11} {"b" 12 12} {"c" 13 13}}  {{"d" 21 21} {"e" 22 22} {"f" 23 23}}  {#end}}  0 3
## Example 5:  img_proc::label_list_of_triples_insert_empty {{#begin}  {{"a" 11 11} {"b" 12 12} {"" 0 0}}  {{"d" 21 21} {"e" 22 22} {"" 0 0}}  {#end}}  1 1
proc ::img_proc::label_list_of_triples_insert_empty {inpLabelsListOfTriples  \
                                             indexOrEnd {numToInsertOrNeg -1}}  {
  if { 0 == [set numSublabelsInLabelOrig \
           [img_proc::label_list_of_triples_width $inpLabelsListOfTriples]] }  {
    return  0;  # error already printed
  }
  set maxWidth [::img_proc::MAX_SUPPORTED_LABEL_LIST_OF_TRIPLES_WIDTH]
  set numCanInsert [expr $maxWidth - $numSublabelsInLabelOrig]

  if { ($numCanInsert == 0) || ($numToInsertOrNeg == 0) }  {
    return  $inpLabelsListOfTriples;  # nothing to do
  }
  if { $numToInsertOrNeg < 0 }  {
    set numToInsert [expr $maxWidth - $numSublabelsInLabelOrig]
  } else {
    set numToInsert [expr {min($numToInsertOrNeg, $numCanInsert)}]
  }
  if { $numToInsert == 0 }  { return  $inpLabelsListOfTriples };  # nothing to do
  set numSublabelsInLabelNew [expr $numSublabelsInLabelOrig + $numToInsert]

  if { ($indexOrEnd == "end") || ($indexOrEnd == $numSublabelsInLabelOrig) }  {
    set index $numSublabelsInLabelOrig
  } elseif { ($indexOrEnd >= 0) && ($indexOrEnd < $numSublabelsInLabelOrig) }  {
    set index $indexOrEnd
  } else {
    ok_err_msg "Invalid insertion index $indexOrEnd; should be 0..[expr $numSublabelsInLabelOrig - 1] or \"end\""
    return  0
  }
  set outLabelsListOfTriples [list]
  set added [lrepeat $numToInsert {"" 0 0}] ;  # [list {""} 0 0] was wrong
  foreach subLabelsGroup $inpLabelsListOfTriples {
    if { [img_proc::label_list_of_triples_element_is_comment $subLabelsGroup] } {
      lappend outLabelsListOfTriples $subLabelsGroup;  # copy comment as is
      continue
    }
    if { [llength $subLabelsGroup] != $numSublabelsInLabelOrig }  {
      ok_err_msg "Wrong original number of sublabels in label '$subLabelsGroup' - [llength $subLabelsGroup] instead of $numSublabelsInLabelOrig"
      return  0
    }
    set newSubLabelsGroup [linsert $subLabelsGroup $index {*}$added]
    ok_trace_msg "Label '$subLabelsGroup' extended into '$newSubLabelsGroup'"
    lappend outLabelsListOfTriples $newSubLabelsGroup
  }
  ok_info_msg "Done extending label-list of [llength $outLabelsListOfTriples] label(s) from $numSublabelsInLabelOrig to $numSublabelsInLabelNew sublabels-in-a-label"
  return  $outLabelsListOfTriples
}


# 1st non-comment line should be the header - returns its index; -1 if not found
proc ::img_proc::label_list_of_triples_find_header {inpLabelsListOfTriples}  {
  for {set j 0} {$j < [llength $inpLabelsListOfTriples]} {incr j 1}  {
    set oneSublabelsList [lindex $inpLabelsListOfTriples $j]; # list of triples
    set origTriple1 [lindex $oneSublabelsList 0];  # 1st sublabel (map from it)
    if { "#" == [string index [lindex $origTriple1 0] 0] }  {
      continue };  # skip comment
    if { [label_list_of_triples_element_is_header $oneSublabelsList] }  {
      #puts "@@ header is:  ==$oneSublabelsList=="
      return  $j;  # found the header - the very 1st non-comment
    } else {
      #puts "@@ 1st non-comment is:  ==$oneSublabelsList=="
      return  -1;  # the very 1st non-comment isn't header ==> no header present
    }
    error "... must not reach here ..."
  }
  return  -1;  # all elements are comments
}


proc ::img_proc::label_list_of_triples_has_header {labelsListOfTriples}  {
  return  [expr {[label_list_of_triples_find_header $labelsListOfTriples] >= 0}]
}


proc ::img_proc::label_list_of_triples_prepend_header {inpLabelsListOfTriples}  {
  set j [label_list_of_triples_find_header $inpLabelsListOfTriples]
  if { $j >= 0 }  {
    return  $inpLabelsListOfTriples;  # header already present
  }
  set numSubLabelsInLabel [label_list_of_triples_width $inpLabelsListOfTriples]
  set headerStr [LABEL_LIST_OF_TRIPLES_HEADER_STR $numSubLabelsInLabel]
  return  [linsert $inpLabelsListOfTriples 0 $headerStr]
}


proc ::img_proc::label_list_of_triples_delete_header {inpLabelsListOfTriples}  {
  set j [img_proc::label_list_of_triples_find_header $inpLabelsListOfTriples]
  if { $j < 0 }  {
    return  $inpLabelsListOfTriples;  # no header present
  }
  return  [lreplace $inpLabelsListOfTriples $j $j]
}



proc ::img_proc::label_list_of_triples_element_is_header {oneSubLabesGroup}  {
  # note, as read from CSV, the header is a list of triples - not a flat string
  set origTriple1 [lindex $oneSubLabesGroup 0];  # 1st sublabel so far
  set firstWord [lindex $origTriple1 0]
  ##if { "#" == [string index $firstWord 0] }  { return  0 }; # comment
  return  [expr {$firstWord == $img_proc::LABEL_LIST_OF_TRIPLES_HEADER_PREFIX}]
}


proc ::img_proc::label_list_of_triples_element_is_comment {oneSubLabesGroup}  {
  set origTriple1 [lindex $oneSubLabesGroup 0];  # 1st sublabel so far
  return  [expr {"#" == [string index [lindex $origTriple1 0] 0]}]
}



## Example:  img_proc::label_list_of_triples_parse_one_label  {{P 77 38} {{} 0 0} {"" 0 0} {{} 0 0}}    slot1Defined slot2Defined slot3Defined slot4Defined   txt1 x1 y1  txt2 x2 y2  txt3 x3 y3  txt4 x4 y4
proc ::img_proc::label_list_of_triples_parse_one_label  {                \
                     oneSublabelsGroup                                   \
                     slot1Defined slot2Defined slot3Defined slot4Defined \
                     txt1 x1 y1  txt2 x2 y2  txt3 x3 y3  txt4 x4 y4}     {
  upvar $slot1Defined hasSlot1
  upvar $slot2Defined hasSlot2
  upvar $slot3Defined hasSlot3
  upvar $slot4Defined hasSlot4
  upvar $txt1 oldTxt_1;  upvar $x1 x_1;  upvar $y1 y_1
  upvar $txt2 oldTxt_2;  upvar $x2 x_2;  upvar $y2 y_2
  upvar $txt3 oldTxt_3;  upvar $x3 x_3;  upvar $y3 y_3
  upvar $txt4 oldTxt_4;  upvar $x4 x_4;  upvar $y4 y_4
  set numSlots [llength $oneSublabelsGroup]
  set set4Present [expr {($numSlots >= 4)}];  # present is not same as defined

  set origTriple1 [lindex $oneSublabelsGroup 0];  # 1st sublabel (map from it)
  set origTriple2 [lindex $oneSublabelsGroup 1];  # 2nd sublabel
  set origTriple3 [lindex $oneSublabelsGroup 2];  # 3rd sublabel
  set hasSlot1 [_sublabel_has_coordinates $origTriple1]
  set hasSlot2 [_sublabel_has_coordinates $origTriple2]
  set hasSlot3 [_sublabel_has_coordinates $origTriple3]
  lassign $origTriple1 oldTxt_1 x_1 y_1;  # actual or {"" 0 0}
  lassign $origTriple2 oldTxt_2 x_2 y_2;  # actual or {"" 0 0}
  lassign $origTriple3 oldTxt_3 x_3 y_3;  # actual or {"" 0 0}
  # 4th sublabel is optional - {} if missing
  if { $set4Present }  {
    set origTriple4 [lindex $oneSublabelsGroup 3]
    set hasSlot4 [_sublabel_has_coordinates $origTriple4]
    lassign $origTriple4 oldTxt_4 x_4 y_4;  # actual or {"" 0 0}
  } else {
    set origTriple4 {}
    set hasSlot4 0
    lassign {"" 0 0} oldTxt_4 x_4 y_4
    set x_4 -1;    set y_4 -1;  # indicate unused
  }
}


# proc ::img_proc::_label_list_of_triples_replace_one_sublabel_text {             \
#                                  oneSublabelsGroup sublabelIdx newTxt oldTxt}  {
#   upvar $oldTxt old_txt
#   if { $sublabelSetIdx >= [llength $oneSublabelsGroup] }  {
#     ok_err_msg "Sublabel-set index #sublabelSetIdx exceeds width of sublabel-group ==$oneSublabelsGroup=="
#     return  0
#   }
#   set oldTriple [lindex $oneSublabelsGroup $sublabelSetIdx]
#   set old_txt   [lindex $oldTriple 0]
#   set newTriple [lreplace $oldTriple 0 0 $newTxt]
#   return  $newTriple
# }


proc ::img_proc::label_list_of_triples_override_one_triple_text {  \
                                   sublabelIdx  newTxt  oneSublabelsGroupRef}  {
  upvar $oneSublabelsGroupRef oneSublabelsGroup
  set numSublabels [llength $oneSublabelsGroup]
  if { ($sublabelIdx < 0) || ($sublabelIdx >= $numSublabels) }  {
    ok_err_msg "Invalid sublabel-index ($sublabelIdx) for $numSublabels sublabel(s) of ==$oneSublabelsGroup=="
    return  0
  }
  set oldSublabelsGroup $oneSublabelsGroup
  set oneSublabelsGroup [list]
  set oldTriple [lindex $oldSublabelsGroup $sublabelIdx]
  set newTriple [lreplace $oldTriple 0 0 $newTxt]
  set oneSublabelsGroup [lreplace $oldSublabelsGroup $sublabelIdx $sublabelIdx \
                                                     $newTriple]
  return  1
}


proc ::img_proc::label_list_of_triples_override_coordinates {  \
                                          flatListOfXY  oneSublabelsGroupRef}  {
  upvar $oneSublabelsGroupRef oneSublabelsGroup
  set numSublabels [llength $oneSublabelsGroup]
  set numXYPairs [llength $flatListOfXY]
  if { ($numXYPairs < $numSublabels) || (($numXYPairs % 2) != 0) }  {
    ok_err_msg "Invalid number of xy-coordinate pairs ($numXYPairs) for $numSublabels sublabel(s) of ==$oneSublabelsGroup=="
    return  0
  }
  set oldSublabelsGroup $oneSublabelsGroup
  set oneSublabelsGroup [list]
  for {set i 0}  {$i < $numSublabels}  {incr i 1}  {
    set oldTriple [lindex $oldSublabelsGroup $i]
    set x [lindex $flatListOfXY [expr $i*2]]
    set y [lindex $flatListOfXY [expr $i*2 + 1]]
    if { ($x >= 0) && ($y >= 0) }  { ;  # coord == -1 for absent slots
      set newTriple [lreplace $oldTriple 1 2 $x $y]
    }
    lappend oneSublabelsGroup $newTriple
  }
  return  1
}


# Returns number of missing mapped-to sublabels in the spec of 'labelSpecCsvPath'
# On error returns -1
# args ==  map1CsvPath map1CsvPath ...
# TODO: ignore headers of map files
proc ::img_proc::label_list_of_triples_check_mapped_sublabels_inclusion { \
                                                      labelSpecCsvPath args} {
  set labelsListOfTriples [csv_to_label_list_of_triples $labelSpecCsvPath cntBad]
  if { $labelsListOfTriples == 0 }  { return  -1 };     # error already printed
  
  set labelOccMap [label_list_of_triples_to_primary_label_occurences_map  \
                                                           $labelsListOfTriples]
  if { $labelOccMap == 0 }  { return  -1 };             # error already printed
  # 'labelOccMap' == {{PRIM-STR OCC-IDX-FROM-1} {SEC-STR1 SEC-STR2 ... }}
  
  set reportStr "Results of sublabel-presense check:"
  set mapPathToMissCnt [dict create];  # for dict {map-CSV-path :: missing-count}
  foreach labelsMapCsvPath $args  {
    set mapFileDescr "label-map '$labelsMapCsvPath'"
    ok_info_msg "Checking inclusion of secondary sublabels from $mapFileDescr in label-list '$labelSpecCsvPath'"
    dict set mapPathToMissCnt $labelsMapCsvPath 0
    set labelsMap [img_proc::csv_to_labels_map $labelsMapCsvPath cntInvalid]
    if { ($labelsMap == 0) || ($cntInvalid > 0) }  {
      ok_err_msg "Skipped '$labelsMapCsvPath' due to error(s) in label mapping"
      dict incr mapPathToMissCnt $labelsMapCsvPath 1;  # indicate a problem
      continue
    }
    # 'labelsMap' == {{PRIMARY-STR OCCURENCE-IDX-FROM-1} SECONDARY-STR}
    dict for {primStrAndCnt secStr} $labelsMap  {
      if { [label_map_key_is_header $primStrAndCnt] }  { continue}; # skip header
      lassign $primStrAndCnt primStr occIdx;    # note, 'occIdx' counts from 1 !!
      set mapDescr "(==$primStr== #$occIdx) :: ==$secStr=="
      set primDescr "primary-sublabel ==$primStr== for $mapDescr"
      set secDescr  "secondary-sublabel ==$secStr== for $mapDescr"
      if { ![dict exists $labelOccMap $primStrAndCnt] }  {
        ok_err_msg "No occurence #$occIdx of $primDescr"
        dict incr mapPathToMissCnt $labelsMapCsvPath 1
        continue
      }
      if { $primStr == $secStr }  {
        continue;  # the case of primary and secodary being the same
      }
      set secStrsList [dict get $labelOccMap $primStrAndCnt]
      set fullLabelDescr "==$primStr== occ:$occIdx :: >>> $secStrsList <<<"
      if { 0 > [set secI [lsearch -exact  $secStrsList  $secStr]] }  {
        ok_err_msg "No $secDescr in label $fullLabelDescr"
        dict incr mapPathToMissCnt $labelsMapCsvPath 1
        continue
      }
      ok_trace_msg "Found secondary sublabel ==$secStr==  for  $primDescr at #$secI  in  ($fullLabelDescr)"
    };#__end_of__loop_over_lines_in_one_map_file
    if { 0 < [set missCnt [dict get $mapPathToMissCnt $labelsMapCsvPath]] }  {
      ok_err_msg "Absent are $missCnt sublabel(s) for $mapFileDescr"
    } else {
      ok_info_msg "Present are all [dict size $labelsMap] sublabel(s) for $mapFileDescr"
    }
    append reportStr ",  '$labelsMapCsvPath': $missCnt"
  };#__end_of__loop_over_map_files
  set totalMissCnt [ok_ladd [dict values $mapPathToMissCnt]]
  append reportStr ".  Total missing: $totalMissCnt."
  if { $totalMissCnt == 0 }  { ok_info_msg "$reportStr"
  } else                     { ok_err_msg  "$reportStr" }
  return  $totalMissCnt
}


# proc ::img_proc::FAILED__label_list_of_triples_find_primary_label_occurences {\
#                                        labelsListOfTriples primStr}  {
#   ## 'labelsListOfTriples' == list of 3|4-element lists of lists of:
#   ##                          {label-text ("" if none),  xCoordPrc,  yCoordPrc}

#   ## Sample search-in-nested-list command:
#   ##  lsearch -all -inline -regexp -index {0 0}  $qqL  {^0$}
#   ###### ... need to use [protect_char $primStr] - for lengyh == 1 only

#   # Incomplete example:
#   ## lsearch -all -inline -regexp -index {0 0}  $qqL  [format {^%s$} [img_proc::protect_char "0"]]
# }


# Builds and returns a map of
#       primary-sublabels' occurences to their secondary sublabels:
##      {{PRIMARY-STR OCCURENCE-IDX-FROM-1} {SECONDARY-STR1 SECONDARY-STR2 ... }}
# On error returns 0.
## Example 1:  img_proc::label_list_of_triples_to_primary_label_occurences_map  {{{"E" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}}
## Example 2:  img_proc::label_list_of_triples_to_primary_label_occurences_map  {{{"E" 24 32} {"" 0 0} {"" 0 0} {"T41" 4 1}}  {{"0" 76 19} {")" 76 13} {"" 0 0} {"T42" 4 2}}}
## Example 3:  img_proc::label_list_of_triples_to_primary_label_occurences_map  {{{"E" 24 32} {"1" 44 46} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}  {{"E" 44 52} {"" 0 0} {"2" 44 66}}}
proc ::img_proc::label_list_of_triples_to_primary_label_occurences_map {  \
                                                    labelsListOfTriples}  {
  set badLabelTriplesList [list];  # for indices of invalid labels
  img_proc::label_list_of_triples_ok $labelsListOfTriples badLabelTriplesList
  if { 0 == [set numSublabelsInLabel \
               [label_list_of_triples_width $labelsListOfTriples]] }  {
    return  0;  # error already printed
  }


  set primOccToSec [dict create];# for {{PRIM-STR OCC-IDX-FROM-1} {SEC-STR1 ...}}
  for {set j 0} {$j < [llength $labelsListOfTriples]} {incr j 1}  {
    set isBad [expr {\
                [lsearch -exact -integer -sorted $badLabelTriplesList $j] >= 0}]
    set sublabelsList [lindex $labelsListOfTriples $j];  # list of triples
    if { $isBad                                                       || \
           [label_list_of_triples_element_is_comment  $sublabelsList] || \
           [label_list_of_triples_element_is_header $sublabelsList]      }  {
      continue
    }
    set primTxt [lindex [lindex $sublabelsList 0] 0]
    if { $primTxt == "" }  {
      continue;  # case of no primary sublabel, thus no mapping for it
    }
    # assume there could be <= 3 occurences of the same primary sublabel
    set occNumFrom1 1;  # the current occ-num is +1 from the largest found
    foreach occI {3 2 1}  {
      if { [dict exists $primOccToSec [list $primTxt $occI]] }  {
        set occNumFrom1 [expr $occI + 1];  break
      }
    }
    if { $occNumFrom1 > 3 }  {
      ok_err_msg "More than 3 occurences of primary sublabel ==$primTxt== encountered at data-line #$j ($sublabelsList); extra ones are ignored"
      continue
    }
    set secList [list];  # for collecting list of mapped-to secondary sublabels
    for {set secI 1} {$secI <= $numSublabelsInLabel} {incr secI 1}  {
      set secSubLabelTriple [lindex $sublabelsList $secI]
      if { "" != [set secTxt [lindex $secSubLabelTriple 0]] }  {
        lappend secList $secTxt
      }
    }
    dict set  primOccToSec  [list $primTxt $occNumFrom1]  $secList
    ok_trace_msg "Label #[dict size $primOccToSec] ==$primTxt== occ=$occNumFrom1: >>> $secList <<<"
  };#__end_of__loop_over_sublabel_groups
  ok_info_msg "Done building map of [dict size $primOccToSec] sublabel-group(s)"
  return  $primOccToSec
}
########## End:    Functions manipulating "label list of triples' ###############



# Reads label-mapping pairs from SPACE-SEPARATED CSV file 'labelsMapCsvPath'.
# Returns dictionary with mappings {{PRIMARY-STR OCCURENCE-COUNT} SECONDARY-STR}.
# On error returns 0.
# The dictionary includes pseudo-mapping for header.
proc ::img_proc::csv_to_labels_map {labelsMapCsvPath cntInvalid}  {
  upvar $cntInvalid cntErr
  
  if { 0 == [ok_read_list_from_file labelsMapAsList $labelsMapCsvPath unicode]} {
    return  0;  # error already printed
  }
  set labelsMap [dict create]
  set occurenceCntDict [dict create];  # to track primary-label duplicates
  set cntErr 0;  set cntDupliate 0
  foreach lineStr $labelsMapAsList {
    set lineStr [string trim $lineStr]
    if { $lineStr == "" }  { continue };                    # skip empty line
    if { "#" == [string index $lineStr 0] }  { continue };  # skip comment
    ##puts $lineStr
    set lineLst [ok_split_string_by_whitespace $lineStr]
    if { 2 != [llength $lineLst] }  {
      ok_err_msg "Invalid label mapping '$lineStr'"
      incr cntErr 1
    }
    # remove enclosing double-quotes (if any) from the both tokens
    set cleanedLst [list]
    foreach word $lineLst  {
      if { [regexp -nocase "\".+\"" $word] }  {
        set word [string range $word 1 end-1]
        # use "string range" instead of trim to protect quote char itself
      }
      lappend cleanedLst $word
    }

    set primary [lindex $cleanedLst 0]
    dict incr occurenceCntDict $primary 1;  # set 1 upon 1st occurence, then incr
    set occCnt [dict get $occurenceCntDict $primary]
    if { $occCnt == 2 }  { ;  # count each duplicate once
      incr cntDupliate 1;  ok_trace_msg "Duplicated primary label --$primary--"
    }
    dict set labelsMap  [list $primary $occCnt]  [lindex $cleanedLst 1]
  }
  set descr "reading [dict size $labelsMap] label mapping(s) from 
'$labelsMapCsvPath'"
  if { $cntErr > 0 }  {
    ok_err_msg "Done $descr. $cntErr error(s) occurred. Number of duplicates: $cntDupliate"
    return  $labelsMap;  # let the caller decide based on 'cntInvalid'
  }
  ok_info_msg "Done $descr. No errors occurred. Number of duplicates: $cntDupliate"
  return  $labelsMap
}


proc ::img_proc::label_map_key_is_header {oneKey}  {
  # note, as read from CSV, the header is a dict record - {list::string}
  #  the header is {{"MapFrom" OCCURENCE-COUNT} "MapTo"}
  # the key is a list {"MapFrom" OCCURENCE-COUNT}
  
  if { [llength $oneKey] != 2 }  { return  0 };            # actually invalid
  set firstWord [lindex $oneKey 0]
  return  [expr {$firstWord == $img_proc::LABEL_MAP_HEADER_PREFIX}]
}


# Converts CSV file with list of text lines from system-default to unicode UTF-16
proc ::img_proc::convert_text_file_to_unicode {inpPath outPath}  {
  return  [_convert_text_file_to_or_from_unicode "TO" $inpPath $outPath]
}

# Converts CSV file with list of text lines from unicode UTF-16 to system-default
proc ::img_proc::convert_text_file_from_unicode {inpPath outPath}  {
  return  [_convert_text_file_to_or_from_unicode "FROM" $inpPath $outPath]
}


# Coverts list of text lines (in CSV file)
# betwen system-default encoding and unicode UTF-16
# (In unicode form the file is usable as KbdLabels input)
proc ::img_proc::_convert_text_file_to_or_from_unicode {toOrFromStr \
                                                          inpPath outPath}  {
  switch -nocase -- $toOrFromStr {
    "to"    { set writeParam "unicode";  set readParam  "";  set dir "to"   }
    "from"  { set readParam  "unicode";  set writeParam "";  set dir "from" }        default { error "Unicode conversion expects TO or FROM; got '$toOrFromStr'"}
  }
  set descr "converting text file '$inpPath' $dir unicode as '$outPath'"
  if { [ok_read_list_from_file txtL $inpPath $readParam] }  {
    if { [ok_write_list_into_file $txtL $outPath  $writeParam] }  {
      ok_info_msg "Success $descr; number of lines: [llength $txtL]"
      return  1
    } else {
      ok_err_msg "Failed $descr - at write stage"
      return  0
    }
  } else {
    ok_err_msg "Failed $descr - at read stage"
    return  0
  }
}


# Removes LibreOffice Calc artifact(s) from list of text lines
#  stored in unicode CSV file '' (that is usable as KbdLabels input)
# betwen system-default encoding and unicode UTF-16
proc ::img_proc::repair_unicode_text_file {inpOutPath} {
  set descr "reparing unicode text file '$inpOutPath'"
  if { [ok_read_list_from_file txtL $inpOutPath unicode] }  {
    if { 0 == [llength $txtL] }  {
      ok_info_msg "Empty file sent to $descr"
      return  0
    }
    set line1 [lindex $txtL 0]
    if { ([string is control [string index $line1 0]]) }  {
      set txtL [lreplace $txtL 0 0 [string range $line1 1 end]];  # OK for len==1
      ok_info_msg "Leading control character removef for $descr"
    }
    if { [ok_write_list_into_file $txtL $inpOutPath unicode] }  {
      ok_info_msg "Success $descr; number of lines: [llength $txtL]"
      return  1
    } else {
      ok_err_msg "Failed $descr - at write stage"
      return  0
    }
  } else {
    ok_err_msg "Failed $descr - at read stage"
    return  0
  }
}


proc ::img_proc::show_text_file_as_unicode {inpPath}  {
  if { [ok_read_list_from_file  lineList  $inpPath  unicode] } {
    foreach el $lineList  { puts $el }
    return  1
  }
  return  0
}


proc ::img_proc::show_text_file_as_default {inpPath}  {
  if { [ok_read_list_from_file  lineList  $inpPath] } {
    foreach el $lineList  { puts $el }
    return  1
  }
  return  0
}
