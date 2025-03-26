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

# hald.tcl - utilities for ImageMagick HALD color LUT-s

# Copyright (C) 2024 by Oleg Kosyakovsky

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


# DO NOT for utils:  set SCRIPT_DIR [file dirname [info script]]
set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
# source [file join $UTIL_DIR     "debug_utils.tcl"]
# source [file join $UTIL_DIR     "common.tcl"]
# source [file join $IMGPROC_DIR  "image_metadata.tcl"]
# source [file join $IMGPROC_DIR  "image_annotate.tcl"]

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"
}


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
  variable _HALD_FORMAT_TXT_OR_PPM 1;  # 0=ImageMagick-TXT, 1=PPM 
  
  namespace export                          \
    hald_rgb_to_idx                         \
    hald_rgb_indices_to_rgb                 \
    hald_rgb_indices_to_line_idx            \
    hald_rgb_indices_to_xy                  \
    hald_read_from_text_file                \
    hald_calc_level_for_hald_list           \
    hald_calc_level_for_hald_list_length    \
    hald_parse_srgb_line                    \
    hald_format_srgb_line                   \
    hald_txt_or_ppm                         \
    hald_list_to_colors_list                \
    hald_find_text_files_diff               \
    hald_find_lists_diff                    \
    hald_get_space_for_level_kb             \
}

#################################################################################
## Make 8-bit/channel HALD-LUT:           magick.exe hald:16 -depth 8 INP/hald_16.png
## Make 8-bit/channel HALD-LUT as text:   magick.exe hald:16 -depth 8 INP/hald_16.txt
#################################################################################

# Returns index of HALD line for color {rgb}
proc ::img_proc::hald_rgb_to_idx {r g b {level 16}}  {
  ok_assert { (1 <= $level) && ($level <= 16) && (int($level) == $level) }  "HALD level must be an integer in \[1 .. 16\] range; got $level"
  ok_assert { (0 <= $r) && ($r <= 255) && (0 <= $g) && ($g <= 255) && (0 <= $b) && ($b <= 255) }  "Values of color channels must be in \[0 .. 255\] range; got {$r $g $b}"
  set idx [expr {$r + $level*$level * $g + $level*$level*$level*$level * $b}]
  return  $idx
}


## Example-01:  lassign {255 0 100} iR iG iB;  hald_rgb_indices_to_rgb  16 255  $iR $iG $iB  r g b;  puts "{$iR $iG $iB} => {$r $g $b}"
## Example-02:  foreach i {0 1 2 3 4 5 6 7 8}  {lassign [list $i 1 8] iR iG iB;  hald_rgb_indices_to_rgb  3 255  $iR $iG $iB  r g b;  puts "{$iR $iG $iB} => {$r $g $b}"}
proc ::img_proc::hald_rgb_indices_to_rgb {level maxRgbVal  iR iG iB  r g b}  {
  upvar $r vR
  upvar $g vG
  upvar $b vB
  if { ![_hald_verify_rgb_indices $level $maxRgbVal  $iR $iG $iB  1] }  {
    return  0;  # error(s) already printed
  }
  set gradLen [expr {$level * $level}]
  set maxIdxAsFloat [expr {$gradLen - 1.0}]
  set vR [expr {int($maxRgbVal * $iR / $maxIdxAsFloat)}]
  set vG [expr {int($maxRgbVal * $iG / $maxIdxAsFloat)}]
  set vB [expr {int($maxRgbVal * $iB / $maxIdxAsFloat)}]
  return  1
}


# Returns index of HALD line for for given RGB indices - starting from 0
# Example-01:  set idxList {0 1 0};  if {[hald_rgb_indices_to_line_idx  3  {*}$idxList  lineIdx]}  {puts "{$idxList} -> $lineIdx"}
# Example-02:  foreach i {0 1 2 3}  {foreach j {0 1 2 3}  {foreach k {0 1 2 3}  { set idxList [list $k $j $i];  if {[hald_rgb_indices_to_line_idx  2  {*}$idxList  lineIdx]}  {puts "{$idxList} -> $lineIdx"} } }}
proc ::img_proc::hald_rgb_indices_to_line_idx {level  iR iG iB  iLine}  {
  upvar $iLine haldLineIdx
  if { ![_hald_verify_rgb_indices $level -1  $iR $iG $iB  1] }  {
    return  0;  # error(s) already printed
  }
  set gradLen [expr {$level * $level}]
  set haldLineIdx [expr {$iR  +  $gradLen * $iG  +  $gradLen * $gradLen * $iB}]
  return  1
}


