::catch {};#\
@echo off
::catch {};#\
:start
::catch {};#\
@set WISH=C:\Oleg\Tools\TCL\freewrap_wish.exe
::catch {};#\
@set TCLSH=C:\Oleg\Tools\TCL\freewrap_tclsh.exe
::catch {};#\
@echo off
::catch {};#\
set script=%0
::catch {};#\
if exist %script%.bat set script=%script%.bat
::catch {};#\
@echo script=='%script%'
::catch {};#\
%TCLSH% %script% %1 %2 %3 %4 %5 %6 %7 %8 %9
::catch {};#\
@goto eof
#--------- TCL code begin ------------------
  puts "Hello, DOS, time now is"
  puts [clock format [clock seconds]]
  puts "  Note that EVERY DOS-BATCH line here is preceded by\n  pseudo-label with TCL-style line-continuation (\\ - backslash);\n  this protects it from TCL interpreter"
  #(doesn't work) puts -nonewline "Please press ENTER __>"
  puts "Please press ENTER __>"
  gets stdin line ;# just to test 
  puts [string toupper $line]
  puts [list argc: $argc argv: $argv]
#------------------------------------------end Tcl\
:eof
 
