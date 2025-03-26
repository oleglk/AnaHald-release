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

# ext_tools.tcl

set SCRIPT_DIR [file dirname [info script]]
set UTIL_DIR    [file join $SCRIPT_DIR "ok_utils"]
source [file join $UTIL_DIR "debug_utils.tcl"]
source [file join $UTIL_DIR "common.tcl"]
source [file join $UTIL_DIR "csv_utils.tcl"]
source [file join $UTIL_DIR "cmd_line.tcl"]

# DO NOT in 'auto_spm': package require ok_utils
namespace import -force ::ok_utils::*

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
}

## Better call path-reading function explicitly from another function
## read_ext_tool_paths_from_csv [file join $SCRIPT_DIR "ext_tool_dirs.csv"]

# - external program executable paths;
# - don't forget to add if using more;
# - COULDN'T PROCESS SPACES (as in "Program Files");

#~ # - ImageMagick:
#~ set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.7-3}] ; # DT
#~ #set _IM_DIR [file join {C:/} {Program Files} {ImageMagick-6.8.6-8}]  ; # Asus
#~ #set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.6-8}]; # Yoga

#~ set _IMCONVERT [format "{%s}" [file join $_IM_DIR "convert.exe"]]
#~ set _IMIDENTIFY [format "{%s}" [file join $_IM_DIR "identify.exe"]]
#~ set _IMMONTAGE [format "{%s}" [file join $_IM_DIR "montage.exe"]]
#~ # - DCRAW:
#~ #set _DCRAW "dcraw.exe"
#~ set _DCRAW [format "{%s}" [file join $_IM_DIR "dcraw.exe"]]
#~ # - ExifTool:
#~ set _EXIFTOOL "exiftool.exe" ; #TODO: path


####### Do not change after this line ######

# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc set_ext_tool_paths_from_csv {csvPath}  {
  unset -nocomplain ::_IMCONVERT ::_IMIDENTIFY ::__IMMOGRIFY ::_IMMONTAGE  ::_IMCOMPOSITE ::_DCRAW ::_EXIFTOOL ::SPM
  
  set isWindows [expr {"WINDOWS" == [ok_utils::ok_detect_os_type]}]
  if { !$isWindows }  {
    # assume an unixoid - can use straight executable names
    set ::_IMCONVERT    "convert"
    set ::_IMIDENTIFY   "identify"
    set ::_IMMONTAGE    "montage"
    set ::_IMMOGRIFY    "mogrify"
    set ::_IMCOMPOSITE  "composite"
    set ::_DCRAW        "dcraw"
    set ::IMCONVERT   "$::_IMCONVERT" ;  # sync historical flavors
    set ::IMMOGRIFY   "$::_IMMOGRIFY" ;  # sync historical flavors
    set ::IMIDENTIFY  "$::_IMIDENTIFY";  # sync historical flavors
    set ::IMMONTAGE   "$::_IMMONTAGE" ;  # sync historical flavors
    set ::IMCOMPOSITE "$::_IMCOMPOSITE"; # sync historical flavors
    set ::DCRAW       "$::_DCRAW"     ;  # sync historical flavors
    puts "-I- Assume running on an unixoid - use pure tool executable names"
    return  1
  }
  if { 0 == [ok_read_variable_values_from_csv \
                                      $csvPath "external tool path(s)"]} {
    return  0;  # error already printed
  }
  return  [_set_ext_tool_paths_from_variables "source: '$csvPath'"]
}


# Reads the system-dependent paths from their global variables,
# then assigns ultimate tool paths
proc _set_ext_tool_paths_from_variables {srcDescr}  {
  unset -nocomplain ::_IMCONVERT ::_IMMOGRIFY ::_IMIDENTIFY ::_IMMONTAGE ::_IMCOMPOSITE ::_DCRAW ::_EXIFTOOL
  if { 0 == [info exists ::_IM_DIR] }  {
    ok_err_msg "Imagemagick directory path not assigned to variable _IM_DIR; $srcDescr"
    return  0
  }
  set ::_IMCOMPOSITE  [format "{%s}"  [file join $::_IM_DIR  \
			       [choose_one_im_tool_option "composite.exe"]]]
  set ::_IMCONVERT    [format "{%s}"  [file join $::_IM_DIR  \
			       [choose_one_im_tool_option "convert.exe"]]]
  set ::_IMMOGRIFY    [format "{%s}"  [file join $::_IM_DIR  \
			       [choose_one_im_tool_option "mogrify.exe"]]]
  set ::_IMIDENTIFY [format "{%s}"  [file join $::_IM_DIR  \
			       [choose_one_im_tool_option "identify.exe"]]]
  set ::_IMMONTAGE  [format "{%s}"  [file join $::_IM_DIR  \
			       [choose_one_im_tool_option "montage.exe"]]]
  set ::IMCONVERT   "$::_IMCONVERT" ;  # sync historical flavors
  set ::IMMOGRIFY   "$::_IMMOGRIFY" ;  # sync historical flavors
  set ::IMIDENTIFY  "$::_IMIDENTIFY";  # sync historical flavors
  set ::IMMONTAGE   "$::_IMMONTAGE" ;  # sync historical flavors
  set ::IMCOMPOSITE "$::_IMCOMPOSITE"; # sync historical flavors
  # - DCRAW:
  # unless ::_DCRAW_PATH points to some custom executable, point at the default
  if { (![info exists ::_DCRAW_PATH]) || (""== [string trim $::_DCRAW_PATH]) } {
    set ::_DCRAW      [format "{%s}"  [file join $::_IM_DIR "dcraw.exe"]]
  } else {
    ok_info_msg "Custom dcraw path specified; $srcDescr"
    set ::_DCRAW      [format "{%s}"  $::_DCRAW_PATH]
  }
  # - ExifTool:
  ## set ::_EXIFTOOL "exiftool.exe" ; #TODO: path
  return  1
}


