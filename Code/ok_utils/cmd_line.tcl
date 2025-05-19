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

# cmd_line.tcl - command-line handler

# Copyright (C) 2007 by Oleg Kosyakovsky

namespace eval ::ok_utils:: {

    namespace export             \
	ok_new_cmd_line_descr    \
	ok_delete_cmd_line_descr \
	ok_set_cmd_line_params   \
	ok_read_cmd_line         \
	ok_help_on_cmd_line      \
        ok_cmd_line_str          \
        ok_format_switch_descr_record     \
        ok_CheckNonEmptyStringCB          \
        ok_CheckIntCB                     \
        ok_CheckReadableFileCB            \
        ok_CheckEmptyStrOrReadableFileCB  \
        ok_CheckWritableFileCB            \
        ok_CheckWritableFileOrAutoCB      \
        ok_CheckIsDirectoryCB             \
        ok_CheckReadableDirectoryCB       \
        ok_cmdline_check_straight_value_argument  \
        ok_cmdline_check_list_value_argument      \
        ok_cmdline_check_argument_presense
}

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
} else {;
# 	set scriptDir [file dirname [info script]]
# 	puts "---- Sourcing '[info script]' in '$scriptDir' ----"
# 	source [file join $scriptDir "debug_utils.tcl"]
    # assume running standalone; define required proc-s instead of sourcing
if { "" == [info procs ::ok_utils::ok_err_msg] } {
    proc ::ok_utils::ok_err_msg {text} {	puts "* $text" }
}
if { "" == [info procs ok_utils::ok_list_to_array] } {
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
}
}



############ Begin: major procedures ############################################

# Creates a description (spec) for the command line.
# Note, it's not the command line but _the_ spec how to treat it by SW.
# 'argDescrList' == list of {<switch> <{arg help}>}
#                note: {<switch>ONE_SPACE<{arg help}>}
# Returns 1 on success, 0 on error.
# Example 1:
#  set descrList [list \
#               -help {"" "print help"} -year {val "current year"} \
#               -months {list "list of relevant months"}]
#  array unset cmlD;  set isOK [ok_new_cmd_line_descr cmlD $descrList]
#  Resulting array holds two-element list per each argument - {help, valKind}:
#    cmdLine(-help)   = {"print help"              , ""  }
#    cmdLine(-year)   = {"current year"            , val }
#    cmdLine(-months) = {"list of relevant months" , list}
# Example 2 (empty):
#  set dsL [list]; array unset cmlD; ok_new_cmd_line_descr cmlD $dsL
# Example 3:
#  set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; ok_new_cmd_line_descr cmlD $dsL
proc ::ok_utils::ok_new_cmd_line_descr {cmlDescrArrName argDescrList} {
  upvar $cmlDescrArrName cmdL
  if { 0 == [_ok_cmdline_check_arg_descr_conflicts $argDescrList 1] }  {
    # while we only print warnings, still do abort
    return  0
  }
  if { 0 == [ok_list_to_array $argDescrList cmdL] } {
    return  0
  }
  # parray cmdL
  # verify array structure: cmdL(-<argName>) = [list ""|val|list <help>]
  set argNames [array names cmdL]
  foreach argName $argNames {
    if { "-" != [string index $argName 0] } {
      ok_err_msg "Command line description error at '$argName': missing leading -"
      return  0
    }
    set vList $cmdL($argName)
    if { 2 != [llength $vList] } {
      ok_err_msg "Command line description error at '$argName': spec should be {\"\"|val|list <help>}"
      return  0
    }
    set valKind [lindex $vList 0]
    if { ($valKind !="") && ($valKind !="val") && ($valKind !="list") } {
      ok_err_msg "Command line description error at '$argName': spec should be {\"\"|val|list <help>}"
      return  0
    }
  }
  return  1
}

# TODO: looks like setting value for an undeclared parameter makes all _further_ settings invalid

