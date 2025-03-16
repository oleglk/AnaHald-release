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

# image_annotate.tcl
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
source [file join $IMGPROC_DIR  "image_metadata.tcl"]
source [file join $IMGPROC_DIR  "special_char_subst.tcl"]
source [file join $IMGPROC_DIR  "labels_csv.tcl"]

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"
}


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
  namespace export                            \
    annotate_image_zone_values                \
    annotate_image_by_spec                    \
    clean_image_by_spec                       \
    annotate_image_by_csv                     \
    clean_image_by_csv                        \
    annotate_image_coordinates                \
    generate_colorchart_from_list             \
    prefix_outspec                            \
}

set ::_CMD_LENGTH_LIMIT [expr {("WINDOWS" == [ok_detect_os_type])?  \
                                                [expr 4*8192 - 50] : 99999}]

################################################################################
proc ::img_proc::_plain_string_CB {v} { return [format "%s" $v] }
proc ::img_proc::_float_to_string_CB {v} { return [format "%.2f" $v] }
proc ::img_proc::_float_to_floor_string_CB {v} {  \
                                   return [format "%d" [expr {int(floor($v))}]] }


# 'valDict' = dictionary {row,column :: numeric-value
# Output file created in 'outDir' or the current directory.
## Example1:  img_proc::annotate_image_zone_values  V24d2/DSC00589__s11d0.JPG  {0 {0 11 1 12 2 13}  1 {0 21 1 22 2 23}}  "_a2x3"  "OUT"  img_proc::_float_to_string_CB
## Example2:  img_proc::annotate_image_zone_values  V24d2/DSC00589__s11d0.JPG  {0 {0 11 1 12 2 13 3 14 4 15}  1 {0 21 1 22 2 23 3 24 4 25}}  "_a2x5"  "OUT"  img_proc::_float_to_string_CB
proc ::img_proc::annotate_image_zone_values {imgPath valDict outNameSuffix  \
                  outDir {formatCB img_proc::_plain_string_CB}}  {
  # detect annotation-grid dimensions
  set maxBandIdx -1;  set maxStepIdx  -1
  dict for {y x_v} $valDict  {
    dict for {x v} $x_v {
      if { $y > $maxBandIdx }   { set maxBandIdx $y }
      if { $x > $maxStepIdx }   { set maxStepIdx $x }
    }
  }
  set numBands [expr $maxBandIdx + 1];  set numSteps [expr $maxStepIdx + 1]
  ## do not read pixel-data here
  #~ if { 0 == [set pixels [img_proc::read_pixel_values  \
                                    #~ $imgPath $numBands $numSteps 1]] }  {
    #~ return  0
  #~ }
  set outName [format "%s%s.jpg" \
                          [file rootname [file tail $imgPath]]  $outNameSuffix]
  if { $outDir == "" }  { set outDir [pwd] }
  if { !([file exists $outDir] && [file isdirectory $outDir]) }   {
    ok_err_msg "-E- Inexistent or invalid output directory '$outDir'; aborting"
    return  0
 }
  set outPath [file join $outDir $outName]
  set bXs [format {%dx%d} $numBands $numSteps]
  
  # compute text size and cell locations
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set textLength [string length [eval $formatCB 0.123456789]]
  set bandHeight  [expr int(      $imgHeight / $numBands)]
  set cellWidth   [expr int(      $imgWidth  / $numSteps)]
  set pointSize   [expr int( min(0.3*$imgHeight/$numBands, \
                                 0.9*$imgWidth/$numSteps/$textLength) )]

  ok_info_msg "Going to annotate image '$imgPath' with $bXs value grid; output into '$outPath'"
  
  set imAnnotateParam  " \
        -gravity northwest -stroke \"#000C\" -strokewidth 2 -pointsize $pointSize"
  for {set b 0}  {$b < $numBands}  {incr b 1}  {
    set y [expr {int( $b * $bandHeight  +  0.5*($bandHeight - $pointSize) )}]
    for {set s 0}  {$s < $numSteps}  {incr s 1}  {
      set x [expr {int( ($s * $cellWidth)  +  $pointSize)}]
      set txt [expr {[dict exists $valDict $b $s]?  \
                          [eval $formatCB [dict get $valDict $b $s]] : "---"}]
      append imAnnotateParam [format "  -annotate +%d+%d \"$txt\"" $x $y]
    }
  }
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set cmd "$::IMCONVERT  $imgPath  $imAnnotateParam  -depth 8 -quality 90 $outPath"
  ok_trace_msg "(Annotation command) ==> '$cmd'"
  #exec  {*}$cmd
  if { 0 == [ok_run_silent_os_cmd $cmd] }  {
    return  0; # error already printed
  }

  ok_info_msg "Created image '$outPath' annotated with $bXs value grid"
  return  1
}