# Example-01:  set idxList {0 1 0};  if {[hald_rgb_indices_to_xy  3  {*}$idxList  x y]}  {puts "{$idxList} -> $x $y"}
# Example-02:  foreach i {0 1 2 3}  {foreach j {0 1 2 3}  {foreach k {0 1 2 3}  { set idxList [list $k $j $i];  if {[hald_rgb_indices_to_xy  2  {*}$idxList  x y]}  {puts "{$idxList} -> $x,$y"} } }}
proc ::img_proc::hald_rgb_indices_to_xy {level  iR iG iB  x y}  {
  upvar $x xCoord
  upvar $y yCoord
  if { ![hald_rgb_indices_to_line_idx $level  $iR $iG $iB  haldLineIdx] }  {
    return  0;  # error(s) already printed
  }
  set gradLen [expr {$level * $level}]
  set width   [expr {$level * $level * $level}]
  set yCoord  [expr {$haldLineIdx / $width}];  # integer division !
  set xCoord  [expr {$haldLineIdx % $width}]
  return  1
}


proc ::img_proc::_hald_verify_rgb_indices {level maxRgbValOrNeg  iR iG iB  \
                                                                 {loud 1}} {
  set levelOK [expr { (1 <= $level) && ($level <= 16) &&  \
                        (int($level) == $level) }]
  set gradLen [expr {$level * $level}]
  set maxIdxAsFloat [expr {$gradLen - 1.0}]
  set maxValOK [expr { ($maxRgbValOrNeg < 0) ||                                \
                       ($maxRgbValOrNeg == 255) || ($maxRgbValOrNeg == 65535) }]
  set idxOK [expr { ($iR >= 0) && ($iR <= $maxIdxAsFloat) &&  \
                    ($iG >= 0) && ($iG <= $maxIdxAsFloat) &&  \
                    ($iB >= 0) && ($iB <= $maxIdxAsFloat) }]
  if { $loud }  {
    if { !$levelOK }  {
      ok_err_msg "HALD level must be an integer in \[1 .. 16\] range; got $level"
    }
    if { !$maxValOK }  {
      ok_err_msg "Max color channel value must be 255 or 65535, or <0 if irrelevant; got $maxRgbValOrNeg"
    }
    if { !$idxOK }  {
      ok_err_msg "HALD channel index for level $level must be \[0 ... [expr int($maxIdxAsFloat)]\]"
    }
  }
  return [expr {$levelOK && $maxValOK && $idxOK}]
}


# Reads HALD from either proprietary ImageMagick image-text-file format or PPM
proc ::img_proc::hald_read_from_text_file {haldTxtFilePath \
                                             haldListVar haldLevelVar}  {
  upvar $haldListVar  haldList
  upvar $haldLevelVar haldLevel
  if { ![ok_read_commented_list_from_file haldList $haldTxtFilePath "#"] }  {
    return  0;  # error already printed
  }
  set ext [file extension $haldTxtFilePath]
  if {       [string equal -nocase $ext ".TXT"] }  { ; # ImageMagick-TXT; 
  } elseif { [string equal -nocase $ext ".PPM"] }  { ; # PPM
    # the data begins after a separate line with maxRgbVal - either 255 or 65535
    set idxOfMaxRgbVal -1
    for {set i 1}  {$i < 22}  {incr i}  { ; # search maxVal in reasonable prefix
      if { [regexp  {^\s*(\d+)\s*$}  [lindex $haldList $i]  all maxRgbVal]  &&  \
                              (($maxRgbVal == 255) || ($maxRgbVal == 65535)) }  {
        set idxOfMaxRgbVal $i;  break
      }
    }
    if { $idxOfMaxRgbVal == -1 }  {
      ok_err_msg "Invalid format for HALD list in PPM file '$haldTxtFilePath' - missing line with max channel value in the header"
      return  0
    }
    puts "@@ PPM HALD data starts after index $idxOfMaxRgbVal"
    set haldList [lrange $haldList  [expr $idxOfMaxRgbVal +1]  end]
  } else {
    ok_err_msg "Allowed HALD text formats are TXT or PPM; got '$ext'"
    return  0
  }
  set haldLevel [expr sqrt( round(pow([llength $haldList], 1.0/3)) )]
  if { ($haldLevel > [expr 16*16]) || (int($haldLevel) != $haldLevel) }  {
    ok_err_msg "Invalid size for HALD list - [llength $haldList]; the level would be $haldLevel; instead should be integer in \[1 .. 16\] range"
    return  0
  }
  set haldLevel [expr int($haldLevel)]
  ok_info_msg "Success reading HALD list of level $haldLevel - [llength $haldList] color(s)"
  return  1
}
## Verify HALD indices with:  foreach i {0 1 end}  {puts "[lindex $h16Orig $i]"}


proc ::img_proc::hald_calc_level_for_hald_list {haldList}  {
  return  [hald_calc_level_for_hald_list_length [llength $haldList]]
}