# Adds and/or overrides parameter values in command line array 'cmlArrName'.
# Syntax should match description in 'cmlDescrArrName'
# 'paramsList' is a list of 2-element lists
# Returns 1 on success, 0 on error.
# Example 1:
#  set dsL {-help {"" "print help"} -year {val "current year"} -months {list "list of relevant months"}};  array unset cmlD;  array set cmlD $dsL;  array unset cml;  ok_set_cmd_line_params cml cmlD {{-year 1969} {-months {1 2}} {-help ""}}
# Example 2 (empty - no args to set - NO ARRAY CREATED!):
# set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; array unset cml; array set cmlD $dsL;  ok_set_cmd_line_params cml cmlD [list]
# Example 3:
# set dsL {-a {"" Ahelp} -b {val Bhelp} -cd {list Chelp}}; array unset cmlD; array unset cml; array set cmlD $dsL;  ok_set_cmd_line_params cml cmlD {{-cd {d}}}
proc ::ok_utils::ok_set_cmd_line_params {cmlArrName cmlDescrArrName \
					     paramsList} {
  upvar $cmlArrName      cml
  upvar $cmlDescrArrName cmlDescr
  # copy values using spec; should be "-name <val>|list"
  foreach paramSet $paramsList {
    set paramName [lindex $paramSet 0]
    if { [llength $paramSet] == 2 } {;	    # parameter with value(s)
        set paramVal [lindex $paramSet 1]
    } elseif { [llength $paramSet] == 1 } {;    # parameter without value
        set paramVal ""
    } else {
        ok_err_msg "Command line error at '$paramName': should be \"-name <val>|list\""
        return  0
    }
    # puts ">>> paramName='$paramName';  paramVal='$paramVal'"
    if { "-" != [string index $paramName 0] } {
        ok_err_msg "Command line error at '$paramName': missing leading -"
        return  0
    }
    if { ![info exists cmlDescr($paramName)] } {
        ok_err_msg "Command line error at '$paramName': unknown name"
        return  0
    }
    set valSpec [lindex $cmlDescr($paramName) 0]
    set valCnt [llength $paramVal]
    if { $valSpec == "val" } {
      if { $valCnt > 1 } {
        ok_err_msg "Command line error at '$paramName': one value expected, got '$paramVal'"
        return  0
      } elseif { $valCnt == 0 } {
        ### !!! The below fix came in commit 40a30be:
        ### !!!      "Check for error returned by command-line help builder"
        ### !!! It prevented an optional (empty) argument -
        ### !!! - '-primaryAbcMapFile' in KbdLabels:map_replace_label_spec_by_csv
        ## ok_err_msg "Command line lacks value for '$paramName'"; # it's OK
        ## return  0
        ok_info_msg "Command line lacks- or carries empty value for '$paramName'"
        # it's OK; do not return error
      } else { ;  # $valCnt == 1
        set cml($paramName) $paramVal
      }
    } elseif { $valSpec == "list" } {
        # force parameter value to be a list
        if { $valCnt == 1 } {
      set cml($paramName) [list $paramVal]
        } elseif { $valCnt > 1 } {
      set cml($paramName) $paramVal
        } else {
      set cml($paramName) [list]
        }
    } else {;	# assume the spec is ""
        set cml($paramName) ""
    }
  }
    return  1
}

