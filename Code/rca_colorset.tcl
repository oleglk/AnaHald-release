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

# rca_colorset.tcl

# Debug loading (Windows):    catch {namespace delete rca img_proc ok_utils;  rename arrange_anahald ""};    source C:/ANY/GitWork/AnaHald/Code/setup_anahald.tcl;    arrange_anahald;    ok_set_loud 1
# Debug loading (Linux):      catch {namespace delete rca img_proc ok_utils;  rename arrange_anahald ""};    cd ~/ANY/GitWork/AnaHald;  source Code/setup_anahald.tcl;    arrange_anahald;    ok_set_loud 1


set SCRIPT_DIR [file dirname [info script]]
if { ![info exists ANAHALD_SETUP_PERFORMED] || !$ANAHALD_SETUP_PERFORMED }  {
  source [file join $SCRIPT_DIR "setup_anahald.tcl"]
  # if { 0 == [set_ext_tool_paths_from_csv  "~/dualcam_ext_tool_dirs.csv"] } {
  #   set err "Fatal: external tools aren't configured. Aborting"
  #   ok_err_msg $err
  #   error $err
  # }

  # set ANAHALD_SETUP_PERFORMED 1
  ok_info_msg "Finished setup of AnaHald suite (context: '[file tail [info script]]')"
}


namespace eval ::rca:: {

  variable CFG;  array unset CFG;  # configuration array
  variable _CFG_REQUIRED_OPTIONS  0;  # to check config files for missing options

  ######## BEGIN:  "constants" ##################################################
  variable _CFG_SECTION_ORIGINAL    {[Original_User_Specified]};
  variable _CFG_SECTION_DERIVED     {[Secondary]};

  variable _MAX_RGB_VAL             255
  # Workaround to ensure 'CFG(_LowPassThreshold)' >= 1 to prevent corner case
  variable _MIN_LowPassFractionWhenMinor [expr (1.0 / $rca::_MAX_RGB_VAL)]
  
  variable _MIN_MINOR_TO_MAJOR      1;  # min-minor balanced directly vs the major
  variable _MIN_MINOR_AS_MAX_MINOR  2;  # relative-change of min-minor equal to relative-change of max-minor

  # How to smoothen the balanced/unbalanced boundary when fixing colors
  variable _SMOOTH_BND_BALANCED_LINEAR     1
  variable _SMOOTH_BND_BALANCED_PARABOLIC  2
  ######## END:    "constants" ##################################################

  ######## BEGIN:  default configuration settings ###############################
  set CFG(MaxRgbVal) $rca::_MAX_RGB_VAL

  ####### User-specified settings
  set CFG(MaxBalancedMajorToMaxMinorRatio) 2.0; # max( r/max(g,b), max(g,b)/r )

  # define part of balanced colors range to scale diminishingly towards grey-s
  #     (performed to smoothen boundary btw balanced and unbalanced)
  # "marginally balanced" ==
  #   == [MinBndBalancedMajorToMaxMinorRatio ... MaxBalancedMajorToMaxMinorRatio]
  set CFG(MinBndBalancedMajorToMaxMinorRatio)  1.3;  # 1.1+;
  # set CFG(MinBndBalancedMajorToMaxMinorRatio) [expr {  \
  #        0.75 * $CFG(MaxBalancedMajorToMaxMinorRatio)}]

  set CFG(GreenToBlueBiasMultWhenMinor)  1.0;  # G = G*BiasMult;  B = B/BiasMult

  # PreSqueezeMajorToFract == (newMajor - oldMaxMinor / (oldMajor - oldMaxMinor)
  # newMajor = oldMaxMinor + PreSqueezeMajorToFract * (oldMajor - oldMaxMinor)
  # Example1: (r0 g0 b0)=(200 100  50), fr=0.75  => r1 = 100+0.75*(200-100) = 175
  # Example2: (r0 g0 b0)=(200 150  50), fr=0.50  => r1 = 150+0.50*(200-150) = 175
  # Example3: (r0 g0 b0)=(200  50 150), fr=0.10  => r1 = 150+0.10*(200-150) = 155
  set CFG(PreSqueezeMajorToFract) 1.0;  # maj1 = maxMinor0 + fr *(maj0-maxMinor0)

  # TODO: comment for PreInflateMinorToFract
  set CFG(PreInflateMinorToFract) 1.0;  # min1 = maxMajor0 - fr *(maj0-maxMinor0)

  set CFG(MinMinorScaleOption)  $_MIN_MINOR_TO_MAJOR

  set CFG(SmoothBndBalancedOption)  $_SMOOTH_BND_BALANCED_PARABOLIC

  set _CFG_REQUIRED_OPTIONS [array names CFG];  # right after CFG array init !!!

  set CFG(_ZeroSubstRgbValForRatio)  0.5;  # value to use in safe ratio instead of zero; should be >0 but <=1; HIDDEN OPTION DEFINED ON TOP-LEVEL AS WORKAROUND

  ####### Automatic/derived settings
  proc ::rca::_process_config_derived_options {}  {;  # define early to call here
    variable CFG
    set CFG(_MinRgbVal) 0
    # set CFG(_ZeroSubstRgbValForRatio) performed on top-level - as a workaround
    set CFG(_MaxBalancedMajorToMinMinorRatio) 6.0; # max(r/min(g,b), ?min(g,b)/r)
    # Scaling based on _MaxBalancedMajorToMinMinorRatio problematic; deactivated
    
    set CFG(_ScaleBoudaryBalanced) [expr {  \
		  $CFG(MinBndBalancedMajorToMaxMinorRatio) <  \
		            	          $CFG(MaxBalancedMajorToMaxMinorRatio)}]

    # Workaround to ensure 'CFG(_LowPassThreshold)' >= 1 to prevent corner case
    set CFG(_LowPassFractionWhenMinor)  [expr (1.0 / $rca::CFG(MaxRgbVal))]; # fraction of maxVal considered noise

    set CFG(_LowPassThreshold) [expr {round(  \
                          $CFG(MaxRgbVal) * $CFG(_LowPassFractionWhenMinor))}]

  }
  rca::_process_config_derived_options
  ######## END:    default configuratio settings ################################

  variable _CFG_BACKUP [array get CFG];  # store default setting right after load
  
  
  variable RED_CYAN_ANAGLYPH_SENSITIVITY_THRESHOLD  2

  variable SYS_TMP_DIR   {Y:/};  # for systems with randisk/etc.
  proc ::rca::_SYSTMP_OR_DIR {dirPath}  { ;  # use rca::SYS_TMP_DIR if available
    return  [expr {([info exists  rca::SYS_TMP_DIR] &&                   \
                    [file exists $rca::SYS_TMP_DIR])? $rca::SYS_TMP_DIR  \
                                                    : $dirPath}]
  }

  
  
  namespace export                      \
    balance_hald_file                   \
    build_all_balanced_colors_hald_file_by_config \
    check_config_sanity                 \
    check_free_output_space_sufficiency \
    list_all_balanced_colors            \
    format_rgb_list_as_color_enum       \
    make_column_image_from_rgb_list     \
    replace_all_mapped_colors_in_hald_list     \
    replace_all_mapped_colors_in_hald_file     \
    replace_all_unbalanced_colors_in_hald_file \
    build_all_balanced_colors_hald_file \
    hald_file_txt_to_tiff               \
    map_all_unbalanced_colors           \
    choose_colors_to_scale              \
    is_color_balanced_red_cyan          \
#    balance_red_cyan                   \
    store_config                        \
    load_config                         \
    reset_config_to_default             \
    select_config                       \
    collect_config_summary_from_file_list      \
    collect_config_summary_from_file_glob      \
}

# namespace import -force ::ok_utils::*;  # to reference proc-s without prefix
# namespace import -force ::img_proc::*;  # to reference proc-s without prefix




############### BEGIN: global variables #########################################
############### END:   global variables #########################################


#################################################################################
## TMP: AnaHald complete examples

# INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00703.TIF
proc __ANAHALD_EX_01 {}  {;  # -remap
  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00703.TIF"  256];  llength $qqL;    set qqMap [rca::map_all_unbalanced_colors $qqL];        set qqNew [rca::replace_all_mapped_colors_in_indexed_colors_list $qqL $qqMap];  llength $qqNew
  rca::make_column_image_from_rgb_list  $qqNew  1  TMP/DSC00703_newColors.tif
  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00703.TIF"  -remap TMP/DSC00703_newColors.tif -depth 8 -compress LZW "OUT/DSC00703_remap.TIF"
}

# kfar_kana_1.18.TIF
proc __ANAHALD_EX_02 {}  {;  # -remap
  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/kfar_kana_1.18.TIF"  256];  llength $qqL;    set qqMap [rca::map_all_unbalanced_colors $qqL];        set qqNew [rca::replace_all_mapped_colors_in_indexed_colors_list $qqL $qqMap];  llength $qqNew
  rca::make_column_image_from_rgb_list  $qqNew  1  TMP/kfar_kana_1.18_newColors.tif
  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/kfar_kana_1.18.TIF"  -remap TMP/kfar_kana_1.18_newColors.tif -depth 8 -compress LZW "OUT/kfar_kana_1.18_remap.TIF"
}


# Replace all unbalanced colors in hald_03
proc __ANAHALD_EX_03 {{verifyMap 0}}  {;  # -hald-clut with hald_03
  global qqMap;  # OK_TMP
  hald_read_from_text_file INP/hald_03.txt h3List 3
  set qqL [hald_list_to_colors_list $h3List];  llength $qqL
  set qqMap [rca::map_all_unbalanced_colors $qqL];  dict size $qqMap
  if { $verifyMap }  {
    rca::_DBG_verify_unbalanced_colors_mapping $qqL $qqMap
  }
  rca::replace_all_mapped_colors_in_hald_file  $qqL  "INP/hald_03.txt"  "Y:/hald_bal_3.txt"  $qqMap
  # View map with:  dict for {k v}  [dict create {*}[lrange $qqMap end-21 end]]  {puts "$k => $v"}
}


# Replace all unbalanced colors in hald_8
proc __ANAHALD_EX_04 {}  {;  # -hald-clut with hald_08
  set oldLoud $::ok_utils::LOUD_MODE
  ok_set_loud 0
  set OUTDIR [rca::_SYSTMP_OR_DIR "TMP"]
  hald_read_from_text_file INP/hald_08.txt h08List 8
  set qqL [hald_list_to_colors_list $h08List];  llength $qqL
  #ok_write_list_into_file  $qqL  "$OUTDIR/hald_08_colors.txt"
  set qqMap [rca::map_all_unbalanced_colors $qqL];  dict size $qqMap
  ok_write_list_into_file  $qqMap  "$OUTDIR/hald_08_map.txt"
  # View map with:  dict for {k v}  [dict create {*}[lrange $qqMap end-21 end]]  {puts "$k => $v"}

  rca::replace_all_mapped_colors_in_hald_file  $qqL  "INP/hald_08.txt"  "$OUTDIR/hald_bal_08.txt"  $qqMap
  ok_set_loud $oldLoud
}


# Replace all unbalanced colors in hald_16
proc __ANAHALD_EX_05 {}  {;  # -hald-clut with hald_16
  global qqMap;  # OK_TMP
  set oldLoud $::ok_utils::LOUD_MODE
  ok_set_loud 0
  set OUTDIR [rca::_SYSTMP_OR_DIR "TMP"]
  hald_read_from_text_file INP/hald_16.txt h16List 16
  set qqL [hald_list_to_colors_list $h16List];  llength $qqL
  set qqMap [rca::map_all_unbalanced_colors $qqL];  dict size $qqMap
  # View map with:  dict for {k v}  [dict create {*}[lrange $qqMap end-21 end]]  {puts "$k => $v"}

  rca::replace_all_mapped_colors_in_hald_file  $qqL  "INP/hald_16.txt"  "$OUTDIR/hald_bal_16.txt"  $qqMap
  ok_set_loud $oldLoud
}


proc __ANAHALD_EX_06 {}  {;  # kfar_kana_1.18.TIF;  -hald-clut
  ## Assume:  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}  hald:16  -depth 8  INP/hald_16.txt
  set OUTDIR [rca::_SYSTMP_OR_DIR "TMP"]
  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/kfar_kana_1.18.TIF"  256];  llength $qqL
  set qqMap [rca::map_all_unbalanced_colors $qqL];  dict size $qqMap
  rca::replace_all_mapped_colors_in_hald_file  $qqL  "INP/hald_16.txt"  "$OUTDIR/hald_16__kfar_kana_1.18.txt"  $qqMap
  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/kfar_kana_1.18.TIF"  "$OUTDIR/hald_16__kfar_kana_1.18.txt" -hald-clut    -depth 8 -compress LZW "OUT/kfar_kana_1.18_hald16.TIF"
}
#################################################################################