proc ::img_proc::hald_calc_level_for_hald_list_length {haldListLength}  {
  set haldLevel [expr sqrt( round(pow($haldListLength, 1.0/3)) )]
  if { ($haldLevel > [expr 16*16]) || (int($haldLevel) != $haldLevel) }  {
    ok_err_msg "Invalid size for HALD list - $haldListLength; the level would be $haldLevel; instead should be integer in \[1 .. 16\] range"
    return  0
  }
  set haldLevel [expr int($haldLevel)]
}


# Reads data-line from either proprietary ImageMagick image-text-file format or PPM
# Returns rgb list from line like: "1,0: (31,0,0)  #1F0000  srgb(31,0,0)"
# On error returns 0.
## !!! Essentially it deals with standard ImageMagick image-text-file format !!!
proc ::img_proc::hald_parse_srgb_line {haldLine  x y  r g b}  {
  upvar $x xx;  upvar $y yy
  upvar $r rr;  upvar $g gg;  upvar $b bb
  variable _HALD_FORMAT_TXT_OR_PPM
  if { $_HALD_FORMAT_TXT_OR_PPM == 0 }  { ; # ImageMagick-TXT
    set isOK [regexp {^(\d+),(\d+): +\((\d+),(\d+),(\d+)\)}  $haldLine  \
                                                         all  xx yy  rr gg bb]
  } elseif { $_HALD_FORMAT_TXT_OR_PPM == 1 }  { ; # PPM
    set isOK [regexp {^(\d+) (\d+) (\d+)}  $haldLine     all         rr gg bb]
    set xx -1;  set yy -1; # PPM format doesn't provide coordinates
  } else { error "_HALD_FORMAT_TXT_OR_PPM must be 0 or 1; got $_HALD_FORMAT_TXT_OR_PPM" }
  if { !$isOK  }  {
    ok_err_msg "Invalid HALD list line '$haldLine'"
    return  0
  }
  return  1
}


