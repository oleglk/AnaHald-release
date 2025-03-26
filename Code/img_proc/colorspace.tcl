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

# colorspace.tcl

# Adopted from https://wiki.tcl-lang.org/page/HSV+and+RGB
# Note the rgbToHsv / hsvToRgb pair encodes saturation and value from 0-255, not the usual 0-100%

global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide img_proc 0.1
}

namespace eval ::img_proc:: {

  variable WB_TOLERANCE                      0.05;  # relative

  variable MIN_COLOR_VAL_FOR_RGB_RATIO       0.5;  # protection from zero

  variable _MIN_RGB_RATIO         [expr {$MIN_COLOR_VAL_FOR_RGB_RATIO / 255.0}];
  variable _MAX_RGB_RATIO         [expr {255.0 / $MIN_COLOR_VAL_FOR_RGB_RATIO}];
  
  namespace export                   \
    rgbTrioValid                     \
#   hsvTrioValid                     \
    rgbToHsv                         \
    hsvToRgb                         \
    hls2rgb                          \
    rgbToRedHsv                      \
    rgbToCyanHsv                     \
    rgbToBright                      \
    rgbToRedBright                   \
    rgbToCyanBright                  \
    rgbToRedCyanRivalry              \
    sort_colors_by_wb                \
    verify_colors_sorted_by_wb       \
    get_min_color_val_for_rgb_ratio  \
    set_min_color_val_for_rgb_ratio  \
    safe_color_ratio                 \
    band_min_for_rgb                 \
    band_max_for_rgb                 \
    band_min_for_wb                  \
    band_max_for_wb                  \
    color_is_within_band             \
    wb_of_colors_are_close           \
    rgb_to_wb                        \
#   calc_color_to_color_scale_factor \
    max_rgb_to_depth                 \
}



proc ::img_proc::rgbTrioValid {r g b {loud 1}}  {
  set ok 1
  foreach c [list $r $g $b]  {
    if { ($c < 0) || ($c > 255) }  { set ok 0;  break }
  }
  if { !$ok && $loud }  { ok_err_msg "Invalid RGB combo {$r $g $b}" }
  return  $ok
}


proc ::img_proc::rgbToHsv {r g b} {
  if { ![rgbTrioValid $r $g $b  1] }  { error  "Invalid color" }; # cause a mess
    set temp  [expr {min($r, $g, $b)}]
    set value [expr {max($r, $g, $b)}]
    set range [expr {$value-$temp}]
    if {$range == 0} {
        set hue 0
    } else {
        if {$value == $r} {
            set top [expr {$g-$b}]
            if {$g >= $b} {
                set angle 0
            } else {
                set angle 360
            }
        } elseif {$value == $g} {
            set top [expr {$b-$r}]
            set angle 120
        } elseif {$value == $b} {
            set top [expr {$r-$g}]
            set angle 240
        }
        set hue [expr { round( double($top) / $range * 60 + $angle ) }]
    }

    if {$value == 0} {
        set saturation 0
    } else {
        set saturation [expr { round( 255 - double($temp) / $value * 255 ) }]
    }
    return [list $hue $saturation $value]
}

proc ::img_proc::hsvToRgb {h s v} {
    set Hi [expr { int( double($h) / 60 ) % 6 }]
    set f [expr { double($h) / 60 - $Hi }]
    set s [expr { double($s)/255 }]
    set v [expr { double($v)/255 }]
    set p [expr { double($v) * (1 - $s) }]
    set q [expr { double($v) * (1 - $f * $s) }]
    set t [expr { double($v) * (1 - (1 - $f) * $s) }]
    switch -- $Hi {
        0 {
            set r $v
            set g $t
            set b $p
        }
        1 {
            set r $q
            set g $v
            set b $p
        }
        2 {
            set r $p
            set g $v
            set b $t
        }
        3 {
            set r $p
            set g $q
            set b $v
        }
        4 {
            set r $t
            set g $p
            set b $v
        }
        5 {
            set r $v
            set g $p
            set b $q
        }
        default {
            error "Wrong Hi value in hsvToRgb procedure! This should never happen!"
        }
    }
    set r [expr {round($r*255)}]
    set g [expr {round($g*255)}]
    set b [expr {round($b*255)}]
    return [list $r $g $b]
}


