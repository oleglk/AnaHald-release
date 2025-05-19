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

# special_char_subst.tcl - map of special characters;
##                         separated to preserve balance in code editors

namespace eval ::img_proc:: {

  namespace export \
  protect_char


  variable _SPECIAL_CHAR_SUBST_LIST  [list]
    lappend _SPECIAL_CHAR_SUBST_LIST {"} {\"}
    lappend _SPECIAL_CHAR_SUBST_LIST {[} {\[}
    lappend _SPECIAL_CHAR_SUBST_LIST {]} {\]}
    lappend _SPECIAL_CHAR_SUBST_LIST "\\" {\\\\}
    lappend _SPECIAL_CHAR_SUBST_LIST {<} {\\<}
    lappend _SPECIAL_CHAR_SUBST_LIST {>} {\\>}
    lappend _SPECIAL_CHAR_SUBST_LIST {|} {\\|}
}




# Prepends: double-quote with 1 backslash, 'less' with 2 backslashes, etc.
proc ::img_proc::protect_char {oneChar}  {
  if { [string length $oneChar] != 1 }  {
    error "* protect_char expects one-character string"
  }
  return  [string map -nocase  $img_proc::_SPECIAL_CHAR_SUBST_LIST  $oneChar]
}