################ TODO: Read "Font size and dpi" #################################
###  in  https://karttur.github.io/setup-theme-blog/blog/add-text-to-image/   ###
#################################################################################


# Imprints "labels" on image from 'inpImgPath'; saves according to 'outSpec'
# 'outSpec'             - a string with saving parameters and output path
# 'labelsListOfTriples' - list of 3|4-element lists of lists of:
#### {label-text ("" if none),  xCoordPrc,  yCoordPrc}
# 'fontSizes'  - 3|4-element list of font sizes to use for the 3|4 sets of labels
# 'fontColors' - 4|5-element list of:
#### {background-color,  color1,  color2,  color3[,  color4]} to use for the 3|4 sets of labels.
# Returns 1 on success, 0 on error
## Example 1:
## img_proc::annotate_image_by_spec  "KBD/K400p_01__SNAP__eng_heb.png"  "TMP/try13.png"  {{{"E" 24 32} {"" 0 0} {"" 0 0}}  {{"0" 76 19} {")" 76 13} {"" 0 0}}}    {22 22 18}    {rgb(250,250,250) Red Green Blue}
## Example 2:
## img_proc::annotate_image_by_spec  "KBD/K400p_01__SNAP__eng_heb.png"  "TMP/try14.png"  {{{"E" 24 32} {"" 0 0} {"" 0 0} {"Y" 46 31}}  {{"0" 76 19} {")" 76 13} {"" 0 0} {"" 0 0}}}    {22 22 18 26}    {rgb(250,250,250) Red Green Blue Orange}
##############
#### Sample directive for one sub-label: {  -stroke "rgb(0,0,0)" -pointsize 12 -annotate +158+142 "E"}
#### Length of one directive ~60 characters.
####-- Aassuming 60 keys to override, 3 labels per key, 69 * 3 * 60 = 12420 > 8192
####-- Or: 35 keys with 3 labels, 25 keys with 2 labels: (35*3 + 25*2) *60 = 9300 > 8192
####-- 3 ABC-s, digits not overriden: 35 keys with 3 labels, 15 keys with 2 labels, 10 keys with 1 label: (35*3 + 15*2 + 10) *60 = 8700 > 8192
####++ 2 ABC-s, digits not overriden: 35 keys with 2 labels, 15 keys with 2 labels, 10 keys with 1 label: (35*2 + 15*2 + 10) *60 = 6600 < 8192
proc ::img_proc::annotate_image_by_spec {inpImgPath outSpec \
                          labelsListOfTriples fontSizes fontColors \
                          {fontNames {"" "" "" ""}}}  {
  return  [_annotate_image_by_spec 1 $inpImgPath $outSpec \
         $labelsListOfTriples $fontSizes $fontColors $fontNames]
}
proc ::img_proc::clean_image_by_spec {inpImgPath outSpec \
                                labelsListOfTriples fontSizes fontColors}  {
  return  [_annotate_image_by_spec 0 $inpImgPath $outSpec \
             $labelsListOfTriples $fontSizes $fontColors {"" "" "" ""}]
}


## Example (test - RGB overrides on original labels):    img_proc::annotate_image_by_csv  "KBD/K400_2__SNAP__eng.png" LNX/MOD/K400_2__ORIG__eng.csv  TMP/try_k400_eng.png  {20 20 16}    {rgb(250,250,250) rgb(255,0,0) rgb(0,255,0) rgb(0,0,255)}
## Example (production - mostly black labels over cleaned image):  img_proc::annotate_image_by_csv  "KBD/cln__K400_2__eng.png"  "LNX/MOD/K400_2__ORIG__eng.csv"  TMP/k400_eng.png  {20 20 16}    {rgb(250,250,250) rgb(0,0,0) rgb(0,0,0) rgb(0,0,255)}
## Example (minimal):  img_proc::annotate_image_by_csv  "KBD/K400p_01__SNAP__eng_heb.png"  INP/try_in.csv  "TMP/try_csv_out_1.png"  {18 18 16}    {rgb(250,250,250) rgb(255,0,0) rgb(0,255,0) rgb(0,0,255)}
## Example (production - bold primary, normal secondary labels over cleaned image):  img_proc::annotate_image_by_csv  "KBD/cln__K400_2__eng.png"  "LNX/MOD/K400_2__REPL__eng_heb__UTF16_4sets.csv"  TMP/k400_eng_heb.png  {20 20 16 18}    {rgb(250,250,250) rgb(0,0,0) rgb(0,0,0) rgb(0,0,255) Brown}
proc ::img_proc::annotate_image_by_csv {inpImgPath csvPath \
         outSpec fontSizes fontColors {fontNames {"" "" "" ""}}}  {
  return  [_annotate_image_by_csv 1 $inpImgPath $csvPath \
             $outSpec $fontSizes $fontColors $fontNames]
}