proc ::img_proc::hls2rgb {h l s} {
    # h, l and s are floats between 0.0 and 1.0, ditto for r, g and b
    # h = 0   => red
    # h = 1/3 => green
    # h = 2/3 => blue

    set h6 [expr {($h-floor($h)) * 6}]
    set r [expr {($h6 <= 3) ? (2-$h6) : ($h6-4)}]
    set g [expr {($h6 <= 2) ? ($h6) :
                 ($h6 <= 5) ? (4-$h6) : ($h6-6)}]
    set b [expr {($h6 <= 1) ? (-$h6) :
                 ($h6 <= 4) ? ($h6-2) : (6-$h6)}]
    set r [expr {max(0.0, min(1.0, double($r)))}]
    set g [expr {max(0.0, min(1.0, double($g)))}]
    set b [expr {max(0.0, min(1.0, double($b)))}]

    set r [expr {(($r-1) * $s + 1) * $l}]
    set g [expr {(($g-1) * $s + 1) * $l}]
    set b [expr {(($b-1) * $s + 1) * $l}]
    return [list $r $g $b]
}


# The brightness or luminance of a color is calculated
#     as a weighted sum of the red, green, and blue values.
# A common formula is:   Luminance = 0.2126 * R + 0.7152 * G + 0.0722 * B.
## Adopted from https://www.quora.com/How-do-you-know-the-color-is-the-same-brightness-in-RGB-if-RGB-mix-the-color-value-and-the-brightness-value
proc ::img_proc::rgbToBright {r g b} {
  return  [expr {0.2126*$r + 0.7152*$g + 0.0722*$b}]
}


proc ::img_proc::rgbToBright_int {r g b} {
  return  [expr {min( 255,  round([rgbToBright $r $g $b]) )}]
}



############## BEGIN: Anaglyph-related stuff ###################################
proc ::img_proc::rgbToRedHsv {r g b} {
  return  [rgbToHsv $r 0 0]
}


proc ::img_proc::rgbToCyanHsv {r g b} {
  return  [rgbToHsv 0 $g $b]
}


proc ::img_proc::rgbToRedBright {r g b} {
  return  [rgbToBright $r 0 0]
}

proc ::img_proc::rgbToCyanBright {r g b} {
  return  [rgbToBright 0 $g $b]
}


# TMP: return rivalry as saturation
proc ::img_proc::rgbToRedCyanRivalry {r g b} {
  set hsv [rgbToHsv $r $g $b]
  lassign $hsv hue sat val
  return  $sat
}


# 'rgbList' is a list of {?index? R G B} lists of integers
# Returns the list sorted by R/G, then R/B
## Example 1:  sort_colors_by_wb {{100 2 2} {50 3 3} {100 51 50} {50 26 27}}
## Example 2:  sort_colors_by_wb {{11 12 13} {4 5 4} {4 5 6} {7 8 9}}
proc ::img_proc::sort_colors_by_wb {rgbList}  {
  if { [llength $rgbList] == 0 }  { return  $rgbList }
  set cmpProc [expr {([llength [lindex $rgbList 0]] ==4)? "_irgb_cmp" : "_rgb_cmp"}]
  return  [lsort  -command $cmpProc  -increasing  $rgbList]
}


proc ::img_proc::verify_colors_sorted_by_wb {rgbList {priErr 1}}  {
  if { [llength $rgbList] == 0 }  { return  1 }
  set cmpProc [expr {([llength [lindex $rgbList 0]] ==4)? "_irgb_cmp" : "_rgb_cmp"}]
  set prevRGB {0.0 255 255};  # R/G, R.B are smaller than expected min  
  foreach rgb $rgbList {
    if { [$cmpProc $prevRGB $rgb] > 0 }  {
      if { $priErr }  {
        ok_err_msg "Violation of sorted order by white-balance - at ... {$prevRGB}, {$rgb}, ..."
      }
      return  0
    }
    set prevRGB $rgb
  }
  return  1
}


proc ::img_proc::_irgb_cmp {irgb1 irgb2}  {
  return  [_rgb_cmp  [lrange $irgb1 end-2 end]  [lrange $irgb2 end-2 end]]
}