# Reads command line from 'cmdLineAsString' into array 'cmlArrName'
# structured according to the spec in array 'cmlDescrArrName'
# Returns 1 on success, 0 on error.
# Example:
#  set isOK [ok_read_cmd_line "-year 1969 -months 1 2 -help" cml cmlD]
proc ::ok_utils::ok_read_cmd_line {cmdLineAsString cmlArrName \
				       cmlDescrArrName} {
    upvar $cmlArrName      cml
    upvar $cmlDescrArrName cmlDescr
    # parse 'cmdLineAsString' into 'paramsList' for ok_set_cmd_line_params
    set paramsList [list]
    set prevKey "";    set valList [list]
    set tN 0;  # serial number of the token for trace/debug - 1...
    set cmdLineAsList [ok_split_string_by_whitespace $cmdLineAsString]
    foreach token $cmdLineAsString {
        incr tN;  #ok_trace_msg "Token #$tN = '$token'"
	if { 1 == [_token_looks_like_switch $token] } {;   # done with prev. parameter
	    if { $prevKey != "" } {
		lappend paramsList [list $prevKey $valList]
	    }
	    set prevKey $token;    set valList [list]
	} else {;    # continuing with values for prev. parameter
	    #(wrong) lappend valList $token
      set valList [concat $valList $token]
	}
    }
    if { $prevKey != "" } {;	# save the last parameter
	lappend paramsList [list $prevKey $valList]
    }
    ok_trace_msg $paramsList
    set isOK [ok_set_cmd_line_params cml cmlDescr $paramsList]
    return $isOK
}


# Builds and returns a string with help on command line
# whose structure described by 'cmlDescrArrName'
# and defaults set in 'defaultCmlArrName' command-line array of same structure
proc ::ok_utils::ok_help_on_cmd_line {defaultCmlArrName cmlDescrArrName \
					  {separator "\n"}} {
    upvar $defaultCmlArrName defCml
    upvar $cmlDescrArrName   cmlD
    set helpParamList [list]
    foreach paramName [array names cmlD] {
	set defVal [expr {([info exists defCml($paramName)])? \
			                $defCml($paramName) : "<none>"}]
	lappend helpParamList [list $paramName $cmlD($paramName) \
				    "default:" $defVal]
    }
    return [format "%s%s" $separator [join $helpParamList $separator]]
}


# Builds and returns a string with command line from 'cmlArrName'
# whose structure described by 'cmlDescrArrName'
# Record per a parameter separated by 'separator'.
# If 'priHelp' == 1, adds help for each appearing parameter.
proc ::ok_utils::ok_cmd_line_str {cmlArrName cmlDescrArrName \
				      {separator " "} {priHelp 0}} {
    upvar $cmlArrName      cml
    upvar $cmlDescrArrName cmlD
    set cmdStr ""
    foreach paramName [array names cml] {
	if { $cmdStr != "" } {	    append cmdStr $separator	}
	append cmdStr $paramName
	if { [info exists cmlD($paramName)] } {
	    set paramSpec [lindex $cmlD($paramName) 0]
	    set paramHelp [lindex $cmlD($paramName) 1]
	} else {
	    set paramHelp "!INVALID_ARGUMENT!"
	}
	append cmdStr " " $cml($paramName)
	if { 1 == $priHelp } {
	    append cmdStr " <" $paramHelp ">"
	}
    }
    return  $cmdStr
}


proc ::ok_utils::_token_looks_like_switch {token} {
  return  [expr { ("-" == [string index $token 0]) && \
                  (2 <= [string length $token])    && \
                  (0 == [string is digit [string index $token 1]])}]
}


proc ::ok_utils::example_on_cmd_line {} {
    # create the command-line description
    set descrList [list \
		       -help {"" "print help"} -year {val "current year"} \
		       -months {list "list of relevant months"} \
		       -days {list "list of relevant days"} \
		       -loud {"" "print trace"}]
    array unset cmlD
    ok_new_cmd_line_descr cmlD $descrList
    puts "==== Below is the command-line description ====";    parray cmlD
    # create dummy command line with the default parameters
    array unset defCml
    ok_set_cmd_line_params defCml cmlD {{-year 1969} {-months {7}}}
    puts "==== Below is the default command line ====";    parray defCml
    # print a usual help where defaults are specified
    set cmdHelp [ok_help_on_cmd_line defCml cmlD "\n"]
    puts "==== Below is the command line help separated by <CR> ====\n$cmdHelp"
    # now parse a typical real-life command line
    array unset cml
    ok_read_cmd_line "-year 2007 -months 1 2 -loud" cml cmlD
    puts "==== Below is the ultimate command line ====";    parray cml
    # now build a string representation of the real-life command line
    set cmdStrNoHelp [ok_cmd_line_str cml cmlD " " 0]
    puts "==== Below is the ultimate command line as a string (no help) ===="
    puts "$cmdStrNoHelp"
    set cmdStrWithHelp [ok_cmd_line_str cml cmlD "\n" 1]
    puts "==== Below is the ultimate command line as a string with help ===="
    puts "$cmdStrWithHelp"
    return [array get cml]
}


