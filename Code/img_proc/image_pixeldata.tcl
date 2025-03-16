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

# image_pixeldata.tcl
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
source [file join $IMGPROC_DIR  "image_metadata.tcl"]
source [file join $IMGPROC_DIR  "image_annotate.tcl"]

if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  ok_utils::ok_trace_msg "---- Sourcing '[info script]' in '$IMGPROC_DIR' ----"
}


# DO NOT in 'auto_spm': package require ok_utils; 
namespace import -force ::ok_utils::*
############# Done loading code ################################################


namespace eval ::img_proc:: {
    namespace export                          \
}

# channel histogram precision as number of floating-point digits
set ::FP_DIGITS  1

# assumed max value of any color channel
set ::MAX_CHANNEL_VALUE 32767
set ::MIN_CHANNEL_VALUE -32768

# regular expression to parse one pixel grayscale value
set ::_ONE_PIXEL_CHANNEL_DATA_REGEXP  {(\d+),(\d+):\s+.+gray\(([0-9.]+)%?\)}


# Returns list of 'numSteps' relative-brightness values (0-1)
# of image 'imgPath'
# in a horizontal band of height 'bandHeight' that encloses 'bandY'
#~ proc ::img_proc::read_brightness_of_band {imgPath' bandY bandHeight numSteps}  {
  #~ set numBands [expr int($imgHeight / $bandHeight)]
#~ }


# Returns list of lists - 'numBands'*'numSteps' relative-brightness values (0-1)
# of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set matrix [img_proc::read_brightness_matrix  V24d2/DSC00589__s11d0.JPG  2 3]
proc ::img_proc::read_brightness_matrix {imgPath numBands numSteps {priErr 1}}  {
  set matrDecr [format "%dx%d matrix" $numBands $numSteps]
  if { 0 == [set pixels [img_proc::read_pixel_values \
                          $imgPath $numBands $numSteps $priErr]] }  {
    return  0;  # error already printed
  }

  #~ # convert marked list of values into list-of-lists
  #~ if { 0 == [img_proc::_brightness_txt_to_matrix $pixels nRows nCols $priErr] }  {
    #~ ok_err_msg "Invalid pixel-data format in '$imgPath'"
    #~ return  0
  #~ }
  #~ if { ($nRows != $numBands) || ($nCols != $numSteps) } {
    #~ ok_err_msg "Invalid dimension(s) for $matrDecr out of '$imgPath': $nRows lines, $nCols columns"
    #~ return  0
  #~ }
  #~ ok_info_msg "Success parsing pixel-data of '$imgPath' into $matrDecr"
  
  return  $pixels;  # OK_TMP
}


############# BEGIN: pixel-data READING stuff ##################################
# Returns list of formatted pixel values of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set pixels [img_proc::read_pixel_values  V24d2/DSC00589__s11d0.JPG  2 3]
proc ::img_proc::read_pixel_values {imgPath numRowsOrZero numColumnsOrZero \
                                      {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set numRows    [expr {($numRowsOrZero > 0)?    $numRowsOrZero    : $imgHeight}]
  set numColumns [expr {($numColumnsOrZero > 0)? $numColumnsOrZero : $imgWidth}]
  set bandHeight [expr $imgHeight / $numRows]
  set wXhStr [format {%dx%d!} $numColumns $numRows]
  set resizeParam [expr {(($numRowsOrZero > 0) || ($numColumnsOrZero > 0)) ?  \
                                                         "-resize $wXhStr" : ""}]
  ## read data with 'convert <PATH>  -resize 3x2!  -colorspace gray  txt:-'
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s -quiet  %s  -colorspace gray  txt:-} \
                      $::IMCONVERT $imgPath $resizeParam]
  set tclExecResult [catch {
    # Open a pipe to the program
    #   set io [open "|identify -format \"%w %h\" $fullPath" r]
    set io [eval [list open $imCmd r]]
    set buf [read $io];	# Get the full reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get pixel data of '$imgPath'"
    }
    return  0
  }
  # split into list with element per a pixel
  set asOneLine [join $buf " "];  # data read into arbitrary chunks
  set pixels [regexp -all -inline \
        {\d+,\d+:\s+\([0-9.,]+\)\s+#[0-9A-F]+\s+gray\([0-9.]+%?\)} \
        $asOneLine]

  return  $pixels
}


