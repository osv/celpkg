# core functions
#
# Copyright (C) 2010, Sydorchuk Olexandr  <olexandr.syd@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

package require msgcat
package require md5

namespace import msgcat::*

if {[info exists ::env(LC_MESSAGES)]} {
    ::msgcat::mclocale $::env(LC_MESSAGES)
}

# set true if use tk before loading this file
variable GUI

variable prog_name [mc "Celestia addon manager"]
variable target_program "celestia"
# option name for selection data dir
variable target_program_opt_dir "--dir"
# extention for detecting windows file association
variable target_program_ext ".cel"

# default path setup
# root dir
variable cpath "~/sync/celpkg/"

# pkg path, where info about addon will be
# here "db/" dir contains all installed addons 
variable pkgpath [file join $cpath pkg]

# distribute files place
variable distpath [file join ${cpath} pkg distfiles]

# db patch location: $pkgpath/db
variable dbpath

# temp dir, where files be extracted
variable workdir [file join $pkgpath db]

# db cache file
variable dbcache

# configfile
variable mainConfigFile "~/.celpkg.cfg"

# url for self update 
variable celpkgUpdateUrl "http://github.com/osv/celpkg/zipball/master"

# Array for all avail. addons
variable pkgDB 

# Expression db for "if" command
variable expDB

# Info about authors, maintainer
variable userDB
# Cache of installed addons
variable pkgCache 
# array of tasks to proceed
variable todo

# directory name where index archive saved (subdir of "$pkgDB/")
variable dwnlIndexDir "index"

set indexUrl "http://github.com/osv/celpkg-index/zipball/master"
set celVersion 1.6
set config(firstRun) yes
set config(profile) "Default"

variable celVerMajor
variable celVerMinor

# List of  installed addon  by one proceed  session. Need  to exclude
# addons from install that was installed as dependencies
variable sesInstalled
namespace eval ::core {}
namespace eval ::misc {}

#------------------------------
# append log with list of text and tag
# example: LOG {"hello" normal "worl" bold}
#-----------------------------

proc LOG { arglist } {
    global GUI
    if $GUI {
	::uilog::log $arglist
    } else {
	for {set i 0} {$i < [llength $arglist]} {incr i 2} {
	    puts -nonewline [lindex $arglist $i]
	}
    }
}

proc LOG\r { arglist {logr no} } {
    global GUI
    if $GUI {
	::uilog::log\r $arglist $logr
    } else {
	if {$logr} {
	    puts -nonewline \r
	}
	for {set i 0} {$i < [llength $arglist]} {incr i +2} {
	    puts -nonewline [lindex $arglist $i]
	}
	if {$logr} {
	    flush stdout
	} else {
	    puts {}
	}
    }
}


#-----------------------------------------------
# misc proc
#-----------------------------------------------

# return 1 if element in list
proc in {list element} {expr [lsearch -exact $list $element] >= 0}

#---------------
# http://wiki.tcl.tk/3958
# atExit - exit hook
namespace eval AtExit {
    variable atExitScripts [list]

    proc atExit script {
        variable atExitScripts
        lappend atExitScripts \
                [uplevel 1 [list namespace code $script]]
    }

    namespace export atExit
 }

 rename exit AtExit::ExitOrig
 proc exit {{code 0}} {
     variable AtExit::atExitScripts
     set n [llength $atExitScripts]
     while {$n} {
        catch [lindex $atExitScripts [incr n -1]]
     }
     rename exit {}
     rename AtExit::ExitOrig exit
     namespace delete AtExit
     exit $code
 }

namespace import AtExit::atExit

#---------------
# If the <prog>ram successfully starts, its STDOUT and STDERR is dispatched
# line by line to the <readHandler> (via bgExecGenericHandler) as last arg.
# <pCount> holds the number of processes called this way. If a <timeout> is
# specified (as msecs), the process pipeline will be automatically closed after
# that duration. If specified, and a timeout occurs, <toExit> is called with
# the PIDs of the processes right before closing the process pipeline.
# Returns the handle of the process-pipeline.
#
# http://wiki.tcl.tk/12704
proc bgExec {prog readHandler pCount {timeout 0} {toExit ""}} {
    global tcl_platform
    upvar #0 $pCount myCount
    set myCount [expr {[info exists myCount]?[incr myCount]:1}]
    set p [expr {[lindex [lsort -dict [list 8.4.7 [info patchlevel]]] 0] == "8.4.7"?"| $prog 2>@1":"| $prog 2>@stdout"}]
    set pH [open $p r]
    fconfigure $pH -blocking 0; # -buffering line (does it really matter?!)
    set tID [expr {$timeout?[after $timeout [list bgExecTimeout $pH $pCount $toExit]]:{}}]
    fileevent $pH readable [list bgExecGenericHandler $pH $pCount $readHandler $tID]
    # kill (SIGQUIT) process when exit
    if {$tcl_platform(platform) == "windows"} {
	atExit [list exec kill -9 [pid $pH]]; # for windows need -9 signal
    } else {
	atExit [list exec kill [pid $pH]];	
    }
    return $pH
}

proc bgExecGenericHandler {chan pCount readHandler tID} {
    global errorCode
    upvar #0 $pCount myCount
    if {[eof $chan]} {
	after cancel $tID;   # empty tID is ignored
	catch {close $chan}; # automatically deregisters the fileevent handler
	# (see Practical Programming in Tcl an Tk, page 229)
	incr myCount -1
    } elseif {[gets $chan line] != -1} {
	# we are not blocked (manpage gets, Practical... page.233)
	lappend readHandler $line
	if {[catch {uplevel $readHandler}]} {
            # user-readHandler ended with error -> terminate the processing
            after cancel $tID
            catch {close $chan}
            incr myCount -1
	}
    }
}

proc bgExecTimeout {chan pCount toExit} {
    upvar #0 $pCount myCount
    if {[string length $toExit]} {
	catch {uplevel [list $toExit [pid $chan]]}
    }
    catch {close $chan}
    incr myCount -1
}

#---------------
proc ::misc::sleep {time} {
    after $time set end 1
    vwait end
}

proc ::misc::lrmdups list {
    set res {}
    foreach element $list {
	if {[lsearch -exact $res $element]<0} {lappend res $element}
    }
    set res
}

# compare version
# version 1.2 not equal to 1.2.0!
# return "g", "l", "eq"
proc ::misc::cmpversion { v1 v2 } {
    set lv1 [split $v1 .]
    set lv2 [split $v2 .]
    for {set i 0} {$i < [llength $lv1]} {incr i} {
	if {[lindex $lv1 $i] < [lindex $lv2 $i]} {
	    return l
	}
	if {[lindex $lv1 $i] > [lindex $lv2 $i]} {
	    return g
	}
    }
    # equal
    if {[llength $lv1] > [llength $lv2]} {
	return g
    } elseif {[llength $lv1] < [llength $lv2]} {
	return l
    }
    return eq
}
#---------------
# open cfg file
# see http://wiki.tcl.tk/15470
#---------------
proc ::misc::config:open {{fname ~/.celpkg.cfg}} {
    global config profiles
    global cpath distpath pkgpath workdir indexUrl celVersion
    global GUI

    if {[file exists $fname]} {
	set fp [open $fname r]
    } else {
	return 0
    }

    # read line by line
    # respond appropriate to what is found
    # see http://wiki.tcl.tk/2438
    while {![eof $fp]} {
	set data [gets $fp]
	switch [lindex $data 0] {
	    \# {
		# these are comments
	    }
	    #
	    # place other switch values and commands here..
	    #
	    geometry {
		if $GUI {
		    # restore last position on screen
		    wm geometry [winfo toplevel .] [lindex $data 1]
		}
	    }

	    profiles {
		set profile [lindex $data 2]
		set value [lindex $data 3]
		switch [lindex $data 1] {
		    root { set profiles($profile:cpath) $value}
		    pkg { set profiles($profile:pkgpath) $value}
		    dist { set profiles($profile:distpath) $value}
		    work { set profiles($profile:workdir) $value}
		    url { set profiles($profile:indexUrl) $value}
		    version {set profiles($profile:celVersion) $value}
		}
	    }
	    default {
		# restore some other values that might be useful
		set config([lindex $data 0]) [lindex $data 1]
	    }
	}
    }

    # setup global
    catch { set cpath $profiles($config(profile):cpath) }
    catch { set pkgpath $profiles($config(profile):pkgpath) }
    catch { set distpath $profiles($config(profile):distpath) }
    catch { set workdir $profiles($config(profile):workdir) }
    catch { set indexUrl $profiles($config(profile):indexUrl) }
    catch { set celVersion $profiles($config(profile):celVersion) }
    close $fp
    return 1
}