## Example:  img_proc::clean_image_by_csv  "KBD/K400_2__SNAP__eng.png"  "LNX/MOD/K400_2__ORIG__eng.csv"  TMP/cln__K400_2__eng.png  {20 20 16}    {rgb(250,250,250) rgb(0,0,0) rgb(0,0,0) rgb(0,0,0)}
proc ::img_proc::clean_image_by_csv {inpImgPath csvPath \
                                     outSpec fontSizes fontColors}  {
  return  [_annotate_image_by_csv 0 $inpImgPath $csvPath \
             $outSpec $fontSizes $fontColors {"" "" "" ""}]
}


proc ::img_proc::_annotate_image_by_csv {cleanOrWrite inpImgPath csvPath \
         outSpec fontSizes fontColors  {fontNames {"" "" "" ""}}}  {
  ##puts "@_annotate_image_by_csv@ cleanOrWrite=$cleanOrWrite fonts: {$fontNames}"
  set cntInvalid 0
  if { 0 == [set labelsListOfTriples \
               [csv_to_label_list_of_triples $csvPath cntInvalid]] }  {
    return  0;  # error already printed
  }
  # the 1st line believed to be the CSV header
  set res [_annotate_image_by_spec $cleanOrWrite $inpImgPath $outSpec \
             [lrange $labelsListOfTriples 1 end]          \
             $fontSizes $fontColors $fontNames]
  if { $cntInvalid > 0 }  {
    ok_warn_msg "Note, $cntInvalid invalid label(s) skipped"
  }
  return  $res
}


### Note, cleaning by printing "space" doesn't work !!!

