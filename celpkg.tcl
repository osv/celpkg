#
# Copyright (C) 2010, Sydorchuk Olexandr  <olexandr.syd@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

#-----------------------------------------------
# command args
#-----------------------------------------------
proc show-help {} {
    puts "Usage:"
    puts "$::argv0 COMMAND \[args\]

The most commonly used $::argv0 commands are:
   list         Show list of addons
   installed    List installed addons
   check-index  Validate index files
   conflict     Show package's conflicts
   install      Install package
   deinstall    Deinstall package
   distclean    Clean distribute files of package
   distlist     List distribute files of package
   dependency   List dependencies of package
   require      List package that required by specified package
   tree         Show dependencies tree
   export       Export configuration to archive
   import       Import configuration from archive
   help         Print help

For more information about command use:
$::argv0 help COMMAND"
}

proc show-list-or-installed-help {list} {
    puts "Usage of $list command:
$::argv0 $list
$::argv0 $list \[options \] <pattern>

Options:
 -line              Show file and line number of index file
                    where addon was defined
 -field <field>     Set field that matches pattern:
    name            Match name \(default\)
    category        Match category
    author          Match author
    maintainer      Match maintainer
    description     Match description
    descr           Match description
    copy            Match copy
    backup          Match backup
    xpatch          Match xpatch
    patch           Match patch
    www             Match www
    license         Match license

Example:
    $::argv0 $list -field category educat"
}
set action none
switch [lindex $::argv 0] {
    list { # list matched addons
	set action list-addons
    }
    check-index { # just load index file for check error
	set action check-index
    }
    installed {
	set action installed-addons
    }
    conflict {
	set action conflict
    }
    install {
	set action install
    }
    deinstall {
	set action deinstall
    }
    distclean {
	set action distclean
    }
    distlist {
	set action distlist
    }
    dependency {
	set action dependency
    }
    require {
	set action require
    }
    tree {
	set action dependency-tree
    }
    export {
	set action export
    }
    import {
	set action import
    }
    help {
	if {$::argc >= 1} {
	    switch [lindex $::argv 1] {
		list {
		    show-list-or-installed-help list
		    exit
		}
		installed {
		    show-list-or-installed-help installed
		    exit
		}
		install {
		    puts "$::argv0 install \[options \] <pkgname>
Options:
    -recursive      Install dependencies (default = yes)
    -force          Force install even dependencies not installed (default = no)
"
		    exit
		}
		deinstall {
		    puts "$::argv0 deinstall \[options \] <package>
Options:

    -force          Force deinstall even this package is required by
                    other (default = no)
"
		    exit
		}
		export {
		    puts "$::argv0 export \[options \] <packagename>

Export configuration to archive. Also create addon that
require current installed addons.

Options:
    -c <comment>    More description about exported addon

Example:
    $::argv0 export -c \"my backup config\" backup
"
		    exit
		}
		import {
		    puts "$::argv0 export \[options \] <packagename>

Import options and addon from archive created by `export` command.

Options:
    -c <comment>    More description about exported addon

Example:
    $::argv0 export -c \"my backup config\" backup
"
		    exit
		}

	    }
	}
	show-help
	exit
    }    
    default {
	set action none
    }
}

if {$action == "none"} {
    show-help
    exit
}

# get value of param of command line 
proc get-option {optname default} {
    set maxargc [expr $::argc -1]
    # skip arg 0 
    for {set i 1} {$i < $maxargc} {incr i } {
	if {$optname == [lindex $::argv $i]} {
	    if {$i < $maxargc} {
		return [lindex $::argv [expr $i +1]]
	    } else {
		return $default
	    }
	}
    }
    return $default
}

variable loadCfg yes
variable GUI no
variable firstRun no
variable loadCfg yes

source celpkg-core.tcl

::misc::config:open $mainConfigFile
::core::check-vars
::core::load-index yes

