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

# setup_utils.tcl
# Copyright:  Oleg Kosyakovsky

##############################################################################
namespace eval ::setup {
    namespace export \
	define_src_path \
	check_dirs_in_list
}
##############################################################################


# Tells TCL interpreter to look for converter code under 'tclSrcRoot'
# and for standard TCL extensons - under 'tclStdExtRoot'
proc ::setup::define_src_path {tclSrcRoot tclStdExtRoot} {
    global auto_path
    # guarantee that TCL interpreter finds the code
    if { -1 == [lsearch -exact $auto_path $tclSrcRoot] } {
	lappend auto_path $tclSrcRoot
    }
    # guarantee that TCL interpreter finds the required standard libs
    if { -1 == [lsearch -exact $auto_path $tclStdExtRoot] } {
	lappend auto_path $tclStdExtRoot
    }
}


# Checks directories in 'dirList' for existence. Exits if anyone absent.
proc ::setup::check_dirs_in_list {dirList} {
    foreach dir $dirList {
	if { [expr {$dir == ""} || ![file exists $dir] || \
		  ![file isdirectory $dir]] } {
	    puts "Invalid or inexistent directory name '$dir'"
	    return  -code error
	}
    }
}
