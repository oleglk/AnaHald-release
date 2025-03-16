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

# depth_test.tcl - utilities to generate synthetic depth-test charts. Adopted from "StereoView/Lenticular/Lenticular_TCL/depth_test.tcl" 

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    # source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}


namespace eval ::img_proc:: {
  namespace export                          \
    SetDirectPixelIntent                      \
    MakeDepthChart                            \
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
source [file join $IMGPROC_DIR "image_metadata.tcl"]


################################################################################
proc ::img_proc::_DepthChartFileName {wd ht depthMmList ext}  {
  set charReplaceMap {"." "d"  "-" ""  "+" ""};   # needed to replace ./+/-
  set minD [format "%+3.1f" [lindex $depthMmList   0]]
  set maxD [format "%+3.1f" [lindex $depthMmList end]]
  set minStr [string map $charReplaceMap $minD]
  set maxStr [string map $charReplaceMap $maxD]
  set pureName [format "depth3Dchart_%ddpi_%dx%d_%sto%s" \
                        $::DENSITY [expr $wd/2] $ht $minStr $maxStr]
  return  "$pureName.$ext"
}


#### a special "intent" for test images on any device - pixels as units
proc ::img_proc::SetDirectPixelIntent {}  {
  ####### BEGIN: intent content #################################################
  set ::CANVAS_DIRECT             {1280x720!}
  set ::DENSITY_DIRECT            {1};   # [expr $::DENSITY_Z5P * 12.0 / 31]
  set ::GUIDELINES_DIRECT         {}
  # span-line spans known integer number of lens-columns (= 2 * image-columns)
  set ::DOTSINCOLUMN_DIRECT       {1}; #ZZ pixel-width of one-perspective columm
  set ::SPANLINES_DIRECT          {}
  set ::TEXT_STROKE_WIDTH_DIRECT  {3}; # like P83D
  set ::FONTWEIGHT_DIRECT         {Thin}; # like P83D
  set ::TEXT_POINTSIZE_DIRECT     {50}; # experimentally
  set ::MAGNIFICATION_DIRECT      {1.0};  # like P83D
  set ::REVERSE_DIRECT            {0};  #ZZ order reversal required for lenticulars
  set ::ROTATE_DIRECT             {0};  #ZZ like P83D 
  set ::BW_NEGATIVE_DIRECT        {0};  #ZZ to print on regular B&W paper
  ####### END:   intent content #################################################
  _SetIntent "DIRECT"
}


# Generates depth-test chart for disparities (in mm) from 'depthMmList'.
# Geometry is computed for the current output "intent".
# Note, width sent for L+R
# Returns output-file-path or "" on error.
#### (How to see available fonts:  exec $::IMCONVERT -list font > fonts_list.txt)
# Example-1: 
## cd [file normalize {D:\DC_TMP\TryDT}]
## ::lpi_test::_SetIntent PRI600;       depth_test::MakeDepthChart 4096 2048 {-3 -2.5 -2 -1.5 -1 0 1 1.5 2 2.5 3 3.5} "."
## ::lpi_test::_SetIntent QUADHD_H;  depth_test::MakeDepthChart 3072 1536 {-3 -2.5 -2 -1.5 -1 0 1 1.5 2 2.5 3 3.5} "."
## set wd [expr 6.0 * 300/2.54];  set ht [expr $wd / 2.0 * 4/3];  ::lpi_test::_SetIntent STCARDPRI300;  depth_test::MakeDepthChart [expr int($wd)] [expr int($ht)] {-3 -2.5 -2 -1.5 -1 0 1 1.5 2 2.5 3 3.5} "."
# Example-2:
## set _IM_DIR "C:/Program\ Files/Imagemagick_711_3/";     ::img_proc::SetDirectPixelIntent;       img_proc::MakeDepthChart 1280 640 {-50 -40 -30 -20 -10 0 10 20 30 40 50} "./TMP"
proc ::img_proc::MakeDepthChart {wd ht depthMmList outDir}  {
  # if { ![lpi_test::_VerifyToolsAvailability] || ![lpi_test::_VerifyIntent] }  { return "" }

  set dpi       [expr $::DENSITY / $::MAGNIFICATION]
  set unitsStr  [expr {($::DENSITY == 1.0)? "px" : "mm"}]
  set dotsPerMm [expr {($::DENSITY == 1.0)? 1.0 : ($dpi / 25.4)}]
  # 'bgRectDef' <= arguments to build the background gray rectangle
  set bgRectDef [format "-size %dx%d xc:rgb(225,225,225)" $wd $ht];  #?-depth 8?

  set strokeDef  "-stroke black -strokewidth $::TEXT_STROKE_WIDTH -pointsize $::TEXT_POINTSIZE -antialias -weight $::FONTWEIGHT -font {DejaVu-Sans}"; # TODO: put into intent

  set nLines [llength $depthMmList]
  #set y1 200;  
  set y1 [expr 1.0 * $ht / ([llength $depthMmList] + 1)]
  set dy [expr {int(($ht - 1.0 * $y1) / $nLines)}]
  
  # horizontal text offsets for zero-parallax line
  set xZeroL [expr {int(0.25 * $wd - 0.17 * $wd)}]
  #set xZeroL [expr {int(0.03 * $wd)}]
  set xZeroR [expr {int(0.50 * $wd + $xZeroL)}] 

  # parallax < 0: move left text leftwards, move right text rightwards
  # parallax > 0: move left text rightwards, move right text leftwards
  
  set linesParams "";   # for a list of per-line parameters
  for {set i 1} {$i <= $nLines}  {incr i 1}  {
    set dMm_i [lindex $depthMmList [expr $i-1]];  # disparity/parallax in mm
    set dPx_i [expr {int($dMm_i * $dotsPerMm)}];  # disparity/parallax in dots
    #set sign_i [expr {($dMm_i != 0)?  ($dMm_i / abs($dMm_i))  :  0}]
    set y_i [expr int($y1 + ($i - 1) * $dy)];   # TODO: ?why? *0.5 ???
    set xL_i [expr {int($xZeroL + 0.5 * $dPx_i)}]
    set xR_i [expr {int($xZeroR - 0.5 * $dPx_i)}]
    set geomL_i [format "359x359+%d+%d" $xL_i $y_i]   ; # 359x359 == rotation
    set geomR_i [format "359x359+%d+%d" $xR_i $y_i] ; # 359x359 == rotation
    append linesParams [format                                             \
      "  -annotate %s \"disparity==%+3.1f%s\" -annotate %s \"disparity==%+3.1f%s\""  \
      $geomL_i $dMm_i $unitsStr $geomR_i $dMm_i $unitsStr]
  }
 
  set outPath [file join $outDir [_DepthChartFileName $wd $ht $depthMmList "BMP"]]
  # intermediate PPM format prevents original-color-depth of 16 bits-per-pixel
###  set cmd "$::IMCONVERT $bgRectDef  $strokeDef  $linesParams  -depth 8  -density $::DENSITY  bmp:- | {$::IMCONVERT} ppm:-  -depth 8  -density $::DENSITY -compress LZW  $outPath"
#   set cmd "$::IMCONVERT $bgRectDef  $strokeDef  $linesParams  -depth 8  -density $::DENSITY -compress LZW  $outPath"
   set cmd "$::IMCONVERT   $bgRectDef  $strokeDef  $linesParams  -depth 8  -density $::DENSITY  $outPath"

  puts "Going to create depth-chart in '$outPath'; command:   '$cmd'"
  exec {*}$cmd

  if { [info exists ::_IM_DIR] }  {
    if { 0 == [img_proc::check_image_integrity_by_imagemagick $outPath] }  {
      ok_err_msg "Corrupted output depth-chart image in '$outPath'"
      return  ""
    }
  } else {
    ok_warn_msg "Will not verify depth-chart image; missing path for Imagemagick 'identify' utility"
  }
  ok_info_msg "Generated depth-chart image in '$outPath'"
  return  $outPath
}
######################
## How to make stereo anaglyph from side-by-side image in one command:
##    convert SBS/DSC03172.jpg -crop 50%x100% -swap 0,1 -define compose:args=20 -compose stereo -composite -quality 90 ANA/DSC03172_FCA_STRAIGHT.JPG
######################


# Creates quadratic SBS depth-chart in outDir
## ::lenticular::ex__ANY_make_depthtest_interlaced  P83D  {-3 -2.5 -2 -1.5 -1 0 1 1.5 2 2.5 3 3.5}  "."
proc img_proc::MakeDepthChartForIntent {intentName depthMmList outDir}  {
#::img_proc::_SetIntent QUADHD_H;  depth_test::MakeDepthChart 3072 1536 {-3 -2.5 -2 -1.5 -1 0 1 1.5 2 2.5 3 3.5} "."
  if { 0 == [img_proc::_SetIntent $intentName] }  {
    return  "";  # error already printed
  }
  if { 0 == [img_proc::_GetIntentDimensions canvWd canvHt] }  {
    return  "";  # error already printed
  }
  # make a quadratic original SBS
  set wd [expr min($canvWd/2, $canvHt)];  set ht $wd
  ##set wd [expr min($canvWd/2, $canvHt)];  set ht $canvHt
  if { "" == [set sbsPath [depth_test::MakeDepthChart [expr 2*$wd] $ht \
                                                      $depthMmList $outDir]] } {
    return  "";  # error already printed
  }
  return  $sbsPath
}


proc ::img_proc::_EXAMPLE__make_direct_depth_charts {}  {
  # set _IM_DIR "C:/Program\ Files/Imagemagick_711_3/";     ::img_proc::SetDirectPixelIntent;       img_proc::MakeDepthChart 1280 640 {-50 -40 -30 -20 -10 0 10 20 30 40 50} "./TMP"
  set depthPxListOfLists  [list                             \
    [lsort -integer -increasing { 0  -3  -6  -9 -12 -15 -18 -21 -24 -27 -30 }]  \
    {                             0   3   6   9  12  15  18  21  24  27  30 }   \
    [lsort -integer -increasing { 0  -5 -10 -15 -20 -25 -30 -35 -40 -45 -50 }]  \
    {                             0   5  10  15  20  25  30  35  40  45  50 }   \
    {                           -50 -40 -30 -20 -10   0  10  20  30  40  50 }
                          ]
  puts "@@ [join $depthPxListOfLists \n]"

  img_proc::SetDirectPixelIntent
  foreach dl $depthPxListOfLists  {
    set sbsPath [img_proc::MakeDepthChart 1280 640 $dl "./TMP"]
    if { $sbsPath != "" }  {
      set sbsNameNoExt [file rootname [file tail $sbsPath]]
      exec $::IMCONVERT  $sbsPath -crop 50%x100% -swap 0,1 -define compose:args=20 -compose stereo -composite -quality 80 [file join "./TMP" "${sbsNameNoExt}.JPG"]
    }
  }
}



#################################################################################
# Adopted from lpi_test::_SetIntent
proc ::img_proc::_SetIntent {outIntentSuffix}  {
  foreach param {"CANVAS" "DENSITY" "GUIDELINES" "SPANLINES" \
                 "FONTWEIGHT" "REVERSE" "ROTATE" "BW_NEGATIVE" \
                 "TEXT_STROKE_WIDTH" "TEXT_POINTSIZE" "MAGNIFICATION"}  {
    set varName [format "::%s_%s" $param $outIntentSuffix]
    puts "About to set ::$param to $$varName"
    if { ! [info exists $varName] }   {
      puts "*** Missing '$varName' (unknown output intent '$outIntentSuffix'?)"
      return  0
    }
    set val  [set  "::$param"  [subst "$$varName"]]
    puts "Assigned ::$param to '$val'"
  }
  return  1
}


################ Internal utilities ############################################
#~ proc depth_test::_VerifyToolsAvailability {}  {
  #~ if { ![info exists ::IMCONVERT] }   {
    #~ puts "*** Please set ::IMCONVERT to the path of Imagemagick 'convert' utility"
    #~ return  0
  #~ }
  #~ if { ![file exists $::IMCONVERT] }  {
    #~ puts "*** Inexistent 'convert' utility ($::IMCONVERT)";  return 0
  #~ }
  #~ return  1
#~ }


################################################################################
#~ ### TODO: hoose font weight by intent; only strokewidth isn't enough.

#~ -weight fontWeight
#~ Set a font weight for text.

#~ This setting suggests a font weight that ImageMagick should try to apply to the currently selected font family. Use a positive integer for fontWeight or select from the following.
#~ Thin Same as fontWeight = 100
#~ ExtraLight Same as fontWeight = 200
#~ Light Same as fontWeight = 300
#~ Normal Same as fontWeight = 400
#~ Medium Same as fontWeight = 500
#~ DemiBold Same as fontWeight = 600
#~ Bold Same as fontWeight = 700
#~ ExtraBold Same as fontWeight = 800
#~ Heavy Same as fontWeight = 900

#~ To print a complete list of weight types, use -list weight.
################################################################################


