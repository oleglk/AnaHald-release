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

# image_metadata.tcl
# Copyright (C) 2016 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


namespace eval ::img_proc:: {
    namespace export                          \
      is_standard_image                       \
      get_listed_images_global_timestamps     \
      get_image_global_timestamp              \
      get_image_timestamp_by_imagemagick      \
      get_image_brightness_by_imagemagick     \
      check_image_integrity_by_imagemagick    \
      get_image_dimensions_by_imagemagick     \
      get_image_comment_by_imagemagick        \
      get_image_attributes_by_imagemagick     \
      get_image_attributes_by_dcraw           \
}

# DO NOT for utils:  set SCRIPT_DIR [file dirname [info script]]
set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
source [file join $UTIL_DIR "debug_utils.tcl"]

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"
}
source [file join $UTIL_DIR "common.tcl"]


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*



################################################################################
## (DOES NOT WORK:) To obtain the list of available EXIF attributes, run:
####  identify -format "%[EXIF:*]" <IMAGE_PATH>
################################################################################
# indices for metadata fields
set iMetaDate 0
set iMetaTime 1
set iMetaISO  2
set iMetaRGBG 3

# extensions of standard image files
set g_stdImageExtensions {.bmp .jpg .png .tif}
foreach e $g_stdImageExtensions {lappend g_stdImageExtensions [string toupper $e]}
################################################################################


proc ::img_proc::is_standard_image {path} {
  set ext [file extension $path]
  return  [expr {0 <= [lsearch -exact $::g_stdImageExtensions $ext]}]
}


#~ proc ::img_proc::is_raw_image {path} {
  #~ set ext [file extension $path]
  #~ return  [expr {0 <= [lsearch -exact $::g_rawImageExtensions $ext]}]
#~ }


# Returns dictionary with global times of images in 'imgPathList': {purenane->time}.
# On error returns 0.
# Detects formats by extension; applies relevant methods accordingly.
proc ::img_proc::get_listed_images_global_timestamps {imgPathList} {
  set nameToTimeDict [dict create]
  set inexistentCnt 0
  foreach fPath $imgPathList {
    if { 0 == [file exists $fPath] }  {
      ok_err_msg "Inexistent image '$fPath'"
      incr inexistentCnt 1;   continue
    }
    if { -1 == [set gTime [get_image_global_timestamp $fPath]] }  {
      continue; # error already printed
    }
    set purename [AnyFileNameToPurename [file tail $fPath]]
    dict set nameToTimeDict $purename $gTime
  }
  set cntGood [dict size $nameToTimeDict];  set cntAll [llength $imgPathList]
  if { $cntGood == $cntAll }  {
    ok_info_msg "Success reading timestamp(s) of $cntGood image(s)"
  } elseif { $cntGood > 0 }  {
    ok_warn_msg "Read timestamp(s) of $cntGood image(s) out of $cntAll; $inexistentCnt inexistent"
  } else { ;    # all failed
    ok_err_msg "Failed reading timestamp(s) of all $cntAll image(s)"
    return  0
  }
  return  $nameToTimeDict
}


# Returns global time of image 'fullPath'. On error returns -1.
# Detects format by extension; applies relevant method accordingly.
proc ::img_proc::get_image_global_timestamp {fullPath} {
  global iMetaDate iMetaTime
  array unset imgInfoArr
  if { [is_standard_image $fullPath] } {
    ok_trace_msg "Image '$fullPath' considered a standard image format"
    set formatStr {%Y %m %d %H %M %S}
    set res [get_image_timestamp_by_imagemagick $fullPath imgInfoArr]
  } else {
    ok_info_msg "Image '$fullPath' considered a RAW image format"
    set formatStr {%Y %b %d %H %M %S}
    set res [get_image_attributes_by_dcraw $fullPath imgInfoArr]
  }
  if { $res == 0 }  {
    return  -1; # error already printed
  }
  set gt [_date_time_to_global_time \
                    $imgInfoArr($iMetaDate) $imgInfoArr($iMetaTime) $formatStr]
  if { $gt == -1 }  {
    ok_err_msg "Failed recognizing global timestamp of image '$fullPath'"
    return -1
  }
  ok_trace_msg "Global timestamp of image '$fullPath' is $gt"
  return  $gt
}