# Formats record (list): {-SWITCH-NAME {""|val|list SWITCH-DESCR} DEF-VAL}
proc ::ok_utils::ok_format_switch_descr_record {descrRecWithDefVal}  {
  lassign $descrRecWithDefVal  swNameWithDash swValDescr defVal
  lassign $swValDescr          swValType swDescr
  set valTypeDict [dict create \
                    "" "NO-VALUE"    val "ONE-VALUE"    list "LIST-OF-VALUES"]

  set valTypeStr [dict get $valTypeDict $swValType]
  set defStr [expr {($swValType != "")? "  (default: $defVal)"  :  ""}]
  return  "$swNameWithDash:  $valTypeStr  \t<==  $swDescr  $defStr"
}
############ End:   major procedures ############################################



############ Begin: parameter-value verification callbacks ######################
set ::_NoCB  0;  # means no optional callback

proc ::ok_utils::ok_CheckNonEmptyStringCB {val}  {
  if { $val == "" }  {
    return  "ERROR: Empty-string value is prohibited"
  }
  return  $val
}


proc ::ok_utils::ok_CheckIntCB {val}  {
  if { ![string is integer -strict $val]}  {
    return  "ERROR: Instead of integer got '$val'"
  }
  return  $val
}


proc ::ok_utils::ok_CheckNumberCB {val}  {
  if { ![ok_isnumeric $val]}  {
    return  "ERROR: Instead of number got '$val'"
  }
  return  $val
}


proc ::ok_utils::ok_CheckReadableFileCB {val}  {
  if { ![ok_filepath_is_readable $val] || ![file exists $val] }  {
    return  "ERROR: File '$val' ([file normalize $val]) is not readable to the current user as an existent regular file"
  }
  return  [file normalize $val]
}


proc ::ok_utils::ok_CheckEmptyStrOrReadableFileCB {val}  {
  if { $val == "" }  { return  "{}" };  # ensure explicit empty string
  return  [ok_CheckReadableFileCB $val]
}


proc ::ok_utils::ok_CheckWritableFileCB {val}  {
  if { ![ok_filepath_is_writable $val] }  {
    return  "ERROR: File-path '$val' ([file normalize $val]) is not writable to the current user as a regular file"
  }
  return  [file normalize $val]
}


proc ::ok_utils::ok_CheckWritableFileOrAutoCB {val}  {
  if { [string equal -nocase  $val  "_AUTO_"] }  {
    return  "_AUTO_";  # do not check - leave at the caller's responsibility
  }
  if { ![ok_filepath_is_writable $val] }  {
    return  "ERROR: File-path '$val' ([file normalize $val]) is not writable to the current user as a regular file"
  }
  return  [file normalize $val]
}


proc ::ok_utils::ok_CheckIsDirectoryCB {val}  {
  if { ![file isdirectory $val] || ![file exists $val] }  {
    return  "ERROR: Non-directory '$val' ([file normalize $val]) specified as output directory"
  }
  return  [file normalize $val]
}


proc ::ok_utils::ok_CheckReadableDirectoryCB {val}  {
  if { ![file isdirectory $val] || ![file exists $val] || \
       ![file readable $val] }  {
    return  "ERROR: Provided name/path '$val' ([file normalize $val]) is not a readable directory"
  }
  return  [file normalize $val]
}