# Imprints "labels" on image from 'inpImgPath'; saves according to 'outSpec'
## 'cleanOrWrite'==0 - clean by printing spaces in place of labels
## 'cleanOrWrite'==1 - print the actual labels
# 'outSpec'             - a string with saving parameters and output path
# 'labelsListOfTriples' - list of 3-element lists of lists of:
#### {label-text ("" if none),  xCoordPrc,  yCoordPrc}
# 'fontSizes'  - 3|4-element list of font sizes to use for the 3|4 sets of labels
# 'fontColors' - 4|5-element list of:
#### {background-color,  color1,  color2,  color3[,  color4]} to use for the 3|4 sets of labels.
# 'fontNames'  - list of 3|4 enforced font names per sublabels' sets 0/1/2[/3]
# Returns 1 on success, 0 on error
proc ::img_proc::_annotate_image_by_spec {cleanOrWrite inpImgPath outSpec \
          labelsListOfTriples fontSizes fontColors {fontNames {"" "" "" ""}}}  {
  ##puts "@_annotate_image_by_spec@ cleanOrWrite=$cleanOrWrite fonts: {$fontNames}"
  # check consistency of assumed number of sublabel sets (3|4)
  if { 0 == [set numSublabelsInLabel \
               [img_proc::label_list_of_triples_width $labelsListOfTriples]] }  {
    return  0;  # error already printed
  }
  if { [llength $fontSizes] < $numSublabelsInLabel }  {
    ok_err_msg "Please provide $numSublabelsInLabel font-size(s)"
    return  0
  }
  if { [llength $fontColors] < [expr $numSublabelsInLabel + 1] }  {
    ok_err_msg "Please provide backround-color and $numSublabelsInLabel font-color(s)"
    return  0
  }
  if { [llength $fontNames] < $numSublabelsInLabel }  {
    ok_err_msg "Please provide $numSublabelsInLabel font-name(s)"
    return  0
  }
  set cleanPad 4;  # in "cleaning" mode add 'cleanPad' dots at each side
  incr cleanPad -1;  # account for clean by 9 shifted repetitions of same string
  set bold [expr {($cleanOrWrite != 0)?  "-weight Normal" : "-weight Heavy"}]

  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $inpImgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  if { 0 == [ok_create_absdirs_in_list                        \
               [list [img_proc::outspec_to_outdir $outSpec]] \
               [list "output directory"]] }  {
    return  0;  # error already printed
  }

  #img_proc::_choose_fixed_font fontName fontFamilyName
  set bgColor  [lindex $fontColors 0]
  set strokeWidth [expr {($cleanOrWrite != 0)? 1 : 4}]; # simulate clean by "@"
  # "-density 72" makes one point in font-size equal to one pixel
  set annotStrPref "-density 72 -gravity northwest -strokewidth $strokeWidth -background \"$bgColor\""

  # verify all labels and list invalid ones
  set badLabelTriplesList_j [list];  # j-s of invalid labels
  img_proc::label_list_of_triples_ok $labelsListOfTriples badLabelTriplesList_j

  # imprint the valid labels - in 'annotStr(<i>)'
  array unset annotStr
  set lCnt 0
  set lsRange [expr {($numSublabelsInLabel <= 3)? {0 1 2}  :  {0 1 2 3}}]
  foreach i $lsRange  { ;  # each subset goes to separate pipe-connected command
    set annotStr($i) $annotStrPref
    set pointSize [lindex $fontSizes $i]
    set pointSize [expr {($cleanOrWrite != 0)?  $pointSize  \
                           : [expr $pointSize +2*$cleanPad]}]
    set colorIdx  [expr {($cleanOrWrite != 0)? [expr $i + 1] : 0}]
    set color     [lindex $fontColors $colorIdx] ;  # #0 - background
    set fontNameAndFamily \
            [img_proc::_format_font_and_family_for_sublabel $i $fontNames]
    ok_trace_msg "Start processing sublabels #$i (color $color)"
    set subLabelCommon [format  \
      "    $fontNameAndFamily  -stroke \"%s\" -fill \"%s\" -pointsize %d $bold" \
      $color       $color          $pointSize]
    # postpone append' to the command until 1st verified sublabel found
    for {set j 0}  {$j < [llength $labelsListOfTriples]}  {incr j 1}  {
      set sublabelsList [lindex $labelsListOfTriples $j]
      # verify label structure
      if { [lsearch -exact -integer -sorted $badLabelTriplesList_j $j] >= 0 }  {
        ok_trace_msg "Skipped invalid label $j (at sublabel $i)"
        continue;  # error (non-trace) printed earlier
      }
      # all sub-labels in triple #j believed to be OK; imprint the one at #i now
      lassign [lindex $sublabelsList $i]  txt xPrc yPrc
      if { $txt == "" }  { continue };  # no text in this sublabel slot
      ok_trace_msg "Processing sublabel {'$txt' '$xPrc' '$yPrc'}"
      set padOr0 [expr {($cleanOrWrite == 0)? $cleanPad : 0}]
      set x [expr {int(floor($xPrc * $imgWidth  / 100.9 - $padOr0))}]
      set y [expr {int(floor($yPrc * $imgHeight / 100.9 - $padOr0))}]
      set str [expr {($cleanOrWrite != 0)?  $txt  \
                       :  [string repeat {@} [string length $txt]]}]
      # prepend: double-quote with 1 backslash, 'less' with 2 backslashes, etc.
      set str [string map -nocase  $img_proc::_SPECIAL_CHAR_SUBST_LIST  $str]
      if { $cleanOrWrite != 0 }  {
        set oneSubLabel [format "  -annotate +%d+%d \"%s\"" $x $y $str]
      } else {  ;  # clean by 9 shifted repetitions of the same string
        set oneSubLabel ""
        foreach xs [list [expr $x - 1]  $x  [expr $x + 1]]  {
          foreach ys [list [expr $y - 1]  $y  [expr $y + 1]]  {
            append oneSubLabel [format "  -annotate +%d+%d \"%s\"" $xs $ys $str]
          }
        }
      }
      # TODO: verify the length WILL BE < 8192
      ok_trace_msg "[expr {($cleanOrWrite != 0)? {Sub-label} : {CLEAN}}] #$j:$i = '$txt' at {$xPrc, $yPrc}, color $color ==> {$oneSubLabel}"
      if { $subLabelCommon != "" }  {; # header for sublabels at one index - once
        append annotStr($i) $subLabelCommon
        set subLabelCommon "";  # tell not to append it next time
      }
      set newLength [expr {[string length $annotStr($i)] + \
                           [string length $oneSubLabel]}]
      if { $newLength >= $::_CMD_LENGTH_LIMIT }  {
        ok_err_msg "Command length ($newLength) at component #$i (label #$j) exceeds the limit of $::_CMD_LENGTH_LIMIT"
        #ok_err_msg "Violating command would be: '$annotStr($i) $oneSubLabel'"
        return  0
      }
      append annotStr($i) $oneSubLabel
      incr lCnt 1
    };#__END_OF__loop_over_whole_list_for_one_sublabel_index
    ok_info_msg "Done processing sublabels #$i out of $lsRange (color $color); command length: [string length $annotStr($i)]"
  };#__END_OF__loop_over__sublabel_indices

  #set cmd "$::IMCONVERT  $inpImgPath    $annotStr    $outSpec"
  # IMPORTANT: Space between | and $::IMCONVERT: ' ppm:- | $::IMCONVERT ppm:- '
  ###set cmd "$::IMCONVERT $inpImgPath $annotStr(0) ppm:- | $::IMCONVERT ppm:- $annotStr(1) ppm:- | $::IMCONVERT ppm:- $annotStr(2) ppm:- | $::IMCONVERT ppm:- $annotStr(3)  $outSpec"
  ####### TODO: test image path with spaces ###########
  set cmd ""
  set firstI [lindex $lsRange 0];    set lastI  [lindex $lsRange end]
  foreach i $lsRange  {
    append cmd "$::IMCONVERT " \
              [expr {($i > $firstI)? "ppm:- "  :  "$inpImgPath "}]  $annotStr($i)
    append cmd [expr {($i < $lastI)? " ppm:- | "  :  " $outSpec"}]
  }
                 
  ok_info_msg "Running command with annotation directive(s) for $lCnt sub-label(s); total length is [string length $cmd]"
  ## puts "@TMP@ (Annotation command) ==> '$cmd'"
  ## if {$cleanOrWrite == 1}  {return  0};  # OK_TMP

#exec  {*}$cmd
  if { 0 == [ok_run_silent_os_cmd $cmd] }  {
    return  0; # error already printed
  }
  ok_info_msg "Created image '[lindex $outSpec end]' annotated with $lCnt sub-label(s)"
  return  1
}