# Returns 1|0|-1 if 'rgb1' is larger|equal|smaller compared to 'rgb2'
proc ::img_proc::_rgb_cmp {rgb1 rgb2}  {
  lassign $rgb1 r1 g1 b1
  lassign $rgb2 r2 g2 b2
  set rgRatio1 [safe_color_ratio $r1 $g1];  # was: [expr {1.0 * $r1/$g1}]
  set rgRatio2 [safe_color_ratio $r2 $g2];  # was: [expr {1.0 * $r2/$g2}]
  set rbRatio1 [safe_color_ratio $r1 $b1];  # was: [expr {1.0 * $r1/$b1}]
  set rbRatio2 [safe_color_ratio $r2 $b2];  # was: [expr {1.0 * $r2/$b2}]
  ##puts "@@ rgRatio1=$rgRatio1 rgRatio2=$rgRatio2  rbRatio1=$rbRatio1 rbRatio2=$rbRatio2"
  if { $rgRatio1 > $rgRatio2 }  { return  1 }
  if { $rgRatio1 < $rgRatio2 }  { return -1 }
  if { $rbRatio1 > $rbRatio2 }  { return  1 }
  if { $rbRatio1 < $rbRatio2 }  { return -1 }
  return  0
}


# # Ratios internally rely on 1 ... 256 range 
# ### use constants for speed-up;  0.1/255 = 0.0003921568627450981
# proc ::img_proc::_min_rgbRatio {}  { return 0.00390625 };  # ~ [expr {1.0 / 256}]
# proc ::img_proc::_max_rgbRatio {}  { return 256.0      };  # ~ [expr {256 / 1.0}]
# proc ::img_proc::_min_rgbWB []  { return {0.00390625 0.00390625} }
# proc ::img_proc::_max_rgbWB []  { return {256.0      256.0} }

# # Returns bound-protected c1/c2. DO NOT call it inside ::img_proc (performance)
# proc ::img_proc::safe_color_ratio__plus1 {c1 c2} {
#   # protect from 0 by using [1 ... 256] range instead of [0 ... 255]
#   return  [expr {max([_min_rgbRatio],  1.0 * ($c1+1) / ($c2+1))}]
# }


proc ::img_proc::get_min_color_val_for_rgb_ratio []  {
  return  $img_proc::MIN_COLOR_VAL_FOR_RGB_RATIO
}


proc ::img_proc::set_min_color_val_for_rgb_ratio {newVal}  {
  ok_assert { ($newVal > 0) && ($newVal <= 1) }  \
    "* Invalid value $newVal for min-color-val-for-channel-ratio; must be (0..1]"
  set img_proc::MIN_COLOR_VAL_FOR_RGB_RATIO $newVal
  set img_proc::_MIN_RGB_RATIO  [expr {$newVal / 255.0}]
  set img_proc::_MAX_RGB_RATIO  [expr {255.0   / $newVal}]
  ok_info_msg "Color-ratio tuning: MIN_COLOR_VAL_FOR_RGB_RATIO=$img_proc::MIN_COLOR_VAL_FOR_RGB_RATIO;  _MIN_RGB_RATIO=$img_proc::_MIN_RGB_RATIO;  _MAX_RGB_RATIO=$img_proc::_MAX_RGB_RATIO"
}


# Ratios internally rely on MIN_COLOR_VAL_FOR_RGB_RATIO ... 255 range 
### use constants for speed-up;  0.5/255 = 0.00196078431372549
proc ::img_proc::_min_rgbRatio {}  { return  $img_proc::_MIN_RGB_RATIO };
proc ::img_proc::_max_rgbRatio {}  { return  $img_proc::_MAX_RGB_RATIO };
proc ::img_proc::_min_rgbWB []  {
  return  {$img_proc::_MIN_RGB_RATIO $img_proc::_MIN_RGB_RATIO} }
proc ::img_proc::_max_rgbWB []  {
  return  {$img_proc::_MAX_RGB_RATIO $img_proc::_MAX_RGB_RATIO} }


# Returns bound-protected c1/c2. DO NOT call it inside ::img_proc (performance)
proc ::img_proc::safe_color_ratio {c1 c2} {
  # protect from 0 by using [MIN_COLOR_VAL_FOR_RGB_RATIO ... 255] range
  # .....................................  instead of [0 ... 255]
  return  [expr {1.0 * $c1 / max($c2, $img_proc::MIN_COLOR_VAL_FOR_RGB_RATIO)}]
}