# proc ::ok_utils::UNCHECKED__ok_CheckYesNoPromptCB {val}  {
#   set valU [string toupper $val]
#   if { ($valU != "YES") && ($valU != "NO") && ($valU != "PROMPT") }  {
#     return  "ERROR: Expected YES, NO, or PROMPT; '$val' is invalid"
#   }
#   return  $valU
# }
############ End:   parameter-value verification callbacks ######################




############ Begin: cmd-line checkers ###########################################
#  If simple argument 'argNameNoDash' is present (no matter if valid),
#        stores it in destArrName_orEmpty(argNameNoDash) and returns 1;
#        otherwise, if 'argNameNoDash' is mandatory, returns 0
# 'checkAndMassageCB_orZero' returns updated value or string "ERROR: <any-text>"
proc ::ok_utils::ok_cmdline_check_straight_value_argument {                    \
                                               argNameNoDash descrList         \
                                               isMandatory cmlArrName          \
                                               checkAndMassageCB_orZero        \
                                               destArrName_orEmpty errCntVar}  {
  upvar $cmlArrName           cml
  upvar $destArrName_orEmpty  destArr
  upvar $errCntVar            errCnt
  # DO NOT - instead, let caller init it:  set errCnt 0

  if { 0 == [ok_cmdline_check_argument_presense  $argNameNoDash $descrList \
               $isMandatory $cmlArrName found $errCntVar] }  {
    return  0;  # error already printed and error-count updated
  }
  
  if { $found && ($checkAndMassageCB_orZero != 0) }  {
    set massageRes [eval $checkAndMassageCB_orZero $cml(-$argNameNoDash)]
    if { [string match -nocase {ERROR: *}  $massageRes] }  {
      ok_err_msg "In argument '-$argNameNoDash' $massageRes"
      incr errCnt 1
      return  0
    }
    set cml(-$argNameNoDash) $massageRes;  # no error; update param value
  }

  if { $found && ($destArrName_orEmpty != "") }  {
    set destArr($argNameNoDash)  $cml(-$argNameNoDash)
  }
  if { $found }  { ok_trace_msg "Cmd-line includes '-$argNameNoDash'" }

  return  1
}


## Example:   _cmdline_check_list_value_argument "fontSizes"  $descrList  1  cml  ok_CheckIntCB  {3 4}  ::STS  errorCount
proc ::ok_utils::ok_cmdline_check_list_value_argument {argNameNoDash descrList  \
                          isMandatory cmlArrName                                \
                          checkAndMassageOneElemCB_orZero listOfLengths_orEmpty \
                          destArrName_orEmpty errCntVar                      }  {
  upvar $cmlArrName           cml
  upvar $destArrName_orEmpty  destArr
  upvar $errCntVar            errCnt
  # DO NOT - instead, let caller init it:  set errCnt 0

  set argDescr [expr {[dict exists $descrList "-$argNameNoDash"]?  \
        [lindex [dict get $descrList "-$argNameNoDash"] 1] : "(no description)"}]
  
  if { 0 == [ok_cmdline_check_argument_presense  $argNameNoDash $descrList \
               $isMandatory $cmlArrName found $errCntVar] }  {
    return  0;  # error already printed and error-count updated
  }
  if { !$found }  { ;
    return  1;  # this optional argument doesn't appear; message already printed
  }
  
  # the argument at least appears
  set valLst $cml(-$argNameNoDash)
  set numElems [llength $valLst]

  #### check length of value-list
  if { $listOfLengths_orEmpty != {} }  {
    set lengthOK 0
    foreach len $listOfLengths_orEmpty {
      if { $numElems == $len }  { set lengthOK 1;  break }
    }
    if { !$lengthOK }  {
      ok_err_msg "Invalid length ($numElems) of value-list at:  -$argNameNoDash <<$argDescr>>;  must be one of {$listOfLengths_orEmpty}"
      ok_trace_msg "Command line: '[array get cml]'"
      incr errCnt 1
      return  0
    }
  }

#  puts "@@@@@@ Inside _cmdline_check_list_value_argument(-$argNameNoDash {$valLst}, (CB=$checkAndMassageOneElemCB_orZero))";  # OK_TMP

  #### list length is valid; check individual elements of value-list
  if { $checkAndMassageOneElemCB_orZero != 0 }  {
    set newValList [list]
    for {set i 0}  {$i < $numElems}  {incr i}  {
      set elem [lindex $valLst $i]
      set massageRes [eval $checkAndMassageOneElemCB_orZero $elem]
      if { [string match -nocase {ERROR: *}  $massageRes] }  {
        ok_err_msg "In argument '-$argNameNoDash' - list-element #$i - $massageRes"
        incr errCnt 1
        return  0
      }
      lappend newValList $massageRes;  # no error; update element value
    }
    set cml(-$argNameNoDash) $newValList;  # no error; update param value-list
  }

  if { $found && ($destArrName_orEmpty != "") }  {
    set destArr($argNameNoDash)  $cml(-$argNameNoDash)
  }
  if { $found }  { ok_trace_msg "Cmd-line includes '-$argNameNoDash'" }

  return  1
}