# Copy-pasted from Lazyconv "::dcraw::is_dcraw_result_ok"
# Verifies whether dcraw command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc is_dcraw_result_ok {execResultText} {
    # 'execResultText' tells how dcraw-based command ended
    # - OK if noone of 'errKeys' appears
    set result 1;    # as if it ended OK
    set errKeys [list {Improper} {No such file} {missing} {unable} {unrecognized} {Non-numeric}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
    foreach key $errKeys {
	if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
    }
    return  $result
}


# Chooses the way of invoking IM command depending on version - pre-V7 or V7+.
proc choose_one_im_tool_option {imToolNameNoExt}  {
  global _IM_DIR
  if { ![info exists _IM_DIR] }  {
    ok_err_msg "Imagemagick directory path must be defined in '::_IM_DIR' before search for specific executables there"
    return  ""
  }
  set res ""
  # first look for executable named after the tool
  foreach name [list $imToolNameNoExt "$imToolNameNoExt.exe"]  {
    if { [file exists [file join $_IM_DIR $name]] }  {
      set res $name
      break
    }
  }
  ##### ???  the 2nd option - invoke through "magick TOOLNAME"
  # the 2nd option - invoke through "magick"
  if { $res == "" }  {
    set magickExe ""
    foreach name [list "magick" "magick.exe"]  {
      if { [file exists [file join $_IM_DIR $name]] }  {
	set magickExe $name
	break
      }
    }
    if { $magickExe == "" }  {
      ok_err_msg "No way to invoke '$imToolNameNoExt' - no executables for 'magick' or '$imToolNameNoExt'"
      return ""
    }
    ##### ???  set res "$magickExe $imToolNameNoExt"
    set res "$magickExe"
  }
  ok_info_msg "ImageMagick command for '$imToolNameNoExt':  '$res'"
  return  $res
}


proc verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::_IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMOGRIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMMOGRIFY'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMIDENTIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'identify' tool '$::_IMIDENTIFY'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMONTAGE " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'montage' tool '$::_IMMONTAGE'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_DCRAW " {}"]] }  {
    ok_err_msg "Inexistent 'dcraw' tool '$::_DCRAW'"
    incr errCnt 1
  }
  if { ([info exists ::_ENFUSE_DIR]) &&               \
       ("" != [string trim $::_ENFUSE_DIR " {}"]) &&  \
       (![ok_filepath_is_existent_dir [string trim $::_ENFUSE_DIR " {}"]]) }  {
    ok_err_msg "Inexistent or invalid 'enfuse' directory '$::_ENFUSE_DIR'"
    incr errCnt 1
  }
  if { $errCnt == 0 }  {
    ok_info_msg "All external tools are present"
    return  1
  } else {
    ok_err_msg "Some or all external tools are missing"
    return  0
  }
}


# Retrieves external tools' paths from their variables.
# Returns list of {key val} pair lists
proc ext_tools_collect_and_verify {srcDescr}  {
  global _IM_DIR _DCRAW_PATH _ENFUSE_DIR
  set listOfPairs [list]
  if { ([info exists _IM_DIR]) && ("" != [string trim $_IM_DIR]) } {
    lappend listOfPairs [list "_IM_DIR"     $_IM_DIR] }
  if { ([info exists _DCRAW_PATH]) && ("" != [string trim $_DCRAW_PATH]) } {
    lappend listOfPairs [list "_DCRAW_PATH" $_DCRAW_PATH] }
  if { ([info exists _ENFUSE_DIR]) && ("" != [string trim $_ENFUSE_DIR]) } {
    lappend listOfPairs [list "_ENFUSE_DIR" $_ENFUSE_DIR] }
  if { 0 == [_set_ext_tool_paths_from_variables $srcDescr] }  {
    return  0;  # error already printed
  }
  if { 0 == [verify_external_tools] }  {
    return  0;  # error already printed
  }
  #puts "@@@ {$listOfPairs}";  set ::_TMP_PATHS $listOfPairs
  return  $listOfPairs
}


proc ext_tools_collect_and_write {srcDescr}  {
  set extToolsAsListOfPairs [ext_tools_collect_and_verify $srcDescr]
  if { $extToolsAsListOfPairs == 0 }  {
    return  0;  # error already printed
   }
  return  [ext_tools_write_into_file $extToolsAsListOfPairs]
}


# Saves the obtained list of pairs (no header) in the predefined path.
# Returns 1 on success, 0 on error.
proc ext_tools_write_into_file {extToolsAsListOfPairs}  {
  set pPath [dualcam_find_toolpaths_file 0]
  if { 0 == [CanWriteFile $pPath] }  {
    ok_err_msg "Cannot write into external tool paths file <$pPath>"
    return  0
  }
  # prepare wrapped header; "concat" data-list to it 
  set header [list [list "Environment-variable-name" "Path"]]
  set extToolsListWithHeader [concat $header $extToolsAsListOfPairs]
  return  [ok_write_list_of_lists_into_csv_file $extToolsListWithHeader \
                                                $pPath ","]
}
