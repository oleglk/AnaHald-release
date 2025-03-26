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

# colorchart.tcl

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}

set IMGPROC_DIR [file dirname [info script]]
set UTIL_DIR    [file join $IMGPROC_DIR ".." "ok_utils"]
source [file join $UTIL_DIR     "debug_utils.tcl"]
source [file join $UTIL_DIR     "common.tcl"]
#source [file join $UTIL_DIR     "csv_utils.tcl"]
source [file join $IMGPROC_DIR  "image_annotate.tcl"]


namespace eval ::img_proc:: {
  variable HUE_RANGE_HALF_WIDTH   10
  namespace export                     \
    generate_colorchart_for_hue_range  \
    generate_colorchart_for_rgb_range  \
    detect_anaglyph_low_channels       \
}



################################################################################
################################################################################


## Print hue values for basis colors
## foreach r {0 255} {foreach g {0 255} {foreach b {0 255} {set hsv [rgbToHsv $r $g $b];  puts "RGB={$r,$g,$b}\t=> HSV([join $hsv {,}])"}}}
# RGB={0,0,0}           => HSV(0  ,0  ,0  ) <= IGNORE
# RGB={0,0,255}         => HSV(240,255,255) <= RR
# RGB={0,255,0}         => HSV(120,255,255) <= RR
# RGB={0,255,255}       => HSV(180,255,255) <= RR
# RGB={255,0,0}         => HSV(0  ,255,255) <= RR
# RGB={255,0,255}       => HSV(300,255,255) <= OK
# RGB={255,255,0}       => HSV(60 ,255,255) <= OK
# RGB={255,255,255}     => HSV(0  ,0  ,255) <= IGNORE


### VERDICT: close range rotation meaningless, since it may add blue to green
## Example:  img_proc::generate_colorchart_for_hue_range  {1 119 251}  10  black  1000  720  TMP/chart_hue001.jpg
proc ::img_proc::generate_colorchart_for_hue_range {centralHSV rangeWidth \
                                                  bgColor \
                                                  maxWidth maxHeight outSpec}  {
  ## Example 01:  img_proc::generate_colorchart_from_list  {{0  0 255 255}  {1  255 0 255}  {2  255 255 0}}  black  1000  960  TMP/out_01.jpg
  lassign $centralHSV  centralHue sat val
  set halfW [expr 0.5 * $rangeWidth]
  set hMin [expr {int(floor($centralHue - $halfW))}]
  set hMax [expr {int( ceil($centralHue + $halfW))}]
  set rgbList [list] ;  # for list of {index=hue  r g b}
  for {set hue $hMin}  {$hue <= $hMax}  {incr hue 1}  {
    if {       $hue <  0.0   }  { set hVal [expr {$hue + 360}]
    } elseif { $hue >= 360.0 }  { set hVal [expr {$hue - 360}]
    } else                      { set hVal        $hue }
    set rgb [hsvToRgb  $hVal  $sat $val]
    lappend rgbList [list  $hVal {*}$rgb]
  }
  puts "@@ rgbList(hue=($centralHue +- $halfW) \[$hMin .. $hMax\]) = {$rgbList}"
  return  [generate_colorchart_from_list  $rgbList  $bgColor  \
                                          $maxWidth  $maxHeight  $outSpec]
}


