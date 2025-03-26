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

# setup_anahald.tcl

# Debug loading (Windows):    catch {namespace delete rca img_proc ok_utils;  rename arrange_anahald ""};    cd C:/ANY/GitWork/AnaHald;  source Code/setup_anahald.tcl;    arrange_anahald;    ok_set_loud 1
# Debug loading (Linux):      catch {namespace delete rca img_proc ok_utils;  rename arrange_anahald ""};    cd ~/ANY/GitWork/AnaHald;  source Code/setup_anahald.tcl;    arrange_anahald;    ok_set_loud 1


set SCRIPT_DIR [file dirname [info script]]

##############################################################################
# OK_TCLSRC_ROOT <- root directory for TCL source code
set OK_TCLSRC_ROOT    $SCRIPT_DIR
# OK_TCLSTDEXT_ROOT <- root directory for TCL standard extension libraries
set OK_TCLSTDEXT_ROOT $SCRIPT_DIR/../Libs_TCL
#LZC: # OK_CONV_WORK_DIR <- root directory for converter internal use
#LZC: set OK_CONV_WORK_DIR  "e:/LazyConv/TCL/Work"
##############################################################################

proc arrange_anahald {}  {
  # arrange environment and load common utility code
#################################################################################
  #(some stuff missing)  uplevel source [file join $::SCRIPT_DIR "setup_anahald.tcl"]
  # some important settings are in "rca_colorset.tcl"; load it first
  uplevel source [file join $::SCRIPT_DIR "rca_colorset.tcl"]
  unset -nocomplain ::_IMCONVERT ::IMCONVERT

  # Imagemagick "convert"/"magick" priorities:
  #   (1) local batch, (2) according to system path
  set isWindows [expr {"WINDOWS" == [ok_utils::ok_detect_os_type]}]
  if { !$isWindows }  {
    # assume an unixoid - can use straight executable names
    set imcBatchPath [file normalize [file join  \
                                      $::SCRIPT_DIR  ".."  "bin"  "convert.sh"]]
    if { [file exists $imcBatchPath] }  {
      set ::_IMCONVERT $imcBatchPath
    } else {
      #set ::_IMCONVERT "convert";     # author's installed version is rather old
      set ::_IMCONVERT "magick";      # hope the installed version is new enough
    }
  } else {
    # assume MS Windows - executable names include extensions
    set imcBatchPath [file normalize [file join  \
                                      $::SCRIPT_DIR  ".."  "bin"  "convert.bat"]]
    if { [file exists $imcBatchPath] }  {
      set ::_IMCONVERT $imcBatchPath
    } else {
      set ::_IMCONVERT "magick.exe";  # hope the installed version is new enough
      ok_info_msg "Missing '$imcBatchPath' - will try default location for Imagemagick convert/magick utility"
    }
  }
  set ::IMCONVERT   "$::_IMCONVERT" ;  # sync historical flavors
  ok_info_msg "Imagemagick convert/magick utility will be called as '$::_IMCONVERT'"
  set ::ANAHALD_SETUP_PERFORMED 1
#################################################################################

  # 'import' # to reference proc-s without prefix
  uplevel namespace import -force ::ok_utils::* 
  uplevel namespace import -force ::img_proc::*


  # load application-specific code
#################################################################################
  # uplevel source [file join $::SCRIPT_DIR  "search_for_files.tcl"]
#################################################################################

############# BEGIN:  Finetune 'img_proc' constants if needed #################
  img_proc::set_min_color_val_for_rgb_ratio $rca::CFG(_ZeroSubstRgbValForRatio)
############# END:    Finetune 'img_proc' constants if needed #################

  ok_info_msg "Finished setup of AnaHald suite (context: '[file tail [info script]]')"
#################################################################################
}


### DO NOT CHANGE ANYTHING UNDER THIS LINE !!!
##############################################################################
set normTclSrcRoot    [file normalize $OK_TCLSRC_ROOT]
set normTclStdExtRoot [file normalize $OK_TCLSTDEXT_ROOT]
#LZC: set normConvWorkDir   [file normalize $OK_CONV_WORK_DIR]
##############################################################################

##############################################################################
source [file join $normTclSrcRoot setup_utils.tcl]
##############################################################################
#LZC: set dirList [list $normTclSrcRoot $normTclStdExtRoot $normConvWorkDir]
## set dirList [list $normTclSrcRoot $normTclStdExtRoot]
set dirList [list $normTclSrcRoot];  # AnaHald code doesn't use std lib-s; TODO:change
setup::check_dirs_in_list $dirList
##############################################################################
setup::define_src_path $normTclSrcRoot $normTclStdExtRoot
##############################################################################

foreach _nsp {::ok_utils ::img_proc}  {
  if { [namespace exists $_nsp] }  {   namespace delete $_nsp  }
}
# (note ::setup isn't deleted)
unset _nsp

foreach _p {ok_utils img_proc}  {
  package forget $_p
}
unset _p

# puts ">>>> Packages before 'package require'"
# package names

package require ok_utils
package require img_proc

# puts ">>>> Packages after 'package require'"
# package names

namespace import -force ::ok_utils::*
#LZC: namespace import -force ::filesorter::*
namespace import -force ::setup::*