#---------------
# save cfg file
#---------------
proc ::misc::config:save {{fname ~/.celpkg.cfg}} {
    global config prog_name profiles
    global cpath distpath pkgpath workdir indexUrl celVersion
    global GUI
    set fp [open $fname w]
    # write specific items of information
    puts $fp "# config of $prog_name"
    if $GUI {
	puts $fp "geometry\t[winfo geometry [winfo toplevel .]]"
    }
    # write contents of config array,
    foreach i [array names config] {
	# somehow a enmpty item exists, can some other tcler tell me why?
	if {$i!=""} {
	    puts $fp "$i\t\{$config($i)\}"
	}
    }
    puts $fp {}
    puts $fp "# Profiles"

    # setup current $config(profile) profile for save first
    set profiles($config(profile):cpath) $cpath
    set profiles($config(profile):pkgpath) $pkgpath
    set profiles($config(profile):distpath) $distpath
    set profiles($config(profile):workdir) $workdir
    set profiles($config(profile):indexUrl) $indexUrl
    set profiles($config(profile):celVersion) $celVersion

    puts $fp "# Root path"
    foreach prf [array names profiles *:cpath] {
	set lst [split $prf :]
	puts $fp "profiles root {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    puts $fp "# Addon path"
    foreach prf [array names profiles *:pkgpath] {
	set lst [split $prf :]
	puts $fp "profiles pkg {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    puts $fp "# Distribute file place"
    foreach prf [array names profiles *:distpath] {
	set lst [split $prf :]
	puts $fp "profiles dist {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    puts $fp "# Work place"
    foreach prf [array names profiles *:workdir] {
	set lst [split $prf :]
	puts $fp "profiles work {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    puts $fp "# index Url"
    foreach prf [array names profiles *:indexUrl] {
	set lst [split $prf :]
	puts $fp "profiles url {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    puts $fp "# target program version"
    foreach prf [array names profiles *:celVersion] {
	set lst [split $prf :]
	puts $fp "profiles version {[lindex $lst 0]} \t{$profiles($prf)}"
    }
    close $fp
}

#---------------
# browse url
#---------------
proc ::misc::browseurl {url} {
    global env tcl_platform
    global GUI

    if $GUI {
	# Set the clipboard value to this url in-case the user needs to paste the 
	# url in (some windows systems).
	clipboard clear
	clipboard append $url
    }

    switch -- $tcl_platform(platform) {
	windows {
	    # DDE uses commas to separate command parts
	    set url [string map {, %2c} $url]

	    # See if we can use dde and an existing browser.
	    set handled 0
	    foreach app {Firefox {Mozilla Firebird} Mozilla Netscape IExplore} {
		if {[set srv [dde services $app WWW_OpenURL]] != {}} {
		    if {[catch {dde execute $app WWW_OpenURL $url} msg]} {
			puts "dde exec $app failed: \"$msg\""
		    } else {
			set handled 1
			break
		    }
		}
	    }

	    # The windows NT shell treats '&' as a special character. Using
	    # a '^' will escape it. See http://wiki.tcl.tk/557 for more info. 
	    if {! $handled} {
		if {[string compare $tcl_platform(os) "Windows NT"] == 0} { 
		    set url [string map {& ^&} $url]
		}
		if {[catch {eval exec [auto_execok start] [list $url] &} emsg]} {
		    MessageDlg .browse_err -aspect 50000 -icon info \
			-buttons ok -default 0 -cancel 0 -type user \
			-message \
			[format \
			     [::msgcat::mc "Error displaying %s in browser\n\n%s"] \
			     $url $emsg]
		}
	    }
	}

	macintosh {
	    if {![info exists env(BROWSER)]} {
		set env(BROWSER) "Browse the Internet"
		AppleScript execute \
		    "tell application \"env(BROWSER)\"\nopen url \"$url\"\nend tell\n"
	    }
	}

        default {
            if {![info exists env(BROWSER)]} {
                foreach b [list firefox galeon konqueror mozilla-firefox \
                               mozilla-firebird mozilla netscape \
                               iexplorer opera] {
                    if {[llength [set e [auto_execok $b]]] > 0} {
                        set env(BROWSER) [lindex $e 0]
                        break
                    }
                }
                if {![info exists env(BROWSER)]} {
		    if {[cequal $tcl_platform(os) Darwin]} {
			exec open $url &
			set_status ""
			return
		    }
                    MessageDlg .browse_err -aspect 50000 -icon info \
                        -message [::msgcat::mc "Please define environment variable BROWSER"] \
			-type user \
			-buttons ok -default 0 -cancel 0
                    return
                }
            }

            if {[catch { eval exec $env(BROWSER) -remote \"openURL($url, new-tab)\" } msg ]} {
		puts $msg
		if {[catch { exec $env(BROWSER) -remote $url }]} {
		    exec $env(BROWSER) $url &
		}
	    }
	}
    }
}

#---------------
# start target program with dir option (for celestia it be --dir)
# TODO: maybe good to have stdout catch for logs, maybe later?
#---------------
proc ::misc::start_target_program {} {
    global env tcl_platform
    global target_program target_program_opt_dir target_program_ext
    global cpath

    switch -- $tcl_platform(platform) {
	windows {
	    package require registry

	    set ext $target_program_ext
	    # Read the type name
	    set type [registry get HKEY_CLASSES_ROOT\\$ext {}]
	    # Work out where to look for the command
	    set path HKEY_CLASSES_ROOT\\$type\\Shell\\Open\\command
	    # Read the command!
	    set command [lindex [registry get $path {}] 0]

	    # first try $target_program
	    if {[catch {eval exec $target_program $target_program_opt_dir [list $cpath] &} emsg]} {
		# otherwise associated command with $target_program_ext
		if {[catch {eval exec [list $command] $target_program_opt_dir [list $cpath] &} emsg]} {
		    MessageDlg .browse_err -aspect 50000 -icon info \
			-buttons ok -default 0 -cancel 0 -type user \
			-message \
			[format \
			     [::msgcat::mc "Error launching %s\n\n%s"] \
			     $target_program $emsg]
		}
	    }
	}

        default {
	    if {[catch {eval exec $target_program $target_program_opt_dir [list $cpath] &} emsg]} {
		MessageDlg .browse_err -aspect 50000 -icon info \
		    -buttons ok -default 0 -cancel 0 -type user \
		    -message \
		    [format \
			 [::msgcat::mc "Error launching %s\n\n%s"] \
			 $target_program $emsg]
	    }
	}
    }
}

#------------------------------------------------------------------------
# read index file to array pkgDB; file format:
# format of index db file:
# - Similar to tcl list is used (i.e. {a b c} equal to "a b c")
# - Comment start from "#"
# - All variables start from "$"
#

#---------------
# help func
# Check line for first element as expression
# and append pkgDB and expDB (expression db where each key is $addonname:$var:"value for pkgDB")
# Example of expDB expDB("Foo addon:depend:Bar addon")
#---------------
proc appendDB {curAddon varname line } {
    global pkgDB expDB
    set startindex 0
    set curexpression ""
    if {[llength $line] > 1} {
	# check for expression 
	if {[lindex [lindex $line 0] 0] eq "if"} {
	    set startindex 1
	    # avoid exploit [some comman] when we will check expres..
	    if {![string match "*\]*" [lindex [lindex $line 0] 1]] } {
		#   {if {expr1 && expr2}}
		# get --^^^^^^^^^^^^^^^^
		set curexpression [lindex [lindex $line 0] 1]
		foreach var [lindex $line 1] {
		    lappend pkgDB($curAddon:$varname) $var
		    set expDB($curAddon:$varname:$var) $curexpression
		}
	    } 
	    return
	}
    }
    # append only pkgDB
    foreach var $line {
	lappend pkgDB($curAddon:$varname) $var
    }
}

#-----------------------------------------------
# read index file
# apend pkgDB and fill pkgTree
#-----------------------------------------------
proc read_index {fname quiet} {
    global pkgDB
    global GUI

    set news ""
    if $GUI {
	global ::uipkg::pkgTree ::uipkg::infoText
    }
    variable dbvars "www conflicts distfile unpack maintainer author 
                depend screenshot license patch backup copy renamework
                choice options installmsg deinstallmsg install xpatch
                provide require"
    if {[catch {set fh [open $fname "r"]} msg]} {
	LOG [list "Fail to load index file: " blinkyellow $fname\n bold $msg\n bold]
	return;
    }
    fconfigure $fh -encoding utf-8
    if {!$quiet} {
	LOG [list "Loading index file: " normal $fname\n bold]
    }

    set lineNum 0

    # check for brace match for text
    proc check-brace {text fname lineNum } {
	if {[ catch {set temp [lindex $text 0]} msg ] } {
	    puts stderr "$fname:$lineNum: Error when parsing index file, possible unmatched open brace: $msg"
	    exit
	}
    }

    proc add-param-to-db { addon param line fname lineNum} {
	global userDB 
	variable dbvars

	if {$param == "USER"} {
	    check-brace $line $fname $lineNum
	    foreach u $line {
		# add to user db
		foreach {nick descr} $u {
		    set userDB($nick) $descr
		}
	    }
	} elseif {$addon != "" &&
		  [in $dbvars $param]} {
	    check-brace $line $fname $lineNum
	    appendDB $addon $param $line
	}
    }

    set curAddon {}
    set curParam {}
    set pline {}
    while {[gets $fh line] >= 0} {
	# $end -finish defining addon
	if {[regexp {^\s*\$end((\s+.*$)|(\s*$))} $line -> param]} {
	    set curAddon {}
	    puts $param
	    set line $param
	}

	incr lineNum
	# remove comments
	if {[string index $line 0] == "#"} {
	    set line ""
	}
	set param ""
	# check for param (start from `$`)
	regexp {^\s*\$(\w+)((\s+.*$)|(\s*$))} $line -> param line
	# concat if no new param set
	if {$param == ""} {
	    if {![regexp {^\s*$} $line]} {
		if {$curParam == "description"} {
		    set line [string trimleft $line { }]
		    lappend pkgDB($curAddon:description) $line
		} elseif {$curParam == "news"} {
		    set line [string trimleft $line {\t }]
		    set line [string trimright $line {\t }]
		    lappend news $line
		} else {
		    set pline "$pline $line" 
		}
	    }
	} else {
	    # add current param to db
	    add-param-to-db $curAddon $curParam $pline $fname $lineNum

	    set pline $line
	    set curParam $param

	    # seems new param
	    if {$param == "addon"} {
		set curAddon [lindex $line 0]
		# clear old addon's info except
		if [info exist pkgDB($curAddon:category)] {
		    catch {LOG [list "Warning: " bold "$fname:$lineNum: " normal " Redefining addon (old was found in " normal \
				    "$pkgDB($curAddon:indexf):$pkgDB($curAddon:line):)\n" red]}
		}

		foreach var $dbvars {
		    catch {unset pkgDB($curAddon:$var)}
		}

		catch  {unset pkgDB($curAddon:description)}

		set pkgDB($curAddon:installed) "no"
		# for debug
		set pkgDB($curAddon:line) $lineNum
		set pkgDB($curAddon:indexf) $fname
	    } elseif {$param == "category"} {
		foreach cat $line {
		    if $GUI {
			set nodename [::uipkg::tree-add $::uipkg::pkgTree $cat $curAddon]
			if {$nodename != ""} { # maybe exist
			    lappend pkgDB($curAddon:treenodes) $nodename
			    lappend pkgDB($curAddon:category) $cat
			}
		    } else {
			lappend pkgDB($curAddon:category) $cat
		    }
		}
	    } elseif {$param == "version" } {
		check-brace $line $fname $lineNum
		set pkgDB($curAddon:version) [lindex $line 0]
	    } elseif {$param == "modified"} {
		check-brace $line $fname $lineNum
		set pkgDB($curAddon:modified) [lindex $line 0]
	    } elseif {$param == "created"} {
		check-brace $line $fname $lineNum
		set pkgDB($curAddon:created) [lindex $line 0]
	    } elseif {$param == "description"} {
		set line [string trimleft $line {\t }]
		set line [string trimright $line {\t }]
		lappend pkgDB($curAddon:description) $line
	    } elseif {$param == "news"} {
		set line [string trimleft $line {\t }]
		set line [string trimright $line {\t }]
		lappend news $line
	    } else {
		if {![in $dbvars $param] && $param != "USER"} {
		    LOG [list "Warning: " yellowbgm "$fname:$lineNum: " normal "Unknown param: $param\n" red]
		}
	    }
	}
    }
    add-param-to-db $curAddon $curParam $pline $fname $lineNum

    close $fh

    if {$news != ""} {
	foreach n $news {
	    LOG [list $n\n bold]
	}
    }
}

#-----------------------------------------------
# create pkg db of installed addons

# TODO: save into file pkgCache, currently no need this because no so
# much addons may be installed.
#-----------------------------------------------
proc build-pkg-cache {} {
    global dbpath dbcache pkgCache pkgDB GUI
    if $GUI {
	global ::uipkg::pkgTree
    }

    catch {unset pkgCache}
    
    foreach dir [lsort [glob -nocomplain -type {d l} [file join $dbpath *]]] {
	set fcontent [file join $dir "contents"]
	set finfo [file join $dir "pkginfo"]
	set frequiredby [file join $dir "required_by"]
	# file tail $dir
	set name [file tail $dir]
	if {[file exists $finfo]} {
	    if {[catch {set fh [open $finfo "r"]} msg]} {
		puts $msg;
		continue
	    }
	    fconfigure $fh -encoding utf-8

	    lappend pkgCache($name:name) $name
	    while {[gets $fh line] >= 0} {
		if {[lindex $line 0] eq "category:"} {
		    for {set i 1} {$i < [llength $line]} {incr i} {
			lappend pkgCache($name:category) [lindex $line $i]
			# append pkgDB and tree
			if $GUI {
			    set nodename [::uipkg::tree-add $::uipkg::pkgTree [lindex $line $i] $name]
			    # mark pkg as installed 
			    if {$nodename != ""} { # maybe exist
				lappend pkgDB($name:treenodes) $nodename
				lappend pkgDB($name:category) [lindex $line $i]
			    }
			} else {
			    lappend pkgDB($name:category) [lindex $line $i]
			}
			set pkgDB($name:installed) yes
		    }
		} elseif {[lindex $line 0] eq "depend:"} {
		    for {set i 1} {$i < [llength $line]} {incr i} {
			lappend pkgCache($name:depend) [lindex $line $i]
		    }
		} elseif {[lindex $line 0] eq "provide:"} {
		    for {set i 1} {$i < [llength $line]} {incr i} {
			lappend pkgCache($name:provide) [lindex $line $i]
		    }
		} elseif {[lindex $line 0] eq "require:"} {
		    for {set i 1} {$i < [llength $line]} {incr i} {
			lappend pkgCache($name:require) [lindex $line $i]
		    }
		} elseif {[lindex $line 0] eq "version:"} {
		    set pkgCache($name:version) [lindex $line 1]
		} elseif {[lindex $line 0] eq "license:"} {
		    set pkgCache($name:license) [lindex $line 1]
		} elseif {[lindex $line 0] eq "www:"} {
		    set pkgCache($name:www) [lindex $line 1]
		} elseif {[lindex $line 0] eq "modified:"} { 
		    # date format YYYY-MM-DD
		    set pkgCache($name:modified) [lindex $line 1]
		} elseif {[lindex $line 0] eq "created:"} { 
		    # date format YYYY-MM-DD
		    set pkgCache($name:created) [lindex $line 1]
		} elseif {[lindex $line 0] eq "description:"} { 
		    lappend pkgCache($name:description) [lindex $line 1]
		}		
	    }
	    close $fh
	    if {[file exists $frequiredby]} {
		if {[catch {set fh [open $frequiredby "r"]} msg]} {
		    puts $msg;
		    continue
		}
		fconfigure $fh -encoding utf-8
		while {[gets $fh line] >= 0} {
		    lappend pkgCache($name:requiredby) $line
		}
		close $fh
	    }	    
	}
    }	
}


#-----------------------------------------------
# read info about installed addons
#-----------------------------------------------
proc read_pkg {quiet} {
    global dbpath dbcache pkgCache
    # try read db cache file
    if {![file readable $dbcache]} {
	if {!$quiet} {
	    puts "Cache file not found '$dbcache', rebuilding";
	}
	return [build-pkg-cache]	
    }
    # todo: load pkg cache
}

#-----------------------------------------------
# Search in list pair 
#-----------------------------------------------
proc getNamedVar {args name} {
    foreach {key val} $args {
	if {[string equal -nocase $key $name]} {
	    return $val
	}
    }
    return ""
}

#-----------------------------------------------
# Core functions 
#-----------------------------------------------

#-----------------------------
# Recursive file search and do command
# sourcedir must end "/" if it is dir
# @commandFile - command for file for example [list file copy]
# @commandPreDir, @commandPostDir - command for directory, before 
# andafter recursive
# Example:
#   ::core::proceed-file-recursive celestia.cfg .
#   ::core::proceed-file-recursive data/ .
# return true if have some problems
#-----------------------------
proc ::core::proceed-file-recursive {sourcedir destdir {commandFile {}} {commandPreDir {}} {commandPostDir {}} } {
    # special case: $sourcedir is _not_ directory i.e not ended by "/", 
    # do commandFile
    set problems no
    if {[string index $sourcedir end] != "/"} {
    	set fileName $sourcedir
    	set destfile $destdir
    	if {$commandFile != ""} {
    	    if [catch { eval $commandFile \"$fileName\" \"$destfile\"} msg] {
    		LOG [list $msg\n\n red] 
		set problems yes
    	    }
    	}
    	return $problems
    }

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set sourcedir [string trimright [file join [file normalize $sourcedir] { }]]

    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
    foreach fileName [glob -nocomplain -type {f r} -path $sourcedir *] {
	set destfile [file join $destdir [file tail $fileName]]
	if {$commandFile != ""} {
	    if [catch { eval $commandFile \"$fileName\" \"$destfile\"} msg] {
		LOG [list $msg\n\n red] 
		set problems yes
	    }
	}
	::misc::sleep 1
    }

    # Now look for any sub direcories
    foreach dirName [glob -nocomplain -type {d  r} -path $sourcedir *] {
	set dirName $dirName/
	set dirDest [file join $destdir [file tail $dirName]]

	if {$commandPreDir != ""} {
	    if [catch { eval $commandPreDir \"$dirDest\" } msg] {
		LOG [list $msg\n\n red] 
		set problems yes
	    }
	}

	set res [::core::proceed-file-recursive $dirName $dirDest $commandFile $commandPreDir $commandPostDir]
	if {!$problems && $res} {
	    set problems yes
	}
	if {$commandPostDir != ""} {
	    if [catch { eval $commandPostDir \"$dirDest\" } msg] {
		LOG [list $msg\n\n red] 
		set problems yes
	    }
	}
	::misc::sleep 1
    }
    return $problems
}

#------------------------------ 
# uninstall addon
#------------------------------
proc ::core::proceed-uninstall {pkgname force} {
    global dbpath pkgCache pkgDB workdir
    global cpath
    # array of addon's status for pretty report
    global todoStatus

    if {!$pkgDB($pkgname:installed)} {
	LOG [list "Addon not \"$pkgname\" installed\n" greenbg]
	return true
    }
    LOG [list "===>  " prefix [mc "Deinstalling for "] normal $pkgname\n bold]
    ::misc::sleep 200
    set dbdir [file join $dbpath $pkgname]
    set contentfile [file join $dbdir "contents"]
    set infofile [file normalize [file join $dbdir "pkginfo"]]
    set requiredbyfile [file join $dbdir "required_by"]

    # continue deinstall only if !force and no required_by
    set numofrequired 0
    if [info exist pkgCache($pkgname:requiredby)] {
	set numofrequired [llength $pkgCache($pkgname:requiredby)]
    }
    if {!$force && $numofrequired > 0} {
	LOG [list "===>  " prefix [mc "Skip deinstallation. This addon is required for "] \
		 normal $numofrequired blinkgreen [mc " addon(s) (no force specified)"]\n normal]
	set todoStatus($pkgname:status) [list [mc "Skipped, required for $numofrequired addons(s)."]\n yellowbgm]
	return false
    }
    # remove required_by first of this
    catch {unset pkgCache($pkgname:requiredby)}
    catch {file delete $requiredbyfile}

    if {[catch {set fh [open $contentfile "r"]} msg] } {
	LOG [list [mc "Can't read content file:\n"] bold $msg\n red]
	set todoStatus($pkgname:status) [list [mc "Failed, missing context files."]\n redbgm]
	return false
    }
    fconfigure $fh -encoding utf-8

    LOG [list \n normal]

    set backups {}
    set tempdir [file join [file join $workdir $pkgname] tmp]
    set file_list {} ; # file list of deleted files
    file mkdir $tempdir
    while {[gets $fh line] >= 0} {
	::misc::sleep 1
	if {[lindex $line 0] eq "rmfile:"} {
	    set file [file normalize [lindex $line 1]]
	    set md5 [lindex $line 2]
	    if {$md5 != ""} { # if have md5 for file
		if {[file exists $file]} {
		    set fmd5 [::md5::md5 -hex -filename $file]
		    if {[string equal -nocase $md5 $fmd5]} {
			
			LOG\r [list "rmfile \"$file\"" download]
			catch {file delete $file}
			lappend file_list $file
		    } else {
			LOG [list "MD5 mismatch for \"$file\" Skip delete.\n\n" download]
		    }
		}
	    } else { # quiet rm
		LOG\r [list "rmfile \"$file\"" download]
		catch {file delete $file}
		lappend file_list $file
	    }
	} elseif {[lindex $line 0] eq "rmdir:"} {
	    set dir [file normalize [lindex $line 1]]
	    LOG\r [list "rmdir \"$dir\"" download]
	    catch {file delete $dir}
	} elseif {[lindex $line 0] eq "xpatch:"} {
	    set patch [lindex $line 1]
	    set fname [getNamedVar $patch -file]
	    LOG\r [list "revert \"$fname\"" download]
	    if {![::core::apply-xpatch $patch $tempdir]} {
		LOG {\n download}
	    }
	}
    }
    close $fh 

    # now recover backups
    set backupdir [file join $dbpath $pkgname "backup"]/
    if [file exist $backupdir] {
	LOG [list "==> " prefix [mc "Recover backuped files"]\n normal]
	set fdest $cpath
	if [::core::proceed-file-recursive $backupdir $fdest [list file rename -force] [list file mkdir]] {
	    set todoStatus($pkgname:recoverbackup) [list [mc "Problem with recovering backup."]\n yellowbgm]
	}
    }
    # delete backup and rbackup dir
    catch {file delete -force [file join $dbdir "backup"]}
    catch {file delete -force [file join $sdbdir "rbackup"]}
    if {[catch {file delete [file join $dbdir "backup_info"]} msg] } {
	LOG [list [mc "Can't delete backup info file:\n"] bold $msg\n red]
	set todoStatus($pkgname:status) [list [mc "Failed."]\n redbgm]
	return false
    }

    # clear tmp
    file delete -force $tempdir

    # Now fix all installed pkgs, if it have some provides
    if [info exist pkgCache($pkgname:provide)] {
	if [llength $pkgCache($pkgname:provide)] {
	    # make filename list as absolute path from $cpath
	    set flist {}
	    set cpath_sz [string length [file normalize $cpath]]
	    incr cpath_sz
	    foreach f $file_list {
		lappend flist [string range $f $cpath_sz end]
	    }

	    # for all addon...
	    set addons_p [array names pkgCache *:category]
	    foreach a $addons_p {
		set fixpkg [lindex [split $a ":"] 0]

		set backupdir [file join $dbpath $fixpkg "backup"]
		foreach provide $pkgCache($pkgname:provide) {
		    if [file exist [file join $backupdir $provide]] {
			LOG [list "==> " prefix "Remove backuped files of " normal \"$fixpkg\" bold " package that use some provided resource of this pkg\n" normal ]

			# now remove all matched files
			foreach f $flist {
			    set testfile [file join $backupdir $f]
			    if [file exist $testfile] {
				LOG\r [list "delete from backup: $testfile" download]
				catch {file delete $testfile}
				catch {file delete [file dirname $testfile]}
			    }
			    ::misc::sleep 1
			}
			break
		    }
		}
	    }
	}
    }

    LOG [list "===>   " prefix [mc "Unregistering installation for "] normal \
	     $pkgname\n bold ]

    ::misc::sleep 100

    if {[catch {file delete $contentfile} msg] } {
	LOG [list [mc "Can't delete content file:\n"] bold $msg\n red]
	set todoStatus($pkgname:status) [list [mc "Failed."]\n redbgm]
	return false
    }
    if {[catch {file delete $infofile} msg] } {
	LOG [list [mc "Can't delete info file:\n"] bold $msg\n red]
	set todoStatus($pkgname:status) [list [mc "Failed."]\n redbgm]
	return false
    }

    # unregister required_by for all depends
    if [info exists pkgDB($pkgname:depend)] {
	foreach dep $pkgDB($pkgname:depend) {
	    ::core::rm-from-required $dep $pkgname
	}
    }

    # put deinstallmsg if exist it
    set f_msgdeinst [file normalize [file join $dbdir "msg-deinstall"]]

    if {![catch {set fh [open $f_msgdeinst "r"]}]} {
	fconfigure $fh -encoding utf-8
	LOG [list [string repeat "*" 80]\n bold]
	while {[gets $fh line] >= 0} {
	    LOG [list "$line\n" bold]
	}
	close $fh
	LOG [list [string repeat "*" 80]\n bold]
	catch {file delete $f_msgdeinst}
    }
    ::misc::sleep 100
    
    catch {file delete $dbdir}

    set pkgDB($pkgname:installed) no
    foreach key [array names pkgCache $pkgname:*] {
	unset pkgCache($key)
    }

    LOG [list "===>   " prefix [mc "Addon \""] blinkgreen $pkgname blinkgreen [mc "\" deinstalled successfully\n"] blinkgreen]
    ::misc::sleep 100
    set todoStatus($pkgname:status) [list [mc "Deinstalled."]\n greenbgm]
    return true
}

#---------------
# Help func.
# Check expression for variable from pkgDB($pkgname:$variable)
# and return result.
# If no express. found return true
#---------------
proc ::core::check-options {pkgname varname variable} {
    global pkgDB expDB
    global celVerMajor celVerMinor env tcl_platform opt config
    if {[info exists expDB($pkgname:$varname:$variable)]} {
	if {($expDB($pkgname:$varname:$variable) eq "")} {return true}
	set res 0
	catch {eval "if {($expDB($pkgname:$varname:$variable))} {
                          set res 1
                     } else {
                          set res 0
                     }" }
	return $res
    } else {
	return true
    }
}

#---------------
# Help func.
# Check md5 and other chksums for file
# Return false if file not exist
# Param dist - list of parameters
#---------------
proc ::core::checksum {dist {dolog true}} {
    global distpath
    set md5 [getNamedVar $dist -md5]
    set sha256 [getNamedVar $dist -sha256]
    set sha1 [getNamedVar $dist -sha1]
    set name [getNamedVar $dist -name]
    set fname [file join $distpath $name]
    ::misc::sleep 50
    if {[file exists $fname]} {
	if {$md5 != ""} {   
	    if {$dolog} {
		LOG [list "=> " prefix [mc "MD5 Checksum "] normal]
	    }
	    ::misc::sleep 50
	    if {[catch { set fmd5 [exec md5 -q $fname] } msg]} {
		if {[catch { set fmd5 [lindex [exec md5sum $fname] 0] } msg]} {
		    LOG [list $msg\n bold]
		    LOG [list "=> " prefix [mc "Can not calculate md5 checksum\n"] blinkred]
		    return false
		}
	    }
	    if {![string equal -nocase $md5 $fmd5]} {
		if {$dolog} {
		    LOG [list [mc "mismatch"] blinkred \
			     [mc " for "] normal $name.\n normal ]
		}
		return false
	    } else {
		if {$dolog} {
		    LOG [list [mc "OK for "] normal [file tail $name].\n normal ]
		}
	    }
	}
	::misc::sleep 100

	if {$sha256 != ""} {
	    if {$dolog} {
		LOG [list "=> " prefix [mc "SHA256 Checksum "] normal ]
	    }
	    ::misc::sleep 50
	    if {[catch { set fsha256 [exec sha256 -q $fname] } msg]} {
		if {[catch { set fsha256 [lindex [exec sha256sum $fname] 0] } msg]} {
		    LOG [list $msg\n bold]
		    LOG [list "=> " prefix [mc "Can not calculate sha256 checksum\n"] blinkred]
		    return false
		}
	    }    
	    if {![string equal -nocase $sha256 $fsha256]} {
		if {$dolog} {
		    LOG [list [mc "mismatch"] blinkred \
			     [mc " for "] normal $name.\n normal ]
		}
		return false
	    } else {
		if {$dolog} {
		    LOG [list [mc "OK for "] normal [file tail $name].\n normal ]
		}
	    }
	}

	::misc::sleep 100
	if {$sha1 != ""} {
	    if {$dolog} {
		LOG [list "=> " prefix [mc "SHA1 Checksum "] normal ]
	    }
	    ::misc::sleep 50
	    if {[catch { set fsha1 [exec sha1 -q $fname] } msg]} {
		if {[catch { set fsha1 [lindex [exec sha1sum $fname] 0] } msg]} {
		    LOG [list $msg\n bold]
		    LOG [list "=> " prefix [mc "Can not calculate sha1 checksum\n"] blinkred]
		    return false
		}
	    }
	    if {![string equal -nocase $sha1 $fsha1]} {
		if {$dolog} {
		    LOG [list [mc "mismatch"] blinkred \
			     [mc " for "] normal $name.\n normal ]
		}
		return false
	    } else {
		if {$dolog} {
		    LOG [list [mc "OK for "] normal [file tail $name].\n normal ]
		}
	    }
	}
	return true
    } else {
	return false 
    }
}

proc ::core::write-required_by {pkgname} {
    global dbpath pkgCache
    set frequiredby [file join $dbpath $pkgname "required_by"]
    set fh [open $frequiredby "w"]
    fconfigure $fh -encoding utf-8
    catch {foreach r $pkgCache($pkgname:requiredby) {
	puts $fh $r
    }}
    close $fh
}

proc ::core::add-to-required {pkgname required_by} {
    global pkgCache
    if {[info exists pkgCache($pkgname:requiredby)]} {
	if {[lsearch -exact $pkgCache($pkgname:requiredby) $required_by] < 0} {
	    lappend pkgCache($pkgname:requiredby) $required_by
	    ::core::write-required_by $pkgname 
	}
    } else {
	lappend pkgCache($pkgname:requiredby) $required_by
	::core::write-required_by $pkgname
    }
}

proc ::core::rm-from-required {pkgname required_by} {
    global pkgCache

    if {[info exists pkgCache($pkgname:requiredby)]} {
	set res {}
	foreach i $pkgCache($pkgname:requiredby) {
	    if {$i eq $required_by} {continue}
	    lappend $res $i
	}
	set pkgCache($pkgname:requiredby) $res
	::core::write-required_by $pkgname
    }  
}

#------------------------------
# Get addons that conflicted 
# with spec addon.
#------------------------------
proc ::core::get-conflicted-addons {pkgname} {
    global pkgDB pkgCache

    # list of pairs: addon name, conflict reson
    set res {}

    # check conflicts specified in conflicts category
    if [info exist pkgDB($pkgname:conflicts)] {
	foreach c $pkgDB($pkgname:conflicts) {
	    foreach confl [array names pkgDB *:conflicts] {
		set name [lindex [split $confl :] 0]
		if {$name == $pkgname } {
		    continue }
		if {[in $pkgDB($confl) $c]} {
		    lappend res $name
		}
	    }
	}
    }

    # addons that use equal $backup
    if [info exist pkgDB($pkgname:backup)] {
	foreach c $pkgDB($pkgname:backup) {
	    foreach confl [array names pkgDB *:backup] {
		set name [lindex [split $confl :] 0]
		if {$name == $pkgname } {
		    continue }
		foreach c2 $pkgDB($confl) {
		    # glob backup dir
		    if {[string match $c2* $c] ||
			[string match $c* $c2]} {
			lappend res $name
			break
		    }
		}
	    }
	}
    }

    # addons that use equal $backup
    if [info exist pkgDB($pkgname:provide)] {
	foreach c $pkgDB($pkgname:provide) {
	    foreach confl [array names pkgDB *:provide] {
		set name [lindex [split $confl :] 0]
		if {$name == $pkgname } {
		    continue }
		foreach c2 $pkgDB($confl) {
		    # glob backup dir
		    if {[string match $c2* $c] ||
			[string match $c* $c2]} {
			lappend res $name
			break
		    }
		}
	    }
	}
    }


    # addons that use equal $copy
    if [info exist pkgDB($pkgname:copy)] {
	foreach c $pkgDB($pkgname:copy) {
	    set destfile1 [lindex $c 1]
	    foreach confl [array names pkgDB *:copy] {
		set name [lindex [split $confl :] 0]
		if {$name == $pkgname } {
		    continue }
		foreach copy $pkgDB($confl) {
		    set destfile2 [lindex $copy 1]
		    # glob copy dir
		    if {[string match $destfile1* $destfile2] ||
			[string match $destfile2* $destfile1]} {
			lappend res $name
			break
		    }
		}
	    }
	    # conflict with -file of xpatch
	    foreach a [array names pkgDB *:xpatch] {
		set name [lindex [split $a :] 0]
		if {$pkgname == $name } {
		    continue }
		foreach p $pkgDB($a) {
		    set filename [getNamedVar $p -file]
		    if [string equal $filename $destfile1] {
			lappend res $name
		    }
		}
	    }
	}
    }

    # conflicts by xpatch
    if [info exist pkgDB($pkgname:xpatch)] {
	# for each xpatch of pgkname
	set addonsXPatches [array names pkgDB *:xpatch]
	foreach p1 $pkgDB($pkgname:xpatch) {
	    set filename1 [getNamedVar $p1 -file]

	    # filename will conflict with $copy
	    foreach confl [array names pkgDB *:copy] {
		set name [lindex [split $confl :] 0]
		if {$name == $pkgname } {
		    continue }
		foreach copy $pkgDB($confl) {
		    set destfile2 [lindex $copy 1]
		    if [string equal $filename1 $destfile2] {
			lappend res $name
		    }
		}
	    }

	    set pbody1 [getNamedVar $p1 -body]
	    set filetype1 [lindex $pbody1 0]
	    set vartype1 [lindex $pbody1 1]
	    set varname1 [lindex $pbody1 2]
	    set action1 [lindex $pbody1 3]
	    set values1 [lindex $pbody1 4]
	    # each addons that have xpatch
	    foreach p2 $addonsXPatches {
		# skip self
		set name [lindex [split $p2 :] 0]
		if {$name == $pkgname } {
		    continue }
		
		# each xpatch in addon
		foreach xpatch $pkgDB($p2) {
		    # first check filename which must be patched
		    set filename2 [getNamedVar $xpatch -file]
		    if {![string equal $filename1 $filename2]} {
			continue }

		    set pbody2 [getNamedVar $xpatch -body]
		    
		    # check filetype (script or lua)
		    set filetype2 [lindex $pbody2 0]
		    set vartype2 [lindex $pbody2 1]
		    if {$filetype1 != $filetype2} {
			continue }

		    if {$vartype1 == "variable" ||
			$vartype1 == "array"} {
			# check varnames for equal
			set varname2 [lindex $pbody2 2]
			if {[llength $varname1] != [llength $varname2]} {
			    continue }
			set skip no
			for {set i 0} {$i < [llength $varname1]} {incr i} {
			    if {[lindex $varname1 $i] != [lindex $varname2 $i]} {
				set skip yes
				break
			    }
			}
			if $skip { continue }

			# if vartape "variable" then it conflict in any case
			if {$vartype1 == "variable" && 
			    $vartype1 == $vartype2 } {
			    lappend res $name
			    continue
			}

			# for vartape "array" need search crosses in values 
			# which is array elements
			if {$vartype1 == "array" &&
			    $vartype1 == $vartype2} {
			    set values2 [lindex $pbody2 4]
			    foreach v $values1 {
				if [in $values2 $v] {
				    lappend res $name
				    continue
				}
			    }
			}

			# if vartypes different it be conflict
			if {$vartype1 != $vartype2} {
			    lappend res $name
			    continue
			}
		    } elseif {$vartype1 == "require"} {
			# find crosses in requires
			set varname2 [lindex $pbody2 2]
			foreach v $varname1 {
			    if [in $varname2 $v] {
				lappend res $name
				continue
			    }
			}
		    }
		}
	    }
	}
    }
    return [lsort -unique $res]
}

#------------------------------
# load from db/$pkgname/options file options
# file format:
# choice: varname varValue
# options: varname varValue
#------------------------------
proc ::core::load-options {pkgname} {
    global opt dbpath

    set file [file normalize [file join $dbpath $pkgname options]]

    if {![file exists $file]} {
	return 0
    }
    
    if {[catch {set fh [open $file "r"]} msg]} {
	return 0;
    }
    fconfigure $fh -encoding utf-8

    while {[gets $fh line] >= 0} {
	if {[lindex $line 0] eq "choice:"} {	
	    set opt([lindex $line 1]) [lindex $line 2]
	} elseif {[lindex $line 0] eq "options:"} {	
	    set opt([lindex $line 1]) [lindex $line 2]
	}
    }
    close $fh
    return 1
}

#------------------------------
# Load saved options for pkg.
# If saved options are not loaded try 
# to show config dialog if need
#------------------------------
proc ::core::update-options { pkgname } {
    global pkgDB opt GUI

    # clear old opt
    catch {unset opt}

    # load from opt file first
    set loaded [::core::load-options $pkgname]

    if {!$loaded && ([info exists pkgDB($pkgname:options)] ||
		     [info exists pkgDB($pkgname:choice)])} {
	if $GUI {
	    ::uipkg::configure-pkg $pkgname
	    ::core::update-options $pkgname
	} else {
	    puts "No configuration for package \"$pkgname\" found, use default."

	    # update opt array
	    if {[info exists pkgDB($pkgname:choice)]} {
		foreach o $pkgDB($pkgname:choice) {
		    # set only if default value is in list
		    if {[lsearch [lindex $o 3] [lindex $o 1]] >= 0} {
			set opt([lindex $o 0]) [lindex $o 1]]
		    }
		}
	    }
	    if {[info exists pkgDB($pkgname:options)]} {
		foreach o $pkgDB($pkgname:options) {
		    set opt([lindex $o 0]) [lindex $o 1]
		}
	    }
	}
    }
}

#------------------------------
# install addon 
# $depend - recursive install
# $force - force install if some depends cannot be installed
#------------------------------
proc ::core::proceed-install {pkgname {depend no} {force no}} {
    global dbpath distpath opt workdir cpath
    global pkgCache pkgDB sesInstalled
    global todoStatus

    ::core::update-options $pkgname

    set dbdir [file join $dbpath $pkgname]
    set contentfile [file normalize [file join $dbdir "contents"]]
    set infofile [file normalize [file join $dbdir "pkginfo"]]

    # just for log
    set upgrade yes
    if {!$pkgDB($pkgname:installed)} {
	set upgrade no
	LOG [list "===>  " prefix [mc "Installing addon "] normal \
		 $pkgname bold " (recursive: $depend, force: $force)\n" normal]
    } else {
	LOG [list "===>  " prefix [mc "Upgrade addon "] normal \
		 $pkgname bold " (recursive: $depend, force: $force)\n" normal]
    }
    ::misc::sleep 200

    # check conflicts
    set conflicts [::core::get-conflicted-addons $pkgname]
    set isConflict no
    foreach addonname $conflicts {
	if {$pkgDB($addonname:installed)} {
	    set isConflict yes
	    break
	}
    }
    if $isConflict {
	LOG [list "===>  " prefix $pkgname bold [mc " conflicts with installed package(s):"]\n normal]
	foreach addonname $conflicts {
	    if {$pkgDB($addonname:installed)} {
		LOG [list $addonname\n table]
	    }
	}
	LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
		 $pkgname\n blinkred ]
	set todoStatus($pkgname:status) [list [mc "Aborted, conflicts found."]\n redbgm]
	return false
    }

    # download first
    set faillist ""
    if {[info exists pkgDB($pkgname:distfile)]} {
	foreach dist $pkgDB($pkgname:distfile) {
	    if {![::core::check-options $pkgname distfile $dist]} {
		continue }
	    set name [getNamedVar $dist -name]
	    set fname [file join $distpath $name]
	    set fsize [getNamedVar $dist -size]
	    if {![file exists $fname]} {
		LOG [list "=> " prefix $name bold \
			 [mc " doesn't seem to exist in " ] normal $distpath.\n normal]		
	    }
	    if {(![file exists $fname]) || ([file size $fname] < $fsize)} {
		foreach url [getNamedVar $dist -url] {
		    ::misc::sleep 200
		    ::core::download $url
		    if {([file exists $fname]) && ([file size $fname] >= $fsize)} {
			break
		    }
		}
	    }
	    if {![::core::checksum $dist]} {
		lappend faillist $name
	    }
	}
	
	# check for fail downloads
	if {[llength $faillist] > 0} { # some files not downloaded!
	    LOG [list "=> " prefix [mc "Some files not found:\n"] bold ]
	    foreach file $faillist {
		LOG [list $file\n table]
	    }
	    LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
		     $pkgname\n blinkred ]
	    set todoStatus($pkgname:status) [list [mc "Aborted, some files not downloaded or checksum mismatch."]\n redbgm]
	    return false
	}
    }
    # after download check dependencies
    set faildepend ""
    if {$depend && [info exists pkgDB($pkgname:depend)]} {
	foreach dep $pkgDB($pkgname:depend) {
	    if {![::core::check-options $pkgname depend $dep]} {
		continue }
	    # check for actual addon
	    LOG [list "===>   " prefix $pkgname bold [mc " depends on package: "] normal \
		     $dep bold " - " normal]
	    ::misc::sleep 100

	    if {[info exists pkgDB($dep:version)]} {
		set needinstall 0
		if {[info exists pkgCache($dep:version)]} {
		    if {[::misc::cmpversion $pkgDB($dep:version) $pkgCache($dep:version)] == "g"} {
			set needinstall 1
		    }
		} else {
		    set needinstall 1
		}
		if {$needinstall} {
		    LOG [list [mc "not found\n" ] bold]
		    # install depend
		    if {![::core::proceed-install $dep yes]} {
			# fail to install depend, save problem pkg name
			set faildepend $dep
		    }
		    LOG [list "===>   " prefix [mc "Returning to install of "] greenbg \
			     $pkgname\n greenbgbold ]
		    ::misc::sleep 100
		    if {($faildepend != "") && !$force} {
			LOG [list "=> " prefix [mc "Dependence not installed:\n"] normal $faildepend\n table]
			LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
				 $pkgname\n blinkred ]
			set todoStatus($pkgname:status) [list [mc "Aborted, dependence not installed."]\n redbgm]
			::misc::sleep 200
			return false
		    }

		} else {
		    LOG [list [mc "found\n" ] bold]
		}		    
	    } else { # no version of depend's pkg, some problem with him
		LOG [list [mc "no version\n" ] blinkred]
	    }


	    ::misc::sleep 200
	    # get opts
	    ::core::update-options $pkgname
	}
    }

    # than resolve require
    if {$depend && [info exists pkgDB($pkgname:require)]} {
	foreach r $pkgDB($pkgname:require) {
	    if {![::core::check-options $pkgname require $r]} {
		continue
	    }
	    # check for actual addon
	    LOG [list "===>   " prefix $pkgname bold [mc " depends on file: "] normal \
		     $r bold " - " normal]
	    ::misc::sleep 100

	    # does provider of file installed?
	    set needinstall 1
	    foreach pkg [array names pkgCache *:provide] {
		if [in $pkgCache($pkg) $r] {
		    LOG [list [mc "found\n" ] bold]
		    set needinstall 0
		    break
		}
	    }

	    # need install some provider
	    if {$needinstall} {
		LOG [list [mc "not found\n" ] bold]
		# first find best provider based on creation time of addon
		set providerpkg_name ""
		set providerpkg_create ""
		foreach pkg [array names pkgDB *:provide] {
		    if [in $pkgDB($pkg) $r] {
			set name [lindex [split $pkg :] 0]
			if {[::misc::cmpversion $pkgDB($name:created) $providerpkg_create] == "g"} {
			    set providerpkg_name $name
			    set providerpkg_create $pkgDB($name:created)
			}
		    }
		}
		if {$providerpkg_name == ""} {
		    LOG [list "=> " prefix [mc "Provider not declared, you may try update index and retry\n"] normal]
		    LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
			     $pkgname\n blinkred ]
		    set todoStatus($pkgname:status) [list [mc "Aborted, provider of file not declared."]\n redbgm]
		    ::misc::sleep 200
		    return false
		} else {
		    # install
		    ::misc::sleep 100
		    if {![::core::proceed-install $providerpkg_name yes]} {
			# fail to install depend, save problem pkg name
			set faildepend $providerpkg_name
		    }
		    LOG [list "===>   " prefix [mc "Returning to install of "] greenbg \
			     $pkgname\n greenbgbold ]
		    ::misc::sleep 200
		    if {($faildepend != "") && !$force} {
			LOG [list "=> " prefix [mc "Dependence not installed:\n"] normal $faildepend\n table]
			LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
				 $pkgname\n blinkred ]
			set todoStatus($pkgname:status) [list [mc "Aborted, dependence not installed."]\n redbgm]
			::misc::sleep 200
			return false
		    }
	    
		    ::misc::sleep 200
		    # get opts again
		    ::core::update-options $pkgname
		}
	    }
	    
	}
    }

    # Install

    # extract dir is $workdir/$pkgname/work/
    set extractdir [file nativename [file join [file join $workdir $pkgname] work]]
    file mkdir $extractdir
    # but first clean him for old
    file delete -force $extractdir
    if [info exists pkgDB($pkgname:unpack)] {
	LOG [list "===>  " prefix [mc "Extracting for "] normal $pkgname\n bold ]
	foreach pack $pkgDB($pkgname:unpack) {
	    if {![::core::check-options $pkgname unpack $pack]} {
		continue }
	    if {![::core::unpack $pack $extractdir]} {
		LOG [list "===> " prefix [mc "Aborted installation of addon "] blinkred \
			 $pkgname\n blinkred [mc "Reason: can't unpack archive.\n"] blinkred]
		set todoStatus($pkgname:status) [list [mc "Aborted, can't unpack archive."]\n redbgm]
		return 0
	    }
	    ::misc::sleep 100
	}
    }

    # rename in work dir
    # does not overwrite existing file if need
    # FIXME: need allow overwriting, we may extract several archives
    if [info exist pkgDB($pkgname:renamework)] {
	LOG [list "===>  " prefix [mc "Rename in work dir for "] normal $pkgname\n bold ]
	foreach rename $pkgDB($pkgname:renamework) {
	    if {![::core::check-options $pkgname renamework $rename]} {
		continue }
	    if {[llength $rename] == 0} {
		continue }    
	    set dest [file join $extractdir [lindex $rename 1]]
	    set src [file join $extractdir [lindex $rename 0]]
	    # make sure that dir exist
	    file mkdir [file dirname $dest]
	    if [catch {file rename $src $dest} msg] {
		LOG [list $msg\n red]
		set todoStatus($pkgname:rename) [list [mc "Problem renaming files. Addon may be not correct installed."]\n yellowbgm]
	    }
	}
	::misc::sleep 100
    }

    # apply patches
    if [info exist pkgDB($pkgname:patch)] {
	LOG [list "===>  " prefix [mc "Applying patches for "] normal $pkgname\n bold ]
	::misc::sleep 200
	foreach p $pkgDB($pkgname:patch) {
	    if {[::core::check-options $pkgname patch $p]} {
		::misc::sleep 200
		set filename [file nativename [file join $cpath $distpath $p]]
		if {[catch {exec patch -s -p0 -d $extractdir -i $filename} msg]} {
		    LOG [list $msg\n bold]
		    LOG [list "=> " prefix [mc "Can not apply patch. Abort installation\n"] blinkred]
		    set todoStatus($pkgname:status) [list [mc "Aborted, can't not apply patch."]\n redbgm]
		    return false
		}
		::misc::sleep 100
	    }
	}
    }
    # if installed - remove old pkg ie deinstall old
    if {$pkgDB($pkgname:installed)} {
	LOG [list "===>  " prefix [mc "Uninstalling the old version\n"] normal ]
	::misc::sleep 200
	::core::proceed-uninstall $pkgname yes
    }

    # info about installed pkg into pkginfo file
    file mkdir $dbdir
    set finfo [open $infofile w]
    fconfigure $finfo -encoding utf-8
    puts $finfo "# -*-coding: utf-8 -*-"

    puts $finfo "category: $pkgDB($pkgname:category)"
    puts $finfo "version: $pkgDB($pkgname:version)"
    if {[info exists pkgDB($pkgname:modified)]} {
	puts $finfo "modified: $pkgDB($pkgname:modified)\n"
    }
    if {[info exists pkgDB($pkgname:created)]} {
	puts $finfo "created: $pkgDB($pkgname:created)\n"
    }
    if {[info exists pkgDB($pkgname:license)]} {
	puts $finfo "license: $pkgDB($pkgname:license)\n"
    }
    if {[info exists pkgDB($pkgname:www)]} {
	puts $finfo "www: $pkgDB($pkgname:www)\n"
    }
    if {[info exists pkgDB($pkgname:depend)]} {
	puts $finfo "depend: $pkgDB($pkgname:depend)\n"
    }
    if {[info exists pkgDB($pkgname:provide)]} {
	puts $finfo "provide: $pkgDB($pkgname:provide)\n"
	set pkgCache($pkgname:provide) $pkgDB($pkgname:provide)
    }
    if {[info exists pkgDB($pkgname:require)]} {
	puts $finfo "require: $pkgDB($pkgname:require)\n"
	set pkgCache($pkgname:require) $pkgDB($pkgname:require)
    }
    if {[info exists pkgDB($pkgname:description)]} {
	foreach descr $pkgDB($pkgname:description) {
	    puts $finfo "description: \{$descr\}"
	}
    }

    close $finfo

    ::misc::sleep 200

    # content file
    set fid [open $contentfile w]
    fconfigure $fid -encoding utf-8
    puts $fid "# -*- coding: utf-8; mode: tcl -*-"

    # make backup if need
    if [info exist pkgDB($pkgname:backup)] {
	LOG [list "===>  " prefix [mc "Make backups for "] normal $pkgname\n\n bold ]

	# copy into backup dir of addon db folder from root dir
	foreach f $pkgDB($pkgname:backup) {
	    if {![::core::check-options $pkgname backup $f]} {
		continue }
	    set backupdir [file join $dbdir "backup" [file dirname $f]]
	    set fsource [file join $cpath $f]
	    # if it is dir - append / to end of source name
	    if [file isdirectory $fsource] {
		set fsource $fsource/
		set backupdir [file join $backupdir [file tail $f]]
	    }
	    file mkdir $backupdir
	    LOG\r [list "backup \"$fsource\"" download]

	    if [::core::proceed-file-recursive $fsource $backupdir \
		      [list file copy -force] [list file mkdir]] {
		set todoStatus($pkgname:backup) [list [mc "Problem backuping. (Try \"Fix installed addons.\")"]\n yellowbgm]
	    }
	}
	::misc::sleep 200

	# Make rbackup for reinstall some files (backups file)
	# if depended addon will be reinstalled
	# i.e backuping files from this addon too
	# Just copy files from extract dir (files is renamed before)
	LOG [list "===>  " prefix [mc "Prepare rbackups for "] normal $pkgname\n bold ]
	LOG [list \n normal]

	# helper, copy file and log src file into file excluding first
	# @basepath_sz chars
	proc ::core::tmp-copy-and-log {fh basepath_sz src dst} {
	    puts "forrbackup: $src -> $dst"
	    file copy -force $src $dst
	    puts $fh [string range [file normalize $src] $basepath_sz end]
	}

	# create file for backup filename list
	set fbck [open [file join $dbdir "backup_info"] w]
	foreach f $pkgDB($pkgname:backup) {
	    if {![::core::check-options $pkgname backup $f]} {
		continue }
	    set rbackupdir [file join $dbdir "rbackup" [file dirname $f]]
	    set fsource [file join $extractdir $f]
	    # if it is dir - append / to end of source name
	    if [file isdirectory $fsource] {
		set fsource $fsource/
		set rbackupdir [file join $rbackupdir [file tail $f]]
	    }
	    file mkdir $rbackupdir
	    LOG\r [list "rbackup \"$fsource\"" download]

	    set base_sz [string length [file normalize $extractdir]]
	    incr base_sz

	    if [::core::proceed-file-recursive $fsource $rbackupdir \
		    [list ::core::tmp-copy-and-log $fbck $base_sz] [list file mkdir]] {
		set todoStatus($pkgname:rbackup) [list [mc "Problem Rbackuping."]\n yellowbgm]
	    }
	}
	::misc::sleep 200
	close $fbck

    }

    LOG [list "===>  " prefix [mc "Installing for "] normal $pkgname\n\n bold ]

    # copy files first if need
    if {[info exists pkgDB($pkgname:copy)]} {
	foreach cop $pkgDB($pkgname:copy) {
	    if {![::core::check-options $pkgname copy $cop]} {
		continue }
	    set fsource [lindex $cop 0]
	    set fdest [lindex $cop 1]
	    if {$fsource == "" || $fdest == ""} {
		continue }
	    set fdest [file join $cpath $fdest]
	    LOG\r [list "copy \"$fsource\" \"$fdest\"" download]
	    # make sure that dest dir exist
	    set fsrc [file join $extractdir $fsource]
	    catch { file mkdir [file dirname $fdest] }
	    puts $fid {}
	    puts $fid "# clean for copy \"$fsrc\" \"$fdest\""
	    proc ::core::tmp-copyFile {fh fileSrc fileDest} {
		file copy -force $fileSrc $fileDest
		puts $fh "rmfile: \"$fileDest\""
	    }	    

	    proc ::core:tmp-mkDir {dir} {
		file mkdir $dir
	    }

	    proc ::core::tmp-checkDirPost {fh dirName} {
		# remove empty dir, if it not empty log "rmdir" to contents file
		if [catch {file delete $dirName}] {
		    puts $fh "rmdir: \"$dirName\""
		}
	    }

	    if [::core::proceed-file-recursive $fsrc $fdest \
		      [list ::core::tmp-copyFile $fid] \
		      [list ::core:tmp-mkDir] \
		      [list ::core::tmp-checkDirPost $fid]] {
		set todoStatus($pkgname:copy) [list [mc "Problem copying."]\n yellowbgm]
	    }

	    puts $fid "rmdir: \"$fdest\""
	    puts $fid "# end clean for copy \"$fsrc\" \"$fdest\""
	    puts $fid ""
	    ::misc::sleep 1
	}
	::misc::sleep 100
    }

    close $fid

    # check rules for install
    set allowrules {}
    set denyrules {}
    if {[info exists pkgDB($pkgname:install)]} {
	foreach rule $pkgDB($pkgname:install) {
	    if {![::core::check-options $pkgname install $rule]} {
		continue }		
	    set pattern [lindex $rule 0]
	    set allow 1
	    set nocase 1
	    set md5 0
	    for {set i 1} {$i < [llength $rule]} {incr i} {
		switch [lindex $rule $i] {
		    -skip {
			set allow 0
		    }
		    -deny {
			set allow 0
		    }
		    -case {
			set nocase 0
		    }
		    -md5 {
			set md5 1
		    }
		}
	    }
	    set rule [list $pattern $nocase $md5]
	    if {$allow} {
		lappend allowrules $rule
	    } else {
		lappend denyrules $rule
	    }
	}
    } else { # default install all, case insensitive, no md5 chksum
	lappend allowrules [list  * 1 0 ]
    }

    # install extracted files with install rules
    set fid [open $contentfile a]
    fconfigure $fid -encoding utf-8
    puts $fid "\n# installed files:"
    if {[::core::install-extracted-files $allowrules $denyrules $extractdir $fid $cpath]} {
	set todoStatus($pkgname:install) [list [mc "Some files not installed."]\n yellowbgm]
    }

    puts $fid {}

    if [info exists pkgDB($pkgname:xpatch)] {

	set fxpath [open [file normalize [file join $dbdir "xpatch"]] w]
	fconfigure $fid -encoding utf-8

	# save current xpatch for repatching when depended addon
	# will be reinstalled, append info file
	set finfo [open $infofile a]
	fconfigure $finfo -encoding utf-8
	puts $finfo {}
	puts $finfo "# list if xpatches:"

	file mkdir $extractdir
	LOG [list "===>  " prefix [mc "Post install configuring for "] normal $pkgname\n bold ]
	LOG [list \n normal]
	foreach p $pkgDB($pkgname:xpatch) {
	    if {[::core::check-options $pkgname xpatch $p]} {
		set fname [getNamedVar $p -file]
		LOG\r [list "xpatch \"$fname\"" download]
		::misc::sleep 1
		if {![::core::apply-xpatch $p $extractdir $fid]} {
		    LOG [list "===> " prefix [mc "Addon may not work"]\n blinkred \
			    ]
		    set todoStatus($pkgname:xpatch) [list [mc "XPatch failed, addon may not work properly."]\n yellowbgm]
		    # todo mark as broken
		}
		puts $fxpath $p
	    }
	}
	close $fxpath
	close $finfo
    }

    ::misc::sleep 100

    # clear work
    file delete -force $extractdir

    LOG [list "===>   " prefix [mc "Registering installation for "] normal \
	     $pkgname\n bold ]
    ::misc::sleep 200

    # when all depends installed fine set required_by these deps for this pkgname
    if {$depend && [info exists pkgDB($pkgname:depend)]} {
	foreach dep $pkgDB($pkgname:depend) {
	    if {![::core::check-options $pkgname depend $dep]} {
		continue }
	    ::core::add-to-required $dep $pkgname
	}
    }

    close $fid

    ::core::fix-required-addon $pkgname

    # TODO: check installed addons  that have problem during inst. i.e
    # not ending by "installed."
    set fid [open $contentfile a]
    fconfigure $fid -encoding utf-8
    puts $fid "\ninstalled."
    close $fid

    lappend sesInstalled $pkgname
    set pkgDB($pkgname:installed) yes
    set pkgCache($pkgname:name) $pkgname
    set pkgCache($pkgname:category) $pkgDB($pkgname:category)
    if {[info exists pkgDB($pkgname:modified)]} {
	set pkgCache($pkgname:modified) $pkgDB($pkgname:modified)
    }
    if {[info exists pkgDB($pkgname:created)]} {
	set pkgCache($pkgname:created) $pkgDB($pkgname:created)
    }

    if {[info exists pkgDB($pkgname:depend)]} {
	set pkgCache($pkgname:depend) $pkgDB($pkgname:depend)
    }
    set pkgCache($pkgname:version) $pkgDB($pkgname:version)
    
    # put installmsg if exist it
    if {[info exists pkgDB($pkgname:installmsg)]} {
	LOG [list [string repeat "*" 80]\n bold ]
	foreach msg $pkgDB($pkgname:installmsg) {
	    if {![::core::check-options $pkgname installmsg $msg]} {
		continue }
	    LOG [list "$msg\n" bold]
	}
	LOG [list [string repeat "*" 80]\n bold ]
    }
    # save deinstall msg that be shown when addon deinstalled
    if {[info exists pkgDB($pkgname:deinstallmsg)]} {
	set fh [open [file normalize [file join $dbdir "msg-deinstall"]] w]
	fconfigure $fh -encoding utf-8
	foreach msg $pkgDB($pkgname:deinstallmsg) {
	    if {![::core::check-options $pkgname deinstallmsg $msg]} {
		continue }
	    puts $fh $msg
	}
	close $fh
    }
    
    LOG [list "===>   " prefix [mc "Addon \""] blinkgreen $pkgname blinkgreen [mc "\" installed successfully\n"] blinkgreen]	
    if $upgrade {
	set todoStatus($pkgname:status) [list [mc "Upgraded."]\n greenbgm]
    } else {
	set todoStatus($pkgname:status) [list [mc "Installed."]\n greenbgm]
    }
    return true
}

# Checkout all installed pkg's  depend for required_by for curr. addon
# (@pkgname) auto  fix depend list,  backup newer installed  files and
# recover files from rbackups/ of  addon that required this addon, its
# more faster than reinstalling required_by addon.
#
# Rexpatch, and  backup/recover backup for addon that  use provides of
# this addon.
proc ::core::fix-required-addon {pkgname} {
    global cpath dbpath pkgCache pkgDB todoStatus
    set fixed_addons {}

    set contentfile [file normalize [file join $dbpath $pkgname "contents"]]

    # first get file list from content file
    set fid [open $contentfile r]
    set filelist {}
    
    # make filename list as absolute path from $cpath
    set cpath_sz [string length [file normalize $cpath]]
    incr cpath_sz
    while {[gets $fid line] >= 0} {
	if {[lindex $line 0] eq "rmfile:"} {
	    lappend filelist [string range [lindex $line 1] $cpath_sz end]
	}
    }
    close $fid
    
    # help func, 
    # Update newer file to backup/ and recover from rbackup.
    # @filelist - list of installed files
    proc ::core::fix-backup {fixpkg filelist} {
	global dbpath cpath workdir

	LOG [list \n normal]

	set backup_info [file join $dbpath $fixpkg "backup_info"]
	# backup
	if {[file exist $backup_info]} {

	    set backupdir [file join $dbpath $fixpkg "backup"]
	    set rbackupdir [file join $dbpath $fixpkg "rbackup"]
	    
	    # load backup file list for this pkg
	    set fbck [open $backup_info r]
	    set backup_list {}
	    while {[gets $fbck line] >= 0} {
		lappend backup_list $line
	    }
	    close $fbck

	    foreach f $backup_list {
		# installed file must exist in backup file list
		if {![in $filelist $f]} {
		    continue
		}
		set newerfile [file join $cpath $f]
		# update newer file to backup/
		set forbackup [file join $backupdir $f]
		file mkdir [file dirname $forbackup]
		if [catch {file copy -force $newerfile $forbackup} msg] {
		    LOG [list $msg\n\n red]
		}

		set fromrecover [file join $rbackupdir $f]
		if [file exist $fromrecover] {
		    LOG\r [list "recover $fromrecover" download]

		    if [catch {file copy -force $fromrecover $newerfile} msg] {
			LOG [list $msg\n\n red]
		    }
		}
		::misc::sleep 1
	    }
	} ;# fix backup

	# need re-xpatch?
	set xpatchname [file join $dbpath $fixpkg "xpatch"]
	if [file exist $xpatchname] {
	    set tempdir [file join [file join $workdir $fixpkg] tmp]
	    file mkdir $tempdir

	    set fxpatch [open $xpatchname r]
	    while {![eof $fxpatch]} {
		set line [gets $fxpatch]
		set f [getNamedVar $line -file]
		if {[in $filelist $f]} {
		    LOG\r [list "rexpatch \"$f\"" download]
		    if {![::core::apply-xpatch $line $tempdir]} {
			LOG [list "===> " prefix [mc "Addon may not work"]\n\n blinkred \
				]
			set todoStatus($fixpkg:xpatch) [list [mc "XPatch failed, addon may not work properly."]\n yellowbgm]
		    }
		}
		::misc::sleep 1
	    }
	    close $fxpatch
	    # clear tmp
	    file delete -force $tempdir
	}
    }
    
    # first recover from required_by addons
    foreach dep [array names pkgCache *:depend] {
	# extract name of pkg
	set depname [lindex [split $dep ":"] 0]
	if [in $pkgCache($depname:depend) $pkgname] {
	    # make sure addon is in required_by list
	    ::core::add-to-required $pkgname $depname
	    LOG [list "=> " prefix "Fix " normal \"$depname\" bold " that require " normal \"$pkgname\"\n bold ]

	    ::core::fix-backup $depname $filelist

	    lappend fixed_addons $depname
	    ::misc::sleep 1
	}
    }

    ::misc::sleep 100
    # Now fix provides for this addons. $provide is a list of files
    # and we need recover from dir rbackup/ all this files, re
    # xpatching this too
    if [info exist pkgDB($pkgname:provide)] {
	if [llength $pkgDB($pkgname:provide)] {
	    set addons_p [array names pkgCache *:category]
	    foreach a $addons_p {
		set fixpkg [lindex [split $a ":"] 0]

		# check rbackup for provide files
		# firt make sure this addon not fixed yet
		if [in $fixed_addons $fixpkg] {
		    continue}
		lappend fixed_addons $fixpkg

		set need_fix no

		foreach provide $pkgDB($pkgname:provide) {
		    # recover existed $provide files from rbackup/ of installed addon
		    # or re xpath if exist
		    if {[file exist [file join $dbpath $fixpkg "rbackup" $provide]]} {
			LOG [list "==> " prefix "Fix " normal \"$fixpkg\" bold " package that use some provided resource of " \
				 normal \"$pkgname\"\n bold ]
			set need_fix yes
		    }
		}

		if [file exist [file join $dbpath $fixpkg "xpatch" ]] {
		    set need_fix yes
		}

		if $need_fix {
		    LOG [list "==> " prefix "Fix " normal \"$fixpkg\" bold " package that (may) use some provided resource of " \
			     normal \"$pkgname\"\n bold ]
		    ::core::fix-backup $fixpkg $filelist
		}
	    }
	}
    }
}

#---------------
# install files from work dir using filters and log to fh
#---------------
proc ::core::install-extracted-files {allowrules denyrules sourcedir fh destdir} {
    proc ::core::tmp-checkfile {allowrules denyrules fh fileSrc fileDest} {
	set allow 0
	set md5 0
	# first check pass rules
	foreach rule $allowrules {
	    set nocase [lindex $rule 1]
	    if {$nocase} {
		set match [string match -nocase *[lindex $rule 0] $fileSrc]
	    } else {
		set match [string match  *[lindex $rule 0] $fileSrc]
	    }
	    if {$match} {
		set allow 1
		set md5 [expr $md5 || [lindex $rule 2]]
	    }
	}
	# check deny rules
	foreach rule $denyrules {
	    set nocase [lindex $rule 1]
	    if {$nocase} {
		set match [string match -nocase *[lindex $rule 0] $fileSrc]
	    } else {
		set match [string match  *[lindex $rule 0] $fileSrc]
	    }
	    if {$match} {
		set allow 0
	    }
	}
	if {$allow} {
	    file rename -force $fileSrc $fileDest
	    if {$md5} { # md5
		set fmd5 [::md5::md5 -hex -filename [file normalize $fileDest]]
		puts $fh "rmfile: \"$fileDest\" \t$fmd5"
	    } else {
		puts $fh "rmfile: \"$fileDest\""
	    }
	    LOG\r [list "install $fileDest" download]
	}
    }

    proc ::core::tmp-checkDirPre {dirName} {
	file mkdir $dirName
	LOG\r [list "mkdir $dirName" download]
    }

    proc ::core::tmp-checkDirPost {fh dirName} {
	# remove empty dir, if it not empty log "rmdir" to contents file
	if [catch {file delete $dirName}] {
	    puts $fh "rmdir: \"$dirName\""
	}
    }

    return [::core::proceed-file-recursive $sourcedir/ $destdir/ \
		[list ::core::tmp-checkfile $allowrules $denyrules $fh] \
		[list ::core::tmp-checkDirPre] \
		[list ::core::tmp-checkDirPost $fh]]
}

proc ::core::unpack {opts extrdir} {
    global distpath
    set fname [getNamedVar $opts -file]
    set packer [getNamedVar $opts -type]
    set dir [getNamedVar $opts -dir]
    
    ::misc::sleep 1

    if {![string length $fname]} {
	LOG [list "Nil file name for unpack\n" blinkred]
	return 0
    }
    set fname [file normalize [file join $distpath $fname]]
    set dir [ file normalize [file join $extrdir $dir]]

    file mkdir $dir
    LOG [list "$packer $fname\n" download]
    ::misc::sleep 1
    switch $packer {
	zip { 
	    if {[catch { exec unzip -o -d $dir $fname } results options]} {
		set details [dict get $options -errorcode]
		if {[lindex $details 0] eq "CHILDSTATUS"} {
		    set status [lindex $details 2]
		    # status 1 is only warning
		    # need check Windows wersion of unzip for error
		    if {$status == 1} {
			LOG [list "Warning: " yellowbgm $results\n\n normal]
		    } else {
			return 0
		    }
		} else {
		    LOG [list $results\n bold]
		    return 0
		}
	    }
	}
	tar {
	    if {[catch { exec tar -xf $fname -C $dir } results options]} {
		LOG [list $results\n bold]
		return 0
	    }
	}
	default {
	    LOG [list "Don't know how to unpack file: '$fname' as type '$packer'\n" blinkred]
	    return 0
	}
    }
    return 1
}

#------------------------------
# Simple patcher for files
#------------------------------
proc ::core::apply-xpatch {p tmpdir {f_content ""}} {
    global cpath
    set fname [getNamedVar $p -file]
    set fname [file join $cpath $fname]

    if {[catch {set fs [open $fname "r"]} msg]} {
	LOG [list [mc "Cannot open file for patching: "] normal $msg\n\n red]
	return false
    }
    fconfigure $fs -encoding utf-8

    set tmpfile [file join $tmpdir tmp]
    if {[catch {set fd [open $tmpfile "w"]} msg]} {
	LOG [list [mc "Cannot open file for patching: "] normal $msg\n\n red]
	close $fs
	return false
    }
    fconfigure $fd -encoding utf-8

    set res [::core::xpatch [getNamedVar $p -body] $fs $fd revert]
    close $fs
    close $fd
    if $res {
	# apply
	file rename -force $tmpfile $fname
	# write to content file revert patch
	if {$f_content != "" &&
	    [info exist revert]} {
	    puts $f_content "xpatch: { -file \"$fname\" -body {$revert} }"
	}
    } else {
	# clear tmp file
	catch {file delete $tmpfile}
	return false
    }
    return true
}

#------------------------------
# Patcher core
# @param patch	patch body
# @param fs	source file
# @param fd	dest file
# @param revertp upvar for revert patch
#
# For variable name you can use regexp expr.
#
# Usage example of patch
#
# == LUA ==
# Note: array of array not support
# 1. Add string to array of lua file
#   {-file config.lua -body {lua array VARNAME addstring {LISTOFVALUE} }}
# 2. Add number or other in lua's array
#   {-file config.lua -body {lua array VARNAME add {LISTOFVALUE} }}
# 3. Remove string value from lua's array
#   {-file config.lua -body {lua array VARNAME rmstring {LISTOFVALUE} }}
# 4. Remove other value from lua's array
#   {-file config.lua -body {lua array VARNAME rm {LISTOFVALUE} }}
# 5. Modify lua's variable 
#   {-file config.lua -body {lua variable VARNAME set VALUE } }
# 6. Add "require"
#   {-file config.lua -body {lua require {LISTOFVALUE} set} }
# 6. Remove "require" from lua file
#   {-file config.lua -body {lua require {LISTOFVALUE} remove} }
# == SCRIPT ==
# 1. Add string to array of script file:
#   {-file celestia.cfg -body {script array {Configuration ExtrasDirectories} addstring {"~/home"} }}
# 2. Add number or other in script's array:
#   {-file celestia.cfg -body {script array {Configuration ExtrasDirectories} add {/tmp} }}
# 3. Remove string value from script's array:
#   {-file celestia.cfg -body {script array {Configuration ExtrasDirectories} rmstring {myextradir} }}
# 4. Remove other value from script's array:
#   {-file celestia.cfg -body {script array {Configuration ExtrasDirectories} rm {/tmp }}
# 5. Modify or create script variable: 
#   {-file celestia.cfg -body {script variable {Configuration Font} set {"sans12_uk.txf"}} }
# 6. Remove variable
#   {-file celestia.cfg -body {script variable {Configuration LogSize} remove} }
#------------------------------
proc ::core::xpatch {patch fs fd revertp} {
    # WARNING: brainfuck below!
    # validate args
    upvar $revertp revert
    set patchtype [lindex $patch 0]
    switch -- $patchtype {
	lua {
	    switch -- [lindex $patch 1] {
		array {
		    switch [lindex $patch 3] {
			addstring {}
			add {}
			rmstring {}
			rm {}
			default {
			    LOG [list $p\n bold "Patch fail, param 4 for \"lua array [lindex $patch 2]\" must be: addstring, add, rmstring, rm\n" blinkyellow]
			    return false
			}
		    }
		}
		variable {
		    switch [lindex $patch 3] {
			set {}
			default {
			    LOG [list $p\n bold "Patch fail, param 4 for \"lua variable [lindex $patch 2]\" must be: set\n" blinkyellow]
			    return false
			}
		    }
		}
		require {
		    switch [lindex $patch 3] {
			set {}
			remove {}
			default {
			    LOG [list $p\n bold "Patch fail, param 4 for \"lua require [lindex $patch 2]\" must be: set, remove\n" blinkyellow]
			    return false
			}
		    }
		}
		default {
		    LOG [list $p\n bold "Patch fail, param 2 for \"lua\" must be: array, variable\n" blinkyellow]
		    return false
		}
	    }
	}
	script {
	    switch -- [lindex $patch 1] {
		array {
		    switch [lindex $patch 3] {
			addstring {}
			add {}
			rmstring {}
			rm {}
			default {
			    LOG [list $p\n bold "Patch fail, param 4 for \"script array [lindex $patch 2]\" must be: addstring, add, rmstring, rm\n" blinkyellow]
			    return false
			}
		    }
		}
		variable {
		    switch [lindex $patch 3] {
			set {}
			remove {}
			default {
			    LOG [list $p\n bold "Patch fail, param 4 for \"script variable [lindex $patch 2]\" must be: set, remove\n" blinkyellow]
			    return false
			}
		    }
		}
		default {
		    LOG [list $p\n bold "Patch fail, param 2 for \"script\" must be: array, variable\n" blinkyellow]
		    return false
		}
	    }
	}
	default {
	    LOG [list $p\n bold "Patch fail, param 1 must be: lua, script\n" blinkyellow]
	    return false
	}
    }
    
    # proceed patch
    switch -- $patchtype {
	lua {
	    set varpath [lindex $patch 2]
	    set action [lindex $patch 3]
	    set value [lindex $patch 4]

	    # if "lua require"
	    if {[lindex $patch 1] == "require"} {
		# for "lua require" patch third param is lua units for require
		# mark all of them for need add to require
		foreach hunk [lindex $patch 2] {
		    set req_need($hunk) no
		}
		# lua require search need
		set varpath "require"
	    }

	    # try to find var
	    while {![eof $fs]} {
		set line [gets $fs]
		set text $line
		set comment ""
		set margin ""
		regexp {^(\s+).*} $line -> margin 
		regexp {^(\s*)(.*)(--.*)} $line -> margin text comment
		if {$comment != "" } { set comment " $comment" }
		set RE "^\\s*($varpath)((\\s+)|($))"
		if {[regexp $RE $text -> varname]} {

		    # found var and modify him

		    switch -- [lindex $patch 1] {
			variable {
			    #------------------------------
			    # set lua variable
			    #------------------------------
			    if {$action == "set"} {
				set val ""
				set RE "^\\s*${varpath}\\s*=(.*)$"
				regexp $RE $text -> val
				set val [string trimright $val]
				set val [string trimleft $val]
				set revert "lua variable {$varpath} set {$val}"
				puts $fd "$margin$varname = $value$comment"
			    }
			}
			array {
			    if {$action == "add" ||
				$action == "addstring"} {
				#------------------------------
				# add to lua array element
				#------------------------------
				foreach hunk $value {
				    set found($hunk) 0
				}
				
				# prepare revert patch
				set revert "lua array {$varpath}"
				if {$action == "addstring"} {
				    set revert "$revert rmstring \{"
				} else {
				    set revert "$revert rm \{"
				}

				set braceMargin $margin
				set arrEnd 0
				set arrBegin 0
				while {1} {
				    set text $line
				    set comment ""
				    # try to extract comments
				    regexp {^(.*)(--.*)} $line -> text comment
				    # skip untill \{ not be found 
				    if {!$arrBegin} {
					if [regexp {^(.*)\{(.*)} $text -> tmp text] {
					    puts $fd $tmp\{
					    set arrBegin 1
					} else {
					    puts $fd $line
					    if {[eof $fs]} {
						return false
					    }
					    set line [gets $fs]
					    continue
					}
				    }
				    regexp {^(\s*)\}} $line -> braceMargin
				    # check for end of array, find \} otherwise get margin to text
				    if [regexp {^(.*)\}} $text -> text] {
					set arrEnd 1
				    } else {
					regexp {^(\s+)} $text -> margin 
				    }
				    if {$comment != "" } { set comment " $comment" }

				    # if not empty
				    if {![regexp "^\\s*$" $text]} {
					# make sure for coma present at end,
					# remove from begin and move to end
					if {$arrBegin && ![regexp "^(.*),(\\s*)$" $text]} {
					    set text $text,
					}
					
					if {$arrBegin && [regexp "^(\\s*),(.*)$" $text -> space text]} {
					    set text $space$text
					}

					# check for values is presented in array
					foreach hunk $value {
					    set valname $hunk
					    if {$action == "addstring"} {
						set valname \"$hunk\"
					    }
					    set RE "^.*${valname}((\\s+)|(,)|($))"
					    if [regexp $RE $text] {
						set found($hunk) 1
					    }
					}
					puts $fd "$text$comment"
				    } elseif {$comment != ""} {
					puts $fd "$text$comment"
				    }
				    if {[eof $fs] || $arrEnd} {
					break
				    }
				    # next line in array
				    set line [gets $fs]
				}
				foreach hunk $value {
				    if !$found($hunk) {
					set valname $hunk
					if {$action == "addstring"} {
					    set valname \"$hunk\"
					}
					set revert "$revert $valname"
					puts $fd "$margin$valname,"
				    }
				}
				puts $fd "$braceMargin\}"
				set revert "$revert \}"
			    } elseif {$action == "rmstring"||
				      $action == "rm"} {
				#------------------------------
				# remove from array element
				#------------------------------

				# prepear revert patch
				set revert "lua array {$varpath}"
				if {$action == "rmstring"} {
				    set revert "$revert addstring \{"
				} else {
				    set revert "$revert add \{"
				}

				set braceMargin $margin
				set arrEnd 0
				set arrBegin 0
				set text $line
				while {1} {
				    # try to extract comments
				    set comment {}
				    regexp {^(.*)(--.*)} $text -> text comment
				    if {!$arrBegin} {
					if [regexp {^(.*)\{(.*)} $text -> tmp text] {
					    puts $fd $tmp\{
					    set arrBegin 1
					} else {
					    puts $fd $line
					    if {[eof $fs]} {
						return false
					    }
					    set line [gets $fs]
					    continue
					}
				    }
				    regexp {^(\s*).*\{} $text -> braceMargin
				    if {$braceMargin == ""} {set braceMargin $margin}
				    # check for end of array, find \}
				    if [regexp {^(.*)\}} $text -> text] {
					set arrEnd 1
					regexp {^(\s+).*} $text -> braceMargin
				    }
				    foreach hunk $value {
					set valname $hunk
					if {$action == "rmstring"} {
					    set valname \"$hunk\"
					}

					# if value exist in array than append him to revert patch
					if [regexp "^.*$valname" $text] {
					    set revert "$revert $valname"
					}

					set text [regsub -all "(^.*)$valname\\s*,(.*)" $text "\\1\\2"]
					set text [regsub -all "(^.*)$valname\[,\]$" $text "\\1"]
				    }
				    # dont put empty lines (with comment)
				    if {![regexp "^\\s*$" $text]} {
					puts $fd "$text$comment"
				    }
				    # if end of arr - close him \]
				    if {[eof $fs] || $arrEnd} {
					puts $fd "$braceMargin\}"
					set revert "$revert \}"
					break
				    }
				    set text [gets $fs]
				}
			    }
			}
			require {
			    if {$action == "set"} {
				#------------------------------
				# set lua require xxx set
				# seems to find some require, 
				# need to check it for add.
				#------------------------------
				foreach hunk [lindex $patch 2] {
				    set RE "^\\s*require\\s+\"${hunk}\".*$"
				    if [regexp $RE $text] {
					set req_need($hunk) yes
				    }
				}			
				puts $fd $line
			    } elseif {$action == "remove"} {
				#------------------------------
				# set lua require xxx remove
				# Seems to find some require, 
				# check him and remove.
				#------------------------------
				foreach hunk [lindex $patch 2] {
				    set RE "^\\s*require\\s+\"${hunk}\".*$"
				    if [regexp $RE $text] {
					puts found:$hunk
					set req_need($hunk) yes
					set found yes
				    }
				}
				if {!$found} {
				    puts $fd $line
				}				
			    }
			}
		    }		    
		} else {
		    puts -nonewline $fd $line
		    if [eof $fs] {
			break
		    }
		    puts $fd ""
		}
	    }
	    if {[lindex $patch 1] == "require"} {
		# prepear revert patch for
		set revert "lua require \{"
		if {[lindex $patch 3] == "set"} {
		    foreach r [lindex $patch 2] {
			# if not found require add him
			if {!$req_need($r)} {
			    puts $fd "require \"$r\";"
			    set revert "$revert $r"
			}
		    }
		    set revert "$revert \} remove"
		} elseif {[lindex $patch 3] == "remove"} {
		    foreach r [lindex $patch 2] {
			if {$req_need($r)} {
			    set revert "$revert $r"
			}
		    }
		    set revert "$revert \} set"
		}
	    }
	}
	script {
	    set varpath [lindex $patch 2]
	    set type [lindex $patch 1]
	    set action [lindex $patch 3]
	    set value [lindex $patch 4]
	    # search sub section specified in varpath

	    # level of subection i.e num of not closed \{
	    set level 0
	    # current match level
	    set matchlevel 0
	    set notfoundMargin ""
	    set foundvar no
	    while {1} {

		# check for last subsection
		if {$matchlevel == [expr [llength $varpath] -1]} {
		    set margin ""
		    # margin of line -1  
		    set prevmargin ""
		    # try to find var
		    while {![eof $fs]} {
			set line [gets $fs]
			set text $line
			set comment ""
			regexp {^(\s+).*} $line -> margin 
			regexp {^(\s*)(.*)(\#.*)} $line -> margin text comment
			if {$comment != "" } { set comment " $comment" }
			
			set RE "^\\s*([lindex $varpath $matchlevel])((\\s+)|($))"
			if {[regexp $RE $text -> varname] &&
			    $level == $matchlevel} {
			    
			    # found var and modify him
			    set foundvar yes
			    switch -- $type {
				variable {
				    #------------------------------
				    # set variable
				    #------------------------------
				    # prepear revert patch
				    set val ""
				    set RE "^\\s*[lindex $varpath $matchlevel]\\s+(.*)$"
				    regexp $RE $text -> val
				    set val [string trimright $val]
				    set val [string trimleft $val]
				    set revert "script variable {$varpath} set {$val}"					

				    if {$action == "set"} {
					# change script's var
					puts $fd "$margin$varname $value$comment"
				    } elseif {$action == "remove"} {

				    }
				}
				array {
				    if {$action == "add" ||
					$action == "addstring"} {
					#------------------------------
					# add to array element
					#------------------------------
					# prepear revert patch
					set revert "script array {$varpath}"
					if {$action == "addstring"} {
					    set revert "$revert rmstring \{"
					} else {
					    set revert "$revert rm \{"
					}
					foreach hunk $value {
					    set found($hunk) 0
					}
					set braceMargin $margin
					set arrEnd 0
					while {1} {
					    set text $line
					    set comment ""
					    # try to extract comments
					    regexp {^(.*)(\#.*)} $line -> text comment
					    regexp {^(\s*)\[} $line -> braceMargin
					    regexp {^(\s*)\]} $line -> braceMargin
					    # check for end of array, find \] otherwise get margin to text
					    if [regexp {^(.*)\]} $text -> text] {
						set arrEnd 1
					    } else {
						regexp {^(\s+)} $text -> margin 
					    }
					    if {$comment != "" } { set comment " $comment" }
					    if {![regexp "^\\s*$" $text]} {
						# check for values is presented in array
						foreach hunk $value {
						    set valname $hunk
						    if {$action == "addstring"} {
							set valname \"$hunk\"
						    }
						    set RE "^.*$valname\\s"
						    if [regexp $RE $text] {
							set found($hunk) 1
						    }
						    set RE "^.*$valname$"
						    if [regexp $RE $text] {
							set found($hunk) 1
						    }
						}
						puts $fd "$text$comment"
					    } elseif {$comment != ""} {
						puts $fd "$text$comment"
					    }
					    if {[eof $fs] || $arrEnd} {
						break
					    }
					    # next line in array
					    set line [gets $fs]
					}
					foreach hunk $value {
					    if !$found($hunk) {
						set valname $hunk
						if {$action == "addstring"} {
						    set valname \"$hunk\"
						}
						set revert "$revert $valname"
						puts $fd "$margin$valname"
					    }
					}
					puts $fd "$braceMargin\]"
					set revert "$revert \}"
				    } elseif {$action == "rmstring"||
					      $action == "rm"} {
					#------------------------------
					# remove from array element
					#------------------------------

					# prepear revert patch
					set revert "script array {$varpath}"
					if {$action == "rmstring"} {
					    set revert "$revert addstring \{"
					} else {
					    set revert "$revert add \{"
					}

					set braceMargin $margin
					set arrEnd 0
					set text $line
					while {1} {
					    # try to extract comments
					    set comment {}
					    regexp {^(.*)(\#.*)} $text -> text comment
					    regexp {^(\s*).*\[} $text -> braceMargin
					    if {$braceMargin == ""} {set braceMargin $margin}
					    # check for end of array, find \]
					    if [regexp {^(.*)\]} $text -> text] {
						set arrEnd 1
						regexp {^(\s+).*} $text -> braceMargin
					    }
					    foreach hunk $value {
						set valname $hunk
						if {$action == "rmstring"} {
						    set valname \"$hunk\"
						}

						# if value exist in array than append him to revert patch
						if [regexp "^.*$valname" $text] {
						    set revert "$revert $valname"
						}

						set text [regsub -all "(^.*)$valname\\s+(.*)" $text "\\1\\2"]
						set text [regsub -all "(^.*)$valname$" $text "\\1"]
					    }
					    if {![regexp "^\\s*$" $text]} {
						puts $fd "$text$comment"
					    }
					    # if end of arr - close him \]
					    if {[eof $fs] || $arrEnd} {
						puts $fd "$braceMargin\]"
						set revert "$revert \}"
						break
					    }
					    set text [gets $fs]
					}
				    }
				}
			    }
			    break
			} else {
			    if [regexp "^.*\{" $text] {
				incr level
			    }
			    if [regexp "^.*\}" $text] {
				#------------------------------
				# if var not found than create it
				#------------------------------
				if {!$foundvar &&
				    ($action == "addstring" ||
				     $action == "add" ||
				     $action == "set") &&
				    $level == [expr [llength $varpath] -1]} {
				    set valname [lindex $varpath [expr [llength $varpath] -1]]
				    if {$type == "array"} {
					puts $fd "$prevmargin$valname \["
					foreach hunk $value {
					    if {$action == "addstring"} {
						puts $fd "$prevmargin  \"$hunk\""
					    } else {
						puts $fd "$prevmargin  $hunk"
					    }
					}
					puts $fd "$prevmargin\]"
					# revert script
					if {$action == "addstring"} {
					    set revert "script array {$varpath} rmstring {$value}"
					} else {
					    set revert "script array {$varpath} rm {$value}"
					}
				    } elseif {$type == "variable"} {
					puts $fd "$prevmargin$valname $value"
					# revert script
					set revert "script variable {$varpath} remove"
				    }
				    set foundvar no
				}

				incr level -1
				if {$matchlevel > $level } {
				    puts $fd $line
				    break
				}
			    }
			    puts $fd $line
			    set prevmargin $margin
			}
		    }
		    # end if
		} 
		# get next line if not eof
		if [eof $fs] {
		    return true
		}
		set line [gets $fs]

		set text $line
		regexp {^(\s*)(.*)(\#.*)} $line -> margin text comment
		set RE "^(\\s*)([lindex $varpath $matchlevel])((\\s+)|($))"
		if {[regexp $RE $text -> margin varname] &&
		    $matchlevel == $level} {
		    incr matchlevel
		}
		if [regexp "^.*\{" $text] {
		    incr level
		}
		if [regexp "^.*\}" $text] {
		    incr level -1

		    if {$matchlevel > $level } {
			set matchlevel $level
		    }
		}
		
		puts -nonewline $fd $line
		if [eof $fs] {return true}
		puts $fd ""
	    }
	}
    }
    return true
}

proc ::core::download-logger {output} {
    if {[regexp "\\s+\\d+K .*" $output]} {
	LOG\r [list $output download] yes
    } else {
	LOG [list $output\n download]
    } 
}

#------------------------------
# download file and log progres
# in $distpath by default
#------------------------------
proc ::core::download {url {destdir {}}} {
    global distpath errorCode

    if {$destdir == {}} {
	set destdir $distpath
    }
    file mkdir $destdir
    LOG [list "=> " prefix [mc "Attempting to fetch from "] normal $url\n normal]
    set h1 [bgExec "wget -c --no-check-certificate --no-directories -P \"$destdir\"
                    \"$url\" --progress=dot:mega" ::core::download-logger pCount]
    # wait for finish
    vwait pCount
    LOG [list \n normal]
}

#------------------------------
# get addons that matches with 
# some field of array
#------------------------------
proc ::core::get-matched-addon-list { matchstr {listby name}} {
    global pkgDB
    set res {}

    # scpecial field
    if {$listby == "name"} {
	foreach a [array names pkgDB *:installed] {
	    set pkgname [lindex [split $a :] 0]
	    if {[string match -nocase $matchstr $pkgname]} {
		lappend res $pkgname
	    }
	}
    } elseif {$listby == "all"} {
	foreach a [array names pkgDB *] {
	    set pkgname [lindex [split $a :] 0]
	    if {[string match -nocase $matchstr $pkgname]} {
		lappend res $pkgname
	    }
	    if {[string match -nocase $matchstr $pkgDB($a)]} {
		lappend res $pkgname
	    }
	}
    } else {
	foreach a [array names pkgDB *:$listby] {
	    set pkgname [lindex [split $a :] 0]
	    if {[string match -nocase $matchstr $pkgDB($a)]} {
		lappend res $pkgname
	    }
	}
    }
    set res [::misc::lrmdups $res]
    return $res
}


#---------------
# delete dist files for addon
#---------------
proc ::core::distclean {pkgname} {
    global pkgDB distpath
    if [info exist pkgDB($pkgname:distfile)] {
	LOG [list "===>  " prefix [mc "Distclean for "] normal $pkgname\n bold]
	foreach dist $pkgDB($pkgname:distfile) {
	    set name [getNamedVar $dist -name]
	    catch {file delete [file join $distpath $name]}
	    LOG [list "delete: $name\n" table]
	}
    }
}

proc ::core::deptree-recursive {pkgname {level 0}} {
    LOG [list "[string repeat { } $level]$pkgname\n" table]
    global pkgDB pkgCache
    set deps {}
    if [info exist pkgDB($pkgname:depend)] {
	set deps $pkgDB($pkgname:depend)
    }
    if [info exist pkgCache($pkgname:depend)] {
	set deps "$deps $pkgCache($pkgname:depend)"
    }

    set deps [::misc::lrmdups $deps]
    incr level 4
    foreach dep $deps {
	deptree-recursive $dep $level
    }
}

#-----------------------------------------------
# Export all options files and create index file which
# have pkg that depend on all installed files. Put 
# options and index into archive.
# @filename - file name without extention
# -----------------------------------------------
proc ::core::export-configuration {filename comment} {
    global pkgpath dbpath pkgDB
    set configname [file tail $filename]
    
    set addonCategory "export configuration"
    set exportdir [file join $pkgpath tmpexp]
    catch {file delete -force $exportdir}
    catch {file mkdir $exportdir}
    catch {file mkdir [file join $exportdir userindex]}
    # index
    set fod [open [file join $exportdir userindex $configname.index] w]
    puts [file join $exportdir userindex $configname.index]
    puts $fod "\$addon {$configname}"
    puts $fod "\$category {$addonCategory}"
    puts $fod "\$version 1.0"
    puts $fod "\$created [clock format [clock scan now] -format \"%Y-%m-%d\"]"
    puts $fod "\$description Export of configuration"
    if {$comment != {}} {
	puts $fod "\$description $comment"
    }

    # options files
    foreach pkginst [array names pkgDB *:installed] {
	set pkgname [lindex [split $pkginst :] 0]
	set optf [file join $dbpath $pkgname options]
	
	# copy option files if installed
	if {$pkgDB($pkginst) && [file exists $optf]} {
	    set dstdir [file join $exportdir db $pkgname]
	    catch {file mkdir $dstdir}
	    catch {file copy $optf $dstdir}
	}
	# add depend in index
	if $pkgDB($pkginst) {
	    # ...but skip installed addons that are old export
	    if [info exist pkgDB($pkgname:category)] {
		if {![in $pkgDB($pkgname:category) $addonCategory]} {
		    puts $fod "\$depend {$pkgname}"
		}
	    }
	}
    }
    close $fod
    # create tarbar
    if {[catch {exec tar -czvf $filename.tar.gz -C [file normalize $exportdir] ./ } msg]} {
	LOG [list $msg\n red]
    }
    catch {file delete -force $exportdir}
}

#-----------------------------------------------
# Import from archive options and index file
# @archive - tar.gz file
# @all - import addon configuration too
# -----------------------------------------------
proc ::core::import-configuration {archive all} {
    global pkgpath dbpath 

    if {![file exists $archive]} {
	LOG [list "File not found: \"$archive\"\n" red]
	return false
    }
    
    set out {}
    set indexname [lindex [split $archive . ] 0]
    if {[catch {set out [exec tar -ztf $archive ]} msg]} {
	LOG [list $msg\n red]
    }

    set indexfname ./userindex/[file tail $indexname].index
    if {![regexp ./userindex/[file tail $indexname]\\.index $out]} {
	LOG [list "Index file \"$indexfname\" not found in archive\n" red]
	return false
    } else {
	LOG [list "Found index file: \"$indexfname\" in archive\n" green]
    }

    if $all {
	LOG [list "Import configuration of addons: \"$indexfname\" from archive\n" green]
	if {[catch {exec tar -xvf $archive -C $pkgpath } msg]} {
	    LOG [list "$msg\n" red]
	}
    } else {
	if {[catch {exec tar -xvf $archive -C $pkgpath $indexfname} msg]} {
	    LOG [list "$msg\n" red]
	}
    }
    return true
}

proc ::core::load-index-recursive {sourcedir quiet} {
    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set sourcedir [string trimright [file join [file normalize $sourcedir] { }]]

    ::misc::sleep 1

    foreach f [lsort [glob -nocomplain -type {f l} [file join $sourcedir *.index]]] {
	read_index $f $quiet
    }
    foreach f [lsort [glob -nocomplain -type {f l} [file join $sourcedir *.zip]]] {
	# read piped zip file
	read_index "|unzip -p $f \"*.index\"" $quiet	
    }

    # Now look for any sub direcories
    foreach dir [glob -nocomplain -type {d  r} -path $sourcedir *] {
	::core::load-index-recursive $dir $quiet
    }
}

proc ::core::update-celpkg {rootdir} {
    global GUI config distpath pkgpath celpkgUpdateUrl tcl_platform


    # check for develop version is running, skip overvrite
    # check for .git
    if [file exist [file join $rootdir .git]] {
	LOG [list "Development version is running, skip update\n" bold]
	return;
    }

    set dwnPath [file join $rootdir .tmp]
    # clean old
    catch {file delete -force $dwnPath}
    if {[catch {file mkdir $dwnPath} msg]} {
	LOG [list "Temporary dir not created\n$msg\n" red]
	return;
    }

    # download update index file
    LOG [list "===>  " prefix [mc "Fetch update list"]\n normal]
    ::core::download $celpkgUpdateUrl $dwnPath
    ::misc::sleep 100
    set updatelist {}

    foreach file [glob -nocomplain -type {f} [file join $dwnPath *.zip]] {
	LOG [list "===>  " prefix [mc "Read $file"]\n normal]

	set fh [open "|unzip -p $file \"*.update\"" "r"]

	while {[gets $fh line] >= 0} {
	    # structure of line:
	    # filename md5 options
	    set filename [file join $rootdir [lindex $line 0]]
	    set md5 [lindex $line 1]
	    set options [lindex $line 2]

	    set os [getNamedVar $options -os]

	    if {(($os eq "win" || $os eq "windows") && ($tcl_platform(platform) != "windows"))} {
	    	continue
	    }

	    if {(($os eq "unix" || $os eq "linux") && ($tcl_platform(platform) == "windows"))} {
	    	continue
	    }

	    if [file exists $filename] {
		set fmd5 [::md5::md5 -hex -filename $filename]
		if {![string equal -nocase $md5 $fmd5]} {
		    LOG [list "$filename\t" normal "is outdate\n" bold]
		    lappend updatelist $line
		} else {
		    LOG [list "$filename\t" normal "up to date" green \n normal]
		}
	    } else {
		LOG [list "$filename\t" normal "is outdate\n" bold]
		lappend updatelist $line
	    }
	    ::misc::sleep 1
	}  
	catch {close $fh}
    }

    ::misc::sleep 250
    LOG [list "===>  " prefix [mc "Download files"]\n normal]

    # now download all need files
    foreach {line} $updatelist {
	set opt [lindex $line 2]

	LOG [list "Download $filename\n" normal]
	set url [getNamedVar $opt -url]

	::core::download $url $dwnPath

	# make sure file is downloaded
	set filename [file join $dwnPath [file tail [lindex $line 0]]]
	if [file exists $filename] {
	    set fmd5 [lindex $line 1]
	    if {![string equal -nocase $fmd5 [::md5::md5 -hex -filename $filename]]} {
		LOG [list "MD5 Checksum mismatch for downloaded $filename\n" red]
		return
	    }
	} else {
	    LOG [list "File not downloaded: $filename\n" red]
	    return
	}
    }

    # now install update
    ::misc::sleep 250
    foreach {line} $updatelist {
	set dstfile [file join $rootdir [lindex $line 0]]
	set srcfile [file join $dwnPath [file tail [lindex $line 0]]]
	catch {file mkdir [file dirname $dstfile]}
	LOG [list $dstfile normal]
	file copy -force  $srcfile $dstfile
	LOG [list "\tok\n" green]
	::misc::sleep 1
    }
    LOG [list "===>  " prefix [mc "Done"]\n normal]
}

proc ::core::load-index {{quiet no}} {
    global pkgpath dwnlIndexDir

    # read piped all zip files
    foreach file [glob -nocomplain -type {f} [file join $pkgpath $dwnlIndexDir *.zip]] {
	read_index "|unzip -p $file \"*.index\"" $quiet	
    }


    # other user's index file in userindex/ directory
    ::core::load-index-recursive [file join $pkgpath userindex] $quiet
    read_pkg $quiet
}

proc ::core::update-index {} {
    global GUI config distpath pkgpath indexUrl dwnlIndexDir
    if $GUI {
	global nb
	$nb raise nb_log
    }
    LOG [list "===>  " prefix [mc "Updating index files"]\n ]

    # first backup old index dir
    LOG [list "==>   " prefix [mc "Backup old index files"]\n ]

    set dwnPath [file join $pkgpath $dwnlIndexDir]
    set backupdDir [file join $pkgpath $dwnlIndexDir.old]

    if {[file exists $dwnPath]} {
	# remove old backup
	file delete -force $backupdDir
	# move to backup
	if {[catch {file rename -force $dwnPath $backupdDir} msg]} {
	    LOG [list "Can't clear old index filem\n$msg\n" red]
	    return
	}

    }
    catch {file mkdir $dwnPath}

    LOG [list "==>   " prefix [mc "Download index"]\n ]

    ::core::download $indexUrl $dwnPath
    ::misc::sleep 100
    ::core::load-index

    LOG [list "===>  " prefix [mc "Done"]\n normal]
}

#------------------------------
# setup some vars
proc ::core::check-vars {} {
    global celVerMajor celVerMinor config celVersion tcl_platform
    global cpath distpath workdir pkgpath 
    global dbpath dbcache

    set celVerMajor [ lindex [split $celVersion "." ] 0]
    set celVerMinor [ lindex [split $celVersion "." ] 1]

    # additional some files setup
    set dbpath [file join $pkgpath db]
    set dbcache [file join $pkgpath pkg.db]
    
    # nativename dirs
    set cpath [file nativename $cpath]
    set distpath [file nativename $distpath]
    set workdir [file nativename $workdir]
    set pkgpath [file nativename $pkgpath]
    set dbpath [file nativename $dbpath]
    set dbcache [file nativename $dbcache]

    # mingw wget cannot download files like c:\download\ in bgExec,
    # so replace \\ to /
    set distpath [string map {\\ /} $distpath]
}

# setup default profile
set profiles($config(profile):cpath) $cpath
set profiles($config(profile):pkgpath) $pkgpath
set profiles($config(profile):distpath) $distpath
set profiles($config(profile):workdir) $workdir
set profiles($config(profile):indexUrl) $indexUrl
set profiles($config(profile):celVersion) $celVersion