# # safeColorRatio == (c1 + 1)/(c2 + 1)
# # Returns == c1/c2 * c3
# ## 
# proc ::img_proc::TODO__scale_color_by_safe_color_ratio {c1 c2 c3} {
# }

# safeColorRatio == (c1 + 1)/(c2 + 1)
# res == c1/c2 * c3 ?vs? (c3 + 1) * (c1 + 1)/(c2 + 1) - 1
# proc Scale0 {c1 c2 c3} {return [expr ($c3+0)*1.0*$c1/$c2               -0]}
# proc Scale1 {c1 c2 c3} {return [expr ($c3+1)*[safe_color_ratio $c1 $c2] -1]}
# proc Scale2 {c1 c2 c3} {return [expr ($c3+0)*[safe_color_ratio $c1 $c2] -0]}
# lassign {50 25 4} c1 c2 c3;  foreach prc {"Scale0" "Scale1" "Scale2"}  {puts -nonewline "   $prc: [$prc $c1 $c2 $c3]"}; puts ""
# ## 
# proc ::img_proc::scale_color_by_safe_color_ratio {c safeColorRatio} {
# }


# Returns pair of {min(R/G), min(R/B)}
#     considered WB-wise similar to {r g b}
proc ::img_proc::band_min_for_rgb {r g b}  {
  #was:  return  [img_proc::band_min_for_wb  \
	#          [expr {1.0 * $r / max(0.1, $g)}]   [expr {1.0 * $r / max(0.1, $b)}]]
  return  [img_proc::band_min_for_wb  \
             [safe_color_ratio $r $g]  [safe_color_ratio $r $b]]
}


# Returns pair of {max(R/G), max(R/B)}
#     considered WB-wise similar to {r g b}
proc ::img_proc::band_max_for_rgb {r g b}  {
  #was: return  [img_proc::band_max_for_wb  \
 	#          [expr {1.0 * $r / max(0.1, $g)}]   [expr {1.0 * $r / max(0.1, $b)}]]
  return  [img_proc::band_max_for_wb  \
             [safe_color_ratio $r $g]  [safe_color_ratio $r $b]]
}


# Returns pair of {min(R/G), min(R/B)}
#     considered WB-wise similar to {rgRatio rbRatio}
proc ::img_proc::band_min_for_wb {rgRatio rbRatio}  {
  variable WB_TOLERANCE
  return  [list [expr {max([_min_rgbRatio], $rgRatio*(1 - $WB_TOLERANCE))}]  \
     	          [expr {max([_min_rgbRatio], $rbRatio*(1 - $WB_TOLERANCE))}]]
}

# Returns pair of {max(R/G), max(R/B)}
#     considered WB-wise similar to {rgRatio rbRatio}
proc ::img_proc::band_max_for_wb {rgRatio rbRatio}  {
  variable WB_TOLERANCE
  return  [list [expr {min([_max_rgbRatio], $rgRatio*(1 + $WB_TOLERANCE))}]  \
                [expr {min([_max_rgbRatio], $rbRatio*(1 + $WB_TOLERANCE))}]]
}


