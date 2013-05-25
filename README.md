## Log4TCL

Log4TCL is a Logger for logging you application messages / logs
based on the verbosity level specified in the config.xml file
[ Note the logger configurations are loaded by default from the config.xml 
  file along with the package tcl. 
  The latest version also supports to provide new config file paths ]

Check the config.xml file for details on each configuration supported
by Log4TCL


## Usage
Include new library paths if required as below
```tcl
lappend auto_path /host/lib
package require Log4TCL
```

### Displays the loaded Log4TCL Version
```tcl
puts $Log4TCL::Version
```

### Displays the changelog
```tcl
puts $Log4TCL::ChangeLog
```

### The logger
```tcl
Log4TCL::Info "Calculator => 5 + 5 = [expr 5 + 5]"
Log4TCL::Fatal "Calculator => 5 + 5 = [expr 5 + 5]"
```

# Changing config mode
Switching to other config modes in the default config file
The Log4TCL config can have mutiple configuration modes / modes each
having different timezone or dateformat or prefix or debuglevel .. etc
The default mode would be "default" in the config.xml
You can override it with your own custom mode as below

```tcl
Log4TCL::SwitchConfigMode test
Log4TCL::Fatal "Calculator => 5 + 5 = [expr 5 + 5]"
```

# Changing config file
Provide the new config xml file and optionally the mode to load, else 
the default mode will be loaded
```tcl
Log4TCL::LoadConfigXML c:\\Tcl\\lib\\Log4TCL\\newconf.xml test
Log4TCL::Fatal "Calculator => 5 + 5 = [expr 5 + 5]"
```

# Object oriented style usage
This gives a better flexibility to create different logger instances
with different config modes

```tcl
set r1 [Log4TCL::RegisterLog rpc1]
set r2 [Log4TCL::RegisterLog rpc2]
$r1 debug "Obj Calculator => 5 + 5 = [expr 5 + 5]"
$r2 fatal "Obj Calculator => 5 + 5 = [expr 5 + 5]"
```

## Destroy an object
```tcl
$r destroy
$r fatal "Calculator => 5 + 5 = [expr 5 + 5]" ;#should throw error
```

# Other Features
One of the useful features of Log4TCL is that you can see the depth of
you program stack if you have set the prefix as "tree" in your config file
This feature is illustrated below

```tcl
#!/opt/oss/bin/tclsh

# lappend auto_path "<your_lib_path>"
package require Log4TCL

set log [Log4TCL::RegisterLog "sample"]  ;# takes the sample configuration

proc e { } {
    $::log info "inside e"
}

proc d { } {
    $::log info "inside d"
    e
    $::log info "inside d"
}

proc c { } {
    $::log info "inside c"
    d
    $::log info "inside c"
}

proc b { } {
    $::log info "inside b"
    c
    $::log info "inside b"
}

proc a { } {
    $::log info "inside a"
    b
    $::log info "inside a"
}

a
```
the config xml should contain your sample config like
```xml
<Log4TCL>
    <reloadConfigInterval>10</reloadConfigInterval>
    <defaultLevelOverride>off</defaultLevelOverride>
    <logExceptions></logExceptions>
    
    <mode id="sample">
        <debugLevel>info</debugLevel>  
        <timeZone>GMT</timeZone>
        <log>stdout</log>
        <prefix>tree</prefix>
        <!-- calltrace can be turned on to print the entire stack for each log -->
        <callTrace>off</callTrace>
        <dateFormat>%d-%m-%y %H:%M:%S</dateFormat>
        <levelInfo>on</levelInfo>
    </mode>
    
</Log4TCL>
```
```
[INFO]   [25-05-13 09:38:09] : |_ (a) -> inside a
[INFO]   [25-05-13 09:38:09] : |_|_ (b) -> inside b
[INFO]   [25-05-13 09:38:09] : |_|_|_ (c) -> inside c
[INFO]   [25-05-13 09:38:09] : |_|_|_|_ (d) -> inside d
[INFO]   [25-05-13 09:38:09] : |_|_|_|_|_ (e) -> inside e
[INFO]   [25-05-13 09:38:09] : |_|_|_|_ (d) -> inside d
[INFO]   [25-05-13 09:38:09] : |_|_|_ (c) -> inside c
[INFO]   [25-05-13 09:38:09] : |_|_ (b) -> inside b
[INFO]   [25-05-13 09:38:09] : |_ (a) -> inside a
```
Changes in the config xml gets reflected immediately

### Switching modes in the new config file (Remember you switched to a new config)
```tcl
Log4TCL::SwitchConfigMode default
Log4TCL::Fatal "Calculator => 5 + 5 = [expr 5 + 5]"
```
