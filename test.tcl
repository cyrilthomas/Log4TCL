#!/opt/oss/bin/tclsh

package require Log4TCL

set logger [Log4TCL::RegisterLog "rpc"] ;# creates a new loggeer instance



proc test_fatal { x y z } {
  $::logger fatal "a fatal message"
}

proc test_error { } {
  test_fatal hello world 100
  $::logger error "an error message"
}

proc test_warn { } {
  test_error
  $::logger warn "a warning message"
}

proc test_info { s } {
  test_warn
  $::logger info "an info message" 
}

proc test_debug { } {
  test_info samba
  $::logger debug "a debug message"
}

test_debug
$::logger info "am i still here"
$::logger destroy   ;# deletes logger
Log4TCL::Info "Calculator => 5 + 5 = [expr 5 + 5]"  ;# old-style usage - uses the default configurations