# Returns a string with IM command-line parameters of font- and font-family names
#  for requested set of sublabels - #'sublabelSet0123' (0|1|2|3)
## Example:  foreach i {0 1 2 3}  {puts "$i:  [img_proc::_format_font_and_family_for_sublabel $i {{dummy1} {dummy2} {}}]"}
proc img_proc::_format_font_and_family_for_sublabel {sublabelSet0123 \
                                                       forcedFontsInTriple}  {
  if { ($sublabelSet0123 != 0) && ($sublabelSet0123 != 1) &&
       ($sublabelSet0123 != 2) && ($sublabelSet0123 != 3) }  {
    error "Invalid sublabel index $sublabelSet0123; should be 0/1/2/3"
  }
  set fontNamesAndFamiliesInTriple \
    [img_proc::_choose_fonts_for_sublabels $forcedFontsInTriple]
  set fontAndFamily [lindex $fontNamesAndFamiliesInTriple $sublabelSet0123]
  lassign $fontAndFamily fontName fontFamilyName
  set fontParam "-font \"$fontName\" -family \"$fontFamilyName\""
  ##puts "@_format_font_and_family_for_sublabel@: {$forcedFontsInTriple}"
  ok_info_msg "Font spec for sublabels-set $sublabelSet0123: {$fontParam}"
  return  $fontParam
}