# Makes either proprietary ImageMagick image-text-file format or PPM
# Returns line like:
#   "1,0: (31,0,0)  #1F0000  srgb(31,0,0)" for _HALD_FORMAT_TXT_OR_PPM == 0
#      or
#   "31 0 0"                               for _HALD_FORMAT_TXT_OR_PPM == 1
proc ::img_proc::hald_format_srgb_line {x y  r g b}  {
  variable _HALD_FORMAT_TXT_OR_PPM
  if { $_HALD_FORMAT_TXT_OR_PPM == 0 }  { ; # ImageMagick-TXT
    return  [format  {%d,%d: (%d,%d,%d)  #%02X%02X%02X  srgb(%d,%d,%d)}  \
             $x $y    $r $g $b    $r $g $b    $r $g $b]
  } elseif { $_HALD_FORMAT_TXT_OR_PPM == 1 }  { ; # PPM
    return  [format  {%d %d %d}  $r $g $b]
  } else { error "_HALD_FORMAT_TXT_OR_PPM must be 0 or 1; got $_HALD_FORMAT_TXT_OR_PPM" }
}


# Returns list of HALD-file header lines
proc ::img_proc::_hald_format_header {level maxRgbVal}  {
  variable _HALD_FORMAT_TXT_OR_PPM
  set gradLen [expr {$level * $level}]
  set imgSide [expr {$level * $level * $level}]
  set imgSize [expr {$imgSide * $imgSide}]
  set hdrLines [list]
  if { $_HALD_FORMAT_TXT_OR_PPM == 0 }  { ; # ImageMagick-TXT
    lappend hdrLines "# ImageMagick pixel enumeration: $imgSide,$imgSide,$maxRgbVal,srgb";  # was: "... : $imgSide,$imgSide,0,$maxRgbVal,srgb"
  } elseif { $_HALD_FORMAT_TXT_OR_PPM == 1 }  { ; # PPM
    lappend hdrLines  "P3 $imgSide $imgSide"    "# HALD of level $level - made by Anaglyph HALD Generator"    "$maxRgbVal"
  } else { error "_HALD_FORMAT_TXT_OR_PPM must be 0 or 1; got $_HALD_FORMAT_TXT_OR_PPM" }
  return  $hdrLines
}


proc ::img_proc::hald_txt_or_ppm {extension}  {
  upvar $extension ext
  variable _HALD_FORMAT_TXT_OR_PPM
  if { $_HALD_FORMAT_TXT_OR_PPM == 0 }  { ; # ImageMagick-TXT
    set ext "TXT";  return  0
  } elseif { $_HALD_FORMAT_TXT_OR_PPM == 1 }  { ; # PPM
    set ext "PPM";  return  1
  } else { error "_HALD_FORMAT_TXT_OR_PPM must be 0 or 1; got $_HALD_FORMAT_TXT_OR_PPM" }
}


# Returns list of (irgb) colors in 'haldList' or 0 on error.
proc ::img_proc::hald_list_to_colors_list {haldList}  {
  set n [llength $haldList]
  set irgbList [list]
  for {set i 0}  {$i < $n}  {incr i 1}  {
    if { 0 == [hald_parse_srgb_line [lindex $haldList $i]  x y  r g b] }  {
      ok_err_msg "Invalid 1st HALD list line #$i:  '[lindex $haldList $i]'"
      return  0
    }
    lappend irgbList [list $i $r $g $b]
  }
  return  $irgbList
}


# Returns list of "differing" indices or 0 on error.
proc ::img_proc::hald_find_text_files_diff {haldTxtFile1 haldTxtFile2}  {
  if { ![hald_read_from_text_file $haldTxtFile1 haldList1 haldLevel1] }  {
    return  0;  # error already printed
  }
  if { ![hald_read_from_text_file $haldTxtFile2 haldList2 haldLeve2] }  {
    return  0;  # error already printed
  }
  return  [hald_find_lists_diff $haldList1 $haldList2]
}


# Returns list of "differing" indices or 0 on error.
proc ::img_proc::hald_find_lists_diff {hList1 hList2}  {
  set n1 [llength $hList1];  set n2 [llength $hList2]
  if { $n1 != $n2 }  {
    ok_err_msg "Cannot compare HALD lists of different lengths - $n1, $n2"
    return  0
  }
  set diffIdxList [list]
  for {set i 0}  {$i < $n1}  {incr i 1}  {
    if { 0 == [hald_parse_srgb_line [lindex $hList1 $i]  x1 y1  r1 g1 b1] }  {
      ok_err_msg "Invalid 1st HALD list line #$i:  '[lindex $hList1 $i]'"
      return  0
    }
    if { 0 == [hald_parse_srgb_line [lindex $hList2 $i]  x2 y2  r2 g2 b2] }  {
      ok_err_msg "Invalid 2nd HALD list line #$i:  '[lindex $hList2 $i]'"
      return  0
    }
    if { ($x1 != $x2) || ($y1 != $y2) ||  \
           ($r1 != $r2) || ($g1 != $g2) || ($b1 != $b2) }  {
      lappend diffIdxList $i
    }
  }
  set nDiffs [llength $diffIdxList]
  if { $nDiffs == 0 }  {
    ok_info_msg "Found no diff-s in HALD lists of length $n1"
  } else {
    ok_info_msg "Found $nDiffs diff-s in HALD lists of length $n1"
  }
  return  $diffIdxList
}


## Example:  hald_get_space_for_level_kb  8  forTxt forTif forAll;  puts "=> $forTxt $forTif $forAll"
proc ::img_proc::hald_get_space_for_level_kb {level  \
                                                forTxtVar forTifVar forAllVar}  {
  upvar $forTxtVar forTxt
  upvar $forTifVar forTif
  upvar $forAllVar forAll
  variable _HALD_FORMAT_TXT_OR_PPM
  if { ($level < 2) || ($level > 16) }  {
    ok_err_msg "Invalid HALD level $level. Allowed range is \[2..16\]."
    return  0
  }
  # full sizes' table for hald-levels [2..16] built experimentally
  set haldLevelToTxtAndPpmAndTifRawSizesInBytes [dict create  \
     2   {2953       1024           400}  \
     3   {34543      9216          1282}  \
     4   {197023     50176         4340}  \
     5   {759665     191488       12788}  \
     6   {2302599    571392       30344}  \
     7   {5855297    1442816      63536}  \
     8   {13095489   3211264     101928}  \
     9   {26609737   6506496     232816}  \
    10   {50187179   12259328    409372}  \
    11   {89853923   21700608    587912}  \
    12   {152594521  36578304   1018518}  \
    13   {248065585  59165696   1509178}  \
    14   {388449897  92277760   2340214}  \
    15   {589438673  139630592  3382284}  \
    16   {870303297  205742080  3477592}              ]
  
  lassign [dict get $haldLevelToTxtAndPpmAndTifRawSizesInBytes $level]  \
                                                          bTxt bPpm  bTif
  set bTmp [expr {($_HALD_FORMAT_TXT_OR_PPM == 0)?  $bTxt : $bPpm}]
  set forTxt [expr {int(ceil(1.05 * $bTmp /1024.0))}];  # kb with 5% spare
  set forTif [expr {int(ceil(1.05 * $bTif /1024.0))}];  # kb with 5% spare
  set forAll [expr {$forTxt + $forTif}]
  return  1
}
