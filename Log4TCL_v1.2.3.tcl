#!/usr/bin/tclsh

#---------------------------------------------------------
# Log4TCL - A TCL Logger
# Written by Cyril Thomas George (thomas.cyril@gmail.com)
#
# v1.2.2 / 20-10-2011
#---------------------------------------------------------

package provide Log4TCL 1.2.3

package require tdom
#source /host/shared/StdUtils.tcl

namespace eval Log4TCL {
    # Global Variables
    variable debug
    variable info
    variable warn
    variable error
    variable fatal
    variable logCnt
    variable configRegister
    variable lastLoadedConfig
    variable objectConfig
    variable object
}

set Log4TCL::Version 1.2.3

proc Log4TCL::ChangeLog {} {
    set chLg [open $Log4TCL::libDir/ChangeLog r]
    puts [read $chLg]
    close $chLg
}

#------------------------------------------------------
# Register Log
# A pseudo-object-oriented approach for creating
# multiple logger instances
#------------------------------------------------------
proc Log4TCL::RegisterLog { mode } {
    variable logCnt
    variable lastLoadedConfig
    variable objectConfig
   
    incr logCnt
    set object Log4TCL$logCnt
    set objectConfig($object) $mode
    set destroyFuncBody ""

    set methods [list Debug Info Warn Error Fatal]
    namespace eval ::$object "
        namespace export [string tolower $methods] destroy
        namespace ensemble create
    "
    # Create object methods
    foreach method $methods {
        set functionName "::${object}::[string tolower ${method}]"
        set functionBody ""
        append functionBody " "
        append functionBody "set ::Log4TCL::object $object"
        append functionBody "\n "
        append functionBody {if { ![::Log4TCL::_SwitchConfigMode] } return }
        append functionBody "\n "
        append functionBody "::Log4TCL::_$method " {{*}$args}
        #puts "My generated proc ::$functionName\nproc ::$functionName { args } {\n$functionBody\n}"
        eval {
            proc $functionName { args }  "$functionBody"
        }
    }
    append destroyFuncBody " "
    append destroyFuncBody "::Log4TCL::CleanObjectRefs $object"
    append destroyFuncBody "\n "
    append destroyFuncBody "namespace delete ::${object}" ;#self destruct
    eval {
        proc ::${object}::destroy {} $destroyFuncBody
    }
    return Log4TCL$logCnt
}

#------------------------------------------------------
# Clean the object traces
#------------------------------------------------------
proc Log4TCL::CleanObjectRefs { object } {
    variable objectConfig
    catch { unset $objectConfig($object) }
}

proc Log4TCL::CheckVerbosity { level } {
    variable debug
    variable info
    variable warn
    variable error
    variable fatal
    
    switch $level {
        debug   { foreach { debug info warn error fatal } { 1 1 1 1 1 } break }
        info    { foreach { debug info warn error fatal } { 0 1 1 1 1 } break }
        warn    { foreach { debug info warn error fatal } { 0 0 1 1 1 } break }
        error   { foreach { debug info warn error fatal } { 0 0 0 1 1 } break }
        fatal   { foreach { debug info warn error fatal } { 0 0 0 0 1 } break }
        default {
            puts stderr "Unrecognized debugLevel $level - current config file $Log4TCL::configFile"
            foreach { debug info warn error fatal } { 0 0 0 0 0 } break 
        }
    }
}

proc Log4TCL::xGet { node xpath } {
    return [$node selectNodes string($xpath)]
}