# If 'symRange_SYMorUNI' == SYM, generates range around 'centralRGB'.
# If 'symRange_SYMorUNI' == UNI, generates range starting from 'centralRGB'.
## Example:  img_proc::generate_colorchart_for_rgb_range  {251 136 134}  {0 2 2}  SYM black  1000  720  TMP/chart_rgb251.jpg
##### Values tried will be {251 135 133} ... {251 137 135}
## ??? TODO: maybe no need to decrement colors?
proc ::img_proc::generate_colorchart_for_rgb_range {centralRGB bandRangeWidths \
                                              symRange_SYMorUNI bgColor \
					      maxWidth maxHeight outSpec}  {
  #???set lowRC [detect_anaglyph_low_channels $centralRGB]
  #set centralHSV [rgbToHsv {*}$centralRGB]
  lassign $centralRGB centralR centralG centralB
  lassign $bandRangeWidths wR wG wB
  if { ![rgbTrioValid $centralR $centralG $centralB  0] }  {
    ok_err_msg "Invalid RGB combo {$centralRGB}"
    return  0
  }
  if { ($wR < 0) || ($wG < 0) || ($wB < 0) }  {
    ok_err_msg "Color range widths must be non-negative; received {$bandRangeWidths}"
    return  0
  }
  if { $symRange_SYMorUNI == "SYM" }  {
    set hwR [expr {int(ceil($wR/2.0))}];  set hwG [expr {int(ceil($wG/2.0))}]
    set hwB [expr {int(ceil($wB/2.0))}]
    set nSteps [expr {max(2*$hwR, 2*$hwG, 2*$hwB)}]
    set stepR [expr {($nSteps > 0)?  2*$hwR / $nSteps  : 1}]
    set stepG [expr {($nSteps > 0)?  2*$hwG / $nSteps  : 1}]
    set stepB [expr {($nSteps > 0)?  2*$hwB / $nSteps  : 1}]
    set midI [expr {int(round( $nSteps/2.0 ))}]; # 'central' color in the middle
    set minR [expr {$centralR - $hwR}]
    set minG [expr {$centralG - $hwG}]
    set minB [expr {$centralB - $hwB}]
  } elseif { $symRange_SYMorUNI == "UNI" }  {
    set hwR $wR;  set hwG $wG;  set hwB $wB
    set nSteps [expr {max($wR, $wG, $wB)}]
    set stepR [expr {($nSteps > 0)?  $wR / $nSteps  : 1}]
    set stepG [expr {($nSteps > 0)?  $wG / $nSteps  : 1}]
    set stepB [expr {($nSteps > 0)?  $wB / $nSteps  : 1}]
    set midI 0;                                  # 'central' color is the first
    set minR $centralR;  set minG $centralG;  set minB $centralB
  } else {
    ok_err_msg "Please specify whether the range is symmetrical as SYM or UNI; value '$symRange_SYMorUNI' is invalid"
    return  0
  }
  # generate colors for all steps; ensure 'centralRGB' in the middle
  set rgbList [list];  set centralIncluded 0;  set index 0
  # maintain cR,cG,cB as accumulated FLOAT color values
  for {set i 0;  set cR $minR; set cG $minG; set cB $minB}    \
    {$i <= $nSteps}  {incr i 1}                                {
      set iR [expr {int(round($cR))}];  set iG [expr {int(round($cG))}]
      set iB [expr {int(round($cB))}]
      if { [rgbTrioValid $iR $iG $iB  0] }  {
	lappend rgbList [list $index  $iR $iG $iB]
	incr index 1
	if { ($iR == $centralR && ($iG == $centralG)) && ($iB == $centralB) }  {
	  if { $centralIncluded }  { ;  # this color already listed
	    continue
	  }
	  set centralIncluded 1
	}
      } else {
	ok_warn_msg "Skipped invalid RGB combo {$iR $iG $iB}"
      }
      set cR [expr {$cR + $stepR}];  set cG [expr {$cG + $stepG}]
      set cB [expr {$cB + $stepB}]
      # insert 'centralRGB' in the middle if absent
      if { !$centralIncluded && ($i >= $midI) }  {
	lappend rgbList [list $index  $centralR $centralG $centralB]
	incr index 1
	set centralIncluded 1
      }
    }
  
  puts "@@ rgbList(rgb=({$centralRGB} +- 0.5*{$bandRangeWidths}) = {$rgbList}"
  return  [generate_colorchart_from_list  $rgbList  $bgColor  \
                                          $maxWidth  $maxHeight  $outSpec]
}



# Returns list of 0|1 {lowRed lowCyan}
proc ::img_proc::detect_anaglyph_low_channels {rgb}  {
  set hsv [rgbToHsv {*}$rgb]
  lassign $hsv hue sat val
  puts "@@ detect_anaglyph_low_channels({$rgb} / {$hsv})"
  set lowRed 0;  set lowCyan 0
  foreach lowColorRange [_sat_ranges_cyan]  {
    lassign $lowColorRange lo hi
    if { ($hue >= $lo) && ($hue <= $hi) }  {
      set lowRed 1;  break
    }
  }
  foreach lowColorRange [_sat_ranges_red]  {
    lassign $lowColorRange lo hi
    if { ($hue >= $lo) && ($hue <= $hi) }  {
      set lowCyan 1;  break
    }
  }
  return  [list $lowRed $lowCyan]
}



################################################################################
# RGB={0,0,255}         => HSV(240,255,255) <= RR
# RGB={0,255,0}         => HSV(120,255,255) <= RR
# RGB={0,255,255}       => HSV(180,255,255) <= RR
# RGB={255,0,0}         => HSV(0  ,255,255) <= RR
proc ::img_proc::_sat_ranges_red  {}  {
  variable HUE_RANGE_HALF_WIDTH
  return  [list \
   [list [expr 0   -$HUE_RANGE_HALF_WIDTH]  [expr 0   +$HUE_RANGE_HALF_WIDTH]] \
   [list [expr 360 -$HUE_RANGE_HALF_WIDTH]  [expr 360 +$HUE_RANGE_HALF_WIDTH]] ]
}
proc ::img_proc::_sat_ranges_cyan {}  {
  variable HUE_RANGE_HALF_WIDTH
  return  [list \
   [list [expr 120 -$HUE_RANGE_HALF_WIDTH]  [expr 120 +$HUE_RANGE_HALF_WIDTH]] \
   [list [expr 180 -$HUE_RANGE_HALF_WIDTH]  [expr 180 +$HUE_RANGE_HALF_WIDTH]] \
   [list [expr 240 -$HUE_RANGE_HALF_WIDTH]  [expr 240 +$HUE_RANGE_HALF_WIDTH]] ]
}
