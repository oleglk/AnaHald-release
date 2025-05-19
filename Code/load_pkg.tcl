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

# load_pkg.tcl - sources all files in PKG_DIR
if { ![info exists PKG_DIR] } {
    puts "**** Using current dir '[pwd]' as PKG_DIR"
    set PKG_DIR [pwd]
}
if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  puts "\{-------- Start processing TCL sources in $PKG_DIR --------"
}
#foreach f [glob $PKG_DIR/*.tcl] {
#	puts "Encountered file '$f'"
#}
foreach f [glob $PKG_DIR/*.tcl] {
  if { [string match {*.oklib.tcl} $f]           || \
       [string match {*#*} $f]                   || \
       [string equal {pkgIndex.tcl} [file tail $f]] } { continue } 
  if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
    puts "---- Sourcing $f \t----"
  }
  source $f
}
if { ![info exists env(OK_NO_TCL_CODE_LOAD_DEBUG)] || \
       ![string equal -nocase $env(OK_NO_TCL_CODE_LOAD_DEBUG) "YES"] }  {
  puts "\}-------- Done  processing TCL sources in $PKG_DIR --------"
}