############### BEGIN: AnaHald main procedures ######################################
# Applies balancing to TEXT-format HALD file 'identityHaldFilePath',
#  saves the result as TIF image in 'outDirOrEmpty'.
## Example HALD-03:  rca::balance_hald_file DEFAULT  INP/hald_03.txt  TMP
## Example HALD-08:  rca::balance_hald_file CFG/rma_ba02.ini  INP/hald_08.txt ""
proc ::rca::balance_hald_file {iniFilePathOrCurrentOrDefault           \
                                 identityHaldFilePath  outDirOrEmpty}  {
  if { 0 == [select_config $iniFilePathOrCurrentOrDefault] }  {
    return  0;  # error already printed
  }
  set outDir [expr {($outDirOrEmpty != "")? $outDirOrEmpty: [_SYSTMP_OR_DIR ""]}]
  if { $outDir == "" }  {
    ok_err_msg "Please specify output-directory; either as 'outDirOrEmpty' argument or by assigning an _existent_ directory path to 'rca::SYS_TMP_DIR' variable"
    return  0
  }

  set oldLoud $::ok_utils::LOUD_MODE
  ok_set_loud 0;  # prevents too many prints

  set ext [file extension $identityHaldFilePath]
  set expExt [expr {($img_proc::_HALD_FORMAT_TXT_OR_PPM == 0)? ".TXT" : ".PPM"}]
  if { ![string equal -nocase $ext $expExt] }  {
    ok_err_msg "Cannot balance $ext HALD-s when system is in $expExt mode"
    ok_set_loud $oldLoud
    return  0
  }
  # read identity HALD only to detect hald-level
  if { 0 == [hald_read_from_text_file $identityHaldFilePath hList hLevel] }  {
    ok_set_loud $oldLoud
    return  0
  }
  # TODO: detect HALD-file bit-depth from content and compare to CFG(MaxRgbVal)
  if { 0 == [set spaceCheckRes [check_free_output_space_sufficiency           \
                                  $hLevel  "TIF"  $outDir]] }  {
    ok_set_loud $oldLoud
    return  0;  # not enough space - known; message already printed
  } elseif { $spaceCheckRes < 0 }  {
    ok_warn_msg "Cannot check free disk availability; continuing speculatively."
  }

  set iniFileName [file rootname [file tail $iniFilePathOrCurrentOrDefault]]
  set outName "hald__${iniFileName}__[format {%02d} ${hLevel}].TIF"; # was ".txt"
  set newHaldFilePath [file join $outDir $outName]
  if { 0 == [ok_create_absdirs_in_list [list $outDir]  \
               [list "Output directory for HALD file"]] }  {
    return  0;  # error already printed
  }
  set res [replace_all_unbalanced_colors_in_hald_file $identityHaldFilePath   \
             $newHaldFilePath];  # relevant message printed

  ok_set_loud $oldLoud
  return  $res
}


## Example HALD-02:  rca::build_all_balanced_colors_hald_file_by_config CURRENT  2  TMP
## Example HALD-03:  rca::build_all_balanced_colors_hald_file_by_config DEFAULT  3  TMP
## Example HALD-08:  rca::build_all_balanced_colors_hald_file_by_config CFG/rma_ba02.ini  8  ""
proc ::rca::build_all_balanced_colors_hald_file_by_config {                     \
                            iniFilePathOrCurrentOrDefault level outDirOrEmpty}  {
  if { 0 == [select_config $iniFilePathOrCurrentOrDefault] }  {
    return  0;  # error already printed
  }
  set outDir [expr {($outDirOrEmpty != "")? $outDirOrEmpty: [_SYSTMP_OR_DIR ""]}]
  if { $outDir == "" }  {
    ok_err_msg "Please specify output-directory; either as 'outDirOrEmpty' argument or by assigning an _existent_ directory path to 'rca::SYS_TMP_DIR' variable"
    return  0
  }

  set oldLoud $::ok_utils::LOUD_MODE
  ok_set_loud 0;  # prevents too many prints
  
  set iniFileName [file rootname [file tail $iniFilePathOrCurrentOrDefault]]
  set outName "hald__${iniFileName}__[format {%02d} ${level}].TIF"; # was ".txt"
  set newHaldFilePath [file join $outDir $outName]
  if { 0 == [ok_create_absdirs_in_list [list $outDir]  \
               [list "Output directory for HALD file"]] }  {
    return  0;  # error already printed
  }
  set res [build_all_balanced_colors_hald_file $level $newHaldFilePath]
  # relevant message printed

  ok_set_loud $oldLoud
  return  $res
}

############### END:   AnaHald main procedures ##################################


proc ::rca::check_config_sanity {{cfgArrName "rca::CFG"}}  {
  upvar $cfgArrName _cfg
  variable _CFG_REQUIRED_OPTIONS
  set errList [list]
  
  if { $_cfg(_MinRgbVal) != 0 }  {
    lappend errList "Invalid _MinRgbVal '$_cfg(_MinRgbVal)'; must be 0"
  }
  if { ($_cfg(MaxRgbVal) != 255) && ($_cfg(MaxRgbVal) != 65535) }  {
    lappend errList "Invalid MaxRgbVal '$_cfg(MaxRgbVal)'; must be 255 or 65535"
  }
  if { ($_cfg(MaxBalancedMajorToMaxMinorRatio) < 1.0) ||  \
       ($_cfg(MaxBalancedMajorToMaxMinorRatio) > 6.0) }  {
    lappend errList "Invalid MaxBalancedMajorToMaxMinorRatio '$_cfg(MaxBalancedMajorToMaxMinorRatio)'; must be \[1.0 ... 6.0\]"
  }
  if { ($_cfg(GreenToBlueBiasMultWhenMinor) < 0.5) ||  \
       ($_cfg(GreenToBlueBiasMultWhenMinor) > 2.0) }  {
    lappend errList "Invalid GreenToBlueBiasMultWhenMinor '$_cfg(GreenToBlueBiasMultWhenMinor)'; must be \[0.5 ... 2.0\]"
  }
  if { ($_cfg(PreSqueezeMajorToFract) < 0.5) ||  \
       ($_cfg(PreSqueezeMajorToFract) > 1.0) }  {
    lappend errList "Invalid PreSqueezeMajorToFract '$_cfg(PreSqueezeMajorToFract)'; must be \[0.5 ... 1.0\]"
  }
  if { ($_cfg(PreInflateMinorToFract) < 0.5) ||  \
       ($_cfg(PreInflateMinorToFract) > 1.0) }  {
    lappend errList "Invalid PreInflateMinorToFract '$_cfg(PreInflateMinorToFract)'; must be \[0.5 ... 1.0\]"
  }
  if { ($_cfg(PreSqueezeMajorToFract) != 1.0) &&  \
       ($_cfg(PreInflateMinorToFract) != 1.0) }   {
    lappend errList "Only one of PreSqueezeMajorToFract or PreInflateMinorToFract allowed to be active (by being not equal to 1.0)"
  }
  if { ($_cfg(MinBndBalancedMajorToMaxMinorRatio) < 1.0) ||             \
       ($_cfg(MinBndBalancedMajorToMaxMinorRatio) >                     \
                                $_cfg(MaxBalancedMajorToMaxMinorRatio)) }  {
    lappend errList "Invalid MinBndBalancedMajorToMaxMinorRatio '$_cfg(MinBndBalancedMajorToMaxMinorRatio)'; must be \[1.0 ... MaxBalancedMajorToMaxMinorRatio=$_cfg(MaxBalancedMajorToMaxMinorRatio)\]"
  }
  if { ($_cfg(MinMinorScaleOption) != $rca::_MIN_MINOR_TO_MAJOR) &&  \
       ($_cfg(MinMinorScaleOption) != $rca::_MIN_MINOR_AS_MAX_MINOR) }  {
    lappend errList "Invalid MinMinorScaleOption '$_cfg(MinMinorScaleOption)'; must be $rca::_MIN_MINOR_TO_MAJOR or $rca::_MIN_MINOR_AS_MAX_MINOR"
  }
  if { ($_cfg(_LowPassFractionWhenMinor) < $rca::_MIN_LowPassFractionWhenMinor)  \
    || ($_cfg(_LowPassFractionWhenMinor) > 0.02) }  {
    lappend errList "Invalid _LowPassFractionWhenMinor '$_cfg(_LowPassFractionWhenMinor)'; must be \[$rca::_MIN_LowPassFractionWhenMinor ... 0.02\]"
  }
  if { ($_cfg(SmoothBndBalancedOption) !=$rca::_SMOOTH_BND_BALANCED_LINEAR) && \
       ($_cfg(SmoothBndBalancedOption) !=$rca::_SMOOTH_BND_BALANCED_PARABOLIC)} {
    lappend errList "Invalid SmoothBndBalancedOption '$_cfg(SmoothBndBalancedOption)'; must be $rca::_SMOOTH_BND_BALANCED_LINEAR or $rca::_SMOOTH_BND_BALANCED_PARABOLIC"
  }
  if { ($_cfg(_ZeroSubstRgbValForRatio) <= 0.0) ||  \
       ($_cfg(_ZeroSubstRgbValForRatio) >  0.9) }  {
    lappend errList "Invalid _ZeroSubstRgbValForRatio '$_cfg(_ZeroSubstRgbValForRatio)'; must be \[0.0 ... 0.9\]"
  }
  if { [llength $errList] == 0 }  {
    ok_info_msg "Check of configuration found no consistency errors in [array size _cfg] provided option(s)"
  } else {
    ok_err_msg "Check of configuration found [llength $errList] consistency error(s) in [array size _cfg] provided option(s)"
  }
  return  $errList
}


proc ::rca::check_free_output_space_sufficiency {haldLevel outExt outDir}  {
  if { ![hald_get_space_for_level_kb $haldLevel forTxt forTif forAll] }  {
    return  -1;  # invalid level; error already printed
  }
  if { -1 == [set freeKbOrNegative [ok_try_get_free_disk_space_kb $outDir]] }  {
    return  -1;  # error already printed
  }
  set requiredKb [switch -nocase $outExt {
    "TXT" { expr $forTxt }
    "PPM" { expr $forTxt }
    "TIF" { expr $forAll }
    default { ok_err_msg "Invalid HALD output format '$outExt'; should be TXT, PPM or TIF"
      return  -1
    }
  }]
  set descr "HALD file of level $haldLevel in format $outExt under directory '$outDir'"
  set spaceMsg "Free fisk space check for $descr - required: ${requiredKb}Kb;  available: ${freeKbOrNegative}Kb"
  ok_trace_msg $spaceMsg
  if { $freeKbOrNegative < $requiredKb }  {
    ok_info_msg $spaceMsg;  # made 'info' to protect error count 
    ok_err_msg "Insufficient disk space for $descr"
    return  0
  }
  ok_info_msg "Enough disk space available for $descr"
  return  1
}



############### BEGIN: common manipulations with list of colors #################
# Returns (HUGE) list of colors accepted by 'proc is_color_balanced_red_cyan'.
## Example:  set bColors [rca::list_all_balanced_colors 255];  llength $bColors
proc ::rca::list_all_balanced_colors {{maxC 255}}  {
  set bColors [list]
  set idx 0
  for {set cR $maxC} {$cR >= 0}  {incr cR -1}  {
    for {set cG $maxC} {$cG >= 0}  {incr cG -1}  {
      for {set cB $maxC} {$cB >= 0}  {incr cB -1}  {
	if { [is_color_balanced_red_cyan $cR $cG $cB] }  {
	  lappend bColors [list $idx $cR $cG $cB]
	  incr idx 1
	}
      }
    }
  }
  return  $bColors
}


# Converts input list of {index rVal gVal bVal} records
#    into IM color enumeration - standard txt: format.
###  Example output - like that of conversion fro tiff to txt:
###  (AnaHald) 57 % exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}   TMP/tricolors.tif  txt:
###  # ImageMagick pixel enumeration: 1,3,0,255,srgba
###  0,0: (255,0,0,255)  #FF0000FF  red
###  0,1: (0,255,0,255)  #00FF00FF  lime
###  0,2: (0,0,255,255)  #0000FFFF  blue
######
## Example 1:  set c3 [rca::format_rgb_list_as_color_enum  {{0 255 0 0} {1 0 255 0} {2 0 0 255}}];  llength $c3;  ok_write_list_into_file  $c3  TMP/colors3.txt
## Example 2:  ok_set_loud 0;  set bColors [rca::list_all_balanced_colors 255];  llength $bColors;  set fbColors [rca::format_rgb_list_as_color_enum $bColors];  ok_write_list_into_file  $fbColors  TMP/all_balanced_colors.txt
proc ::rca::format_rgb_list_as_color_enum {colorsList}  {
  set colorsEnum [list [format                                                \
			  "# ImageMagick pixel enumeration: 1,%d,0,255,srgba" \
			  [llength $colorsList]]]
  foreach colorLine $colorsList  {;  #{index rVal gVal bVal}
    if { ![img_proc::_parse_color_spec $colorLine index rVal gVal bVal] }  {
      return  0;  # error already printed
    }
    set oneColorStr [rca::_format_one_color_enum_line $index $rVal $gVal $bVal]
    lappend colorsEnum $oneColorStr
  }
  return  $colorsEnum
}