proc Log4TCL::_SwitchConfigMode { } {
    variable configRegister
    variable lastLoadedConfig
    variable logExceptions
    variable objectConfig
    variable object

    if { ![info exists lastLoadedConfig] } { set lastLoadedConfig "" }
    
    if { ![info exists configRegister]
        || ![string match [dict get $configRegister details filename] $Log4TCL::configFile]
        || ( [expr {[file mtime $Log4TCL::configFile] > [dict get $configRegister details lastModified]}])
    } {
        set doc [dom parse [tDOM::xmlReadFile $Log4TCL::configFile]]
        #set node [$doc selectNodes //$mode]
        # TODO: need to replace this with getElementById
        set xpath "Log4TCL/mode"
        set nodes [$doc selectNodes $xpath]
        
        set defaultLevelOverride    [Log4TCL::xGet $doc //defaultLevelOverride]
        set logExceptions           [Log4TCL::xGet $doc //logExceptions]
                
        foreach node $nodes {       
            set mode [$node getAttribute id ""]
            
            if { [string match $defaultLevelOverride "on"] } {
                #set defaultNode    [$doc selectNodes {//default}]
                set defaultNode [$doc selectNodes {Log4TCL/mode[@id="default"]}]
                set debugLevel  [Log4TCL::xGet $defaultNode debugLevel]
            } else {
                set debugLevel  [Log4TCL::xGet $node debugLevel]
            }
            
            dict set configRegister mode $mode [list \
                debugLevel              $debugLevel \
                timeZone                [Log4TCL::xGet $node timeZone] \
                prefix                  [Log4TCL::xGet $node prefix] \
                trace                   [Log4TCL::xGet $node callTrace] \
                dateFormat              [Log4TCL::xGet $node dateFormat] \
                levelInfo               [Log4TCL::xGet $node levelInfo] \
                log                     [Log4TCL::xGet $node log] \
            ]
        }
        
        dict set configRegister details [list \
            reload_flag     1 \
            lastModified    [file mtime $Log4TCL::configFile] \
            filename        $Log4TCL::configFile \
        ]
        
        #puts "Loaded Config"
    }
    
    #puts "Current mode : $objectConfig($object)"
    if { ![dict exists $configRegister mode $objectConfig($object)] } {
        puts stderr "Unrecognized mode $objectConfig($object) - current config file $Log4TCL::configFile"
        return 0
    }
    
    if { ![string match $lastLoadedConfig $objectConfig($object)]
        || [dict get $configRegister details reload_flag]
    } {
        #puts "Loading verbosity for $objectConfig($object)"
        Log4TCL::CheckVerbosity [dict get $configRegister mode $objectConfig($object) debugLevel]
        dict set configRegister details reload_flag 0
    }
    set lastLoadedConfig $objectConfig($object)
    return 1
}

proc Log4TCL::FormattedMsgDumper { call_func args } {
    variable configRegister
    variable lastLoadedConfig
    variable logExceptions
    #variable object
    #variable objectConfig
    
    if { (![string match $logExceptions "none"] || $logExceptions != "" )
        && $lastLoadedConfig in $logExceptions
    } {
        return
    }
    if { [dict get $configRegister mode $lastLoadedConfig log] == "" } { set ch stdout }
    if { [dict get $configRegister mode $lastLoadedConfig log] != "stdout" 
        && [dict get $configRegister mode $lastLoadedConfig log] != "stderr" 
    } {
        set fLog 0
        set ch [open [dict get $configRegister mode $lastLoadedConfig log] a+]
        fileevent $ch w { set fLog 1 }
        vwait fLog
    } else {
        set ch [dict get $configRegister mode $lastLoadedConfig log]
    }
    
    set putsCmd "puts"
    if { [string match [lindex $args 0] "-nonewline"] } {
        append putsCmd " -nonewline"
        set msg [lindex $args 1]
    } else {
        set msg "$args"
    }
    append putsCmd " $ch"


    if { [string match [dict get $configRegister mode $lastLoadedConfig prefix] "filename"] } {
        set filename [uplevel [info level] { file tail [info script] }]
        lappend putsMsg \[$filename\]
    }
    if { [dict get $configRegister mode $lastLoadedConfig prefix] != "" 
        && ![string match [dict get $configRegister mode $lastLoadedConfig prefix] "tree"]
        && ![string match [dict get $configRegister mode $lastLoadedConfig prefix] "filename"]
    } {
        lappend putsMsg \[[dict get $configRegister mode $lastLoadedConfig prefix]\]
    }
    if { [string match [dict get $configRegister mode $lastLoadedConfig levelInfo] on] } {
        switch $call_func {
            INFO    -
            WARN    { set spaceAdjuster " " }
            default { set spaceAdjuster "" }
        }
        lappend putsMsg [format "%- 8s" "\[$call_func\]"]
    }
    if { [dict get $configRegister mode $lastLoadedConfig dateFormat] != "" } {
        lappend putsMsg "\[[clock format [clock seconds] -format [dict get $configRegister mode $lastLoadedConfig dateFormat] -timezone [dict get $configRegister mode $lastLoadedConfig timeZone]]\]"
    }

    set putsLen [string length [join $putsMsg]]

    if { [string match [dict get $configRegister mode $lastLoadedConfig prefix] "tree"] } {
        #puts "Default level : [info level]"
        set currentLevel [expr [info level] - 3]
        set procName ""
        set msgPrefix ""
        if { $currentLevel > 0 } {
            if { [string match [dict get $configRegister mode $lastLoadedConfig trace] "on"] } {
                set cnt 1
                while  {  $cnt <= $currentLevel } {
                    lappend procName "\n"
                    lappend procName "[string repeat " " [expr $putsLen + $cnt]]|_\([lindex [info level $cnt]]\)"
                    incr cnt
                }               
                # set msgPrefix |_
            } else {
                set procName "\([lindex [info level $currentLevel] 0]\)"
                set msgPrefix [string repeat "|_" $currentLevel]
            }
            lappend procName "->"
        }
        lappend msgPrefix $procName $msg
        set msg [join $msgPrefix]
    }
    
    lappend putsMsg ": [join $msg]"
    lappend putsCmd [join $putsMsg]
    #puts "Formated Message => $putsCmd"
    eval $putsCmd
    flush $ch
    if { [dict get $configRegister mode $lastLoadedConfig log] != "stdout" 
        && [dict get $configRegister mode $lastLoadedConfig log] != "stderr" 
    } {
        close $ch
    }
}

proc Log4TCL::_Debug { args } {
    variable debug
    if { $debug } {
        Log4TCL::FormattedMsgDumper DEBUG {*}$args
    }
}

proc Log4TCL::Debug { args } {
    variable object
    set object Log4TCL
    if { ![Log4TCL::_SwitchConfigMode] } return
    Log4TCL::_Debug {*}$args 
}

proc Log4TCL::_Info { args } {
    variable info
    if { $info } {
        Log4TCL::FormattedMsgDumper INFO {*}$args
    }
}

proc Log4TCL::Info { args } { 
    variable object
    set object Log4TCL
    if { ![Log4TCL::_SwitchConfigMode] } return
    Log4TCL::_Info {*}$args 
}

proc Log4TCL::_Warn { args } {
    variable warn
    if { $warn } {
        Log4TCL::FormattedMsgDumper WARN {*}$args
    }
}

proc Log4TCL::Warn { args } { 
    variable object
    set object Log4TCL
    if { ![Log4TCL::_SwitchConfigMode] } return
    Log4TCL::_Warn {*}$args 
}

proc Log4TCL::_Error { args } {
    variable error
    if { $error } {
        Log4TCL::FormattedMsgDumper ERROR {*}$args
    }
}

proc Log4TCL::Error { args } { 
    variable object
    set object Log4TCL
    if { ![Log4TCL::_SwitchConfigMode] } return
    Log4TCL::_Error {*}$args 
}

proc Log4TCL::_Fatal { args } {
    variable fatal
    if { $fatal } {
        Log4TCL::FormattedMsgDumper FATAL {*}$args
    }
}

proc Log4TCL::Fatal { args } { 
    variable object
    set object Log4TCL
    if { ![Log4TCL::_SwitchConfigMode] } return
    Log4TCL::_Fatal {*}$args 
}

proc Log4TCL::ChangeConfig { mode_name {config_xml_file ""} } {
    #puts "Switching to mode $mode_name"
    variable objectConfig
    set objectConfig(Log4TCL) $mode_name
    if {$config_xml_file != "" } {
        set Log4TCL::configFile $config_xml_file
    }
}

#-------------------------------------------------------------------
# Main Part Begins Here
#-------------------------------------------------------------------

set Log4TCL::libDir [file dirname [info script]]
set Log4TCL::configFile ""

if { [file exists $Log4TCL::libDir/conf.xml] } {
    set Log4TCL::configFile $Log4TCL::libDir/conf.xml
    set Log4TCL::objectConfig(Log4TCL) default
}
#-------------------------------------------------------------------
# Main Part Ends Here
#-------------------------------------------------------------------