## Example-1:  set c {60 20 15};  color_is_within_band {*}$c  [band_min_for_rgb {*}$c]  [band_max_for_rgb {*}$c]
## Example-2:  color_is_within_band  60 20 15  [band_min_for_rgb 60 20 15]  [band_max_for_rgb 60 20 15]
## Example-3:  color_is_within_band  60 20 15  [band_max_for_rgb 60 20 15]  [band_min_for_rgb 60 20 15]
## Example-4:  color_is_within_band  60 20 15  [band_min_for_rgb 60 20 15]  [band_min_for_rgb 60 20 15]
## Example-5:  color_is_within_band  60 20 15  {3 4}  {3 4}
proc ::img_proc::color_is_within_band {r g b  bandWbMin bandWbMax}  {
  set wbPair [rgb_to_wb $r $g $b];  # {R/G R/B}
  lassign $wbPair r2g r2b
  return  [expr { ([lindex $bandWbMin 0] <= $r2g) &&  \
    	          ($r2g <= [lindex $bandWbMax 0]) &&  \
		  ([lindex $bandWbMin 1] <= $r2b) &&  \
 	          ($r2b <= [lindex $bandWbMax 1]) }   ]
  ## ??? TODO: decide whether to consider width of band for {r g b} too ???
  # # set wbPairMin [rca__band_min_for_rgb $r $g $b]
  # # set wbPairMax [rca__band_max_for_rgb $r $g $b]
  # set rgRatio [expr {1.0 * $r/$g}]
  # set rbRatio [expr {1.0 * $r/$b}]
  # return  [expr {  ($rgRatio >= [lindex $bandWbMin 0]) && \
  #                  ($rbRatio >= [lindex $bandWbMin 1]) && \
  # 		   ($rgRatio <= [lindex $bandWbMax 0]) && \
  # 	           ($rbRatio <= [lindex $bandWbMax 1])   }]
}


# Checks colors being within bands of each other, not bands' intersection
proc ::img_proc::wb_of_colors_are_close {r1 g1 b1  r2 g2 b2}  {
  set bandMin1 [band_min_for_rgb $r1 $g1 $b1]
  set bandMax1 [band_max_for_rgb $r1 $g1 $b1]
  set bandMin2 [band_min_for_rgb $r2 $g2 $b2]
  set bandMax2 [band_max_for_rgb $r2 $g2 $b2]
  return  [expr { [color_is_within_band $r1 $g1 $b1  $bandMin2 $bandMax2] ||  \
                  [color_is_within_band $r2 $g2 $b2  $bandMin1 $bandMax1] } ]
}


# Returns pair of {R/G, R/B} as a list
## Example:  foreach irgb {{1  0 0 0} {0  0 31 0} {2  95 31 0}}  {puts "{$irgb} => [rgb_to_wb {*}[lrange $irgb end-2 end]]"}
proc ::img_proc::rgb_to_wb {r g b}  {
#  return  [list [expr {1.0*$r / max(0.1, $g)}]  [expr {1.0*$r / max(0.1, $b)}]]
  return  [list [safe_color_ratio $r $g]   [safe_color_ratio $r $b]]
}


# proc ::img_proc::calc_color_to_color_scale_factor {fromColor toColor}  {
#   return  1.05;    # facilitates constant multi-scale
#   ## (FEASIBILITY OF THE BELOW APPROACH IS UNCLEAR)
#   # lassign $fromColor  fR fG fB
#   # lassign $toColor    tR tG tB
#   # if { ![rgbTrioValid $fR $fG $fB 1] || ![rgbTrioValid $tR $tG $tB 1] }  {
#   #   error  "Invalid color" }; # cause a mess
#   # return  [list  [expr {1.0 * $tR / max(1,$fR)}]  \
#   # 	         [expr {1.0 * $tG / max(1,$fG)}]  \
#   #        	 [expr {1.0 * $tB / max(1,$fB)}]]
# }


proc ::img_proc::max_rgb_to_depth {maxRgbChannelVal}  {
  if {       $maxRgbChannelVal == 255   }  { return  8
  } elseif { $maxRgbChannelVal == 65535 }  { return  16
  } else { error "* Invalid maximum RGB channel value $maxRgbChannelVal; should be 255 or 65535"
  }
}


# proc ::img_proc::BAD__rgbToRedCyanRivalry {r g b} {
#   set _EPS 0.01
#   set redB [rgbToBright $r 0 0];  set cyanB [rgbToBright 0 $g $b]
#   set minB [expr {min($redB, $cyanB)}];  set maxB [expr {max($redB, $cyanB)}]
#   if { $minB > $_EPS }  { return  [expr {$maxB / $minB}] }
#   if { $maxB < $_EPS }  { return  1.0 }
#   #return  [expr {abs([rgbToBright $r 0 0] - [rgbToBright 0 $g $b])}]
# }

############## END:   Anaglyph-related stuff ###################################


# # Demo
# set r 100
# set g 200
# set b 150
# foreach {h s v} [rgbToHsv $r $g $b] {}
# puts "rgb: $r $g $b -> hsv: $h $s $v"
# puts "back to hsv: [hsvToRgb $h $s $v]"