# Example: dateList=="{2016 02 13"  timeList=={16 41 08} ==> returns 1455374380
# Returns -1 on error
proc ::img_proc::_date_time_to_global_time {dateList timeList formatStr} {
  set dtStr [join [concat $dateList $timeList]]
  set tclExecResult [catch {
    set globalTime  [clock scan "$dtStr" -format $formatStr]
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Date/time {$dateList} {$timeList} don't match {$formatStr}: $evalExecResult!"
    return  -1
  }
  return  $globalTime
}


# Puts into 'imgInfoArr' date and time of image 'fullPath'.
# On success returns 1, 0 on error.
# Sample result: imgInfoArr(date)={2016 02 13} imgInfoArr(time)={16 41 08}
# Processing command:
## clock scan "$imgInfoArr($iMetaDate) $imgInfoArr($iMetaTime)" -format {%Y %b %d %H %M %S}
proc ::img_proc::get_image_timestamp_by_imagemagick {fullPath imgInfoArr} {
  global iMetaDate iMetaTime
  upvar $imgInfoArr imgInfo
  if { "" == [set tStr [_get_one_image_attribute_by_imagemagick $fullPath \
                                          {%[EXIF:DateTime]} "timestamp"]] } {
    return  0;  # error already printed
  }
  if { 0 == [_ProcessImIdentifyMetadataLine $tStr imgInfo] }  {
    return  0; # TODO: msg
  }
  return  1
}


# Reads metadata value of 'fullPath' specified by 'attribSpec'
# The input is a standard image, not RAW.
# Returns attribute value text on success, "" on error.
# Sample Imagemagick "identify" invocation:
# 	$::_IMIDENTIFY -quiet -verbose -ping -format "%[EXIF:BrightnessValue] <filename>" 
proc ::img_proc::_get_one_image_attribute_by_imagemagick {fullPath attribSpec attribName} {
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  ""
  }
  set tclExecResult [catch {
	# Open a pipe to the program
	#   set io [open "|identify -format \"\%[EXIF:BrightnessValue]\" $fullPath" r]
  set nv_fullPath [file nativename $fullPath]
    set io [eval [list open \
              [format {|%s -quiet -verbose -ping -format %s {%s}} \
                      $::_IMIDENTIFY $attribSpec $nv_fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get $attribName of '$fullPath'"
    return  ""
  }
  # $line should have some data
  if { $len == -1 } {
    ok_err_msg "Cannot read $attribName of '$fullPath'"
    return  ""
  }
  #ok_trace_msg "{$attribName} of $fullPath = $line"
  set val [string trim $line]
  if { $val == "" } {
    ok_err_msg "Cannot read $attribName of '$fullPath'"
	  return  ""
  }
  ok_trace_msg "$attribName of $fullPath: $val"
  return  $val
}


# Processes the following exif line(s):
# 2016:02:13 16:41:08
# Returns 1 if line was recognized, otherwise 0
proc ::img_proc::_ProcessImIdentifyMetadataLine {line imgInfoArr} {
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  # example:'2016:02:13 16:41:08'
  set isMatched [regexp {([0-9]+):([0-9]+):([0-9]+) ([0-9]+):([0-9]+):([0-9]+)} $line fullMach \
                                    year month day hours minutes seconds]
  if { $isMatched == 0 } {
    return  0
  }
  set imgInfo($iMetaDate) [list $year $month $day]
  set imgInfo($iMetaTime) [list $hours $minutes $seconds]
  return  1
}


# Puts into 'brightness' the EXIF brightness value of 'fullPath'
# The input is a standard image, not RAW.
# Returns 1 on success, 0 on error.
# Imagemagick "identify" invocation:
# 	$::_IMIDENTIFY -quiet -verbose -ping -format "%[EXIF:BrightnessValue] <filename>" 
proc ::img_proc::get_image_brightness_by_imagemagick {fullPath brightness} {
  upvar $brightness brVal
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set tclExecResult [catch {
	# Open a pipe to the program
	#   set io [open "|identify -format \"\%[EXIF:BrightnessValue]\" $fullPath" r]
  set nv_fullPath [file nativename $fullPath]
    set io [eval [list open [format {|%s -quiet -verbose -ping -format %%[EXIF:BrightnessValue] {%s}} \
              $::_IMIDENTIFY $nv_fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
    return  0
  }
  # $line should be: "<BrightnessValue>"
  if { $len == -1 } {
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
    return  0
  }
  # ok_trace_msg "{BrightnessValue} of $fullPath = $line"
  set brVal [string trim $line]
  if { $brVal == "" } {
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
	  return  0
  }
  ok_trace_msg "BrightnessValue of $fullPath: $brVal"
  return  1
}


# Returns 1 if 'fullPath' is a valid image file, 0 otherwise.
proc ::img_proc::check_image_integrity_by_imagemagick {fullPath} {
  set rc [get_image_attributes_by_imagemagick $fullPath width height comment 0]
  if { $rc == 0 }  { return 0 } ;   # cannot even read attributes
  return  [expr { (($width > 0) && ($height > 0))?  1 : 0 }]
}


# Puts into 'width' and 'height' horizontal and vertical sizes of 'fullPath'
# Returns 1 on success, 0 on error.
proc ::img_proc::get_image_dimensions_by_imagemagick {fullPath width height} {
  upvar $width wd
  upvar $height ht
  return  [get_image_attributes_by_imagemagick $fullPath wd ht comment 1]
}


# Puts into 'comment'  the comment field of 'fullPath's metadata
# Returns 1 on success, 0 on error.
proc ::img_proc::get_image_comment_by_imagemagick {fullPath comment} {
  upvar $comment cm
  return  [get_image_attributes_by_imagemagick $fullPath width height cm 1]
}


# (this proc is a derivative from LazyConv - same name under ::imageproc:: -
# except for executable path not enclosed in extra curved brackets)
# Puts into 'width' and 'height' horizontal and vertical sizes of 'fullPath'
# Returns 1 on success, 0 on error.
# Imagemagick "identify" invocation: identify -ping -format "%w %h" <filename>
proc ::img_proc::get_image_attributes_by_imagemagick {fullPath \
        width height comment {priErr 1}} {
  upvar $width wd
  upvar $height ht
  upvar $comment cm
  set isWindows [expr {"WINDOWS" == [ok_utils::ok_detect_os_type]}]
  if {       ![info exists ::_IMIDENTIFY] &&  [info exists ::_IM_DIR] }  {
    set ::_IMIDENTIFY [format {"%s"} [file join $::_IM_DIR  \
                             [expr {$isWindows? "identify.exe" : "identify"}]]]
  } elseif { ![info exists ::_IMIDENTIFY] && ![info exists ::_IM_DIR] }  {
    ok_err_msg "Cannot verify image '$fullPath'; missing path for Imagemagick 'identify' utility";                             # always print unexpected error
    return  0
  }
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"; # always print unexpected error
	  return  0
  }
  set tclExecResult [catch {
    # Open a pipe to the program
    #   set io [open "|identify -format \"%w %h\" $fullPath" r]
    set io [eval [list open \
        [format {|%s -ping -format "%%w_/_/_%%h_/_/_%%c" %s} \
                  $::_IMIDENTIFY $fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get width/height/comment of '$fullPath'"
    }
    return  0
  }
  # $line should be: "<width> <height>"
  if { $len == -1 } {
    if { $priErr == 1 }  {
      ok_err_msg "Cannot get width/height/comment of '$fullPath'"
    }
    return  0
  }
  # ok_trace_msg "{W H} of $fullPath = $line"
  set whList [ok_split_string_by_substring $line "_/_/_"]
  if { [llength $whList] != 3 } {
    if { $priErr == 1 }  {
      ok_err_msg "Cannot get width/height/comment of '$fullPath'"
    }
	  return  0
  }
  set wd [lindex $whList 0];    set ht [lindex $whList 1]
  set cm [lindex $whList 2]
  ok_trace_msg "Dimensions of $fullPath: width=$wd, height=$ht"
  ok_trace_msg "Comment of $fullPath: '$cm'"
  return  1
}


# Verifies whether exiftool command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc ::img_proc::_is_exiftool_result_ok {execResultText} {
  # 'execResultText' tells how exiftool-based command ended
  # - OK if noone of 'errKeys' appears
  set result 1;    # as if it ended OK
  set errKeys [list {exiftool - Read and write} {File not found} \
                    {Unknown file type} {File format error}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
  foreach key $errKeys {
    if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
  }
  return  $result
}


########## DCRAW-based section. Adapted from UWIC "read_image_metadata.tcl" ####

# Processes the following exif line(s):
# Timestamp: Sat Aug 23 08:58:21 2014
# Returns 1 if line was recognized, otherwise 0
proc ::img_proc::_process_dcraw_metadata_line {line imgInfoArr} {
  global iMetaDate iMetaTime iMetaISO iMetaRGBG
  upvar $imgInfoArr imgInfo
  # Time/date;  example:'Timestamp: Sat Aug 23 08:58:21 2014'
  if { 1 == [regexp {Timestamp: ([a-zA-Z]+) ([a-zA-Z]+) ([0-9]+) ([0-9]+):([0-9]+):([0-9]+) ([0-9]+)} $line fullMach \
                       weekday month day hours minutes seconds year] }  {
    set imgInfo($iMetaDate) [list $year $month $day]
    set imgInfo($iMetaTime) [list $hours $minutes $seconds]
  }
  # ISO;  example:'ISO speed: 800'
  if { 1 == [regexp {ISO speed: ([0-9]+)} $line fullMach isoVal] }  {
    set imgInfo($isoVal) $isoVal
  }
  # Color multipliers;  example:'Camera multipliers: 2072.0 1024.0 2152.0 1024.0'
  if { 1 == [regexp {Camera multipliers: ([0-9]+(.[0-9]+)*) ([0-9]+(.[0-9]+)*) ([0-9]+(.[0-9]+)*) ([0-9]+(.[0-9]+)*)} \
                        $line fullMach mR _r mG _g mB _b mG2 _g2] }  {
    set imgInfo($iMetaRGBG) [list $mR $mG $mB $mG2]
  }
  return  1
}


# Puts into 'imgInfoArr' ISO, etc. of image 'fullPath'.
# On success returns number of data fields being read, 0 on error.
proc ::img_proc::get_image_attributes_by_dcraw {fullPath imgInfoArr} {
  global _DCRAW
  global iMetaDate iMetaTime iMetaISO iMetaRGBG
  upvar $imgInfoArr imgInfo
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set readFieldsCnt 0
  # command to mimic: eval [list $::ext_tools::EXIV2 pr PICT2057.MRW]
  set tclExecResult [catch {
    # Open a pipe to the program, then get the reply and process it
    # set io [open "|dcraw.exe -i -v $fullPath" r]
    set io [eval [list open [format {|%s  -i -v %s} \
             $_DCRAW $fullPath] r]]
    # while { 0 == [eof $io] } { set len [gets $io line]; puts $line }
    while { 0 == [eof $io] } {
      set len [gets $io line]
      #ok_trace_msg "Analyzing line '$line'"
      if { 0 != [_process_dcraw_metadata_line $line imgInfo] } {
        incr readFieldsCnt
      }
    }
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Error while trying to read attributes of '$fullPath': $execResult!";	return  0
  }
  set tclExecResult [catch {
    close $io;  # generates error; separate "catch" to suppress it
  } execResult]
  if { $tclExecResult != 0 } { ok_warn_msg "$execResult - at closing dcraw process" }
  if { $readFieldsCnt == 0 } {
    ok_err_msg "Cannot understand metadata of '$fullPath'"
    return  0
  }
  ok_trace_msg "Metadata of '$fullPath': time=$imgInfo($iMetaTime) rgbg={$imgInfo($iMetaRGBG)}"
  return  $readFieldsCnt
}
#### End of DCRAW-based section. Adapted from UWIC "read_image_metadata.tcl" ###