# Returns list of formatted pixel Hue values of image 'imgPath'
### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY;    set pixels [img_proc::read_pixel_hues  rose.tif  1];  llength $pixels
proc ::img_proc::read_pixel_hues {imgPath scale {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
                            imgWidth imgHeight] }  {
    return  0;  # error already printed
  }
  set newWidth  [expr int($imgWidth  / $scale)]
  set newHeight [expr int($imgHeight / $scale)]
  set wXhStr [format {%dx%d!} $newWidth $newHeight]
  ## read data with 'convert <PATH>  -resize 3x2!  -colorspace HSB -channel Hue -separate  txt:-'
  set pixels [list]
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s -quiet  -resize %s  -colorspace HSB -channel Hue -separate  txt:-} \
                      $::IMCONVERT $imgPath $wXhStr]
  set tclExecResult [catch {
    # Open a pipe to the program, then read line-by-line
    set io [eval [list open $imCmd r]]
    while { [gets $io onePixelLine] >= 0 }  {  
      if { 0 != [regexp {^\s*#} $onePixelLine] }  { continue };  # skip comments
      if { 0 != [regexp \
                {\d+,\d+:\s+\([0-9.,]+\)\s+#[0-9A-F]+\s+gray\([0-9.]+%?\)} \
                  $onePixelLine] }  {
        lappend pixels [string trim $onePixelLine { \n\t}]
      }
    }
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get pixel data of '$imgPath'; number of lines read: [llength $pixels]"
    }
    return  0
  }
  return  $pixels
}


# TODO: descr
# Reads from 'TODO' and returns
#  a nested 3-level list simulating 2D array of {e g b} lists
#  where two first list indices represent image {x y} coordinates.
### Color-line example:  "10,0: (31,31,0)  #1F1F00  srgb(31,31,0)"
## Invocation example:  set qq3 [::img_proc::read_pixel_colors TMP/HALD/hald_3.png];  llength $qq3
## Random access example (read {rgb} trio):  lindex $qq3  1 1
proc ::img_proc::read_pixel_colors {imgPath {priErr 1}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  # if { 0 == [img_proc::get_image_dimensions_by_imagemagick $imgPath \
  #                           imgWidth imgHeight] }  {
  #   return  0;  # error already printed
  # }
  # set wXhStr [format {%dx%d!} $imgWidth $imgHeight]
  ## read data with 'convert <PATH>  -colorspace sRGB   txt:-'
  set pixels [list];  # a nested 3-level list simulating 2D array of RGB lists
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s -quiet  -colorspace sRGB  txt:-} \
                      $::IMCONVERT $imgPath]
  set tclExecResult [catch {
    # Open a pipe to the program, then read line-by-line
    set io [eval [list open $imCmd r]]
    while { [gets $io onePixelLine] >= 0 }  {  
      if { 0 != [regexp {^\s*#} $onePixelLine] }  { continue };  # skip comments
      if { 0 != [regexp -- \
                {(\d+),(\d+):\s+\((\d+),(\d+),(\d+)\) } \
                  $onePixelLine  all  x y  r g b] }  {
        lset pixels $x $y [list $r $g $b]
      }
    }
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get color data of '$imgPath'; number of lines read: [llength $pixels]"
    }
    return  0
  }
  return  $pixels
}


# Returns list of per-color lists: {{index rVal gVal bVal} ... {index rVal gVal bVal}}
# If 'maxColorsToSortByWb' <= count of unique colors, the output list is sorted ascending by R/G then R/B
## The idea:  for %f in ( D256\*.tif)  DO  %IMC%  %f   -unique-colors txt:- |%IMC%  txt:-  D256\Palette\%~nf__clr_txt.TXT
## Example-01:  set qqL [img_proc::list_image_unique_colors  TMP/colors40.tif  256];  llength $qqL
## Example-02:  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00035.TIF"  256];  llength $qqL
proc ::img_proc::list_image_unique_colors {imgPath {maxColorsToSortByWb 0}}  {
  if { ![file exists $imgPath] }  {
    ok_err_msg "-E- Inexistent input file '$imgPath'"
    return  0
  }
  set colors [list]
  ####### TODO: resolve $::IMCONVERT vs {$::IMCONVERT}
  set imCmd [format {|%s  %s  -quiet  -unique-colors  txt:-} \
                      $::IMCONVERT  $imgPath]
  set tclExecResult [catch {
    set errCnt 0;  set lineCnt 0
    # Open a pipe to the program, then read line-by-line
    set io [eval [list open $imCmd r]]
    while { [gets $io oneColorLine] >= 0 }  {
      # sample one line:  1,0: (7,8,8)  #070808  srgb(7,8,8)
      ## debug with:  set cl {14,0: (14,23,33)  #0E1721  srgb(14,23,33)};  if {[regexp {^(\d+),.*\((\d+),(\d+),(\d+)\)}  $cl  a i r g b]}  {puts "($i)  R:$r G:$g B:$b"} else {puts "*ERROR"}
      if { 0 != [regexp {^\s*#} $oneColorLine] }  { continue };  # skip comments
      incr lineCnt 1
      if { 0 == [regexp {^(\d+),.*\((\d+),(\d+),(\d+)[),]}  \
		   [string trim $oneColorLine]  all index rVal gVal bVal] }  {
	ok_err_msg "Invalid line #$lineCnt in '$imgPath':  '$oneColorLine'"
	incr errCnt 1
	continue
      }
      lappend colors [list $index $rVal $gVal $bVal]
    }
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    if { $priErr == 1 }  {
      ok_err_msg "$execResult!"
      ok_err_msg "Cannot get color data of '$imgPath'; number of lines read: $lineCnt"
    }
    return  0
  }
  set msg "Done reading list of unique colors in '$imgPath' - [llength $colors] out of $lineCnt"
  if { $errCnt == 0 }  { ok_info_msg "$msg"
  } else               { ok_warn_msg "$msg; $errCnt errors occured" }
  if { $maxColorsToSortByWb >= [llength $colors] }  {
    set colors [sort_colors_by_wb $colors]
  }
  return  $colors
}


## The idea:  for %f in ( D256\*.tif)  DO  %IMC%  %f   -unique-colors txt:- |%IMC%  txt:-  D256\Palette\%~nf__clr_txt.TXT
# proc ::img_proc::TODO__write_image_unique_colors {inpPath outTextFilePath}  {
#   set outDir [file dirname $outTextFilePath]
#   if { 0 == [ok_create_absdirs_in_list [list $outDir]] }  {
#     ok_err msg "Failed creating output directory '$outDir'";    return  0
#   }
#   set cmdList [concat "$::_IMCONVERT"  $inpPath \
# 		 "-dither FloydSteinberg -colors $numColors"  $outSpec]
#   ok_trace_msg "Image-quantize command:  $cmdList"
#   if { 0 == [ok_run_silent_os_cmd $cmdList] }  {
#     return  0;  # error already printed
#   }

#   ok_info_msg "Done reducing '$inpPath' number of colors to $numColors; output into [img_proc::outspec_to_outpath $outSpec]"
#   return  1
# }

############# END:   pixel-data READING stuff ##################################



############# BEGIN: pixel-data annotation stuff ###############################

### Standalone invocation on Linux:
#### namespace forget ::img_proc::*;    source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/ext_tools.tcl;  source ~/ANY/GitWork/DualCam/auto_spm/SPM_TCL/img_proc/image_pixeldata.tcl;    set_ext_tool_paths_from_csv DUMMY
#### img_proc::annotate_pixel_values  V24d2/DSC00589__s11d0.JPG  6 9    "__br6x9"  "OUT"  _float_to_string_CB
proc ::img_proc::annotate_pixel_values {imgPath numBands numSteps \
                  outNameSuffix outDir {formatCB img_proc::_plain_string_CB}}  {
  if { 0 == [set pixels [img_proc::read_pixel_values  \
                                          $imgPath $numBands $numSteps 1]] }  {
    return  0;  # error already printed
  }
  if { 0 == [set brMatrix [img_proc::_brightness_txt_to_matrix \
                            $pixels  $numBands $numSteps  1  1]] }  {
    return  0;  # error already printed
  }

  #set outNameSuffix [format {__br%dx%d} $numBands $numSteps]
  return  [img_proc::annotate_image_zone_values $imgPath $brMatrix    \
                                              $outNameSuffix $outDir $formatCB]
}

############# Generic annotation stuff moved into image_annotate.tcl #########
############# END:   pixel-data annotation stuff ###############################



## Sample input data (for 2*3):
####  -I- Assume running on an unixoid - use pure tool executable names
####  # ImageMagick pixel enumeration: 3,2,255,gray
####  0,0: (133.342,133.342,133.342)  #858585  gray(52.2911%)
####  1,0: (140.304,140.304,140.304)  #8C8C8C  gray(55.021%)
####  2,0: (124.564,124.564,124.564)  #7D7D7D  gray(48.8487%)
####  0,1: (128.23,128.23,128.23)  #808080  gray(50.2861%)
####  1,1: (138.77,138.77,138.77)  #8B8B8B  gray(54.4198%)
####  2,1: (128.152,128.152,128.152)  #808080  gray(50.2556%)
# If 'normalize'=0, returns dictionary {row,column :: gray-value(0.0 ... 100.0)}
# If 'normalize'=1, returns dictionary {row,column :: fract_of_max(0.0 ... 1.0)}
# On error returns 0.
proc ::img_proc::_brightness_txt_to_matrix {pixelLines nRows nCols normalize \
                                            {priErr 1}} {
  # init the resulting dict with negative values
  set resDict [dict create]
  for {set i 0}  {$i < $nRows}  {incr i 1}  {
    for {set j 0}  {$j < $nCols}  {incr j 1}  { dict set resDict  $i $j  -99 }
  }
  set errCnt 0
  set iRow 0
  set iCol 0
  foreach pixelStr $pixelLines  {
    ###puts "@@ Line '%s' simple match = []"
    if { 0 == [regexp {(\d+),(\d+):\s+.+gray\(([0-9.]+)%?\)}  $pixelStr    \
                                                  all  iCol iRow  val] }  {
      if { $priErr }  { ok_err_msg "Invalid one-pixel line '$pixelStr'" }
      incr errCnt 1
      continue
    }
    dict set resDict  $iRow $iCol  $val
  }
  if { $priErr && ($errCnt > 0) }  {
    ok_err_msg "Parsing pixel values encountered $errCnt error(s)"
  }
  if { $normalize == 0 }  {
    return  $resDict;   # scaling values to 0..1 isn't requested
  }
  
  # scale values to 0...1
  set maxBright -1;  set maxPlace {-1 -1}
  dict for {x y_b} $resDict  {
    dict for {y b} $y_b {
      if { $b > $maxBright }  { set maxBright $b;  set maxPlace [list $x $y] }
    }
  }
  if { $maxBright == 0.0 }  {
    ok_err_msg "-E- Zero maximal brightness (at $maxPlace) - cannot normalize"
    return  0
  }
  set scaledDict [dict create]
  for {set i 0}  {$i < $nRows}  {incr i 1}  {
    for {set j 0}  {$j < $nCols}  {incr j 1}  {
      dict set scaledDict  $i $j  \
              [expr {1.0 * [dict get $resDict $i $j] / $maxBright}] }
  }
  return  $scaledDict
}


############# BEGIN: color-channel histogram analysis stuff ####################
# TODO: threshold (units - prc or fraction depend on 'normalize') !!!
## Example:  set hist [img_proc::_channel_txt_to_histogram  $pixels  $::FP_DIGITS  1];  dict size $hist
## Nice-print the histogram:  dict for {k v} $hist  {puts "$k :: $v"}
## Verify normalized:  proc ladd L {expr [join $L +]+0};  ladd [dict values $hist]
## Make sample input 1: exec convert -size 10x10 xc:rgb(0,11,255) -depth 8 near_blue.tif
## Make sample input 2: exec convert rose: -depth 8 rose.tif
## Read pixels from file: set pixels [img_proc::read_pixel_hues  rose.tif  1 1] 
proc ::img_proc::_channel_txt_to_histogram {pixelLines precision normalize \
                                              {priErr 1}} {
  set threshold -1; # OK_TMP
  set precSpec [format {%%.%df} $precision]
  set allValDict [dict create];  # will contain counts for all appearing values
  set errCnt 0
  set iRow 0
  set iCol 0
  foreach pixelStr $pixelLines  {
    ###puts "@@ Line '%s' simple match = []"
    if { 0 == [regexp $::_ONE_PIXEL_CHANNEL_DATA_REGEXP  $pixelStr    \
                                                  all  iCol iRow  val] }  {
      if { $priErr }  { ok_err_msg "Invalid one-pixel line '$pixelStr'" }
      incr errCnt 1
      continue
    }
    set key [format $precSpec $val]
    dict incr allValDict  $key 1
  }
  if { $priErr && ($errCnt > 0) }  {
    ok_err_msg "Parsing pixel values encountered $errCnt error(s)"
  }
  if { ($normalize == 0) && ($threshold < 0) }  {
    return  $allValDict;   # scaling values to 0..1 isn't requested
  }
  
  # scale values to 0...1
  set numPixels [expr [llength $pixelLines] - $errCnt]
  set normDict [dict create]
  dict for {val count} $allValDict  {
    dict set normDict  $val  [expr 1.0 * $count / $numPixels]
  }
  return  $normDict
}


## Nice-print the histogram:  dict for {k v} $hist  {puts "$k :: $v"}
proc ::img_proc::nice_print_channel_histogram {histogramDict putsCB  \
                                                   {min "NONE"} {max "NONE"}} {
  set keys [lsort -real [dict keys $histogramDict]]
  if { $min == "NONE" }    {  set minKey [lindex $keys 0];       # $::MIN_CHANNEL_VALUE
  } else {                                set minKey $min }
  if { $max == "NONE" }    { set maxKey [lindex $keys end];  # $::MAX_CHANNEL_VALUE
  } else {                                set maxKey $max }
  set keysSublist [img_proc::_find_value_range_in_channel_histogram \
                                        $histogramDict [list $minKey $maxKey]]
  foreach key $keysSublist { $putsCB "$key ==> [dict get $histogramDict $key]" }
}


## Example:  img_proc::_channel_histogram_to_ordered_fragments $hist {{0 2.0}}
proc ::img_proc::_channel_histogram_to_ordered_fragments {histogramDict \
                                                          fragmentBounds}   {
  set keys [lsort -real [dict keys $histogramDict]]
  set fragmentsDict [dict create]
  foreach fragmentMinMax $fragmentBounds  {
    if { 2 != [llength $fragmentMinMax] } {
      error "-E- Invalid structure of fragment bounds '$fragmentMinMax'; should be {min max}"
    }
    lassign $fragmentMinMax lo hi;  # min/max channel values in the fragment
    dict set fragmentsDict $fragmentMinMax 0;  # init to no-values-in-fragment
    if { -1 == [set iLast [lsearch -bisect $keys $hi]] }  {
      # no valuies in this histogram fragment 
      continue
    }
    puts "-D- Last key for $hi is at #$iLast"
    set cntInFragm 0
    for {set i $iLast} {$i >= 0} {incr i -1}   {
      set key [lindex $keys $i];  # key has semantics of channel value
      if { $key >= $lo }  {
        set cntForVal [dict get $histogramDict $key];  # known to exist
        puts "-D- Contribute $cntForVal into {$fragmentMinMax} at $key"
        set cntInFragm [expr $cntInFragm + $cntForVal]
      } else {
        break;  # done with the current fragmemt
      }
    }
    dict set fragmentsDict $fragmentMinMax $cntInFragm
  }
  return  $fragmentsDict
}


## Example:  set gaps [img_proc::_find_gaps_in_channel_histogram [img_proc::_complete_hue_histogram $hist $::FP_DIGITS] 0.001 {0 2.0}]
## Fine-print the result:   dict for {b e} $gaps {puts "\[$b ... $e\]"}
proc ::img_proc::_find_gaps_in_channel_histogram {histogramDict thresholdNorm \
                                                                searchBounds}  {
  if { 2 != [llength $searchBounds] } {
      error "-E- Invalid structure of search bounds '$searchBounds'; should be {min max}"
  }
  lassign $searchBounds minV maxV

  # find the search-start and search-end indices
  set keysSubList [img_proc::_find_value_range_in_channel_histogram   \
                                                  $histogramDict $searchBounds]
  if { 0 == [llength $keysSubList] }  {
    # no valuies in requested histogram range; message already printed
    return  [dict create  $minV $maxV];  # one gap over the full range
  }
  puts "-D- Search restricted to \[[lindex $keysSubList 0]...[lindex $keysSubList end]\]: {$keysSubList}"
  
  set gapsDict [dict create];   # will map gapFirstValue :: gapLastValue
  for {set i 0} {$i <= [expr [llength $keysSubList] - 1]} {incr i} {
    # check for a gap started from #i
    for {set j $i} {$j < [llength $keysSubList]} {incr j}   {
      set isLastSubrange [expr {$j == [llength $keysSubList] - 1}]
      set subrangeVal [lindex $keysSubList $j]
      set subrangeCount [dict get $histogramDict $subrangeVal]
      set isAboveThreshold [expr ($subrangeCount > $thresholdNorm)]
      set aboveOrBelow [expr {($isAboveThreshold)? "above" : "below"}]
      puts "-D- \[$i\] val=$subrangeVal cnt=$subrangeCount:\t$aboveOrBelow threshold"
      if { $isAboveThreshold && ($j == $i) }   {
        # gap not started (j==i)
        break;   # no gap - the subrange has pixels;  goto incrementing i
      }
      if { $isAboveThreshold  && ($j > $i) }   {
        # gap ended (j>i) - started at #i and ended at #j-1
        dict set gapsDict \
                  [lindex $keysSubList $i]  [lindex $keysSubList [expr $j-1]]
        break;   # gap ended - the subrange has pixels;  goto incrementing i
      }      
      if { (! $isAboveThreshold) && $isLastSubrange }   {
        # gap ended - started at #i and ended at #j
        ## puts "@TMP@ Gap covers the last subrange [lindex $keysSubList $i] ... [lindex $keysSubList $j]"
        dict set gapsDict  [lindex $keysSubList $i]  [lindex $keysSubList $j]
        break;   # gap at the last subrange;  goto incrementing i; loop will end
      }
      # gap continues
    }; #__loop_over_subranges_in_one_gap
    set i $j; # all subranges before #j are already checked; avoid long loop
  }; #__loop_over_all_subranges
  puts "Found [dict size $gapsDict] gap(s) in value range $minV...$maxV (== [lindex $keysSubList 0]...[lindex $keysSubList end])"
  return  $gapsDict
}
  
  
  # Returns ordered sublist of channel values inside 'rangeBounds'
## Example:  set subList [img_proc::_find_value_range_in_channel_histogram $hist  {0 2.0}]
proc ::img_proc::_find_value_range_in_channel_histogram {histogramDict \
                                                          rangeBounds}  {
  set keys [lsort -real [dict keys $histogramDict]];  # keys are channel values
  set numKeys [llength $keys]
  if { 2 != [llength $rangeBounds] } {
      error "-E- Invalid structure of range bounds '$rangeBounds'; should be {min max}"
  }
  lassign $rangeBounds minV maxV
  set gapsDict [dict create];   # will map gapFirstValue :: gapLastValue
  # find the search-start index (-bisect gives last idx with element <= pattern)
  if { -1 == [set iPrev [ \
                  lsearch -real -bisect $keys [expr $minV - 0.0001]]] }  {
    # start from the beginning; it's OK to pass -1 to lrange
  }
  if { -1 == [set iLast [ \
                  lsearch -real -bisect $keys [expr $maxV + 0.0001]]] }  {
    # no valuies in requested histogram range
    ok_warn_msg "No values below the max-limit ($maxV) in histogram range {$rangeBounds}"
    return  [list]
  }
  if { $iPrev == [expr $numKeys - 1] }  {
    # no valuies in requested histogram range
    ok_warn_msg "No values above the min-limit ($minV) in histogram range {$rangeBounds}"
    return  [list]
  }
  set lastIdx [expr {([lindex $keys $iLast] > $maxV)? [expr $iLast - 1] \
                                                    : $iLast}]
  set keysSubList [lrange $keys  $iPrev  $lastIdx]
  ok_trace_msg "Found sublist \[$iPrev...$lastIdx\] / \[[lindex $keysSubList 0]...[lindex $keysSubList end]\]: {$keysSubList}"
  return  $keysSubList
}


# To workaround floating-point problems:
#                             precision == num of decimal digits after point
# Returns width of one histogram subrange for given precision 0|1|2|3}.
# 'scaledToInt' gets this width multiplied by 1000 - a guaranteed integer
proc ::img_proc::_precision_to_histogram_unit_width {precision \
                                                      {scaledToInt  "NONE"}}  {
  if { $scaledToInt != "NONE" }   {  upvar $scaledToInt scaled  }
  if {       $precision == 0 }  { set step 1.0;     set asInt 1000
  } elseif { $precision == 1 }  { set step 0.1;     set asInt 100
  } elseif { $precision == 2 }  { set step 0.01;    set asInt 10
  } elseif { $precision == 3 }  { set step 0.001;   set asInt 1
  } else {
    error "Unsupported precision (numnber of floating-point digits) $precision; should be 0,1,2,3"
  }
  if { $scaledToInt != "NONE" }   { set scaled $asInt }
  return  $step
}


proc ::img_proc::_is_multiple_of_histogram_unit_width {width precision}  {
  set unit [img_proc::_precision_to_histogram_unit_width $precision unitX1000]
  set widthScaled [expr {int( floor($width * 1000 + 0.000001) )}]
  return  [expr ($widthScaled % $unitX1000) == 0]
}


proc ::img_proc::_calc_num_histogram_units_for_width {width precision}  {
  set unit [img_proc::_precision_to_histogram_unit_width $precision unitX1000]
  set widthScaled [expr {int( floor($width * 1000 + 0.000001) )}]
  return  [expr $widthScaled / $unitX1000]
}
############# END:   color-channel histogram analysis stuff ####################