# Builds and imprints coordinate grid on image 'imgPath'.
# Saves resulting image according to 'outNameSuffix' and 'outDir'.
# Returns 1 on success, 0 on error
## Example:  img_proc::annotate_image_coordinates  1  "INP/K400p_01__SNAP__eng_heb.png"  _coord03x02  OUT  3  2  "rgb(250,250,250)"  "Blue"  "Green"  14
## Practical example requires 2x scale of the input:
###  exec convert "INP/K400p_01__SNAP__eng_heb.png" -resize 200% "INP/K400p_2x.png"
###  img_proc::annotate_image_coordinates  1  "INP/K400p_2x.png"  _coord32x18  OUT  32  18  "rgb(250,250,250)"  "Blue"  "Green"  18
## Better - 3x scale of the input, but finer than ~50x25 won't work on Windows:
###  exec [string trim $_IMCONVERT "{}"] "INP/K400p_01__SNAP__eng_heb.png" -resize 300% "INP/K400p_3x.png"
### img_proc::annotate_image_coordinates  1  "INP/K400p_3x.png"  _coord50x25  OUT  50  25  "rgb(250,250,250)"  "Blue"  "Green"  20
### img_proc::annotate_image_coordinates  3  "KBD/K400p_01__SNAP__eng_heb.png"  _coord34x34  LNX/OUT  34  34  "rgb(250,250,250)"  "Blue"  "Green"  20
# TODO: set ::IMCONVERT [string trim $::_IMCONVERT "{}"]
proc ::img_proc::annotate_image_coordinates {scale imgPath                   \
                               outNameSuffix outDir                          \
                               numColumns numRows                            \
                               bgColor colorForX colorForY fontSize          \
                               {formatCB img_proc::_float_to_floor_string_CB}}  {
  set fontSize 14
  # if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
  #                                                     imgWidth imgHeight] }  {
  #   return  0;  # error already printed
  # }
  # set stepX [expr {floor($imgWidth  / $numColumns)}]
  # set stepY [expr {floor($imgHeight / $numRows)}]
  set labelList [img_proc::_build_xy_grid $numColumns $numRows $formatCB]
  if { $labelList == 0 }  {
    return  0;  # error already printed
  }
  ##puts "@@@TMP@@@: {$labelList}"
  if { $scale != 1.0 }  {
    set scalePrc [expr {int($scale * 100)}]
    set scaledPath [file join $outDir  \
                    [format "scaled%03d__%s" $scalePrc [file tail $imgPath]]]
    if { 0 == [img_proc::scale_image $scale $imgPath $scaledPath] }  {
      return  0;  # error already printed
    }
    #set inSpec "$imgPath  -resize [expr {int($scale*100)}]%  ppm: | "
  }
  # TODO: check how outSpec list is flattened
  set outName [format {%s%s%s} \
                 [file rootname [file tail $imgPath]] \
                 $outNameSuffix [file extension $imgPath]]
  set outSpec [file join $outDir $outName]
  set ultInpPath [expr {($scale != 1.0)? $scaledPath :  $imgPath}]
  set res  [img_proc::annotate_image_by_spec $ultInpPath $outSpec $labelList  \
              [list $fontSize $fontSize 0]                                    \
              [list $bgColor $colorForX $colorForY "white"]]
  if { $scale != 1.0 }  {
    ok_delete_file $scaledPath
  }
  return  $res
}
## img_proc::annotate_image_by_spec  "INP/K400p_01__SNAP__eng_heb.png"  "OUT/coord1.png"  {{{"16" 16 24} {"24" 16 26} {"" 0 0}}  {{"49" 49 24} {"24" 49 26} {"" 0 0}}  {{"82" 82 24} {"24" 82 26} {"" 0 0}}    {{"16" 16 74} {"24" 16 76} {"" 0 0}}  {{"49" 49 74} {"24" 49 76} {"" 0 0}}  {{"82" 82 74} {"24" 82 76} {"" 0 0}}}        {14 14 0}    {rgb(250,250,250) rgb(255,0,0) rgb(0,255,0)}