switch $action {
    list-addons {
	set matchstr *
	if {$::argc >1} {
	    set matchstr *[ lindex $::argv [expr $::argc -1]]*
	}
	set fieldtype [get-option "-field" name]
	set is_linenum [get-option "-line" no]
	puts "===>  List addon(s) where \"$matchstr\" matches field \"$fieldtype\":"
	foreach pkgname [::core::get-matched-addon-list $matchstr $fieldtype] {
	    if {$is_linenum != "no"} {
		if [info exist pkgDB($pkgname:indexf)] {
		    puts -nonewline stderr "$pkgDB($pkgname:indexf):$pkgDB($pkgname:line): "
		}
	    }
	    puts $pkgname
	}
    }
    check-index {

	# check all addons in index files
	foreach a [array names pkgDB *:installed] {
	    set pkgname [lindex [split $a :] 0]

	    variable prev_addon_name {}

	    proc log-error {addon msg} {
		global prev_addon_name pkgDB

		if {$addon != $prev_addon_name} {
		    if [info exist pkgDB($addon:indexf)] {
			puts -nonewline stderr "$pkgDB($addon:indexf):$pkgDB($addon:line):"
		    }
		    puts stderr " Addon \"$addon\" have some problems:"
		}
		set prev_addon_name $addon
		puts stderr $msg
	    }

	    # check $unpack
	    if [info exist pkgDB($pkgname:unpack)] {
		set errtype "\[\$unpack\]"
		foreach unpack $pkgDB($pkgname:unpack) {
		    set f [getNamedVar $unpack -file]
		    set found no
		    # check for exist file of $unpack in $distfile
		    if [info exist pkgDB($pkgname:distfile)] {
			foreach distfile $pkgDB($pkgname:distfile) {
			    if {$f == [getNamedVar $distfile -name]} {
				set found yes
				break
			    }
			}
		    }
		    if {!$found} {
			log-error $pkgname "$pkgname: $errtype Have file for unpack \"$f\", but don't know how to download this (check distfiles)"
		    }
		    # check for unpack type
		    set t [getNamedVar $unpack -type]
		    if {![in "zip tar" $t]} {
			log-error $pkgname "$pkgname: $errtype Unknow file type \"$t\" for unpacking file \"$f\" (check \"-type\")"
		    }
		}
	    }

	    # check $patch
	    if [info exist pkgDB($pkgname:patch)] {
		set errtype "\[\$patch\]"
		foreach f $pkgDB($pkgname:patch) {
		    # check for exist patch file in $distfile
		    if [info exist pkgDB($pkgname:distfile)] {
			foreach distfile $pkgDB($pkgname:distfile) {
			    if {$f == [getNamedVar $distfile -name]} {
				set found yes
				break
			    }
			}
		    }
		    if {!$found} {
			log-error $pkgname "$pkgname: $errtype Don't know how to download patch \"$f\" (check distfiles)"
		    }
		    # check for unpack type
		    set t [getNamedVar $unpack -type]
		    if {![in "zip tar" $t]} {
			log-error $pkgname "$pkgname: $errtype Unknow file type \"$t\" for unpacking file \"$f\" (check \"-type\")"
		    }
		}
	    }

	    # check important fileds
	    foreach field {category version} {
		if {![info exist pkgDB($pkgname:$field)]} {
		    log-error $pkgname "$pkgname: \[Error\] No field \"\$$field\" specified"
		}
	    }

	    # check $copy
	    if {[info exist pkgDB($pkgname:copy)]} {
		set errtype "\[\$copy\]"
		foreach copy $pkgDB($pkgname:copy) {
		    if {[llength $copy] != 2} {
			log-error $pkgname "$pkgname: $errtype Variable \"\$copy\" require 2 parameters:"
			log-error $pkgname "$pkgname:  \$copy \{$copy\}"
		    }
		}
	    }
	}
    }
    installed-addons {
	set matchstr *
	if {$::argc >1} {
	    set matchstr *[ lindex $::argv [expr $::argc -1]]*
	}
	set fieldtype [get-option "-field" name]
	set is_linenum [get-option "-line" no]
	puts "===>  List installed addon(s) where \"$matchstr\" matches field \"$fieldtype\":"
	foreach pkgname [::core::get-matched-addon-list $matchstr $fieldtype] {
	    if $pkgDB($pkgname:installed) {
		if {$is_linenum != "no"} {
		    if [info exist pkgDB($pkgname:indexf)] {
			puts -nonewline stderr "$pkgDB($pkgname:indexf):$pkgDB($pkgname:line): "
		    }
		}
		puts $pkgname
	    }
	}
    }

    conflict {
	set matchstr *
	if {$::argc >1} {
	    set matchstr *[ lindex $::argv [expr $::argc -1]]*
	}
	foreach pkgname [::core::get-matched-addon-list $matchstr name] {
	    puts "===>  Conflicts for package \"$pkgname\":"
	    foreach conflpkg [::core::get-conflicted-addons $pkgname] {
		puts $conflpkg
	    }
	}
    }
    install {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    set force [get-option "-force" no]
	    if {$force != "no"} {set force yes}
	    set recursive [get-option "-recursive" yes]
	    if {$recursive !="yes"} {set recursive no}
	    ::core::proceed-install $pkgname  $recursive $force
	}
    }
    deinstall {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    set force [get-option "-force" no ]
	    if {$force != "no"} {set force yes}
	    ::core::proceed-uninstall $pkgname $force
	}
    }
    distclean {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    ::core::distclean $pkgname
	}
    }
    distlist {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    if [info exist pkgDB($pkgname:distfile)] {
		foreach dist $pkgDB($pkgname:distfile) {
		    set filename [getNamedVar $dist -name]
		    puts $filename
		}
	    }
	}
    }
    dependency {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    set deps {}
	    if [info exist pkgDB($pkgname:depend)] {
		set deps $pkgDB($pkgname:depend)
	    }
	    if [info exist pkgCache($pkgname:depend)] {
		set deps "$deps $pkgCache($pkgname:depend)"
	    }
	    set deps [::misc::lrmdups $deps]
	    foreach dep $deps {
		puts $dep
	    }
	}
    }
    require {
	if {$::argc >1} {
	    set pkgname [ lindex $::argv [expr $::argc -1]]
	    if {![info exist pkgDB($pkgname:installed)]} {
		puts "$::argv0: no such package \"$pkgname\""
		exit
	    }
	    set reqs {}
	    if [info exist pkgDB($pkgname:requiredby)] {
		set reqs $pkgDB($pkgname:requiredby)
	    }
	    if [info exist pkgCache($pkgname:requiredby)] {
		set reqs "$reqs $pkgCache($pkgname:requiredby)"
	    }
	    set reqs [::misc::lrmdups $reqs]
	    foreach req $reqs {
		puts $req
	    }
	}
    }
    dependency-tree {
	set matchstr *
	if {$::argc >1} {
	    set matchstr *[ lindex $::argv [expr $::argc -1]]*
	}
	set fieldtype [get-option "-field" name]
	set is_linenum [get-option "-line" no]
	puts "===>  List dependency tree (for addons where \"$matchstr\" matches field \"$fieldtype\":"
	foreach pkgname [::core::get-matched-addon-list $matchstr $fieldtype] {
	    if {$is_linenum != "no"} {
		if [info exist pkgDB($pkgname:indexf)] {
		    puts -nonewline stderr "$pkgDB($pkgname:indexf):$pkgDB($pkgname:line): "
		}
	    }
	    ::core::deptree-recursive $pkgname
	}
    }
    export {
	if {$::argc >1} {
	    set expname [ lindex $::argv [expr $::argc -1]]

	    puts "===>  Export current configuration into tar file: \"$expname\""
	    set comment [get-option "-c" {} ]

	    ::core::export-configuration $expname $comment
	}
    }
    import {
	if {$::argc >1} {
	    set expname [ lindex $::argv [expr $::argc -1]]
	    puts "===>  Import configuration from tar file: \"$expname\""
	    
	    set all [get-option "-all" no ]
	    if {$all != "no"} {set all yes}
	    
	    ::core::import-configuration $expname $all
	}
    }
}


