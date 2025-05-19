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

# cmdline_anahald.tcl - command line wrapper with min local code dependencies

# TODO: decide whether to "source" here

# A wrapper to call HALD generation.
# Parameters are:
#  - shell-script-file extension (".sh" or ".bat")
#  - standard Tcl (argc, argv) for shell-script arguments
#     not including executable path.
proc anahald_cmd__lut_make {shellScriptExt argC argV}  {
  _detect_shell_type $shellScriptExt ext shellName

  puts "============ Running Anaglyph HALD Generator under $shellName ============="
  puts ""
  if { $argC < 3 }  {
     puts "* Usage:  anahald_lut_make.$ext  <CONFIG-PATH>  <HALD-LEVEL>  <OUTPUT-DIRECTORY-PATH>\n  (minimal reasonable hald-level is 8, recommended for production - 16)"
     return  -1
  }
  lassign $argV  cfgPath  haldLevel  outDir
  puts "Config file: '$cfgPath',  HALD-level: $haldLevel,  output-directory: '$outDir'"
  set rc [rca::build_all_balanced_colors_hald_file_by_config $cfgPath  $haldLevel  $outDir]
  puts ""
  puts "======== Finished running Anaglyph HALD Generator under $shellName ========"
  puts "=== Please examine log messages above for output file path or errors ==="
  return  0
}


# A wrapper to call CFG-file table collection.
# Parameters are:
#  - shell-script-file extension (".sh" or ".bat")
#  - standard Tcl (argc, argv) for shell-script arguments
#     not including executable path.
proc anahald_cmd__cfg_table {shellScriptExt argC argV}  {
  _detect_shell_type $shellScriptExt ext shellName
  set usageStr "* Usage (1):  anahald_cfg_table.$ext  GLOB  <CONFIG-DIRECTORY-PATH>  <CONFIG-FILEPATH-PATTERN> ...\n* Usage (2):  anahald_cfg_table.$ext  LIST  <CONFIG-FILENAME-1>  <CONFIG-FILENAME-2>"

  puts "============ Collecting Anaglyph HALD Config summary under $shellName ============="
  puts ""
  if { $argC < 2 }  {
     puts "$usageStr";  return  -1
  }
  set tp [lindex $argV 0]
  switch -exact $tp  {
    GLOB  {
      if { $argC < 3 }  { puts "$usageStr";  return  -1 }
      lassign $argV  tp  cfgDirPath  cfgNameGlob
      puts "Config files' directory: '$cfgDirPath',  config files' name-pattern: '$cfgNameGlob'"
      set st [::rca::collect_config_summary_from_file_glob $cfgDirPath $cfgNameGlob]
    }
    LIST  {
      set cfgFileList [lrange $argV 1 end]
      puts "Config files' list (count: [llength $cfgFileList]): {$cfgFileList}"
      set st [rca::collect_config_summary_from_file_list  $cfgFileList]
    }
    default { puts "$usageStr";  set st "ERROR";  # print msg and simulate error
    }
  }
  puts ""
  if { $st == "ERROR" }  {
     puts "======== Failed collecting Anaglyph HALD Config summary under $shellName ========"
     return  -1
  } else {
    puts [join $st "\n"]
    puts "======== Finished collecting Anaglyph HALD Config summary under $shellName ========"
    return  0
  }
}
# A wrapper to call CFG-file table collection.
# Parameters are:
#  - shell-script-file extension (".sh" or ".bat")
#  - standard Tcl (argc, argv) for shell-script arguments
#     not including executable path.
## Example 1: anahald_cmd__r2c_histogram  ".sh"  3 {LIST INP/hald_04.png}
proc anahald_cmd__r2c_histogram {shellScriptExt argC argV}  {
  _detect_shell_type $shellScriptExt ext shellName
  set usageStr "* Usage (1):  anahald_r2c_histogram.$ext  GLOB  <IMAGE-DIRECTORY-PATH>  <IMAGE-FILENAME-PATTERN> ...\n* Usage (2):  anahald_r2c_histogram.$ext  LIST  <IMAGE-FILEPATH-1>  <IMAGE-FILEPATH-2>"

  puts "============ Reading image(s) R2C histogram(s) under $shellName ============="
  puts ""
  if { $argC < 2 }  {
     puts "$usageStr";  return  -1
  }
  set tp [lindex $argV 0]
  switch -exact $tp  {
    GLOB  {
      if { $argC < 3 }  { puts "$usageStr";  return  -1 }
      lassign $argV  tp  imgDirPath  imgNameGlob
      puts "Image files' directory: '$imgDirPath',  image files' name-pattern: '$imgNameGlob'"
      set hl [::rca::read_r2c_histogram_from_file_glob $imgDirPath $imgNameGlob 1]
    }
    LIST  {
      set imgFileList [lrange $argV 1 end]
      puts "Image files' list (count: [llength $imgFileList]): {$imgFileList}"
      set hl [rca::read_r2c_histogram_from_file_list  $imgFileList 1]
    }
    default { puts "$usageStr";  set hl "ERROR";  # print msg and simulate error
    }
  }
  puts ""
  if { $hl == "ERROR" }  {
     puts "======== Failed reading image(s) R2C histogram(s) under $shellName ========"
     return  -1
  } else {
    puts [join $hl "\n"]
    puts "======== Finished reading image(s) R2C histogram(s) under $shellName ========"
    return  0
  }
}


proc   _detect_shell_type {shellScriptExt ext shellName}  {
  upvar $ext       ext_
  upvar $shellName shellName_
  set ext_ [string tolower [string trimleft $shellScriptExt "."]]
  set shellName_ [switch $ext_  {
    "sh"    { expr {"SH/BASH"} }
    "bat"   { expr {"DOS-CMD"} }
    default { expr {"UNKNOWWN-SHELL"} }
  }]
}