# TODO:
# 'colorsList' == list of per-color lists of {index rVal gVal bVal}
## Example 01:  img_proc::generate_colorchart_from_list  {{0  0 255 255}  {1  255 0 255}  {2  255 255 0}}  black  1000  960  TMP/out_01.jpg
## Example 02:  set cl [img_proc::list_image_unique_colors OUT/DSC03239_q256.PNG];  img_proc::generate_colorchart_from_list  $cl black  1000  6000  TMP/DSC03239_q256_cc.jpg
proc ::img_proc::generate_colorchart_from_list {colorsList bgColor \
                                           maxWidth maxHeight outSpec}  {
  set outPath [outspec_to_outpath $outSpec]
  
  set descr "Color-chart in '[file tail $outPath]'"
  # "-density 72" makes one point in font-size equal to one pixel
  set annotStrPref "-density 72 -gravity north  -background \"$bgColor\""
  img_proc::_choose_fixed_font fontName fontFamilyName
  set fontNameAndFamily "-font $fontName -family $fontFamilyName"
  set nColors [llength $colorsList]

  # choose and report font-size
  set pointSize [set desiredPointSize 20]
  set lineSpace [set desiredLineSpace 5]
  set ht [expr {$nColors * ($pointSize + $lineSpace) + $lineSpace}]
  set sampleLine {@@@@ #00001 => RGB(255, 000, 255)  HSV(300 255 255)  Brgb(123.4 123.4 123.4)}
  set wd [expr {[string length $sampleLine] * $pointSize + 2*$pointSize}]
  puts "@@ Sample-line width for pointSize=$pointSize would be $wd"
  puts "@@ Full chart height for pointSize=$pointSize would be $ht"
  
  set scaleDn [expr {  \
		  max( (1.0*$ht / $maxHeight),  (1.0*$wd / $maxWidth),  1 )}]
  set pointSize [expr {int(floor(1.0* $pointSize / $scaleDn))}]
  set lineSpace [expr {int(floor(1.0* $lineSpace / $scaleDn))}]
  set scaledDown [expr {$pointSize < $desiredPointSize}]
  ok_info_msg "$descr: (font-size, line-space) [expr {$scaledDown? {reduced to} : {chosen as}}] ($pointSize, $lineSpace)"
  set wd [expr {($wd <= $maxWidth)? $wd : $maxWidth}]
  set ht [expr {($ht <= $maxHeight)? $ht : $maxHeight}]
  set canvasArgs [format {-size %dx%d xc:%s}  $wd $ht $bgColor]
  #### Sample directive for one sub-label: {  -stroke "rgb(0,0,0)" -pointsize 12 -annotate +158+142 "E"}
    # set subLabelCommon [format  \
    #  "  $fontNameAndFamily  -stroke \"%s\" -fill \"%s\" -pointsize %d $bold" \
    #                                   $color       $color          $pointSize]
  set fontArgs [format  \
        "$fontNameAndFamily  -strokewidth 1  -pointsize %d  -weight Heavy"  \
                  $pointSize]
  set colorsLengthLimit [expr {$::_CMD_LENGTH_LIMIT  \
      - [llength $annotStrPref]  - [llength $canvasArgs] - [llength $fontArgs]}]

  #
  set drawCmds ""
  set colorsCnt 0
  set x 0;  # OK_TMP: for now - all centered
  set y $lineSpace
  #set paddedColorsList [concat $colorsList {{-1 0 0 0}}]; #ensure black bottom 
  foreach colorLine $colorsList  {;  #{index rVal gVal bVal}
    if { ![_parse_color_spec $colorLine index rVal gVal bVal] }  {
      return  0;  # error already printed
    }
    ##puts "@@ Processing color line '$colorLine' == {$index $rVal $gVal $bVal}"
    set hsv [img_proc::rgbToHsv $rVal $gVal $bVal]
    lassign $hsv  hsvHue hsvSat hsvVal
    #set rvry  [img_proc::rgbToRedCyanRivalry $rVal $gVal $bVal]
    set brR [img_proc::rgbToBright $rVal 0 0]
    set brG [img_proc::rgbToBright 0 $gVal 0]
    set brB [img_proc::rgbToBright 0 0 $bVal]
    set str [format {@@@@ #%05d => RGB(%03d, %03d, %03d)  HSV(%03d, %03d, %03d)  Brgb=(%5.1f %5.1f %5.1f)}  \
             $index  $rVal $gVal $bVal  $hsvHue $hsvSat $hsvVal $brR $brG $brB]
    set oneColorStr [format {  -stroke "rgb(%d,%d,%d)"  -fill "rgb(%d,%d,%d)"  -annotate +%d+%d "%s"} \
                            $rVal $gVal $bVal  $rVal $gVal $bVal  $x $y $str]
    set newLength [expr {[string length $drawCmds] + \
                         [string length $oneColorStr]}]
    if { $newLength >= $colorsLengthLimit }  {
      ok_err_msg "Command length ($newLength) at color #$index exceeds the limit of $::_CMD_LENGTH_LIMIT"
      return  0
    }
    append  drawCmds  $oneColorStr
    incr y [expr {$pointSize + $lineSpace}]
    incr colorsCnt 1
  }
  #
  set cmd "$::IMCONVERT  $annotStrPref  $canvasArgs  $fontArgs  $drawCmds  $outSpec"
  ##puts "@TMP@ (Color-chart command) ==> '$cmd'"

  ok_info_msg "Running color-chart generation command for $colorsCnt color(s); total length of the command is [string length $cmd]; chart image size is ${wd}x${ht}"
  #exec  {*}$cmd
  if { 0 == [ok_run_silent_os_cmd $cmd] }  {
    return  0; # error already printed
  }
  ok_info_msg "Created color-chart image '$outPath' with $colorsCnt color(s)"
  return  1
}


# 'colorLine' == {index rVal gVal bVal}
proc ::img_proc::_parse_color_spec {colorLine index rVal gVal bVal}  {
  upvar $index idx;    upvar $rVal  rV;    upvar $gVal  gV;    upvar $bVal  bV
  if { ![llength $colorLine] == 4 }  {
    ok_err_msg "Invalid color spec '$colorLine'"
    return  0
  }
  lassign $colorLine  idx rV gV bV
  set idx [expr {int($idx)}]
  return  1
}


# Assumes the last word in 'outspec' is output file path. Prepends its name.
proc ::img_proc::prefix_outspec {outSpec prefixStr}  {
  set allWords [ok_split_string_by_whitespace [string trim $outSpec]]
  set allButLast [lrange $allWords 0 end-1]
  set lastWord [lindex $allWords end]
  set prefLast [format "%s%s" $prefixStr [file tail $lastWord]]
  return  [file join [file dirname $lastWord] $prefLast]
}

########### Hidden utilities ####################################################

# Returns list of list of 3-element-list of triples with X/Y coordinate values
# and where to imprint them.
# All coordinates are integer percentages.
# Each 3-element-list is {{Xval% xForX% yForX%} {Yval% xForY% yForY%} {"" 0 0}}
## 3 colums -> 00-32 33-65 66-99 in 0+(32-0)/2=16 33+(65-33)/2=49 66+(99-66)/2=82
## 2 rows   -> 00-49 50-99       in 0+(49-0)/2=24 50+(99-50)/2=74
#### Example of 1 row, 10 columns:
####   img_proc::_build_xy_grid 10 1 img_proc::_float_to_floor_string_CB
proc ::img_proc::_build_xy_grid {numColumns numRows formatCB}  {
  if { ($numColumns <= 0) || ($numRows <= 0) }  {
    ok_err_msg "Numbers of columns and rows should be positive non-zero"
    return  0
  }
  # heuristical equation for vertical offset between X-label and Y-label
  set vertOffsetPrc [expr {max(int(floor(100 / $numRows / 4)), 1)}]
  # Note, only center coordinates must be integer; min/max are float for accuracy
  set stepX [expr {100.0 / $numColumns}]
  set stepY [expr {100.0 / $numRows}]
  ok_trace_msg "stepX = $stepX;  stepY = $stepY"
  set valDict [dict create]
  set minY 0;    set maxY -1;  # current region boundaries
  set minX 0;    set maxX -1;  # current region boundaries
  set labelList [list]
  for {set iY 0} {$iY < $numRows} {incr iY 1}  {
    # an iteration over Y creates line with X coordinates on top of Y coordinates
    set minY [expr {0 + $iY*$stepY}]
    set maxY [expr {$minY + $stepY - 1}]
    set centrY [expr {int(round($minY + ($maxY - $minY)/2))}]
    set yForX $centrY
    set yForY [expr {$yForX + $vertOffsetPrc}]
    ok_trace_msg "(iY=$iY)  minY=$minY  maxY=$maxY  centrY=$centrY"
    set rowList [list]
    for {set iX 0} {$iX < $numColumns} {incr iX 1}  {
      set minX [expr {0 + $iX*$stepX}]
      set maxX [expr {$minX + $stepX - 1}]
      set centrX [expr {int(round($minX + ($maxX - $minX)/2.0))}]
      ok_trace_msg "(iX=$iX)  minX=$minX  maxX=$maxX  centrX=$centrX"
      lappend rowList [list                                             \
                         [list [eval $formatCB $centrX] $centrX $yForX] \
                         [list [eval $formatCB $yForY]  $centrX $yForY] \
                         [list ""    0                  0             ] ]
    }
    set labelList [concat $labelList $rowList]
  }
  return $labelList
}


# Selects fixed fonts known to be available on the current system
proc ::img_proc::_choose_fixed_font {fontName fontFamilyName}  {
  upvar $fontName font
  upvar $fontFamilyName fontFamily
  set font       "Courier"
  set fontFamily "Courier"
  # set font       "SBL-Hebrew"
  # set fontFamily "SBL Hebrew"
  if { "WINDOWS" == [ok_detect_os_type] }  {
    set font       "Courier-New"
    set fontFamily "Courier New"
  }
}


# Returns list of 3|4 {fontName fontFamilyName_or_empty} nested-lists
proc ::img_proc::_choose_fonts_for_sublabels {{forcedFontNames {"" "" "" ""}}} {
  img_proc::_choose_fixed_font fontName fontFamilyName
  set fontAndFamilyNames [list];  # will be list of pairs
  set lsRange [expr {([llength $forcedFontNames] <= 3)? {0 1 2}  :  {0 1 2 3}}]
  foreach i $lsRange  {
    set forcedFont [lindex $forcedFontNames $i]
    # if font is given (enforced), the family isn't needed
    lappend fontAndFamilyNames [expr {($forcedFont == "")?  \
                     [list $fontName $fontFamilyName] : [list $forcedFont ""]}]
  }
  return  $fontAndFamilyNames
}