proc ::ok_utils::ok_cmdline_check_argument_presense {argNameNoDash descrList   \
                                   isMandatory cmlArrName foundVar errCntVar}  {
  upvar $cmlArrName           cml
  upvar $foundVar             found
  upvar $errCntVar            errCnt
  # DO NOT - instead, let caller init it:  set errCnt 0
  set argDescr [expr {[dict exists $descrList "-$argNameNoDash"]?  \
        [lindex [dict get $descrList "-$argNameNoDash"] 1] : "(no description)"}]

  ok_trace_msg "Checking cmd-line for '-$argNameNoDash':"
  if { ![set found [info exists cml(-$argNameNoDash)]] }  { ; # note no quotes!
    if { $isMandatory }  {
      ok_err_msg "Missing mandatory argument:  -$argNameNoDash <<$argDescr>>"
      ok_trace_msg "Command line: '[array get cml]'"
      incr errCnt 1
      return  0
    }
    ok_trace_msg "Cmd-line lacks '-$argNameNoDash' (optional)"
  } else { ; # found
    ok_trace_msg "Cmd-line includes '-$argNameNoDash'"
  }

  return  1;  # either found or is optional
}


# Warns if 'argDescrList' has conflicting descriptions for same arguments
proc ::ok_utils::_ok_cmdline_check_arg_descr_conflicts {argDescrList  \
                                                        priWarnings}  {
  set dict1 [dict create];  # all arguments once
  set dict2 [dict create];  # 1st problem occcurences for conflicting arguments
  ok_assert { ([llength $argDescrList] % 2) == 0 }  "Argument description list must have even number of elements"
  for {set i 0}  {$i < [llength $argDescrList]}  {incr i 2}  {
    set argName  [lindex $argDescrList $i]
    set argDescr [lindex $argDescrList [expr $i + 1]]
    if { ![dict exists $dict1 $argName] }  {
      dict set dict1 $argName $argDescr
    } elseif { ![string equal -nocase  [dict get $dict1 $argName]  $argDescr] } {
      if { ![dict exists $dict2 $argName] }  {
        dict set dict2 $argName $argDescr
      }
    }
  }
  set errCnt [dict size $dict2]
  if { $errCnt > 0 }  {
    ok_warn_msg "Number of command-line arguments with conflicting argument descriptiona: $errCnt"
    if { $priWarnings }  {
      dict for {k v} $dict2  {
        ok_warn_msg "Conflicting descriptions for command-line argument '$k': {[dict get $dict1 $k]}  and  ($v)"  
      }
    }
  } else {
    ok_trace_msg "No conflicting command-line argument descriptions detected"
  }
  return  [expr {$errCnt == 0}]
}
############ End:   cmd-line checkers ###########################################

namespace import -force ::ok_utils::*