# Example output line:  0,7: (3,2,0,255)  #030200FF  srgba(3,2,0,1)
proc ::rca::_format_one_color_enum_line {index rVal gVal bVal}  {
  set oneColorStr [format                                                     \
 	      {0,%d: (%d,%d,%d,255)  #%02X%02X%02XFF srgba(%d,%d,%d,1)}        \
	      $index  $rVal $gVal $bVal  $rVal $gVal $bVal  $rVal $gVal $bVal]
  return  $oneColorStr
}
  

# 'colorsList' lists records {index rVal gVal bVal}
# !! It doesn't work for huge lists; use 'rca::format_rgb_list_as_color_enum' !!
## Example 1:  rca::make_column_image_from_rgb_list  {{0 255 0 0} {1 0 255 0} {2 0 0 255}}  1  TMP/tricolors.tif
## Example 2:  rca::make_column_image_from_rgb_list  {{0 255 0 0} {1 0 255 0} {2 0 0 255}}  10  TMP/tricolors10.tif
## Example 3:  set c40 [rca::list_all_balanced_colors 3];  rca::make_column_image_from_rgb_list  $c40  1  TMP/colors40.tif
## Example 4:  ok_set_loud 0;  set bColors [rca::list_all_balanced_colors 255];  rca::make_column_image_from_rgb_list  $bColors  1  TMP/allcolors_balanced.tif
## Verify with:  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}   TMP/tricolors.tif  -unique-colors txt:
## Example 4:  set qq3L [img_proc::list_image_unique_colors  "TMP/colors3.TIF"  256];  llength $qq3L;    set qq3Map [rca::map_all_unbalanced_colors $qq3L];  dict size $qq3Map;  
proc ::rca::make_column_image_from_rgb_list {colorsList rowWidth outSpec}  {
  if { ![string is integer $rowWidth] || ($rowWidth < 1) }  {
    ok_err_msg "Invalid color-sample row width $rowWidth"
    return  0
  }
  set outPath [outspec_to_outpath $outSpec]
  set descr "color-column image in '[file tail $outPath]'"

  set wd $rowWidth
  set ht [llength $colorsList]
  set bgColor "black";  # actually doesn;t matter
  set canvasArgs [format {-size %dx%d xc:%s}  $wd $ht $bgColor]

  # "-density 72" makes one point in font-size equal to one pixel
  set cmdStrPref "-density 72 -gravity north  -background $bgColor"
  set nColors [llength $colorsList]

  set drawCmds ""
  set colorsCnt 0
  set x1 0;  set x2 [expr $x1 + $rowWidth - 1];  # OK_TMP: for now - all centered
  set y 0
  foreach colorLine $colorsList  {;  #{index rVal gVal bVal}
    if { ![img_proc::_parse_color_spec $colorLine index rVal gVal bVal] }  {
      return  0;  # error already printed
    }
    set oneColorStr [format {  -fill "rgb(%d,%d,%d)"  -draw "line %d,%d %d,%d"} \
		       $rVal $gVal $bVal  $x1 $y  $x2 $y ]
    append  drawCmds  $oneColorStr
    incr y 1
    incr colorsCnt 1
  }
  set cmd "$::IMCONVERT   -colorspace RGB -depth 8  $cmdStrPref  $canvasArgs  $drawCmds  -set colorspace sRGB  $outSpec"
  #puts "@TMP@ (Color-column generation command) ==> '$cmd'"

  ok_info_msg "Running color-column generation command for $colorsCnt color(s); chart image size is ${wd}x${ht}"
  #exec  {*}$cmd
  if { 0 == [ok_run_silent_os_cmd $cmd] }  {
    return  0; # error already printed
  }
  ok_info_msg "Created $descr with $colorsCnt color(s)"
  return  1
}
############### END:   common manipulations with list of colors #################



################### BEGIN: Colorset proper #####################################

## Example-02:  set qq3L [img_proc::list_image_unique_colors  "TMP/colors3.TIF"  256];  llength $qq3L;    set qq3Map [rca::map_all_unbalanced_colors $qq3L];  dict size $qq3Map;        set qq3New [rca::replace_all_mapped_colors_in_indexed_colors_list $qq3L $qq3Map];  llength $qq3New
## Example-03:  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00035.TIF"  256];  llength $qqL;    set qqMap [rca::map_all_unbalanced_colors $qqL];        set qqNew [rca::replace_all_mapped_colors_in_indexed_colors_list $qqL $qqMap];  llength $qqNew
proc ::rca::replace_all_mapped_colors_in_indexed_colors_list {  \
                                   allColorsList {colorChangeMap 0}}  {
  if { 0 == [llength $allColorsList] }  {
    return  $allColorsList;  # nothing to do with empty colors-list
  }
  ok_assert { 4 == [llength [lindex $allColorsList 0]] }  "Indexed color list (index r g b) is expected"
  
  if { $colorChangeMap == 0 }  {
    set colorChangeMap [map_all_unbalanced_colors $allColorsList]
  }
  set newColorsList [list]
  set cntChanged 0
  foreach irgb $allColorsList  {
    lassign $irgb index r g b
    set rgb [list $r $g $b]
    if { ![dict exists $colorChangeMap $rgb] }  {
      lappend newColorsList $irgb
    } else {
      lappend newColorsList [list $index {*}[dict get $colorChangeMap $rgb]]
      ok_trace_msg "Replace {$irgb} \t by {[lindex $newColorsList end]}"
      incr cntChanged 1
    }
  }
  ok_info_msg "Replaced $cntChanged mapped color(s) in the color-list of [llength $newColorsList]"
  return  $newColorsList
}
## Using the results:
##  rca::make_column_image_from_rgb_list  $qqNew  1  TMP/DSC00035_newColors.tif
##  exec {C:/Program Files/ImageMagick-7.1.1-34/magick.exe}  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00035.TIF"  -remap TMP/DSC00035_newColors.tif -quality 90 "OUT/DSC00035_remap.JPG"


# Treats 'allColorsList' as list of all colors in an image
# Applies changes of 'colorChangeMap' to HALD of 'fullHaldList'.
# Returns the new modified HALD list or 0 on error.
# !!!!!!!!!!! SLOW FOR HUGE HALD LUT-S !!!!!!!!!!!
# !!!!!!!!!!! PARTIAL VERIFICATION     !!!!!!!!!!!
##---------##
## Example-01:  hald_read_from_text_file "INP/hald_03.txt"  haldOld haldLevel;  set haldNew [rca::replace_all_mapped_colors_in_hald_list {}  $haldOld  0];  hald_find_lists_diff $haldOld $haldNew
## Example-02:  hald_read_from_text_file "INP/hald_03.txt"  haldOld haldLevel;  set haldNew [rca::replace_all_mapped_colors_in_hald_list [list [list [hald_rgb_to_idx 255 0 0  16] 255 0 0]]  $haldOld  0];  hald_find_lists_diff $haldOld $haldNew
proc ::rca::replace_all_mapped_colors_in_hald_list {  \
                      allColorsList fullHaldList {colorChangeMap 0}}  {
  if { 0 == [llength $allColorsList] }  {
    return  $fullHaldList;  # nothing to do with empty colors-list
  }
  if { 4 != [llength [lindex $allColorsList 0]] }  {
    ok_err_msg  "Indexed color list (index r g b) is expected; got {[lindex $allColorsList 0]}"
    return  0
  }

  if { 0 == [set haldLevel [hald_calc_level_for_hald_list $fullHaldList]] }  {
    return  0;  # error already printed
  }

  if { $colorChangeMap == 0 }  {
    set colorChangeMap [map_all_unbalanced_colors $allColorsList]
  }
  set newHaldList [list]
  set cntChanged 0
  foreach haldLine $fullHaldList  {
    # set rgb [hald_line_to_rgb $haldLine]
    if { ![hald_parse_srgb_line $haldLine  x y  r g b] }  {
      return  0;  # error already printed
    }
    set rgb [list $r $g $b]
    if { ![dict exists $colorChangeMap $rgb] }  {
      lappend newHaldList $haldLine
    } else {
      # set haldIdx [hald_rgb_to_idx $r $g $b $haldLevel]
      lappend newHaldList [hald_format_srgb_line  $x $y  \
                             {*}[dict get $colorChangeMap $rgb]]; # dict-get safe
      ok_trace_msg "Replace {$rgb} \t by {[lindex $newHaldList end]}"
      incr cntChanged 1
    }
  }
  ok_info_msg "Replaced $cntChanged mapped color(s) in the HALD-list of [llength $newHaldList] color(s)"
  return  $newHaldList
}


##---------##
## Example-01:  rca::replace_all_mapped_colors_in_hald_file {}  "INP/hald_03.txt"  "TMP/hald_03_m01.txt"  0;    hald_find_text_files_diff "INP/hald_03.txt"  "TMP/hald_03_m01.txt"
## Example-02:  rca::replace_all_mapped_colors_in_hald_file {{0  0 0 0} {1  0 31 0} {2  95 31 0}}  "INP/hald_03.txt"  "TMP/hald_03_m02.txt"  0;    hald_find_text_files_diff "INP/hald_03.txt"  "TMP/hald_03_m02.txt"
proc ::rca::replace_all_mapped_colors_in_hald_file {  \
   allColorsList srcHaldFilePath newHaldFilePath {colorChangeMap 0}} {
  set commentGlob "#*"
  set timeStarted [clock seconds]
  if { (0 == [llength $allColorsList]) }  {
    if { ![ok_safe_copy_file $srcHaldFilePath $newHaldFilePath] }  {
      return  0;  # error a;ready printed
    }
    ok_info_msg "Unmodified copy of HALD-file '$srcHaldFilePath' saved in '$newHaldFilePath'"
    return  1;  # nothing to do with empty colors-list
  }
  if { ([llength $allColorsList] > 0) && \
         (4 != [llength [lindex $allColorsList 0]]) }  {
    ok_err_msg  "Indexed color list (index r g b) is expected; got {[lindex $allColorsList 0]}"
    return  0
  }

  if { $colorChangeMap == 0 }  {
    set colorChangeMap [map_all_unbalanced_colors $allColorsList]
  }

  if { ![file exists $srcHaldFilePath] }  {
    ok_err_msg "-E- Inexistent input file '$srcHaldFilePath'"
    return  0
  }

  if { ![ok_mkdir [file dirname $newHaldFilePath]] }  {
    return  0;  # error already printed
  }

  set cntChanged 0;  set cntAll 0
  # read-and-modify from source file line by line; save in the new file
  set tclExecResult [catch {
    set outF [open $newHaldFilePath  w]
    set inpF [open $srcHaldFilePath r]
    while { [gets $inpF oldHaldline] >= 0 } {
      if { [string match $commentGlob $oldHaldline]} {
        puts $outF $oldHaldline;  # copy comments as-is
      } else {
        if { ![hald_parse_srgb_line $oldHaldline  x y  r g b] }  {
          return  0;  # error already printed
        }
        set rgb [list $r $g $b]
        incr cntAll 1
        if { ($cntAll % 2097152) == 0 }  {; # 16777216/2097152==8 lines printed
          ok_trace_msg "... so far processed $cntAll color(s) in HALD list ..."
        }
        if { ![dict exists $colorChangeMap $rgb] }  {
          puts $outF $oldHaldline
        } else {
          set newRgb [dict get $colorChangeMap $rgb]; # dict-get is safe
          set newHaldLine [hald_format_srgb_line  $x $y  {*}$newRgb]
          puts $outF $newHaldLine
          ok_trace_msg "Replace {$rgb} \t by {$newRgb}"
          incr cntChanged 1
        }
      }
    }
    close $inpF
    close $outF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }
  
  ok_info_msg "Replaced $cntChanged mapped color(s) in HALD-file '$srcHaldFilePath' of $cntAll color(s); new version saved in '$newHaldFilePath'"
  ok_info_msg "Runtime of replacing $cntChanged of $cntAll color(s) in HALD-file is [expr {[clock seconds] - $timeStarted}] second(s)"
  return  1
}


##---------##
## Example-01:  rca::replace_all_unbalanced_colors_in_hald_file "INP/hald_03.txt"  "TMP/hald_03_m01.txt";    hald_find_text_files_diff "INP/hald_03.txt"  "TMP/hald_03_m01.txt"
proc ::rca::replace_all_unbalanced_colors_in_hald_file {srcHaldFilePath   \
                                                        newHaldFilePath}  {
  variable CFG
  set commentGlob "#*"
  set timeStarted [clock seconds]

  set ext [file extension $srcHaldFilePath]
  set expExt [expr {($img_proc::_HALD_FORMAT_TXT_OR_PPM == 0)? ".TXT" : ".PPM"}]
  if { $img_proc::_HALD_FORMAT_TXT_OR_PPM != 0 }  {
    ok_err_msg "Balancing existent HALD-s not supported when system is in $expExt mode"
    return  0
  }
  if { ![string equal -nocase $ext $expExt] }  {
    ok_err_msg "Cannot balance $ext HALD-s when system is in $expExt mode"
    return  0
  }
  
  if { ![file exists $srcHaldFilePath] }  {
    ok_err_msg "-E- Inexistent input file '$srcHaldFilePath'"
    return  0
  }
  if { ![ok_mkdir [file dirname $newHaldFilePath]] }  {
    return  0;  # error already printed
  }
  set newHaldTxtFile [format "%s.TXT"  [file rootname $newHaldFilePath]]

  set fullColorRange  [list                                                   \
    [list  \
     $CFG(_MinRgbVal) $CFG(MaxRgbVal) $CFG(MaxRgbVal)] \
    [list  \
     $CFG(MaxRgbVal) $CFG(_MinRgbVal) $CFG(_MinRgbVal)] \
                        ]
  rca::_compute_scaling_parameters_for_red_to_cyan_ratio  $fullColorRange  \
    r2cFractMaxMinor r2cFractMinMinor c2rFractMaxMinor c2rFractMinMinor    \
    minRatio  maxRatio
  
  set cntChanged 0;  set cntAll 0
  # set ddataStartedIfPpm [expr {($::_HALD_FORMAT_TXT_OR_PPM == 0)? 1 : 0}]
  # read-and-modify from source file line by line; save in the new file
  set tclExecResult [catch {
    set outF [open $newHaldTxtFile  w]
    set inpF [open $srcHaldFilePath r]
    while { [gets $inpF oldHaldline] >= 0 } {
      # TODO: skip PPM header if ever supported
      if { !$ddataStartedIfPpm || [string match $commentGlob $oldHaldline]} {
        puts $outF $oldHaldline;  # copy comments as-is
      } else {
        if { ![hald_parse_srgb_line $oldHaldline  x y  r g b] }  {
          return  0;  # error already printed
        }
        #set rgb [list $r $g $b]
        incr cntAll 1
        if { ($cntAll % 2097152) == 0 }  {; # 16777216/2097152==8 lines printed
          ok_trace_msg "... so far processed $cntAll color(s) in HALD list ..."
        }
        _classify_color_balanced  $r $g $b        \
          isMaxMinorBalanced isMinMinorBalanced   \
          isMaxMinorAtBoundary isMinMinorAtBoundary
        # Deciding to fix if min-minor unbalanced means 2 thresholds - too messy
        # set isFixNeeded [expr {$isMaxMinorBalanced && $isMinMinorBalanced &&  \
        #        (!$CFG(_ScaleBoudaryBalanced) || !$isMaxMinorAtBoundary)   &&  \
        #        (!$CFG(_ScaleBoudaryBalanced) || !$isMinMinorAtBoundary)      }]
        set isFixNeeded [expr {!$isMaxMinorBalanced                     ||  \
           ($CFG(_ScaleBoudaryBalanced) && $isMaxMinorAtBoundary)          }]
        if { !$isFixNeeded }   {
          puts $outF $oldHaldline
        } else {
          # TODO: check return val when error-check implemented
          _fix_color_channel_ratios  $r $g $b  newR newG newB       \
            $r2cFractMaxMinor $r2cFractMinMinor                     \
            $c2rFractMaxMinor $c2rFractMinMinor  $minRatio  $maxRatio
          set newHaldLine [hald_format_srgb_line  $x $y  $newR $newG $newB]
          puts $outF $newHaldLine
          ok_trace_msg "Replace {$r $g $b} \t by {$newR $newG $newB}"
          incr cntChanged 1
        }
      }
    }
    close $inpF
    close $outF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    return  0
  }

  ok_info_msg "Replaced $cntChanged mapped color(s) in HALD-file '$srcHaldFilePath' of $cntAll color(s); new text version saved in '$newHaldTxtFile'"
  ok_info_msg "Runtime of replacing $cntChanged of $cntAll color(s) in HALD-file is [expr {[clock seconds] - $timeStarted}] second(s)"

  if { [string equal -nocase [file extension $newHaldFilePath] ".TIF"] }  {
    if { "" == [hald_file_txt_to_tiff $newHaldTxtFile  \
                 [max_rgb_to_depth $CFG(MaxRgbVal)] $newHaldFilePath] }  {
      return  0;  # error already printed
    }
    ok_info_msg "New HALD-image-file of $cntAll color(s) saved in '$newHaldFilePath'"
    if { [ok_delete_file $newHaldTxtFile] }  {
      ok_info_msg "Deleted temporary HALD text file '$newHaldTxtFile'"
    };  # otherwise error already printed
    ok_info_msg "Total runtime of replacing $cntChanged of $cntAll color(s) in HALD-file AND recoding into image is [expr {[clock seconds] - $timeStarted}] second(s)"
  }

  return  1
} 


# Generates HALD text- or image file 'newHaldFilePath'
# with colors balanced for red-cyan anaglyph according to current 'CFG' contents.
# Returns 1 on success, 0 on failure.
## Example-01:  set rca::CFG() 0.01;  rca::select_config CURRENT;  rca::build_all_balanced_colors_hald_file  2  /y/hald_bal_02.txt
## Example-02:  ok_set_loud 0;  rca::select_config CFG/rma_ba02.ini;  rca::build_all_balanced_colors_hald_file  8  Y:/hald_ba02_08.txt
## Example-03:  ok_set_loud 0;  for {set lv 16} {$lv >= 2} {incr lv -1}  {::rca::build_all_balanced_colors_hald_file $lv "Y:/hald_sf__[format {%02d} $lv].PPM";  puts "=======================\n\n\n\n\n\n\n\n"}
proc ::rca::build_all_balanced_colors_hald_file {level newHaldFilePath}  {
  variable CFG
  #  set commentGlob "#*"
  if { ($level < 2) || ($level > 16) }  {
    ok_err_msg "Invalid HALD level $level. Allowed range is \[2...16\]."
    return  0
  }
  if { 0 != [llength [set errs [check_config_sanity "rca::CFG"]]] }  {
    foreach errMsg $errs {
      ok_err_msg "Configuration error:  $errMsg"
    }
    return  0
  }
  if { 0 == [set spaceCheckRes [check_free_output_space_sufficiency           \
           $level  [string range [file extension $newHaldFilePath] end-2 end] \
                                         [file dirname $newHaldFilePath]]] }  {
    return  0;  # not enough space - known; message already printed
  } elseif { $spaceCheckRes < 0 }  {
    ok_warn_msg "Cannot check free disk availability; continuing speculatively."
    # errors other than cannot-measure-space were checked before
  }
  
  set timeStarted [clock seconds]
  if { ![ok_mkdir [file dirname $newHaldFilePath]] }  {
    return  0;  # error already printed
  }
  img_proc::hald_txt_or_ppm fileTypeExt
  # NOT FOR THIS PLACE
  # if { ![string equal -nocase [file extension $newHaldFilePath]  \
  #                              ".$fileTypeExt"] }  {
  #   ok_err_msg "Textual HALD format mismatch - requested '[file extension $newHaldFilePath]' while the suite is in '.$fileTypeExt' mode"
  #   return  0
  # }
  set newHaldTxtFile [format "%s.$fileTypeExt"  [file rootname $newHaldFilePath]]
  set haldStr [format "HALD-%02d" $level]

  set fullColorRange  [list                                                   \
    [list  \
     $CFG(_MinRgbVal) $CFG(MaxRgbVal) $CFG(MaxRgbVal)] \
    [list  \
     $CFG(MaxRgbVal) $CFG(_MinRgbVal) $CFG(_MinRgbVal)] \
                        ]
  rca::_compute_scaling_parameters_for_red_to_cyan_ratio  $fullColorRange  \
    r2cFractMaxMinor r2cFractMinMinor c2rFractMaxMinor c2rFractMinMinor    \
    minRatio  maxRatio

  ### Size example for level==3:
  ###  The table holds a color cube with a side of level^2 colors or 9 colors.
  ###  The full color cube contains (level^2)^3 colors, (9*9*9 = 729 colors),
  ###    stored in an image with side of sqrt((level^2)^3) (=27x27) pix.
  set gradLen [expr {$level * $level}]
  set imgSide [expr {$level * $level * $level}]
  set imgSize [expr {$imgSide * $imgSide}]
  # speed: ~480sec for 256^6; want <= 8 prints with 20sec <= interval <= 60sec
  # 256^6 / 8{steps} = 2097152{colors/step};  256^6 / 480sec ~ 34953{colors/sec}
  # 20 * (256^6 / 480{sec}) ~ 699051{colors/10sec}
  set progressStep [expr {int(max( $imgSize/8.0, 20*$imgSize/480.0 ))}]
  ok_info_msg "Building LUT for $imgSize color(s); progress report occurs once per $progressStep color(s)"

  set cntChanged 0;  set lineIdx -1
  # build the file line by line
  set tclExecResult [catch {
    set outF [open $newHaldTxtFile  w]
    set headerLines [img_proc::_hald_format_header $level $CFG(MaxRgbVal)]
    foreach hl $headerLines  { puts $outF $hl }
    for {set iB 0}  {$iB < $gradLen}  {incr iB 1}  {
      for {set iG 0}  {$iG < $gradLen}  {incr iG 1}  {
        for {set iR 0}  {$iR < $gradLen}  {incr iR 1}  {
          incr lineIdx 1
          if { ![hald_rgb_indices_to_xy  $level  $iR $iG $iB  x y] ||  \
                 ![hald_rgb_indices_to_rgb $level $CFG(MaxRgbVal)  $iR $iG $iB  \
                                           r g b] }  {
            close $outF
            error "* Aborted generation of $haldStr at line-index $lineIdx, RGB indices {$iR $iG $iB}";  # excepton to be catched inside this proc
          }
          _classify_color_balanced  $r $g $b        \
            isMaxMinorBalanced isMinMinorBalanced   \
            isMaxMinorAtBoundary isMinMinorAtBoundary
          #Deciding to fix if min-minor unbalanced means 2 thresholds - too messy
          #set isFixNeeded [expr {$isMaxMinorBalanced && $isMinMinorBalanced && \
          #        (!$CFG(_ScaleBoudaryBalanced) || !$isMaxMinorAtBoundary)  && \
          #        (!$CFG(_ScaleBoudaryBalanced) || !$isMinMinorAtBoundary)    }]
          set isFixNeeded [expr {!$isMaxMinorBalanced                       ||  \
                  ($CFG(_ScaleBoudaryBalanced) && $isMaxMinorAtBoundary)       }]
          if { !$isFixNeeded }   {
            set oldHaldLine [hald_format_srgb_line  $x $y  $r $g $b]
            puts $outF $oldHaldLine
          } else {
            # TODO: check return val when error-check implemented
            _fix_color_channel_ratios  $r $g $b  newR newG newB       \
              $r2cFractMaxMinor $r2cFractMinMinor                     \
              $c2rFractMaxMinor $c2rFractMinMinor  $minRatio  $maxRatio
            set newHaldLine [hald_format_srgb_line  $x $y  $newR $newG $newB]
            puts $outF $newHaldLine
            ok_trace_msg "Replace {$r $g $b} \t by {$newR $newG $newB}"
            incr cntChanged 1
          }
          if { ($lineIdx > 1) && ($lineIdx % $progressStep) == 0 }  {
            ok_info_msg "... so far processed [expr $lineIdx +1] color(s) out of $imgSize in $haldStr ..."
          }
        };#_iR
      };#_iG
    };#_iB
    close $outF
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed generation of $haldStr: $execResult!"
    return  0
  }
                     
  set cntAll [expr $lineIdx + 1]
  set descr "$haldStr with $cntChanged of $cntAll color(s) replaced"
  set sz [expr {round([file size $newHaldTxtFile] / 1024.0)}]
  ok_info_msg "Generated $descr; new text version saved in '$newHaldTxtFile'; size: $sz kB"
  ok_info_msg "Runtime of generating $descr is [expr {[clock seconds] - $timeStarted}] second(s)"

  if { [string equal -nocase [file extension $newHaldFilePath] ".TIF"] }  {
    if { "" == [hald_file_txt_to_tiff $newHaldTxtFile  \
                 [max_rgb_to_depth $CFG(MaxRgbVal)] $newHaldFilePath] }  {
      return  0;  # error already printed
    }
    ok_info_msg "New $haldStr image-file of $cntAll color(s) saved in '$newHaldFilePath'"
    if { [ok_delete_file $newHaldTxtFile] }  {
      ok_info_msg "Deleted temporary $haldStr text file '$newHaldTxtFile'"
    };  # otherwise error already printed
    ok_info_msg "Total runtime of generating $descr AND recoding into image is [expr {[clock seconds] - $timeStarted}] second(s)"
  }

  return  1
}


proc ::rca::hald_file_txt_to_tiff {inpTxtPath depth8Or16 {outSpec ""}}  {
  if { ![file exists $inpTxtPath] }  {
    ok_err_msg "Inexistent input HALD text file '$inpTxtPath'"
    return  ""
  }
  if { ($depth8Or16 != 8) && ($depth8Or16 != 16) }  {
    ok_err_msg "Invalid depth $depth8Or16 for HALD image '$inpTxtPath'; should be 8 or 16"
    return  ""
  }
  if { $outSpec == "" }  {
    set outSpec [format "-compress LZW  %s.TIF"             \
                 [file join [file dirname $inpTxtPath]      \
                    [file rootname [file tail $inpTxtPath]]]]
  } else {
    set outSpec  "-compress LZW $outSpec";  # OK if "-compress LZW" appears twice
  }
  set descr "converting HALD text file '$inpTxtPath' into image '[outspec_to_outpath $outSpec]'"
  set cmd "$::IMCONVERT  $inpTxtPath  -depth $depth8Or16  $outSpec"
  if { 0 == [ok_run_silent_os_cmd $cmd $descr] }  {
    return  ""; # error already printed
  }
  ok_info_msg "Success $descr"

  return  [outspec_to_outpath $outSpec]
}


# Computes and returns color-change map of {rOld gOld bOld} :: {rNew gNew bNew}
# 'allColors' is a list of {?index? r g b} lists
## Example-01:  rca::map_all_unbalanced_colors {{0 0 0}}
## Example-02:  rca::map_all_unbalanced_colors {{0  255 255 0}}
## Example-03:  rca::map_all_unbalanced_colors {{255 0 0}}
## Example-04:  rca::map_all_unbalanced_colors {{0  255 0 0} {1  1 10 20}}
## Example-05:  rca::map_all_unbalanced_colors {{0  48 240 120}  {1  18 60 10}  {2 80 20 100}  {3  9 9 9}  {4  42 30 10}  {5  230 2 10}}
    ##        ----- OLD ----
    ## 0{ 48 240 120} 1{18 60 10} 2{80 20 100} 3{9 9 9} 4{42 30 10} 5{230  2 10 }
   #r2c  
    ##        ----- NEW ----
    ## 0{120 240 120} 1{34 60 10} 2{93 20 100} 3{9 8 8} 4{42 31 10} 5{230 23 115}
##--- HALD-gen goal requires spectrum extremes in input ---##
## Example-06:  rca::map_all_unbalanced_colors {{0 255 0} {10 100 10} {255 0 0}}
## Example-07:  rca::map_all_unbalanced_colors {{0 255 0} {10 100 10} {20 30 40} {100 10 0} {255 0 0}}
##--- Complete examples ---##
## Example-11:  set qqL [img_proc::list_image_unique_colors  "INP/Anaglyph_RR_1080/QUANT/RED/CS_sRGB_g1d00/DSC00035.TIF"  256];  llength $qqL;    set qqMap [rca::map_all_unbalanced_colors $qqL];  dict size $qqMap
### How to verify the map:  foreach irgb $qqL  {set rgb [lrange $irgb end-2 end]; if {![is_color_balanced_red_cyan {*}$rgb] && ![dict exists $qqMap $rgb]} {puts "*** Unmapped color {$irgb}"}}
##-----------------------------------------------------------------------------##
# !!!!! TODO: detect and report error conditions !!!!!!!!
proc ::rca::map_all_unbalanced_colors {allColors}  {
  variable CFG
  set timeStarted [clock seconds]
  set colorChangeMap [dict create];  # for {oldR oldG oldB} :: {newR newG newB}
  set colorsOrder [choose_colors_to_scale $allColors 0];  # only unbalanced
  set numBad [llength $colorsOrder]
  ok_info_msg "Requested mapping of $numBad unbalanced color(s) out of total [llength $allColors] color(s)"
  # note, both unbalanced and (optionally) balanced colors could be mapped
  _compute_scaling_parameters_for_red_to_cyan_ratio $colorsOrder           \
    r2cFractMaxMinor r2cFractMinMinor c2rFractMaxMinor c2rFractMinMinor    \
    r2cMinOld r2cMaxOld
#### TODO rewrite
  # set r2cMaxNew  $CFG(MaxBalancedMajorToMaxMinorRatio)
  # set r2cMinNew  [expr {1.0 / $CFG(MaxBalancedMajorToMaxMinorRatio)}]
  foreach rgb $colorsOrder  {
    lassign [lrange $rgb end-2 end]  rOld gOld bOld
    _fix_color_channel_ratios  $rOld $gOld $bOld  rNew gNew bNew  \
      $r2cFractMaxMinor $r2cFractMinMinor                     \
      $c2rFractMaxMinor $c2rFractMinMinor  $r2cMinOld $r2cMaxOld
    dict set colorChangeMap [list $rOld $gOld $bOld] [list $rNew $gNew $bNew]
  };#__END_OF__loop_over_colors
  ok_info_msg "Defined [dict size $colorChangeMap] mapping(s) to fix $numBad unbalanced color(s) out of total [llength $allColors] color(s).  r2cFractMaxMinor=$r2cFractMaxMinor, r2cFractMinMinor=$r2cFractMinMinor, c2rFractMaxMinor=$c2rFractMaxMinor, c2rFractMinMinor=$c2rFractMinMinor, r2cMinOld=$r2cMinOld, r2cMaxOld=$r2cMaxOld"
  ok_info_msg "Runtime of mapping [dict size $colorChangeMap] color(s) is [expr {[clock seconds] - $timeStarted}] second(s)"

  return  $colorChangeMap
}
# (Print ratios)  foreach c {{0  48 240 120}  {1  18 60 10}  {2 80 20 100}  {3  9 9 9}  {4  42 30 10}  {5  230 2 10}}  { lassign $c i r g b;  puts "{$c}\t =>  R/G=[safe_color_ratio $r $g],\tR/B=[safe_color_ratio $r $b] => ([band_min_for_rgb $r $g $b] ... [band_max_for_rgb $r $g $b])" }


# Returns list of unbalanced colors ({?index? r g b});
#    if 'sortByWb' == 1, the output is sorted by R/G, then R/B
## Example 1:  choose_colors_to_scale {{100 2 2} {50 3 3} {100 51 50} {50 26 27}}
## Example 2:  choose_colors_to_scale {{48 240 120} {18 60 10} {80 20 100} {9 9 9} {42 30 10} {230 2 10}}
proc ::rca::choose_colors_to_scale {irgbList {sortByWb 0}}  {
  variable CFG
  set badColors [list]
  foreach irgb $irgbList  {
    _classify_color_balanced {*}[lrange $irgb end-2 end]  \
                  isMaxMinorBalanced isMinMinorBalanced   \
                  isMaxMinorAtBoundary isMinMinorAtBoundary
    # Deciding to fix if min-minor unbalanced means 2 thresholds - too messy
    # set isFixNeeded [expr {$isMaxMinorBalanced && $isMinMinorBalanced &&  \
    #        (!$CFG(_ScaleBoudaryBalanced) || !$isMaxMinorAtBoundary)   &&  \
    #        (!$CFG(_ScaleBoudaryBalanced) || !$isMinMinorAtBoundary)      }]
    set isFixNeeded [expr {!$isMaxMinorBalanced                         ||  \
           ($CFG(_ScaleBoudaryBalanced) && $isMaxMinorAtBoundary)          }]
    if { $isFixNeeded }   {
      lappend badColors $irgb
    }
  }  
  return  [expr {($sortByWb)? [sort_colors_by_wb $badColors] : $badColors}]
}


# Assuming {rOld gOld bOld} IS(!) unbalanced, computes a fixed replacement.
#  (result could be wrong for balanced color)
#####################
## Look at major/minor, thus "half-range"
## fraction == (256 - 128) / (256 - 1) =~= 1/2
## majorNew == majorOld
## minorNew = majorNew / maxBalancedRatio  +  minorOld * fraction
#### 255   0  ->  255  255/2 +   0*0.5  =  255 128
#### 255  60  ->  255  255/2 +  60*0.5  =  255 158
#### 255 120  ->  255  255/2 + 120*0.5  =  255 188
####  88  22  ->   88   88/2 +  22*0.5  =   88  55
#####################
# TODO: ? error checks ?
## rca::_compute_scaling_parameters_for_red_to_cyan_ratio  {{0 255 0} {255 0 0}}  r2cFract1 r2cFract2 c2rFract1 c2rFract2  minV maxV;  rca::_fix_color_channel_ratios 3 3 50  r g b  $r2cFract1 $r2cFract2 $c2rFract1 $c2rFract2 $minV $maxV
proc ::rca::_fix_color_channel_ratios {rOld gOld bOld  rNewRef gNewRef bNewRef  \
           r2cFractMaxMinor r2cFractMinMinor c2rFractMaxMinor c2rFractMinMinor  \
                                                          r2cMinOld r2cMaxOld}  {
  variable CFG
  upvar $rNewRef r_fx2
  upvar $gNewRef g_fx2
  upvar $bNewRef b_fx2
  set r2cMaxNew  $CFG(MaxBalancedMajorToMaxMinorRatio); #TODO: separate r2c & c2r
  set c2rMaxNew  $CFG(MaxBalancedMajorToMaxMinorRatio); #TODO: separate r2c & c2r
  set r2cMinNew  $CFG(_MaxBalancedMajorToMinMinorRatio);#TODO: separate r2c & c2r
  set c2rMinNew  $CFG(_MaxBalancedMajorToMinMinorRatio);#TODO: separate r2c & c2r
  ## Preserve rgbMaxNew = rgbMaxOld = max(rOld,gOld,bOld) as rNew|bNew|gNMew
  ## Larger of the minor side gets scaled from rgbMaxOld
  ##     using 'r2cFract' or 'c2rFract' accordingly
  ## Smaller of the minor side gets scaled from its old value by the same amoubt as the larger
  ### The problematics in the approach of: >>
  #### -  largest of the smaller side gets scaled from rgbMaxOld
  #### -  Compute new value for the larger of Red|Cyan through rgbMaxNew, r2cNew
  #### -  Compute new value for the smaller of Green|Blue
  ####       through preserving ratio with the largest btw them - Cyan side
  ### >> Unstable for small G,B: {255 0 0}::{255 128 128}  {255 1 0}:{255 128 64}
  set loThresh $CFG(_LowPassThreshold);  # just a shortcut
  #### set loVal [expr {($loThresh == 0)? 0 : int(ceil($loThresh / 2.0))}]
  #### set loVal $loThresh;  # but could be different
  set loVal [expr {($loThresh == 0)? 0 : $loThresh - 1}]

  set minMinorOpt $CFG(MinMinorScaleOption);    # just a shortcut
  # note, only one of 'preSqueeze' or 'preInflate' could be != 1
  set preSqueeze  $CFG(PreSqueezeMajorToFract); # just a shortcut
  set preInflate  $CFG(PreInflateMinorToFract); # just a shortcut
  set maxRGB      $CFG(MaxRgbVal);              # just a shortcut

  _classify_color_balanced  $rOld $gOld $bOld  \
       isMaxMinorBalanced isMinMinorBalanced   \
       isMaxMinorAtBoundary isMinMinorAtBoundary
  if { $isMaxMinorAtBoundary || $isMinMinorAtBoundary }  {
    _balanced_color_scaling_weights $rOld $gOld $bOld  w1 w2dummy;# w1,w2 - float
  } else {
    set w1 1.0;  set w2dummy 1.0 }

  # Color-fix applicaion flow:
  ## *Old > presqueeze|preinflate > thresh > *_0> gb-bias > *_1 > balance >
  ##                                               *_fx1 > weight-to-orig > *_fx2
  set option 0;  # for debug tracking
  if { ($rOld >= $gOld) && ($gOld >= $bOld) }  {
    set r_0 [expr {min($maxRGB, round($gOld + $preSqueeze * ($rOld - $gOld)))}]
    # MaxMinor: need ratio for original-old            ==> pre-inflate, threshold
    # MinMinor: avoid 0*x==0 while max-minor increased ==> threshold, pre-inflate
    set g_t [expr {($gOld < $loThresh)?  min($r_0, $loVal)  :  $gOld}]; # for b_0
    set g_p [expr {min($maxRGB, round($rOld - $preInflate * ($rOld - $gOld)))}]
    set b_t [expr {($bOld < $loThresh)?  min($r_0, $loVal)  :  $bOld}]
    set g_0 [expr {($g_p  < $loThresh)?  min($r_0, $loVal)  :  $g_p}]
    set b_0 [expr {min($maxRGB, $b_t * [safe_color_ratio $g_p $g_t])}]
    #puts "@@ {$rOld $gOld $bOld} => g_p=$g_p, b_t=$b_t => g_0=$g_0, b_0=$b_0"

    if { $CFG(GreenToBlueBiasMultWhenMinor) != 1.0 }  { ;  # apply G<->B bias
      set r_1 $r_0
      set g_1 [expr {min(round(1.0*$g_0 * $CFG(GreenToBlueBiasMultWhenMinor)),  \
                             $maxRGB)}]
      set b_1 [expr {min(round(1.0*$b_0 / $CFG(GreenToBlueBiasMultWhenMinor)),  \
                             $maxRGB)}]
    } else {
      set r_1 $r_0;  set g_1 $g_0;  set b_1 $b_0;
    }
    set r_fx2 [set r_fx1 $r_1];  # max-major unchanged while balancing
    set g_fx1 [expr {round(1.0*$r_fx2 / $r2cMaxNew + $g_1 * $r2cFractMaxMinor)}]
    set g_fx2 [_weight_avg $g_0  $g_fx1  $w1]
    if { $minMinorOpt == $rca::_MIN_MINOR_TO_MAJOR }  {
      # using r2cFractMaxMinor instead of r2cFractMinMinor preserves G <> B ratio
      set b_fx1 [expr {round(1.0*$r_fx2 / $r2cMaxNew + $b_1 *$r2cFractMaxMinor)}]
      set b_fx2 [_weight_avg $b_0  $b_fx1  $w1]; # same weight for minor max,min
    } elseif { $minMinorOpt == $rca::_MIN_MINOR_AS_MAX_MINOR }  {
      ####### TODO: treat b_0==0
      set b_fx1 [expr {round(1.0* $b_1 * [safe_color_ratio $g_fx2 $g_1])}]
      set b_fx2 $b_fx1;  # min-minor already weighted by max-minor
    } else {
      error "Invalid min-minor scaling option $minMinorOpt"
    }
    set option 1
  } elseif { ($rOld >= $bOld) && ($bOld >= $gOld) }  {
    set r_0 [expr {min($maxRGB, round($bOld + $preSqueeze * ($rOld - $bOld)))}]
    # MaxMinor: need ratio for original-old            ==> pre-inflate, threshold
    # MinMinor: avoid 0*x==0 while max-minor increased ==> threshold, pre-inflate
    set b_t [expr {($bOld < $loThresh)?  min($r_0, $loVal)  :  $bOld}]; # for g_0
    set b_p [expr {min($maxRGB, round($rOld - $preInflate * ($rOld - $bOld)))}]
    set g_t [expr {($gOld < $loThresh)?  min($r_0, $loVal)  :  $gOld}]
    set b_0 [expr {($b_p  < $loThresh)?  min($r_0, $loVal)  :  $b_p}]
    set g_0 [expr {min($maxRGB, $g_t * [safe_color_ratio $b_p $b_t])}]
    #puts "@@ {$rOld $gOld $bOld} => b_p=$b_p, g_t=$g_t => b_0=$b_0, g_0=$g_0"
    
    if { $CFG(GreenToBlueBiasMultWhenMinor) != 1.0 }  { ;  # apply G<->B bias
      set r_1 $r_0
      set g_1 [expr {min(round(1.0*$g_0 * $CFG(GreenToBlueBiasMultWhenMinor)),  \
                             $maxRGB)}]
      set b_1 [expr {min(round(1.0*$b_0 / $CFG(GreenToBlueBiasMultWhenMinor)),  \
                             $maxRGB)}]
    } else {
      set r_1 $r_0;  set g_1 $g_0;  set b_1 $b_0;
    }
    set r_fx2 [set r_fx1 $r_1];  # max-major unchanged while balancing
    set b_fx1 [expr {round(1.0*$r_fx2 / $r2cMaxNew + $b_1 * $r2cFractMaxMinor)}]
    set b_fx2 [_weight_avg $b_0  $b_fx1  $w1]
    if { $minMinorOpt == $rca::_MIN_MINOR_TO_MAJOR }  {
      # using r2cFractMaxMinor instead of r2cFractMinMinor preserves G <> B ratio
      set g_fx1 [expr {round(1.0*$r_fx2 / $r2cMaxNew + $g_1 *$r2cFractMaxMinor)}]
      set g_fx2 [_weight_avg $g_0  $g_fx1  $w1]; # same weight for minor max,min
    } elseif { $minMinorOpt == $rca::_MIN_MINOR_AS_MAX_MINOR }  {
      ####### TODO: treat g_0==0
      set g_fx1 [expr {round(1.0* $g_1 * [safe_color_ratio $b_fx2 $b_1])}]
      set g_fx2 $g_fx1;  # min-minor already weighted by max-minor
    } else {
      error "Invalid min-minor scaling option $minMinorOpt"
    }
    set option 2
  } elseif { (($gOld >= $rOld) && ($rOld >= $bOld)) ||  \
             (($gOld >= $bOld) && ($bOld >= $rOld)) }   {
    set g_0 [expr {min($maxRGB, round($rOld + $preSqueeze * ($gOld - $rOld)))}]
    set b_0 $bOld 
    # TODO: decide on minor-side order of pre-inflate and threshold
    set r_p [expr {min($maxRGB, round($gOld - $preInflate * ($gOld - $rOld)))}]
    set r_0 [expr {($r_p < $loThresh)?  min($g_0, $loVal)  :  $r_p}]
    # no G <-> B bias on major side to avoid distorting/burning highlights
    set r_1 $r_0;  set g_1 $g_0;  set b_1 $b_0;
    set g_fx2 [set g_fx1 $g_1];  # max-major unchanged while balancing
    set b_fx1 [expr {round(1.0*$b_1 *[safe_color_ratio $g_fx2 $gOld])}];#MinMajor
    set r_fx1 [expr {round(1.0*$g_fx2 / $c2rMaxNew + $r_1 * $c2rFractMaxMinor)}]
    set r_fx2 [_weight_avg $r_0  $r_fx1  $w1]
    set b_fx2 $b_fx1
    set option 3
  } elseif { (($bOld >= $rOld) && ($rOld >= $gOld)) ||  \
             (($bOld >= $gOld) && ($gOld >= $rOld)) }   {
    set g_0 $gOld 
    set b_0 [expr {min($maxRGB, round($rOld + $preSqueeze * ($bOld - $rOld)))}]
    # TODO: decide on minor-side order of pre-inflate and threshold
    set r_p [expr {min($maxRGB, round($bOld - $preInflate * ($bOld - $rOld)))}]
    set r_0 [expr {($r_p < $loThresh)?  min($b_0, $loVal)  :  $rOld}]
    # no G <-> B bias on major side to avoid distorting/burning highlights
    set r_1 $r_0;  set g_1 $g_0;  set b_1 $b_0;
    set b_fx2 [set b_fx1 $b_1];  # max-major unchanged while balancing
    set g_fx1 [expr {round(1.0*$g_1 *[safe_color_ratio $b_fx2 $bOld])}];#MinMajor
    set r_fx1 [expr {round(1.0*$b_fx2 / $c2rMaxNew + $r_1 * $c2rFractMaxMinor)}]
    set g_fx2 $g_fx1
    set r_fx2 [_weight_avg $r_0  $r_fx1  $w1]
    set option 4
  } else {
    error "* Unexpected RGB color trio {$rOld $gOld $bOld}"
  }
  if { [ok_loud_mode] } {
    set rcOld [expr {(($option==1)||($option==2))                        ?  \
                       [safe_color_ratio $rOld [expr max($gOld, $bOld)]] :  \
                       [safe_color_ratio [expr max($gOld, $bOld)] $rOld]   }]

    set rcNew [expr {(($option==1)||($option==2))                        ?  \
                       [safe_color_ratio $r_fx2 [expr max($g_fx2, $b_fx2)]] :  \
                       [safe_color_ratio [expr max($g_fx2, $b_fx2)] $r_fx2]   }]
    ok_trace_msg "Map {$rOld $gOld $bOld}/{$r_0 $g_0 $b_0} => {$r_1 $g_1 $b_1} to {$r_fx1 $g_fx1 $b_fx1} => {$r_fx2 $g_fx2 $b_fx2}; case=$option; old-ratio=[format {%.5f} $rcOld]; w1=[format {%.2f} $w1], w2dummy=[format {%.2f} $w2dummy]; new-ratio=[format {%.5f} $rcNew]"
  }
  return  1
}


## Example-01:  rca::_compute_scaling_parameters_for_red_to_cyan_ratio {{2 3 4}}  r2c1 r2c2 c2r1 c2r2  minRat maxRat;  puts "$r2c1 $r2c2 $c2r1 $c2r2  $minRat $maxRat"
## Example-02:  rca::_compute_scaling_parameters_for_red_to_cyan_ratio {{1 10 8}  {2 3 4}  {10 4 1}}  r2c1 r2c2 c2r1 c2r2  minRat maxRat;  puts "$r2c1 $r2c2 $c2r1 $c2r2  $minRat $maxRat"
## Example-03:  rca::_compute_scaling_parameters_for_red_to_cyan_ratio {{0 255 255} {255 0 0}}  r2c1 r2c2 c2r1 c2r2  minRat maxRat;  puts "$r2c1 $r2c2 $c2r1 $c2r2  $minRat $maxRat"
proc ::rca::_compute_scaling_parameters_for_red_to_cyan_ratio {allColors       \
                                      r2cScaleMaxMinorRef r2cScaleMinMinorRef  \
                                      c2rScaleMaxMinorRef c2rScaleMinMinorRef  \
                                      r2cMinOldRef r2cMaxOldRef}               {
  variable CFG
  upvar $r2cScaleMaxMinorRef  r2cScaleMaxMinor
  upvar $r2cScaleMinMinorRef  r2cScaleMinMinor
  upvar $c2rScaleMaxMinorRef  c2rScaleMaxMinor
  upvar $c2rScaleMinMinorRef  c2rScaleMinMinor
  upvar $r2cMinOldRef r2cMinOld
  upvar $r2cMaxOldRef r2cMaxOld
  set r2cMaxNew  $CFG(MaxBalancedMajorToMaxMinorRatio)
  set r2cMinNew  [expr {1.0 / $CFG(MaxBalancedMajorToMaxMinorRatio)}]
  set r2cRangeNew [expr {$r2cMaxNew - $r2cMinNew}]
  set rMinOld 99999999;  set gMinOld 99999999;  set bMinOld 99999999
  set rMaxOld -1;        set gMaxOld -1;        set bMaxOld -1
  set r2cMinOld  99999999; # for min(r2c)
  set r2cMaxOld  -1;       # for max(r2c)
  foreach rgb $allColors  {
    lassign [lrange $rgb end-2 end]  r b g
    # OK_TMP: take ratio for min-max color values
    if { $r < $rMinOld }  { set rMinOld $r }
    if { $r > $rMaxOld }  { set rMaxOld $r }
    if { $g < $gMinOld }  { set gMinOld $g }
    if { $g > $gMaxOld }  { set gMaxOld $g }
    if { $b < $bMinOld }  { set bMinOld $b }
    if { $b > $bMaxOld }  { set bMaxOld $b }
    set r2c [safe_color_ratio $r [expr max($g, $b)]]
    if { $r2c < $r2cMinOld }  { set r2cMinOld $r2c }
    if { $r2c > $r2cMaxOld }  { set r2cMaxOld $r2c }
  }

  # MINOR == MAJOR * r2cScale
  _r2c_balanced_range_fraction r2cScaleMaxMinor r2cScaleMinMinor  \
                               c2rScaleMaxMinor c2rScaleMinMinor
  return
}


# MINOR_CHANNEL == MAJOR_CHANNEL * fraction
proc ::rca::_r2c_balanced_range_fraction {  \
                                  r2cFractMaxMinorRef r2cFractMinMinorRef   \
                                  c2rFractMaxMinorRef c2rFractMinMinorRef}  {
  variable CFG
  upvar $r2cFractMaxMinorRef r2cFractMaxMinor
  upvar $r2cFractMinMinorRef r2cFractMinMinor
  upvar $c2rFractMaxMinorRef c2rFractMaxMinor
  upvar $c2rFractMinMinorRef c2rFractMinMinor
  set fullColorRange [expr {$CFG(MaxRgbVal) - $CFG(_MinRgbVal)}]
  set balancedRedMajorRange1 [expr {  \
      $CFG(MaxRgbVal) * (1.0 - 1.0/$CFG(MaxBalancedMajorToMaxMinorRatio))}]
  set balancedRedMajorRange2 [expr {  \
      $CFG(MaxRgbVal) * (1.0 - 1.0/$CFG(_MaxBalancedMajorToMinMinorRatio))}]
  set balancedCyanMajorRange1 [expr {  \
      $CFG(MaxRgbVal) * (1.0 - 1.0/$CFG(MaxBalancedMajorToMaxMinorRatio))}]
  set balancedCyanMajorRange2 [expr {  \
      $CFG(MaxRgbVal) * (1.0 - 1.0/$CFG(_MaxBalancedMajorToMinMinorRatio))}]
  set r2cFractMaxMinor [expr {1.0 * $balancedRedMajorRange1  / $fullColorRange}]
  set r2cFractMinMinor [expr {1.0 * $balancedRedMajorRange2  / $fullColorRange}]
  set c2rFractMaxMinor [expr {1.0 * $balancedCyanMajorRange1 / $fullColorRange}]
  set c2rFractMinMinor [expr {1.0 * $balancedCyanMajorRange2 / $fullColorRange}]
  return
}


# OK_TODO: REWRITE WITH CORRECT THRESHOLDS AND ?MAYBE? proc safe_color_ratio !!!
# OK_TODO: for rewrite see proc rca::_classify_color_balanced
proc ::rca::is_color_balanced_red_cyan {r g b}  {
  _classify_color_balanced $r $g $b                         \
    isMaxMinorBalanced isMinMinorBalanced                   \
    isMaxMinorMarginallyBalanced isMinMinorMarginallyBalanced
  # Deciding to fix if min-minor unbalanced means 2 thresholds - too messy
  ###return  [expr {$isMaxMinorBalanced && $isMinMinorBalanced}]
  return  $isMaxMinorBalanced
  # set minVal $img_proc::RED_CYAN_ANAGLYPH_SENSITIVITY_THRESHOLD
  # if { ![rgbTrioValid $r $g $b  1] }  { error  "Invalid color" }; # cause a mess
  # set maxGB [expr max($g, $b)]
  # if { ($r > $maxGB) && ($r >= $minVal) }  {
  #   return  [expr {$r     <= 2 * $maxGB}]
  # }
  # if { ($r < $maxGB) && ($maxGB >= $minVal) }  {
  #   return  [expr {$maxGB <= 2 * $r}]
  # }
  # return  1
}


## This function needs externally defined scaling; so far unusab;e
# ## Balanced color computation formula:
# ## - new value for the color currently being balanced has:
# ## -- its major side unchaned
# ## -- max of its minor side set to half the major side
# ## -- ratio between max and min of the minor side unchanged
# ## -- (example: {110 40 20} => {110 55 28}
# proc ::rca::balance_red_cyan {r g b}  {
#   if { ![rgbTrioValid $r $g $b  1] }  { error  "Invalid color" }; # cause a mess
#   if { [is_color_balanced_red_cyan $r $g $b] }  {
#     return  [list $r $g $b]
#   }
#   set maxGB [expr max($g,$b)]
#   if { $r > $maxGB }  {
#     set scale [expr {0.5 * $r / max(1,$maxGB)}]
#     set sR $r
#     set sG [expr {min(255, int(round(max(1,$g) * $scale)))}]
#     set sB [expr {min(255, int(round(max(1,$b) * $scale)))}]
#   } elseif { $r < $maxGB }  {
#     set scale [expr {0.5 * $maxGB / max(1,$r)}]
#     set sR [expr {min(255, int(round(max($r) * $scale)))}]
#     set sG $g
#     set sB $b
#   }
#   return  [list $sR $sG $sB]
# }



#################################################################################
## Begin:  Config load/save/etc
#################################################################################
proc ::rca::store_config {cfgPath}  {
  variable CFG
  array unset cfgArr
  foreach key [array names CFG]  {
    set isPrimary [expr { "_" != [string index $key 0]}]
    # sections appear in ABC order; trick primary into being the 1st
    set section [expr {$isPrimary? $rca::_CFG_SECTION_ORIGINAL  \
			                           : $rca::_CFG_SECTION_DERIVED}]
    set optName [expr {$isPrimary? $key : [string range $key 1 end]}]
    set cfgArr([format {-%s__%s} $section $optName])  $CFG($key)
  }
  ok_trace_msg "Assembled configuration array:  {[array get cfgArr]}"
  return  [ok_utils::ini_arr_to_ini_file cfgArr $cfgPath 1]
}


proc ::rca::load_config {cfgPath}  {
  variable CFG
  variable _CFG_REQUIRED_OPTIONS
  array unset iniArr
  array unset CFG
  if { 0 == [ini_file_to_ini_arr $cfgPath iniArr 1] }  {
    return  0;  # error already printed
  }
  set secondarySectionName [string trim $rca::_CFG_SECTION_DERIVED {[]}]
  set errCnt 0;  set optCnt 0
  foreach iniKey [array names iniArr]  {
    set optionVal $iniArr($iniKey)
    ## % ini_key_parse {-[Original_User]__MaxRgbVal} sec op; puts "'$sec', '$op'"
    ##   '[Original_User]', 'MaxRgbVal'
    if { 0 == [ini_key_parse $iniKey sectionName optionName] }  {
      incr errCnt 1;  continue;  # error already printed
    }
    set sectionName [string trim $sectionName {[]}]
    incr optCnt 1
    ok_trace_msg "Read option #$optCnt '${sectionName}::${optionName}' = '$optionVal'"
    if { [string equal -nocase $sectionName $secondarySectionName] }  {
      ok_trace_msg "Option '${sectionName}::${optionName}' is secondary"
      set optionName "_$optionName"
    }
    set CFG($optionName) $optionVal
  }

  # check for missing and/or invalid options
  if { ![_check_config_options_presense errList cntMissing cntUnknown CFG] }  {
    incr errCnt [llength $errList]
    foreach errMsg $errList  { ok_err_msg $errMsg }
  }

  if { $errCnt == 0 }  {
    ok_info_msg "Success reading all [array size iniArr] option(s) from '$cfgPath'"
    return  1
  } else {
    ok_err_msg "Failed reading value(s) for [llength $_CFG_REQUIRED_OPTIONS] mandatory option(s) from '$cfgPath'; with [array size iniArr] option(s) provided, $cntMissing option(s) were missing, $cntUnknown unknown option(s) encountered"
    return  0
  }
}


proc ::rca::reset_config_to_default {}  {
  variable CFG
  variable _CFG_BACKUP
  array unset CFG
  array set CFG $_CFG_BACKUP
  ok_info_msg "Restored default config of [array size CFG] option(s)"
}


# Example-01:  set rca::CFG(GreenToBlueBiasMultWhenMinor) 0.90;  rca::select_config CURRENT
proc ::rca::select_config {iniFilePathOrCurrentOrDefault}  {
  variable CFG
  set errs1 [list];  set errs2 [list]
  if {       [string equal -nocase $iniFilePathOrCurrentOrDefault "CURRENT"] }  {
    ok_info_msg "Using the current running config of [array size CFG] option(s)"
    # check for missing and/or invalid options
    if { ![_check_config_options_presense errs1 cntMissing cntUnknown CFG] }  {
      foreach errMsg $errs1  { ok_err_msg $errMsg }
    }
  } elseif { [string equal -nocase $iniFilePathOrCurrentOrDefault "DEFAULT"] }  {
    reset_config_to_default
  } else {
    if { 0 == [load_config $iniFilePathOrCurrentOrDefault] }  {
      return  0;  # error already printed
    }
    # options; presense checked by 'load_config'
  }
  rca::_process_config_derived_options
  if { [ok_loud_mode] } {
    foreach key [array names CFG]  {ok_trace_msg "Option '$key'\t= $CFG($key)"}
  }
  set errs2 [check_config_sanity "rca::CFG"]
  #set allErrs [concat $errs1 $errs2]
  if { [llength $errs2] != 0 }  {
    foreach errMsg $errs2 { ok_err_msg "Configuration error:  $errMsg" }
    return  0
  }
  return  [expr {([llength $errs1] == 0) && ([llength $errs2] == 0)}]
}


# Returns a list of formatted summary-table lines
#    for files matching  'filePathGlob' under directory "rootDirOrEmpty".
# On error returns string "ERROR".
## Example-01:  set st [rca::collect_config_summary_from_file_glob {CFG} {rma_ba12*.ini}];  join $st "\n"
## Example-02:  set st [rca::collect_config_summary_from_file_glob {C:/Oleg/GitWork/AnaHald} {CFG/rma_ba12*.ini}];  join $st "\n"
proc ::rca::collect_config_summary_from_file_glob {rootDirOrEmpty filePathGlob  \
                                                     {fldSeparator "|"}}  {
  set filePathList [expr {($rootDirOrEmpty != "")?                              \
                [glob -nocomplain -directory $rootDirOrEmpty $filePathGlob] :   \
                [glob -nocomplain                            $filePathGlob]}]
  return  [collect_config_summary_from_file_list $filePathList $fldSeparator]
}


# Returns a list of formatted summary-table lines for files in 'filePathList'.
# On error returns string "ERROR".
## Example:  set st [rca::collect_config_summary_from_file_list  [glob -nocomplain {CFG/rma_ba12*.ini}]];  join $st "\n"
proc ::rca::collect_config_summary_from_file_list {filePathList  \
                                                     {fldSeparator "|"}}  {
  set summaryTableList 0
  if { ![summarize_ini_files_section $filePathList $rca::_CFG_SECTION_ORIGINAL  \
           5 $fldSeparator $rca::_CFG_REQUIRED_OPTIONS summaryTableList] }  {
    return  "ERROR";  # error already printed
  }
  return  $summaryTableList
}


# Check for missing and/or invalid options; puts error messages into 'errListVar'
# Returns 1 if no errors, 0 otherwise
proc ::rca::_check_config_options_presense {errListVar                    \
                                              cntMissingVar cntUnknownVar \
                                              {cfgArrName "rca::CFG"}}    {
  upvar $cntMissingVar cntMissing
  upvar $cntUnknownVar cntUnknown
  upvar $errListVar errList
  upvar $cfgArrName _cfg
  variable _CFG_REQUIRED_OPTIONS
  set errList [list]
  set primarySectionName [string trim $rca::_CFG_SECTION_ORIGINAL {[]}]
  # look for options missing from config-array
  foreach optName $_CFG_REQUIRED_OPTIONS  {
    if { ![info exists _cfg($optName)] }  {
      lappend errList "Missing setting of '$optName'"
    }
  }
  set cntMissing [llength $errList]
  # reversed check - look for unknown options appearing in config-array
  foreach optName [array names _cfg]  {
    if { [string index $optName 0] == "_" }  { continue };  # ignore secondary
    #puts "@@ Check array '$cfgArrName' for '$optName'"
    if { -1 == [lsearch -exact $_CFG_REQUIRED_OPTIONS $optName] }  {
      lappend errList "Unknown option '$optName'"
    }
  }
  set cntErr [llength $errList]
  set cntUnknown [expr {$cntErr - $cntMissing}]
  if { $cntErr > 0 }  {
    ok_err_msg "Check of configuration found $cntErr option-presense error(s) in [array size _cfg] provided option(s)"
  } else {
    ok_info_msg "Check of configuration found no option-presense error(s) in [array size _cfg] provided option(s)"
  }
  return  [expr {$cntErr == 0}]
}
#################################################################################
## End:    Config load/save/etc
#################################################################################



# Assigns 'isBalanced' to 1|0 if {r g b} is within|outside defined balanced range
# Assigns 'isMarginallyBalanced' to 1|0 if {r g b} is close-to|far-from unbalance limit
# TODO: What about balancing Min-Major ???
proc ::rca::_classify_color_balanced {r g b  \
                    isMaxMinorBalanced isMinMinorBalanced                      \
                    isMaxMinorMarginallyBalanced isMinMinorMarginallyBalanced} {
  upvar $isMaxMinorBalanced   balanced1
  upvar $isMinMinorBalanced   balanced2
  upvar $isMaxMinorMarginallyBalanced bndBalancedMaxMinor
  upvar $isMinMinorMarginallyBalanced bndBalancedMinMinor
  variable CFG
  set minVal $rca::RED_CYAN_ANAGLYPH_SENSITIVITY_THRESHOLD
  set r2cMax1 $CFG(MaxBalancedMajorToMaxMinorRatio); # OK_TODO: separate r2c, c2r
  set r2cMax2 $CFG(_MaxBalancedMajorToMinMinorRatio);# OK_TODO: separate r2c, c2r
  set c2rMax  $CFG(MaxBalancedMajorToMaxMinorRatio); # OK_TODO: separate r2c, c2r
  set r2cBnd  $CFG(MinBndBalancedMajorToMaxMinorRatio);  # OK_TODO: separate r2c, c2r
  set c2rBnd  $CFG(MinBndBalancedMajorToMaxMinorRatio);  # OK_TODO: separate r2c, c2r
  if { ![rgbTrioValid $r $g $b  1] }  { error  "Invalid color" }; # cause a mess
  set maxGB [expr max($g, $b)]
  set minGB [expr min($g, $b)]
  if {       $r > $maxGB }  {
    #set balanced1 [expr {($r < $minVal)     || ($r     <= $c2rMax * $maxGB)}]
    set balanced1 [expr {($r < $minVal)     || ($maxGB >= $r / $r2cMax1)}]
    set balanced2 [expr {($r < $minVal)     || ($minGB >= $r / $r2cMax2)}]
    # TODO: bndBalancedMaxMinor == f(balanced1, balanced2)
    #set bndBalancedMaxMinor [expr {$balanced1  &&  ($r >= $c2rBnd * $maxGB)}]
    set bndBalancedMaxMinor [expr {$balanced1  &&  ($maxGB <= $r / $r2cBnd)}]
    set bndBalancedMinMinor [expr {$balanced2  &&  ($minGB <= $r / $r2cBnd)}]
  } elseif { $r < $maxGB }  {
    #set balanced1 [expr {($maxGB < $minVal) || ($maxGB <= $r2cMax1 * $r    )}]
    set balanced1 [expr {($maxGB < $minVal) || ($r     >= $maxGB / $c2rMax)}]
    set balanced2 1
    set bndBalancedMaxMinor [expr {$balanced1       && ($maxGB >= $r2cBnd * $r    )}]
    set bndBalancedMinMinor 0;  # irrelevant when red is minor side
  } else {
    set balanced1    1
    set balanced2    1
    set bndBalancedMaxMinor 0
    set bndBalancedMinMinor 0
  }
  return
}


# Computes coefficienst to "weight" between original and fully-scaled color.
# The values are floating point, never integers.
# wForMax/wForMin relate to larger/smaller of green and blue channels.
# channelValNew = (1 - w) * channelValOld  +  w * channelValIfScaled
#  -  w == 1 when sidesRatio >= CFG(MaxBalancedMajorToMaxMinorRatio)
#  -  w == 0 when sidesRatio <= CFG(MinBndBalancedMajorToMaxMinorRatio)
proc ::rca::_balanced_color_scaling_weights {r g b  wForMax wForMin}  {
  upvar $wForMax w1
  upvar $wForMin w2
  variable CFG
  if { ($r >= $g) && ($g >= $b) }  {
    set sidesRatio1 [safe_color_ratio $r $g]
    set sidesRatio2 [safe_color_ratio $r $b]
  } elseif { ($r >= $b) && ($b >= $g) }  {
    set sidesRatio1 [safe_color_ratio $r $b]
    set sidesRatio2 [safe_color_ratio $r $g]
  } elseif { (($g >= $r) && ($r >= $b)) ||  \
             (($g >= $b) && ($b >= $r)) }   {
    set sidesRatio1 [safe_color_ratio $g $r]
    set sidesRatio2 -1;  # indicates the irrelevant min-major
  } elseif { (($b >= $r) && ($r >= $g)) ||  \
             (($b >= $g) && ($g >= $r)) }   {
    set sidesRatio1 [safe_color_ratio $b $r]
    set sidesRatio2 -1;  # indicates the irrelevant min-major
  } else {
    error "* Unexpected RGB color trio {$r $g $b}"
  }
  set maxBalanced1 $CFG(MaxBalancedMajorToMaxMinorRatio);     # just a shortcut
  set maxBalanced2 $CFG(_MaxBalancedMajorToMinMinorRatio);    # just a shortcut
  set minToScale1  $CFG(MinBndBalancedMajorToMaxMinorRatio);  # just a shortcut
  ##  1.0...minToScale1(1.3).....maxBalanced1(2.0).........................256.0
  ##         ?? minToScale1 = minToScale2
  ##            (maxBalanced2 - minToScale2) == (maxBalanced1 - minToScale1)
  ##  1.0.......................minToScale2(5.3)....maxBalanced2(6.0)......256.0
  set minToScale2 [expr {$maxBalanced2 - ($maxBalanced1 - $minToScale1)}]
  if { $CFG(SmoothBndBalancedOption) == $rca::_SMOOTH_BND_BALANCED_PARABOLIC }  {
    set w1 [_parabolic_weight $sidesRatio1 $minToScale1 $maxBalanced1]
    set w2 [_parabolic_weight $sidesRatio2 $minToScale2 $maxBalanced2]
  } elseif { $CFG(SmoothBndBalancedOption) ==$rca::_SMOOTH_BND_BALANCED_LINEAR} {
    set w1 [_linear_weight    $sidesRatio1 $minToScale1 $maxBalanced1]
    set w2 [_linear_weight    $sidesRatio2 $minToScale2 $maxBalanced2]
  } else {
    error "* Unexpected option $CFG(SmoothBndBalancedOption) for smoothening marginally balanced colors - should be $rca::_SMOOTH_BND_BALANCED_PARABOLIC or $rca::_SMOOTH_BND_BALANCED_LINEAR"
  }
  if { [ok_loud_mode] } {
    puts "@@ _balanced_color_scaling_weights($r $g $b):  sidesRatio1=[format {%.6f} $sidesRatio1] of ($minToScale1 ... $maxBalanced1) ==> [format {%.6f} $w1];  sidesRatio2=[format {%.6f} $sidesRatio2] of ($minToScale2 ... $maxBalanced2) ==> [format {%.6f} $w2]"
  }
  return
}


# W = (sidesRatio - minToScale)/(maxBalanced - minToScale)
## Example:  foreach x {2 1.9 1.8 1.7 1.6 1.5 1.4 1.31 1.3}  {puts "$x => [::rca::_linear_weight $x  1.3  2]"}
proc ::rca::_linear_weight {sidesRatio minToScale maxBalanced}  {
  if {       $sidesRatio > $maxBalanced }  { set w 1.0
  } elseif { $sidesRatio < $minToScale  }  { set w 0.0
  } else                                   { set w [expr {  \
             1.0*($sidesRatio - $minToScale) / ($maxBalanced - $minToScale)}]
  }
  return  $w
}


# W = a*(sidesRatio - maxBalanced)^2 + 1,
#    where a == -1/(minToScale - maxBalanced)^2
## Example:  foreach x {2 1.9 1.8 1.7 1.6 1.5 1.4 1.31 1.3}  {puts "$x => [::rca::_parabolic_weight $x  1.3  2]"}
proc ::rca::_parabolic_weight {sidesRatio minToScale maxBalanced {a 0}}  {
  if { $a == 0 }  {
    set _d1 [expr {$minToScale - $maxBalanced}]
    set a [expr {-1.0 / ($_d1 * $_d1)}]
  }
  if {       $sidesRatio >= $maxBalanced }  { set w 1.0
  } elseif { $sidesRatio <= $minToScale  }  { set w 0.0
  } else {
    set _d2 [expr {$sidesRatio - $maxBalanced}]
    set w [expr {$a * $_d2*$_d2 + 1}]
  }
  return  $w
}


# Returns weighted average:  v = (1 - w) * v1  +  w * v2
# - as rounded integer restricted by max permitted channel value
proc ::rca::_weight_avg {v1 v2 w}  {
  variable CFG
  return [expr {min($CFG(MaxRgbVal),  \
                    int(round( (1 - $w) * $v1  +  $w * $v2 )) ) }]
}



## Example:  set rca::CFG(GreenToBlueBiasMultWhenMinor) 1.05;  set rca::CFG(PreInflateMinorToFract) 0.5;;  ::rca::select_config CURRENT;  rca::_DBG_fix_color_channel_ratios  255 0 0  r g b
proc ::rca::_DBG_fix_color_channel_ratios {rOld gOld bOld  \
                                             rNewRef gNewRef bNewRef}  {
  upvar $rNewRef rNew
  upvar $gNewRef gNew
  upvar $bNewRef bNew
  _compute_scaling_parameters_for_red_to_cyan_ratio  \
    [list [list 0 $rca::_MAX_RGB_VAL 0] [list $rca::_MAX_RGB_VAL 0 0]]     \
                   r2cFract1 r2cFract2  c2rFract1 c2rFract2  r2cMinOld r2cMaxOld
  ok_trace_msg "r2cFractMaxMinor=[format {%.2f} $r2cFract1] r2cFractMinMinor=[format {%.2f} $r2cFract2]  c2rFractMaxMinor=[format {%.2f} $c2rFract1]  c2rFractMinMinor=[format {%.2f} $c2rFract2]"
  return  [rca::_fix_color_channel_ratios $rOld $gOld $bOld  rNew gNew bNew  \
             $r2cFract1 $r2cFract2  $c2rFract1 $c2rFract2  $r2cMinOld $r2cMaxOld]
}


### How to verify the map:  foreach irgb $qqL  {set rgb [lrange $irgb end-2 end]; if {![is_color_balanced_red_cyan {*}$rgb] && ![dict exists $qqMap $rgb]} {puts "*** Unmapped color {$irgb}"}}
# Verifies the mapping of unbalanced colors
proc ::rca::_DBG_verify_unbalanced_colors_mapping {irgbListAll \
                                                     rgbMapUnbalanced} {
  set irgbListAllSorted [sort_colors_by_wb $irgbListAll]
  set irgbListBadSorted [choose_colors_to_scale $irgbListAllSorted]

  # all unbalanced colors must be mapped
  set numUnmappedUnbalanced 0
  foreach irgb $irgbListAllSorted  {
    set rgb [lrange $irgb end-2 end]
    if { ![is_color_balanced_red_cyan {*}$rgb] &&  \
        ![dict exists $rgbMapUnbalanced $rgb]    } {
      incr numUnmappedUnbalanced 1
      puts "*** Unmapped color #$numUnmappedUnbalanced {$irgb}"
    }
  }

  # balanced color should be mapped only if close to some unbalanced
  set numMappedBalanced 0
  set numMappedIsolatedBalanced 0
  foreach rgb [dict keys $rgbMapUnbalanced]  {
    incr numMappedBalanced 1
    lassign $rgb r g b
    if { [is_color_balanced_red_cyan $r $g $b] }  {
      set isNeighbourFound 0
      foreach irgbBad $irgbListBadSorted  {
        lassign [lrange $irgbBad end-2 end] rBad gBad bBad
        set badBandMin [band_min_for_rgb $rBad $gBad $bBad]
        set badBandMax [band_max_for_rgb $rBad $gBad $bBad]
        if { [color_is_within_band $r $g $b  $badBandMin $badBandMax] }  {
          puts "  ... mapped balanced color {$r $g $b} is close to unbalanced color {$irgbBad}  - OK"
          set isNeighbourFound 1
          break
        }
      }
      if { !$isNeighbourFound }  {
        incr numMappedIsolatedBalanced 1
        set colorDescr [_format_color_descr $rgb]
        puts "*** Balanced color $colorDescr is unexpectedly mapped to {[dict get $rgbMapUnbalanced $rgb]}"
        continue
      }
    }
  }
  set isOK [expr {($numUnmappedUnbalanced + $numMappedIsolatedBalanced) == 0}]
  puts "Verification results ([expr {$isOK? {good}:{bad}}]):  unmapped-unbalanced: $numUnmappedUnbalanced;  wrongly-mapped-balanced: $numMappedIsolatedBalanced"
  return  $isOK
}

# Note, proc ::rca::_DBG_try_hald_sizes lacks error checking, thus commented-out
# # Example:  ok_set_loud 0;  set sizeDict [rca::_DBG_try_hald_sizes 2 8];  puts "\n";  dict for {l s} $sizeDict {puts "$l :: $s"}
# proc ::rca::_DBG_try_hald_sizes {minLevel maxLevel}  {
#   set resDict [dict create]
#   set IMC [string trim $::_IMCONVERT {{}}]
#   for {set lv $minLevel}  {$lv <= $maxLevel}  {incr lv 1}  {
#     puts "\n\n================ Start trying HALD level $lv =============="
#     set outPathTxt "Y:/TRY_OUT/hald__${lv}.TXT"
#     set outPathTif "[file rootname $outPathTxt].TIF"
#     if { ![rca::build_all_balanced_colors_hald_file  $lv  $outPathTxt] }  {
#       return  $resDict
#     }
#     exec $IMC  $outPathTxt  -depth 8 -compress LZW  $outPathTif
#     file stat $outPathTxt  stArrTxt
#     file stat $outPathTif  stArrTif
#     dict set resDict $lv "TXT:$stArrTxt(size),  TIF:$stArrTif(size)"
#     file delete $outPathTxt
#     file delete $outPathTif
#   }
#   return  $resDict
# }



proc ::rca::_format_wb {val}           { return  [format {%.3f} $val] }

proc ::rca::_format_wb_pair {valPair}  { return  [format {%.3f, %.3f} [lindex $valPair 0] [lindex $valPair 1]] }

proc ::rca::_format_color_descr {irgb}  {
  set rgb [lrange $irgb end-2 end]
  set wbStr [_format_wb_pair [rgb_to_wb {*}$rgb]]
  return  [format  {{%s}//(%s)}  $irgb  $wbStr]
}

proc ::rca::_format_color_band {minWB maxWB colors}  {
  set colorDescrs [lmap irgb $colors {
    set rgb [lrange $irgb end-2 end]
    #format  {{%s}//(%s)}  $irgb  [rgb_to_wb {*}$rgb]
    _format_color_descr $irgb
  }]
  return  "color-band \[minWB={[_format_wb_pair $minWB]} ... {$colorDescrs} ... maxWB={[_format_wb_pair $maxWB]}\]"
}
