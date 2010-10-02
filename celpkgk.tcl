#!/usr/bin/wish8.5
# -*-coding: utf-8 -*-
#
# Copyright (C) 2010, Sydorchuk Olexandr  <olexandr.syd@gmail.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.

package require Tk
package require BWidget

# root dir may contain some tcl packages
set rootdir [file dirname [info script]]
lappend auto_path $rootdir

package require tablelist
tablelist::addBWidgetComboBox
tablelist::addBWidgetEntry
package require md5

namespace eval ::uicfg {}

namespace eval ::uipkg {
    # tree off all addons
    variable ::uipkg::pkgTree

    # - addon describer
    variable ::uipkg::infoText

    # - describe of all todo thinks like "install addon" upgrade and 
    variable ::uipkg::tableIntall
}

# Current addon namethat described in ::uipkg::infoText
# Used for action button to specif. addon
set currentView {}

namespace eval ::uilog {}

if {$tcl_platform(platform) == "windows"} {
    package require dde
}

# Some GUI config vars (before loading celpkg-core.tcl)
array set config {
    tree:install darkgreen
    tree:uninstall darkred
    tree:normal black
    tree:bg white
    tree:installed darkblue
    text:tittle "-font {TkTextFont 20 bold} -justify center -wrap word"
    text:category "-justify right -font {TkTextFont 10} -wrap word"
    text:propname "-font {TkTextFont 12 bold} -wrap word"
    text:propvalue "-font {TkTextFont 12 normal} -lmargin1 2c -wrap word"
    text:propbold "-font {TkTextFont 12 bold} -lmargin1 2c -wrap word"
    text:descript "-font {TkTextFont 12 normal} -wrap word -lmargin1 1c -lmargin2 0c"
    text:urlbold "-lmargin1 2c -font {TkTextFont 12} -underline on -background blue -foreground white -relief flat -borderwidth 1 -wrap word"
    text:urlnormal "-lmargin1 2c -font {TkTextFont 12} -foreground blue -underline on -background {} -relief flat -wrap word"
    text:normal "-font {TkTextFont 12} -wrap word"
    text:bold "-font {TkTextFont 10 bold} -wrap word"
    txtlog:normal "-font {TkTextFont 10} -wrap word"
    txtlog:bold "-font {TkTextFont 10 bold} -wrap word"
    txtlog:table "-font {TkTextFont 10} -relief solid -borderwidth 1 -wrap word"
    txtlog:tbllist1 "-font {TkTextFont 10} -relief solid -borderwidth 1 -background #ffffb0 -wrap word"
    txtlog:tbllist2 "-font {TkTextFont 10} -relief solid -borderwidth 1 -background #ffffff -wrap word"
    txtlog:green "-font {TkTextFont 10} -foreground darkgreen -wrap word"
    txtlog:red "-font {TkTextFont 10} -foreground red -wrap word"
    txtlog:greenbg "-font {TkTextFont 10} -background lightgreen -wrap word"
    txtlog:greenbgbold "-font {TkTextFont 10 bold} -background lightgreen -wrap word"
    txtlog:redbgm "-font {TkTextFont 10 normal} -background tomato -wrap word"
    txtlog:yellowbgm "-font {TkTextFont 10 normal} -background yellow -wrap word"
    txtlog:greenbgm "-font {TkTextFont 10 normal} -background lightgreen -wrap word"
    txtlog:download "-font {TkTextFont 8} -background #fff8dc -wrap word"
    txtlog:prefix "-font {TkTextFont 10 bold} -foreground darkorange -wrap word"
    txtlog:tittle "-font {TkTextFont 14 bold} -justify center -wrap word"
    moreInfo yes
}

set icon_reload [image create photo -data {
    R0lGODlhEAAQAIUAAPwCBPzOBPzKBPTGBPTCBPS+BOy6BOS2BOSyBPz+/Pz+9
    Pz+7Pz+5Pz+3NyqBASaBOSuBNSiBPz+1NymBNSeBPz+zPz+xPz+vMyaBBSiFB
    yiFPz+tOy2BPz+rPz+pPz+nCyqHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAEAAAAALAAAAAAQABAAAAabQEBgK
    BAMCAWD4YAAOIWJhGK6YDAaiITjKYhSGY9GAxKNOAXUKvghmUwiFOdgQV8/7h
    XLBeMsqB8ZGg8aFnp7fVYNeBp5DxcbfAAcYhJ4encbHZEIDRKVD4UXdx2aTgg
    SjZcbox6RDhV5l3d3Hx+RE3kXorMPHrWREbqPHQ8gGrW/ThS6mR0eD8jJABgb
    zR6+0bZOGNzd3t4AfkEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc
    2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2
    VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==}]

set icon_installed [image create photo -data {
    R0lGODlhEAAQAIIAAPwCBMT+xATCBASCBARCBAQCBEQCBAAAACH5BAEAAAAAL
    AAAAAAQABAAAAM2CLrc/itAF8RkdVyVye4FpzUgJwijORCGUhDDOZbLG6Nd2x
    jwibIQ2y80sRGIl4IBuWk6Af4EACH+aENyZWF0ZWQgYnkgQk1QVG9HSUYgUHJ
    vIHZlcnNpb24gMi41DQqpIERldmVsQ29yIDE5OTcsMTk5OC4gQWxsIHJpZ2h0
    cyByZXNlcnZlZC4NCmh0dHA6Ly93d3cuZGV2ZWxjb3IuY29tADs=}]

set icon_folder [image create photo -data {
    R0lGODlhEAAQAIMAAPwCBASCBMyaBPzynPz6nJxmBPzunPz2nPz+nPzSBPzqn
    PzmnPzinPzenAAAAAAAACH5BAEAAAAALAAAAAAQABAAAARTEMhJq724hp1n8M
    DXeaJgYtsnDANhvkJRCcZxEEiOJDIlKLWDbtebCBaGGmwZEzCQKxxCSgQ4Gb/
    BbciTCBpOoFbX9X6fChYhUZYU3vB4cXTxRwAAIf5oQ3JlYXRlZCBieSBCTVBU
    b0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRGV2ZWxDb3IgMTk5NywxOTk4LiBBb
    GwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDovL3d3dy5kZXZlbGNvci5jb20AOw==}]

set icon_install [image create photo -data {R0lGODlhEAAQAIUAAPwCB
    AxKdBRSfCyGvFSm1BxKfCSWzCyWzBRCXCRKfBwuRAQGDDw6PHy23Cym1CSSxB
    yCxBxunBQSFKyurMTCxExihNza3NTW1JSSlMzKzFxaXLS2tNze3KSipCQmJGx
    mbNTS1KSepLy2vISGhJSWlHx+fERGRPz6/IyKjDw+POzq7JyenMzOzKSmpCwu
    LDQyNIyOjAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
    AAAAAAAACH5BAEAAAAALAAAAAAQABAAAAaeQIBwGBAIAsOkUjAgFJRQQMHgjC
    4PBIEVgAh4D4aEYrGAMhINxwPyiCgYSsmEUmk82grLRZJkYCgXaAEKFxYZcEI
    SGhsZFxwFeY0WHR5CDB8dGCAXG5shGxQicBIMpSMUGxgTGSQlpQwSJicnEwwd
    I7gdKAwTsykpKiobr8QMKxeHDBcsGRvOzxsT0i0uL9HSHdkT2ZkoMJXF4a8Af
    kEAIf5oQ3JlYXRlZCBieSBCTVBUb0dJRiBQcm8gdmVyc2lvbiAyLjUNCqkgRG
    V2ZWxDb3IgMTk5NywxOTk4LiBBbGwgcmlnaHRzIHJlc2VydmVkLg0KaHR0cDo
    vL3d3dy5kZXZlbGNvci5jb20AOw==}]

set icon_remove [image create photo -data {
    R0lGODlhEAAQAIIAAASC/PwCBMQCBEQCBIQCBAAAAAAAAAAAACH5BAEAAAAAL
    AAAAAAQABAAAAMuCLrc/hCGFyYLQjQsquLDQ2ScEEJjZkYfyQKlJa2j7AQnMM
    7NfucLze1FLD78CQAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9
    uIDIuNQ0KqSBEZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2
    ZWQuDQpodHRwOi8vd3d3LmRldmVsY29yLmNvbQA7}]

set icon_pkg [image create photo -data {
    R0lGODlhEAAQAIIAAPwCBAQCBPz+xERCBMTCBISCBDQyNAAAACH5BAEAAAAA
    LAAAAAAQABAAAANPCLoR+7AJ0SALYkxd79za12FgOTlAQBDhRxUFqrKEG8Py
    OqwEfMeKwGDI8zVGul0vFsAFdaxB43ecKZfUKm1lZD6ERZgBZWn0OpYvGeJP
    AAAh/mhDcmVhdGVkIGJ5IEJNUFRvR0lGIFBybyB2ZXJzaW9uIDIuNQ0KqSBE
    ZXZlbENvciAxOTk3LDE5OTguIEFsbCByaWdodHMgcmVzZXJ2ZWQuDQpodHRw
    Oi8vd3d3LmRldmVsY29yLmNvbQA7}]

variable GUI yes

#-----------------------------------------------
# command args
#-----------------------------------------------
proc showHelp {} {
    puts "Usage: $::argv0 options..."
    puts "--reset\t\t\tReset config file"
    puts "--configure\t\tShow configure dialog"
}
variable loadCfg yes
variable firstRun no

for {set i 0} {$i < $::argc} {incr i} {
    switch [lindex $::argv $i] {
        --reset {set loadCfg no}
        --configure {set firstRun yes}
        --help {
            showHelp
            exit
        }
        default {
            puts "$::argv0: invalid option [lindex $::argv $i]"
            showHelp
            exit 1
        }
    }
}

# load core lib
source [file join $rootdir celpkg-core.tcl]

set ::uilog::striptbl 0

#------------------------------------------------------------------------
# tooltip
# see http://wiki.tcl.tk/1954
#------------------------------------------------------------------------
 proc setTooltip {widget text} {
        if { $text != "" } {
                # 2) Adjusted timings and added key and button bindings. These seem to
                # make artifacts tolerably rare.
                bind $widget <Any-Enter>    [list after 500 [list showTooltip %W $text]]
                bind $widget <Any-Leave>    [list after 500 [list destroy %W.tooltip]]
                bind $widget <Any-KeyPress> [list after 500 [list destroy %W.tooltip]]
                bind $widget <Any-Button>   [list after 500 [list destroy %W.tooltip]]
        }
 }
 proc showTooltip {widget text} {
        global tcl_platform
        if { [string match $widget* [winfo containing  [winfo pointerx .] [winfo pointery .]] ] == 0  } {
                return
        }

        catch { destroy $widget.tooltip }

        set scrh [winfo screenheight $widget]    ; # 1) flashing window fix
        set scrw [winfo screenwidth $widget]     ; # 1) flashing window fix
        set tooltip [toplevel $widget.tooltip -bd 1 -bg black]
        wm geometry $tooltip +$scrh+$scrw        ; # 1) flashing window fix
        wm overrideredirect $tooltip 1

        if {$tcl_platform(platform) == {windows}} { ; # 3) wm attributes...
                wm attributes $tooltip -topmost 1   ; # 3) assumes...
        }                                           ; # 3) Windows
        pack [label $tooltip.label -bg lightyellow -fg black -text $text -justify left]

        set width [winfo reqwidth $tooltip.label]
        set height [winfo reqheight $tooltip.label]

        set pointer_below_midline [expr [winfo pointery .] > [expr [winfo screenheight .] / 2.0]]                ; # b.) Is the pointer in the bottom half of the screen?

        set positionX [expr [winfo pointerx .] - round($width / 2.0)]    ; # c.) Tooltip is centred horizontally on pointer.
        set positionY [expr [winfo pointery .] + 35 * ($pointer_below_midline * -2 + 1) - round($height / 2.0)]  ; # b.) Tooltip is displayed above or below depending on pointer Y position.

        # a.) Ad-hockery: Set positionX so the entire tooltip widget will be displayed.
        # c.) Simplified slightly and modified to handle horizontally-centred tooltips and the left screen edge.
        if  {[expr $positionX + $width] > [winfo screenwidth .]} {
                set positionX [expr [winfo screenwidth .] - $width]
        } elseif {$positionX < 0} {
                set positionX 0
        }

        wm geometry $tooltip [join  "$width x $height + $positionX + $positionY" {}]
        raise $tooltip

        # 2) Kludge: defeat rare artifact by passing mouse over a tooltip to destroy it.
        bind $widget.tooltip <Any-Enter> {destroy %W}
        bind $widget.tooltip <Any-Leave> {destroy %W}
 }

#------------------------------------------------------------------------

# add to tree item with spec. category
proc ::uipkg::tree-add {t category item} {
    global icon_pkg icon_folder
    set parentcat root
    # build tree for item
    set subcateg [split $category "/"];
    foreach c $subcateg {
        append categ $c
        append categ "/"
        if {[$t exists $categ] == 0} {
            $t insert end $parentcat $categ \
                -text $c -image $icon_folder
        }
        set parentcat $categ
    }
    # add item
    set itemname $parentcat$item
    if {[$t exists $itemname] == 0} {
        $t insert end $parentcat $itemname -text $item -image $icon_pkg
        return $itemname
    }
}

# textToggle --
# This procedure is invoked repeatedly to invoke two commands at
# periodic intervals.  It normally reschedules itself after each
# execution but if an error occurs (e.g. because the window was
# deleted) then it doesn't reschedule itself.
#
# Arguments:
# cmd1 -        Command to execute when procedure is called.
# sleep1 -      Ms to sleep after executing cmd1 before executing cmd2.
# cmd2 -        Command to execute in the *next* invocation of this
#               procedure.
# sleep2 -      Ms to sleep after executing cmd2 before executing cmd1 again.
proc ::uipkg::textToggle {cmd1 sleep1 cmd2 sleep2} {
    catch {
        eval $cmd1
        after $sleep1 [list ::uipkg::textToggle $cmd2 $sleep2 $cmd1 $sleep1]
    }
}

# colorize and iconize tree
proc ::uipkg::beautify_tree {} {
    global pkgDB todo ::uipkg::pkgTree config
    global icon_pkg icon_installed icon_remove icon_install
    foreach it [array names pkgDB *:treenodes] {
        for {set i 0} {$i < [llength $pkgDB($it)]} {incr i} {
            set item [lindex $pkgDB($it) $i]
            set pkgname [$::uipkg::pkgTree itemcget $item -text]
            
            if {$pkgDB($pkgname:installed) == yes} {
                $::uipkg::pkgTree itemconfigure $item -fill $config(tree:installed) -image $icon_installed
            } else {
                $::uipkg::pkgTree itemconfigure $item -fill $config(tree:normal) -image $icon_pkg
            }
            if {[info exist todo($pkgname:do)]} {
                switch $todo($pkgname:do) {
                    uninstall {$::uipkg::pkgTree itemconfigure $item -fill $config(tree:uninstall) -image $icon_remove }
                    install {$::uipkg::pkgTree itemconfigure $item -fill $config(tree:install) -image $icon_install}
                }
            }
        }
    }
}

proc ::uipkg::cancel-install {pkgname} {
    global pkgDB ::uipkg::pkgTree todo ::uipkg::tableIntall config
    # remove only if pkgname exist in array
    if {[info exists pkgDB($pkgname:treenodes)]} {
        for {set i 0} {$i < [$::uipkg::tableIntall index end]} {incr i} {
            if {[$::uipkg::tableIntall cellcget $i,addon -text] eq $pkgname} {
                $::uipkg::tableIntall delete $i
            }
        }
        
        # set todo($pkgname:do) none
        # foreach it $pkgDB($pkgname:treenodes) {
        #     if {$pkgDB($pkgname:installed) == yes} {
        #       $::uipkg::pkgTree itemconfigure $it -fill $config(tree:installed)
        #     } else {
        #       $::uipkg::pkgTree itemconfigure $it -fill $config(tree:normal)
        #     }
        # }
        catch {unset todo($pkgname:do)}
        ::uipkg::beautify_tree
        ::uipkg::info-pkg-update-force
    }
}

proc ::uipkg::add-to-install {pkgname} {
    global pkgCache pkgDB ::uipkg::pkgTree todo ::uipkg::tableIntall config
    global icon_install

    ::uipkg::cancel-install ${pkgname}

    # if new version available
    if {[info exists pkgDB($pkgname:version)]} {
        # if installed than action is upgrade
        if {[info exists pkgCache($pkgname:version)]} {
            set action [mc "Upgrade"]
        } else {
            set action [mc "Install"]
        }
        set todo($pkgname:do) install 
        $::uipkg::tableIntall insert end [list $pkgname yes $action no]
        $::uipkg::tableIntall cellconfigure end,2 -background lightgreen
        # set fill color for items in addon tree 
        foreach it $pkgDB($pkgname:treenodes) {
            $::uipkg::pkgTree itemconfigure $it -fill $config(tree:install) -image $icon_install
        }
    }
}

proc ::uipkg::toggle-add-to-install {pkgname} {
    global pkgCache pkgDB ::uipkg::pkgTree todo ::uipkg::tableIntall config
    global icon_install

    # if no addon (all addons must have category)
    if {![info exists pkgDB($pkgname:category)]} {return}
    if {[string equal $pkgname ""]} {return}

    # toggle install
    # and append/remove item to todoText info list   
    if {![info exists todo($pkgname:do)]} {
        set todo($pkgname:do) "none"    
    }

    switch $todo($pkgname:do) {
        install {
            ::uipkg::cancel-install ${pkgname}
        }
        uninstall {
            ::uipkg::cancel-install ${pkgname}
        }
        none    {
            ::uipkg::add-to-install ${pkgname}
        }
    }
    # update info
    ::uipkg::info-pkg-update-force
}

# analog of ::uipkg::toggle-add-to-install but for pkgtree
proc ::uipkg::toggle-mark-for-install {args} {
    global pkgCache pkgDB ::uipkg::pkgTree todo ::uipkg::tableIntall config
    global icon_install

    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]

    ::uipkg::toggle-add-to-install $pkgname
}

proc ::uipkg::add-to-uninstall {pkgname {force yes}} {
    global ::uipkg::pkgTree ::uipkg::tableIntall 
    global pkgDB pkgCache todo config
    global icon_remove

    ::uipkg::cancel-install ${pkgname}

    if {[info exists pkgCache($pkgname:version)]} {
        set todo($pkgname:do) uninstall 
        $::uipkg::tableIntall insert end [list $pkgname "" [mc "Uninstall"] $force]
        $::uipkg::tableIntall cellconfigure end,1 -editable no 
        $::uipkg::tableIntall cellconfigure end,2 -background tomato
        # set fill color for items in addon tree 
        foreach it $pkgDB($pkgname:treenodes) {
            $::uipkg::pkgTree itemconfigure $it -fill $config(tree:uninstall) -image $icon_remove
        }
    }
}

# analog of ::uipkg::add-to-uninstall but for pkgtree
proc ::uipkg::toggle-mark-for-uninstall {} {
    global ::uipkg::pkgTree pkgDB pkgCache todo
    
    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    # if no addon (all addons must have category)
    if {![info exists pkgDB($pkgname:category)]} {return}
    if {[string equal $pkgname ""]} {return}
    # toggle install
    # and append/remove item to todoText info list   
    if {![info exists todo($pkgname:do)]} {
        set todo($pkgname:do) "none"    
    }
    switch $todo($pkgname:do) {
        uninstall {
            ::uipkg::cancel-install ${pkgname}
        }
        install {
            ::uipkg::cancel-install ${pkgname}
        }
        none    {
            # if required_by then ask for be sure
            set contDeinst 1
            if {[info exist pkgCache($pkgname:requiredby)]} {
                if {[llength $pkgCache($pkgname:requiredby)] > 0} {
                    set contDeinst 0
                    set msg "One or more addons require addon $pkgname. Are you sure to deinstall?"
                    if {[tk_messageBox -parent . -title "Uninstall?" -icon question \
                             -type yesno -default no -message $msg] == yes} {
                        set contDeinst 1
                    }
                }
            }
            if {$contDeinst} {
                ::uipkg::add-to-uninstall ${pkgname}
            }
        }
    }
    # update info
    ::uipkg::info-pkg-update-force
}

#-----------------------------------------------
# Serach problems in installed pkg 
# Mark for install addons that required by installed 
# addons
#-----------------------------------------------
proc ::uipkg::fix-pkgs {args} {
    global pkgDB pkgCache

    # check all insttaled pkgs for not installed addons
    foreach it [array names pkgCache *:name] {
        set pkgname [lindex [split $it ":"] 0]
        
        ::core::update-options $pkgname

        if {[info exists pkgDB($pkgname:depend)]} {
            foreach dep $pkgDB($pkgname:depend) {
                if {![::core::check-options $pkgname $dep]} {
                    continue }
                # mark to install not installed deps or 
                if {[info exist pkgDB($dep:installed)]} {
                    if {!$pkgDB($dep:installed)} {
                        ::uipkg::add-to-install $dep
                    }
                }
            }
        }
    }
}

#-----------------------------------------------
# Mark to install installed pkg that can be upgraded 
#-----------------------------------------------
proc ::uipkg::mark-all-upgrades {args} {
    global pkgDB pkgCache

    # check all insttaled pkgs for not installed addons
    foreach it [array names pkgCache *:name] {
        set pkgname [lindex [split $it ":"] 0]
        
        if {[info exists pkgCache($pkgname:version)] &&
            [info exists pkgDB($pkgname:version)]} {
            if {[::misc::cmpversion $pkgDB($pkgname:version) $pkgCache($pkgname:version)] == "g"} {
                ::uipkg::add-to-install $pkgname
            }
        }
    }
}

#-----------------------------------------------
# For all depends of current selected addon in pkgTree
# mark to uninstall but not force to prevent required collision.
# Check configured depends too.
#-----------------------------------------------
proc ::uipkg::mark-compete-remove {} {
    global pkgDB

    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    # if no addon (all addons must have category)
    if {[string equal $pkgname ""]} {return}
    if {![info exists pkgDB($pkgname:category)]} {return}

    ::core::update-options $pkgname
    
    if {[info exists pkgDB($pkgname:depend)]} {
        foreach depname $pkgDB($pkgname:depend) {
            if {[::core::check-options $pkgname $depname]} {
                # no force
                ::uipkg::add-to-uninstall $depname no
            }       
        }
    }
    ::uipkg::add-to-uninstall $pkgname no
}

proc ::uipkg::disable-action-buttons {} {
    global installButton uninstallButton configButton
    $uninstallButton configure -state disabled -text [mc "Uninstall"]
    $installButton configure -state disabled -text [mc "Install"]
    $configButton configure -state disabled -text [mc "Configure"]
}


#------------------------------
# add url to info text
#------------------------------
proc ::uipkg::infoText-add-url {urltag urlname cmd} {
    global config
    #make url
    $::uipkg::infoText tag bind $urltag <Any-Enter> "$::uipkg::infoText tag configure $urltag $config(text:urlbold)"
    $::uipkg::infoText tag bind $urltag <Any-Leave> "$::uipkg::infoText tag configure $urltag $config(text:urlnormal)"
    $::uipkg::infoText tag bind $urltag <1> $cmd
    # set default url state
    eval $::uipkg::infoText tag configure $urltag $config(text:urlnormal)
    $::uipkg::infoText insert end $urlname $urltag

}


#------------------------------
# Add info about addon and make url to info about him
#------------------------------
proc ::uipkg::infoText-add-urledaddon-info {urltag urlname pkgname} {
    global pkgDB todo ::uipkg::infoText config

    ::uipkg::infoText-add-url $urltag $pkgname "::uipkg::setTree-selection $::uipkg::pkgTree \
                                                 {[set node [lindex $pkgDB($pkgname:treenodes) 0]]}
                                                ::uipkg::info-pkg-update-force"

    if {[info exists todo($pkgname:do)]} {
        $::uipkg::infoText insert end " "
        if {$todo($pkgname:do) == "install"} {
            $::uipkg::infoText insert end [mc "Will be installed"] blinkgreen
        } elseif {$todo($pkgname:do) == "uninstall"} {
            $::uipkg::infoText insert end [mc "Will be uninstalled"] blinkred
        }
    }

    if $pkgDB($pkgname:installed) {
        $::uipkg::infoText insert end " "
        ::uipkg::infoText-add-url "instTag" [mc "Installed"] ::uipkg::installed-info
    }

    if {![info exists pkgDB($pkgname:version)]} {
        $::uipkg::infoText insert end " "
        $::uipkg::infoText insert end [mc " no new version available!"] blinkred
    }
}

# create url for category with sub cat.
proc ::uipkg::infoText-add-urledcategory {urltag category} {
    global pkgDB todo ::uipkg::infoText config
    set i 0
    set cat {}
    foreach c [split $category "/"] {
        set cat $cat$c
        ::uipkg::infoText-add-url $urltag:$i $c/ [list ::uipkg::category-info $cat]
        set cat $cat/
        incr i  
    }   
}

#-----------------------------
# Add to info: url to addon and
# his depends and requiries if $mode = yes
#-----------------------------
proc ::uipkg::infoText-add-described-addon { indx urltag pkgname } {
    global pkgDB pkgCache todo ::uipkg::infoText
    global config

    $::uipkg::infoText insert end "$indx: " normal
    ::uipkg::infoText-add-urledaddon-info $urltag $pkgname $pkgname

    $::uipkg::infoText insert end \n
    if {$config(moreInfo)} {
        # list depends for addon  
        if [info exists pkgDB($pkgname:depend)] {
            # update option for thus pkg if installed
            if [info exist pkgCache($pkgname:name)] {
                ::core::update-options $pkgname
            }

            $::uipkg::infoText insert end [mc "Depend on: "]\n bold
            for {set i 0} {$i < [llength $pkgDB($pkgname:depend)]} {incr i} {
                set urltag $indx:dep$i
                set depname [lindex $pkgDB($pkgname:depend) $i]

                ::uipkg::infoText-add-urledaddon-info $urltag \t\t$depname $depname
                
                # show configured info only for installed addons
                if {[info exists pkgCache($pkgname:depend)]} {
                    if {![::core::check-options $pkgname $depname]} {
                        $::uipkg::infoText insert end [mc " (Configured without this addon)"] propvalue
                    }
                }
                $::uipkg::infoText insert end \n
            }
        }
        # list of requires
        if {[info exists pkgCache($pkgname:requiredby)]} {
            $::uipkg::infoText insert end [mc "Required by:"]\n bold
            for {set i 0} {$i < [llength $pkgCache($pkgname:requiredby)]} {incr i} {
                set urltag $indx:req$i
                set reqname [lindex $pkgCache($pkgname:requiredby) $i]

                ::uipkg::infoText-add-urledaddon-info $urltag $reqname $reqname
                
                $::uipkg::infoText insert end \n propvalue
            }
        }
    }
}

# create url for date list of creating or last modified of addon.
proc ::uipkg::infoText-add-date-url {urltag date create_modif} {
    global  ::uipkg::infoText
    set i 0
    set cat {}
    set sdate [split $date "/- "]
    set yy [lindex $sdate 0]
    set mm [lindex $sdate 1]
    set dd [lindex $sdate 2]
    if {$create_modif == "created"} {
        set create_modif yes
    } else {
        set create_modif no
    }
        
    ::uipkg::infoText-add-url $urltag:y $yy [list ::uipkg::infoText-add-date-info $create_modif $yy]
    $::uipkg::infoText insert end "-" propvalue
    ::uipkg::infoText-add-url $urltag:m $mm [list ::uipkg::infoText-add-date-info $create_modif $yy $mm]
    $::uipkg::infoText insert end "-" propvalue
    ::uipkg::infoText-add-url $urltag:d $dd [list ::uipkg::infoText-add-date-info $create_modif $yy $mm $dd]
}

#-----------------------------
# info about addon modified or
# created in spec. date
#-----------------------------
proc ::uipkg::infoText-add-date-info {create_modif yy {mm ??} {dd ??}} {
    global ::uipkg::infoText pkgDB pkgCache

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end

    ::uipkg::disable-action-buttons

    set crt_mod "modified"
    if $create_modif {
        set crt_mod "created"
        $::uipkg::infoText insert end [mc "Addons list that created in "]$yy-$mm-$dd\n tittle
    } else {
        $::uipkg::infoText insert end [mc "Addons list that last midified in "]$yy-$mm-$dd\n tittle
    }
    set indx 1
    # for all addon
    foreach a [array names pkgDB *:installed] {
        set pkgname [lindex [split $a ":"] 0]
        set match no        
        if [info exist pkgDB($pkgname:$crt_mod)] {
            if [string match "$yy?$mm?$dd" $pkgDB($pkgname:$crt_mod)] {
                set match yes
            }
        }
        if {!$match && [info exist pkgCache($pkgname:$crt_mod)]} {
            if [string match "$yy?$mm?$dd" $pkgCache($pkgname:$crt_mod)] {
                set match yes
            }
        }
        if $match {
            ::uipkg::infoText-add-described-addon $indx t:$indx $pkgname
            incr indx
        }
    }
    $::uipkg::infoText configure -state disabled
}

#-----------------------------------------------
# Set to infotext all installed or not installed
# addon
#-----------------------------------------------
proc ::uipkg::installed-info {{showInstalled yes}} {
    global pkgDB pkgCache todo ::uipkg::infoText config
    ::uipkg::disable-action-buttons

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end
    if $showInstalled {
        $::uipkg::infoText insert end [mc "List of installed addons"]\n tittle
    } else {
        $::uipkg::infoText insert end [mc "List of not installed addons"]\n tittle
    }

    set indx 1
    set addlist {}
    foreach a [array names pkgDB *:installed] {
        if {$pkgDB($a) == $showInstalled} {
            set urltag t$indx
            set pkgname [lindex [split $a ":"] 0]
            ::uipkg::infoText-add-described-addon $indx $urltag $pkgname

            incr indx
        }
    }
    $::uipkg::infoText insert end \n
    if $showInstalled {
        ::uipkg::infoText-add-url "showinstall" [mc "Click here to see not installed addons\n"] "::uipkg::installed-info no"
    } else {
        ::uipkg::infoText-add-url "showinstall" [mc "Click here to see installed addons\n"] "::uipkg::installed-info yes"
    }
    $::uipkg::infoText configure -state disabled
}

#-----------------------------------------------
# Set to infotext addons of category
#-----------------------------------------------
proc ::uipkg::category-info {category} {
    global ::uipkg::infoText config ::uipkg::pkgTree pkgDB

    # find in tree category item and display all sub categories
    proc ::uipkg::infoText-add-recursive-subcat { tree catlist category index} {
        global pkgDB

        foreach node [$tree nodes $category/] { 
            if {[llength [$tree nodes $node]]>0} {
                regexp {^(.*)/$} $node -> node
                ::uipkg::infoText-add-urledcategory c$index:s $node
                incr index
                $::uipkg::infoText insert end \n                
                # recursive sub cat
                set index [::uipkg::infoText-add-recursive-subcat \
                               $tree $catlist $node $index]
            }       
        }
        return $index
    }

    ::uipkg::disable-action-buttons

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end

    set index 1
    set node $category
    set catlist [array names pkgDB *:category]

    $::uipkg::infoText insert end [mc "Addons of category "]\"$category\"\n tittle

    foreach c $catlist {
        if [in $pkgDB($c) $category] {
            set urltag t$index
            set pkgname [lindex [split $c ":"] 0]
            ::uipkg::infoText-add-described-addon $index $urltag $pkgname
            incr index
        }
    }

    $::uipkg::infoText insert end \n[mc "Other subcategories of category "] normal
    ::uipkg::infoText-add-urledcategory other $category
    $::uipkg::infoText insert end :\n normal

    ::uipkg::infoText-add-recursive-subcat $::uipkg::pkgTree $catlist $category $index
    
    $::uipkg::infoText configure -state disabled
}

proc ::uipkg::user-info {user} {
    global userDB ::uipkg::infoText

    ::uipkg::disable-action-buttons

    $::uipkg::infoText insert end [mc "Information about "]$user\n tittle

    if [info exist userDB($user)] {
        foreach txt [getNamedVar $userDB($user) -info] {
            $::uipkg::infoText insert end $txt\n descript
        }
        $::uipkg::infoText insert end \n

        set indx 0
        set urls [getNamedVar $userDB($user) -www]
        if {[llength $urls] > 0} {
            $::uipkg::infoText insert end "www: " propname
            foreach url $urls {
                $::uipkg::infoText insert end \n
                ::uipkg::infoText-add-url w$indx $url [list ::misc::browseurl $url]
                incr indx
            }
        }
        $::uipkg::infoText insert end \n
        set emails [getNamedVar $userDB($user) -mail]
        if {[llength $emails] > 0} {
            $::uipkg::infoText insert end "e-mail: " propname
            foreach email $emails {
                # TODO: instead of browse mail need call e-client 
                $::uipkg::infoText insert end \n
                ::uipkg::infoText-add-url w$indx $email [list ::misc::browseurl $email]
                incr indx
            }
            $::uipkg::infoText insert end \n
        }
    }
}

proc ::uipkg::author-info {author} {
    global pkgDB ::uipkg::infoText config

    ::uipkg::disable-action-buttons

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end
    $::uipkg::infoText insert end [mc "Addons created by "]$author\n tittle

    set i 1
    foreach c [array names pkgDB *:author] {
        if [in $pkgDB($c) $author] {
            set urltag t$i
            set pkgname [lindex [split $c ":"] 0]
            $::uipkg::infoText insert end "$i: " normal

            ::uipkg::infoText-add-urledaddon-info $urltag $pkgname $pkgname

            incr i
            $::uipkg::infoText insert end \n
        }
    }
    ::uipkg::user-info $author

    $::uipkg::infoText configure -state disabled
}

proc ::uipkg::maintainer-info {maintainer} {
    global pkgDB ::uipkg::infoText config

    ::uipkg::disable-action-buttons

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end
    $::uipkg::infoText insert end [mc "Addons maintained by "]$maintainer\n tittle

    set i 1
    foreach c [array names pkgDB *:maintainer] {
        if [in $pkgDB($c) $maintainer] {
            set urltag t$i
            set pkgname [lindex [split $c ":"] 0]
            $::uipkg::infoText insert end "$i: " normal

            ::uipkg::infoText-add-urledaddon-info $urltag $pkgname $pkgname

            incr i
            $::uipkg::infoText insert end \n
        }
    }
    ::uipkg::user-info $maintainer

    $::uipkg::infoText configure -state disabled
}

#-----------------------------------------------
# Show info about current selected addon in pkgtree
# Manage action buttons
#-----------------------------------------------
proc ::uipkg::info-pkg-update {args} {
    global ::uipkg::pkgTree ::uipkg::infoText todo config currentView
    global installButton uninstallButton configButton 
    global pkgCache pkgDB dbpath
    global txt_canelinstall txt_install txt_uninstall txt_upgrade txt_caneluninstall

    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    if {[string equal $currentView $pkgname]} {
	$::uipkg::infoText yview scroll 1 units
	return
    }
    set currentView $pkgname

    $::uipkg::infoText configure -state normal
    $::uipkg::infoText delete 1.0  end
    $::uipkg::infoText configure -state disabled
    $uninstallButton configure -state disabled -text [mc "Uninstall"]
    $installButton configure -state disabled -text [mc "Install"]
    $configButton configure -state disabled -text [mc "Configure"]
    # if no pkg found that it is category, so display category info
    if {![info exists pkgDB($pkgname:category)]} {
        set cat $pkgname
        set node [lindex [$::uipkg::pkgTree selection get] 0]
        while {[$::uipkg::pkgTree parent $node] != "root"} {
            set node [$::uipkg::pkgTree parent $node]
            set cat [$::uipkg::pkgTree itemcget [lindex $node 0] -text]/$cat
        }
        ::uipkg::category-info $cat
        return
    }

    if {[info exists pkgDB($pkgname:options)] || [info exists pkgDB($pkgname:choice)]} {
        if {[file exists [file join $dbpath $pkgname options]]} {
            $configButton configure -state normal -text [mc "Reconfigure"]
        } else {
            $configButton configure -state normal -text [mc "Configure"]
        }
    }
    if {[string equal $pkgname ""]} {return}

    $::uipkg::infoText configure -state normal

    # set text upgrade instead of install and enable uninstall if pkg installed
    if {$pkgDB($pkgname:installed) == "yes"} {
        $installButton configure -text [mc "Upgrade"]
        $uninstallButton configure -state normal
    }
    if {[info exists pkgDB($pkgname:version)]} {
        $installButton configure -state normal
    }

    if $pkgDB($pkgname:installed) {
        ::uipkg::infoText-add-url showinstall [mc "Intsalled"] "::uipkg::installed-info yes"
    } else {
        ::uipkg::infoText-add-url shownotinstall [mc "Not intsalled"] "::uipkg::installed-info no"
    }
    $::uipkg::infoText insert end " "


    if {[info exists todo($pkgname:do)]} {
        if {$todo($pkgname:do) == "install"} {
            $::uipkg::infoText insert end [mc "Will be installed"] blinkgreen
            $installButton configure -text [mc "Cancel Install"] 
        } elseif {$todo($pkgname:do) == "uninstall"} {
            $::uipkg::infoText insert end [mc "Will be uninstalled"] blinkred
            $uninstallButton configure -text [mc "Cancell uninstall"] 
        }

        $::uipkg::infoText insert end \n
    } else {
        $::uipkg::infoText insert end \n }

    $::uipkg::infoText insert end [mc "category: "] category
    for {set i 0} {$i < [llength $pkgDB($pkgname:category)]} {incr i} {
        set cat [lindex $pkgDB($pkgname:category) $i]
#       ::uipkg::infoText-add-url t$i $cat [list ::uipkg::category-info $cat]
        ::uipkg::infoText-add-urledcategory c$i $cat
        $::uipkg::infoText insert end " "
    }
    $::uipkg::infoText insert end \n

    if {[info exists pkgDB($pkgname:modified)]} {
        $::uipkg::infoText insert end [mc "modified: "] category
        ::uipkg::infoText-add-date-url mod1 $pkgDB($pkgname:modified) modified
    }
    if {[info exists pkgCache($pkgname:modified)]} {
        $::uipkg::infoText insert end [mc " intalled modified: "] category
        ::uipkg::infoText-add-date-url mod2 $pkgCache($pkgname:modified) modified
    }
    $::uipkg::infoText insert end \n

    if {[info exists pkgDB($pkgname:created)]} {
        $::uipkg::infoText insert end [mc "created: "] category
        ::uipkg::infoText-add-date-url crt1 $pkgDB($pkgname:created) created
    } elseif {[info exists pkgCache($pkgname:created)]} {
        $::uipkg::infoText insert end [mc " created: "] category
        $::uipkg::infoText insert end $pkgCache($pkgname:created) category
        ::uipkg::infoText-add-date-url crt2 $pkgCache($pkgname:created) created
    }
    $::uipkg::infoText insert end \n

    if {[info exists pkgDB($pkgname:version)]} {
        $::uipkg::infoText insert end [mc "version: "] category
        $::uipkg::infoText insert end $pkgDB($pkgname:version) category
    }
    if {[info exists pkgCache($pkgname:version)]} {
        $::uipkg::infoText insert end [mc " intalled version: "] category
        # blink if version is older
        if {[info exists pkgDB($pkgname:version)]} {
            if {[::misc::cmpversion $pkgDB($pkgname:version) $pkgCache($pkgname:version)] == "g"} {
                $::uipkg::infoText insert end $pkgCache($pkgname:version) blinkred
            } else {
                $::uipkg::infoText insert end $pkgCache($pkgname:version) category
            }
        } else { 
            # addon not presented in any index
            # maybe custom installed so not possible to reinstall affter uninstall
            $::uipkg::infoText insert end $pkgCache($pkgname:version) category
            $::uipkg::infoText insert end [mc " no new version available!"] blinkred
        }
    } 
    $::uipkg::infoText insert end \n

    # maintainer and author
    if [info exist pkgDB($pkgname:maintainer)] {
        $::uipkg::infoText insert end [mc "maintainer: "] category
        for {set i 0} {$i < [llength $pkgDB($pkgname:maintainer)]} {incr i} {
            set com [lindex $pkgDB($pkgname:maintainer) $i]
            ::uipkg::infoText-add-url com$i $com [list ::uipkg::maintainer-info $com]
            $::uipkg::infoText insert end " "
        }
    }
    $::uipkg::infoText insert end \n
    if [info exist pkgDB($pkgname:author)] {
        $::uipkg::infoText insert end [mc "author: "] category
        for {set i 0} {$i < [llength $pkgDB($pkgname:author)]} {incr i} {
            set aut [lindex $pkgDB($pkgname:author) $i]
            ::uipkg::infoText-add-url aut$i $aut [list ::uipkg::author-info $aut]
            $::uipkg::infoText insert end " "
        }
    }
    $::uipkg::infoText insert end \n

    $::uipkg::infoText insert end $pkgname tittle
    $::uipkg::infoText insert end \n

    # show available description of addon
    if {[info exists pkgDB($pkgname:description)]} {
        foreach descr $pkgDB($pkgname:description) {
            $::uipkg::infoText insert end $descr\n descript
        }
        $::uipkg::infoText insert end \n
    } else {
        if {[info exists pkgCache($pkgname:description)]} {
            foreach descr $pkgCache($pkgname:description) {
                $::uipkg::infoText insert end $descr\n descript
            }
            $::uipkg::infoText insert end \n
        }
    }

    if {[info exists pkgDB($pkgname:www)]} {
        $::uipkg::infoText insert end [mc "WWW:"] propname
        for {set i 0} {$i < [llength $pkgDB($pkgname:www)]} {incr i} {
            $::uipkg::infoText insert end \n propvalue
            # browsable url
            set urltag [lindex $pkgDB($pkgname:www) $i]
            set url [lindex $pkgDB($pkgname:www) $i]
            ::uipkg::infoText-add-url $urltag $url [list ::misc::browseurl $url]
        }
        $::uipkg::infoText insert end \n\n
    } else {
	if {[info exists pkgCache($pkgname:www)]} {
	    $::uipkg::infoText insert end [mc "WWW:"] propname
	    for {set i 0} {$i < [llength $pkgCache($pkgname:www)]} {incr i} {
		$::uipkg::infoText insert end \n propvalue
		# browsable url
		set urltag [lindex $pkgCache($pkgname:www) $i]
		set url [lindex $pkgCache($pkgname:www) $i]
		::uipkg::infoText-add-url $urltag $url [list ::misc::browseurl $url]
	    }
	    $::uipkg::infoText insert end \n\n
	}
    }

    set license {}
    if {[info exists pkgDB($pkgname:license)]} {
	set license $pkgDB($pkgname:license)
    } else {
	if {[info exists pkgCache($pkgname:license)]} {
	    set license $pkgCache($pkgname:license)
	} else {
	set license "unknown"}
    }
    $::uipkg::infoText insert end [mc "License:"] propname
    $::uipkg::infoText insert end " $license\n\n" propvalue

    if {[info exists pkgDB($pkgname:screenshot)]} {
        $::uipkg::infoText insert end [mc "Screenshots:"] propname
        for {set i 0} {$i < [llength $pkgDB($pkgname:screenshot)]} {incr i} {
            $::uipkg::infoText insert end \n propvalue
            #make url
            set urltag [lindex $pkgDB($pkgname:screenshot) $i]
            set url [lindex $pkgDB($pkgname:screenshot) $i]
            ::uipkg::infoText-add-url $urltag [file tail $url] [list ::misc::browseurl $url]
        }
        $::uipkg::infoText insert end \n\n propvalue
    }

    # if addon installed than take info about dependencies from pkgCache
    set dependHash "pkgDB"
    if $pkgDB($pkgname:installed) {
        set dependHash "pkgCache"
    }
    eval [list
          if {[info exists ${dependHash}($pkgname:depend)]} {
              $::uipkg::infoText insert end [mc "Depend on:"]\n propname
              
              # update option for thus pkg if installed
              if [info exist ${dependHash}($pkgname:name)] {
                  ::core::update-options $pkgname
              }
              set deplist [eval "set ${dependHash}(\$pkgname:depend)"]
              for {set i 0} {$i < [llength $deplist]} {incr i} {
                  set urltag dependon$i
                  set depname [lindex $deplist $i]
                  ::uipkg::infoText-add-urledaddon-info $urltag $depname $depname
                  # show configured info only for installed addons
                  if {![::core::check-options $pkgname $depname] && [eval "set ${dependHash}(\$pkgname:installed)"]} {
                      $::uipkg::infoText insert end [mc " (Configured without this addon)"] propvalue
                  }
                  $::uipkg::infoText insert end \n propvalue
              }
              $::uipkg::infoText insert end \n propvalue
          }
         ]

    if {[info exists pkgCache($pkgname:requiredby)]} {
        $::uipkg::infoText insert end [mc "Required by:"]\n propname
        for {set i 0} {$i < [llength $pkgCache($pkgname:requiredby)]} {incr i} {
            set urltag required$i
            set reqname [lindex $pkgCache($pkgname:requiredby) $i]

            ::uipkg::infoText-add-urledaddon-info $urltag $reqname $reqname

            $::uipkg::infoText insert end \n propvalue
        }
    }
    
    # next params show only if moreinfo is on
    if {$config(moreInfo)} {
	if {[info exists pkgDB($pkgname:distfile)]} {
	    $::uipkg::infoText insert end [mc "Distribute files:"] propname
	    $::uipkg::infoText insert end \n propvalue
	    for {set i 0} {$i < [llength $pkgDB($pkgname:distfile)]} {incr i} {
		$::uipkg::infoText insert end [getNamedVar [lindex $pkgDB($pkgname:distfile) $i] -name] propbold

		# Take size and insert commas every 3 positions
		set size [getNamedVar [lindex $pkgDB($pkgname:distfile) $i] -size]
		while {[regsub {^([-+]?\d+)(\d\d\d)} $size "\\1,\\2" size]} {}
		$::uipkg::infoText insert end "\t$size bytes\n" propvalue

		foreach prop "md5 sha256 sha1" {
		    set pval [getNamedVar [lindex $pkgDB($pkgname:distfile) $i] -$prop]
		    if {$pval != ""} {
			$::uipkg::infoText insert end " \t$prop: " propbold
			$::uipkg::infoText insert end $pval\n propvalue
		    }
		}
		set urls [getNamedVar [lindex $pkgDB($pkgname:distfile) $i] -url]
		for {set j 0} {$j < [llength $urls]} {incr j} {
		    # make url
		    set url [lindex $urls $j]
		    set urltag dist:$i:$j
		    
		    ::uipkg::infoText-add-url $urltag $url [list ::misc::browseurl $url]
		    $::uipkg::infoText insert end \n
		}
	    }
	}
    }
    set conflictwith [::core::get-conflicted-addons $pkgname]
    if {$conflictwith != ""} {
	$::uipkg::infoText insert end \n propvalue
	$::uipkg::infoText insert end [mc "Conflict with:"]\n propname
        set i 0
        foreach addonname $conflictwith {
            set urltag con$i
            ::uipkg::infoText-add-urledaddon-info $urltag $addonname $addonname
            $::uipkg::infoText insert end \n propvalue
            incr i
        }
    }

    $::uipkg::infoText configure -state disabled
}

# Dont scroll text view, just recreate
proc ::uipkg::info-pkg-update-force {} {
    global currentView
    set currentView {}
    ::uipkg::info-pkg-update
}

#-----------------------------------------------
# Do installation & deinstalls
# Some widgets will be disabled 
#-----------------------------------------------


#------------------------------
# Show configure dialog for addon.
# At begin options are loaded from file db/$pkgname/options.
# Index file format:
# checkbox
#   $options {varname defaultVal descriptionText}
# combo box
#   $choice {varname defaultVal descriptionText {list of items}}
#------------------------------
proc ::uipkg::configure-pkg {pkgname} {
    global pkgDB opt dbpath
    variable ::tk::Priv
    variable optfr 
    set focus [focus]
    set grab [grab current .]
    set w .cfgPkgDialog
    catch {destroy $w}
    set focus [focus]
    set grab [grab current .]
    set title "[mc {Configure for:} ] $pkgname"
    set optfile [file normalize [file join $dbpath $pkgname options]]
    # clear old opt
    catch {unset opt}

    # load from opt file first
    set isLoaded [::core::load-options $pkgname]

    if {![info exists pkgDB($pkgname:options)] &&
        ![info exists pkgDB($pkgname:choice)]} {
        return
    }
    
    proc ::uipkg::reset {optfr pkgname} {
        global pkgDB opt
        # reset choice
        if {[info exists pkgDB($pkgname:choice)]} {
            foreach o $pkgDB($pkgname:choice) {
                set combo $optfr.[lindex $o 0].c
                # search index
                set i [lsearch [lindex $o 3] [lindex $o 1]]
                if {$i >= 0} {
                    $combo setvalue @$i
                }
            }
        }
        #reset options
        if {[info exists pkgDB($pkgname:options)]} {
            foreach o $pkgDB($pkgname:options) {
                set opt([lindex $o 0]) [lindex $o 1]
            }
        }
    }
    ::misc::sleep 1
    toplevel $w -bd 1 -relief raised -class TkSDialog
    wm title $w $title
    wm iconname $w $title
    wm protocol $w WM_DELETE_WINDOW {set ::tk::Priv(button) 0}
    wm transient $w [winfo toplevel [winfo parent $w]]

    pack [label $w.l -text "[mc Addon: ] $pkgname"] -fill both -expand 1
    pack [set optfr [frame $w.optf]] -fill both -expand 1
    pack [set buttonfr [frame $w.butf]] -fill x -side bottom

    pack [ button $buttonfr.ok -text [mc "Ok"] -command {set ::tk::Priv(button) 1}] \
        [ button $buttonfr.reset -text [mc "Reset"] -command [list ::uipkg::reset $optfr $pkgname]] \
        [ button $buttonfr.cancel -bd 1 -text [mc "Cancel"] -command {set ::tk::Priv(button) 0}] \
        -fill x -side left -expand 1

    # put choice in cfg dial
    if {[info exists pkgDB($pkgname:choice)]} {
        foreach o $pkgDB($pkgname:choice) {
            pack [set frame [labelframe $optfr.[lindex $o 0] -text [lindex $o 2]]]\
                -anchor w 
            pack [set c [ComboBox $frame.c -editable no]] -anchor w
            foreach v [lindex $o 3] {
                $c insert end $v
            }
            # set value from loaded opt file
            if {[info exists opt([lindex $o 0])]} {
                set i [lsearch [lindex $o 3] $opt([lindex $o 0])]
                if {$i >= 0} {
                    $frame.c setvalue @$i
                }
            }
        }
    }

    # put options (check boxs) in cfg dialog
    if {[info exists pkgDB($pkgname:options)]} {
        foreach o $pkgDB($pkgname:options) {
            if {![info exist opt([lindex $o 0])]} {
                set opt([lindex $o 0]) [lindex $o 1]
            }
            pack [checkbutton $optfr.[lindex $o 0] -text [lindex $o 2] \
                      -offvalue "no" -onvalue "yes" -variable opt([lindex $o 0]) ] -anchor w
        }
    }

    if {!$isLoaded} {
        ::uipkg::reset $optfr $pkgname
    }

#    bind $w <Return> {set ::tk::Priv(button) 1}
    bind $w <Destroy> {set ::tk::Priv(button) 0}
    bind $w <Escape> {set ::tk::Priv(button) 0}

    wm withdraw $w
    update idletasks
    set x [expr {[winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 - [winfo vrootx $w]}]
    set y [expr {[winfo screenheight $w]/2 - [winfo reqheight $w]/2 - [winfo vrooty $w]}]
    wm geom $w +$x+$y
    wm deiconify $w
    grab $w

    tkwait variable ::tk::Priv(button)
    bind $w <Destroy> {}

    # cancel or esc dial then reset and load again from cfg
    if {!$::tk::Priv(button)} {
        # apply default
        ::uipkg::reset $optfr $pkgname

        # load saved from file
        ::core::load-options $pkgname

        # set choice (combobox). -textvariable not bind in ComboBox?
        if {[info exists pkgDB($pkgname:choice)]} {
            foreach o $pkgDB($pkgname:choice) {
                foreach v [lindex $o 3] {
                    $c insert end $v
                }
                # set value from loaded opt file
                if {[info exists opt([lindex $o 0])]} {
                    set i [lsearch [lindex $o 3] $opt([lindex $o 0])]
                    if {$i >= 0} {
                        $optfr.[lindex $o 0].c setvalue @$i
                    }
                }
            }
        }
    }

    # save to file
    file mkdir [file join $dbpath $pkgname]
    set fh [open $optfile "w"]
    fconfigure $fh -encoding utf-8

    puts $fh "# -*-coding: utf-8 -*-"
    if {[info exists pkgDB($pkgname:choice)]} {
        foreach o $pkgDB($pkgname:choice) {
            set combo $optfr.[lindex $o 0].c
            # search index
            set i [$combo getvalue]
            puts $fh "choice: [lindex $o 0] {[lindex [lindex $o 3] $i]}"
        }
    }
    if {[info exists pkgDB($pkgname:options)]} {
        foreach o $pkgDB($pkgname:options) {
            set optname [lindex $o 0]
            puts $fh "options: $optname $opt($optname)"
        }
    }

    close $fh

    # update again
    ::core::load-options pkgname

    grab release $w
    destroy $w
    focus -force $focus
    if {$grab != ""} {grab $grab}
    update idletasks
}

#------------------------------
# do all task
#------------------------------
proc ::uipkg::proceed-todo {} {
    global todo installButton uninstallButton proceedButton ::uipkg::pkgTree nb
    global pkgCache pkgDB sesInstalled
    # array of install status and error description
    global todoStatus

    # clear todoStatus
    catch {unset todoStatus}

    ::uilog::clearlog
    $nb raise nb_log
    $nb itemconfigure nb_pkg -state disabled

    # fetch from table recursive and force params for all todo
    foreach it [array names todo *:do] {
        if {$todo($it) != "none"} {
            set pkgname [lindex [split $it ":"] 0]
            for {set i 0} {$i < [$::uipkg::tableIntall index end]} {incr i} {
                if {[$::uipkg::tableIntall cellcget $i,addon -text] eq $pkgname} {
                    set todo($pkgname:recursive) \
                        [$::uipkg::tableIntall cellcget $i,recursive -text]
                    set todo($pkgname:force) \
                        [$::uipkg::tableIntall cellcget $i,force -text]
                    break 
                }
            }
        }
    }

    # uninstall
    set addons {}
    foreach it [array names todo *:do] {
        if {$todo($it) == "uninstall"} {
            set pkgname [lindex [split $it ":"] 0]
            lappend addons $pkgname
        }
    }

    if [llength $addons] {
	::uilog::log [list [mc "Next addons will be uninstalled:\n"] tittle]
	foreach a $addons {
            ::uilog::log [list $a\n table]
	}
    }

    # sort addon that must be uninstall
    # uninstall dependencies _first_
    set sorted_addons {}
    foreach a $addons {
        if [info exist pkgCache($a:requiredby)] {
            foreach reqby $pkgCache($a:requiredby) {
                if [in $addons $reqby] {
                    set sorted_addons [ linsert $sorted_addons 0 $reqby ]
                }
            }
        }
        lappend sorted_addons $a
    }
    set sorted_addons [::misc::lrmdups $sorted_addons]
    # uninstall sorted now
    foreach pkgname $sorted_addons {
        if {$todo($pkgname:do) == "uninstall"} {
            ::misc::sleep 1000
            ::core::proceed-uninstall $pkgname $todo($pkgname:force)
        }
    }

    # First upgrade, than install not installed yet pkg, 
    # also skip addon that have been installed as dependencies
    # i.e. that are not in sesInstalled list
    set pkgInstall {}
    # clear installed list
    set sesInstalled {}
    foreach it [array names todo *:do] {
        if {$todo($it) == "install"} {
            set pkgname [lindex [split $it ":"] 0]
            lappend pkgInstall $pkgname
            lappend pkgInstall $pkgDB($pkgname:installed)
        }
    }

    if [llength $pkgInstall] {
	::uilog::log [list [mc "Next addons will be installed(upgraded):\n"] tittle]
    }

    foreach it [array names todo *:do] {
        if {$todo($it) == "install"} {
            set pkgname [lindex [split $it ":"] 0]
            ::uilog::log [list $pkgname\n table]
        }
    }

    # First upgrade all
    foreach {pkgname installed} $pkgInstall {
        if {$installed} {
            ::misc::sleep 1000
            ::core::proceed-install $pkgname $todo($pkgname:recursive) $todo($pkgname:force)
        }
    }

    # Install not installed yet
    foreach {pkgname installed} $pkgInstall {
        # if not installed as depend
        if {!$installed && 
	    !$pkgDB($pkgname:installed) &&
	    ![in $sesInstalled $pkgname]} {
            ::misc::sleep 1000
            ::core::proceed-install $pkgname $todo($pkgname:recursive) $todo($pkgname:force)
        }
    }

    # show install status
    set resaddons [array names todoStatus *:status]
    if [llength $resaddons] {
	LOG [list [mc "Results:"]\n tittle]
	foreach a $resaddons {
	    set addon [lindex [split $a :] 0]
	    LOG [list "$addon\t\t\t" tbllist1]
	    # First print all except :status
	    foreach s [array names todoStatus $addon:*] {
		if {$s != "$addon:status"} {
		    LOG $todoStatus($s)
		    LOG [list \t\t\t tbllist2]
		}
	    }
	    # now status
	    LOG $todoStatus($addon:status)
	}
    }

    # clear todo
    foreach it [array names todo *:do] {
        unset todo($it)
    }

    # unblock widgets
    $nb itemconfigure nb_pkg -state normal
    $::uipkg::tableIntall delete 0 end
    ::uipkg::beautify_tree
    catch {::uipkg::info-pkg-update-force}

    LOG [list [mc "Done."]\n normal]
}

proc ::uipkg::setTree-selection {tree selnode} {
    $tree selection set [set node $selnode]
    while {[$tree parent $node] != "root"} {
        $tree opentree $node
        set node [$tree parent $node]
    }
    $tree opentree $node false
    $tree see $selnode
}

#------------------------------
# append log with list of text and tag
# example: ::uilog::log {"hello" normal "worl" bold}
#-----------------------------
proc ::uilog::log {arglist} {
    global ::uilog::text
    $::uilog::text configure -state normal
    for {set i 0} {$i < [llength $arglist]} {incr i +2} {
        $::uilog::text insert end [lindex $arglist $i] [lindex $arglist [expr $i+1]]
        # TODO: log to file
        puts -nonewline [lindex $arglist $i]
    }
    $::uilog::text yview moveto 1.0
    $::uilog::text configure -state disabled
}

#------------------------------
# append log with list of text and tag
# example: log {"hello" normal}
# @logr  - put "\r" in stdout if true otherwise \n
#-----------------------------
proc ::uilog::log\r {arglist {logr no }} {
    global ::uilog::text
    $::uilog::text configure -state normal
    $::uilog::text delete "end -2l" "end -1c"
    if {$logr} {
        puts -nonewline \r
    }
    for {set i 0} {$i < [llength $arglist]} {incr i +2} {
        $::uilog::text insert end [lindex $arglist $i] [lindex $arglist [expr $i+1]]
        # TODO: log to file
        puts -nonewline [lindex $arglist $i]
    }
    if {$logr} {
        flush stdout
    } else {
        puts {}
    }

    $::uilog::text insert end \n [lindex $arglist [expr $i+1]]
    $::uilog::text yview moveto 1.0
    $::uilog::text configure -state disabled
}

#-----------------------------
# log as table column with striped color
#-----------------------------
proc ::uilog::log_as_tbl {msg} {
    global ::uilog::striptbl    
    if {$::uilog::striptbl} {
        ::uilog::log [list $msg\n tbllist1]
        set ::uilog::striptbl 0
    } else {
        ::uilog::log [list $msg\n tbllist2]
        set ::uilog::striptbl 1
    }
}

proc ::uilog::clearlog {} {
    global ::uilog::text
    $::uilog::text configure -state normal
    $::uilog::text delete 1.0  end
    $::uilog::text configure -state disabled

}

#-----------------------------------------------
# configure before creating main window
#-----------------------------------------------

#-----------------------------
# proc for creation cfg dialog
# setup vars cpath distpath pkgpath workdir target_program
#-----------------------------
proc ::uipkg::startup_cfg {} {
    global config profiles
    global cpath distpath pkgpath workdir target_program celVersion
    variable ::tk::Priv

    set focus [focus]
    set grab [grab current .]
    set w .startupcfg
    catch {destroy $w}
    set focus [focus]
    set grab [grab current .]
    set title [mc "Configure" ]
    
    toplevel $w -bd 1 -relief raised -class TkSDialog

    wm title $w $title
    wm iconname $w $title
    wm protocol $w WM_DELETE_WINDOW {set ::tk::Priv(button) 0}
    wm transient $w [winfo toplevel [winfo parent $w]]

    pack [set optfr [frame $w.optf]] -fill both -expand 1
    pack [set buttonfr [frame $w.butf]] -fill x -side bottom

    proc ::uipkg::select_dir {varName path} {
        upvar $varName filename
        set res [tk_chooseDirectory -initialdir $path]
        if {$res != ""} {
            set filename $res}
    }

    # profile selector
    pack [set profFrame [labelframe $optfr.prof -text [mc "Profile:"]]] -fill x
    pack [set ::uipkg::selectRofile [ComboBox $profFrame.comb -editable yes]] -fill x
    setTooltip $::uipkg::selectRofile [mc "Pres ENTER when you select profile!"]
    set profileIndex 0
    set i 0
    foreach profile [array names profiles *:cpath] {
	set profileName [lindex [split $profile :] 0]
	if {$profileName == $config(profile)} {
	    set profileIndex $i
	}
	$::uipkg::selectRofile insert end $profileName
	incr i
    }
    $::uipkg::selectRofile setvalue @$profileIndex
    # on enter of profile combo box
    $::uipkg::selectRofile bind <Key-Return> {   
	if {[info exist profiles([$::uipkg::selectRofile get]:cpath)]} {
	    set ::uipkg::rootd $profiles([$::uipkg::selectRofile get]:cpath)
	    set ::uipkg::pkgd $profiles([$::uipkg::selectRofile get]:pkgpath)
	    set ::uipkg::distd $profiles([$::uipkg::selectRofile get]:distpath)
	    set ::uipkg::workd $profiles([$::uipkg::selectRofile get]:workdir)
	    set ::uipkg::indexUrld $profiles([$::uipkg::selectRofile get]:indexUrl)
	    set ::uipkg::celVersiond $profiles([$::uipkg::selectRofile get]:celVersion)
	}
    }
    
    # add/delete profile
    pack [set profilebtn [frame $profFrame.btnfr]] -fill x
    pack [ button $profilebtn.create -bd 1 -text [mc "Create/Save"] -command {
	# don't append into combobox if exist
	if {![info exist profiles([$::uipkg::selectRofile get]:cpath)]} {
	    $::uipkg::selectRofile insert end [$::uipkg::selectRofile get]
	}
	set profiles([$::uipkg::selectRofile get]:cpath) $::uipkg::rootd 
	set profiles([$::uipkg::selectRofile get]:pkgpath) $::uipkg::pkgd
	set profiles([$::uipkg::selectRofile get]:distpath) $::uipkg::distd
	set profiles([$::uipkg::selectRofile get]:workdir) $::uipkg::workd
	set profiles([$::uipkg::selectRofile get]:indexUrl) $::uipkg::indexUrld
	set profiles([$::uipkg::selectRofile get]:celVersion) $::uipkg::celVersiond

    } ] \
        [ button $profilebtn.delete -bd 1 -text [mc "Delete"] -command {
	    set t [$::uipkg::selectRofile get]
	    catch {unset profiles($t:cpath)}
	    catch {unset profiles($t:pkgpath)}
	    catch {unset profiles($t:distpath)}
	    catch {unset profiles($t:workdir)}
	    catch {unset profiles($t:indexUrl)}
	    catch {unset profiles($t:celVersion)}
	    # delete from combobox profile
	    [$::uipkg::selectRofile getlistbox ] delete [$::uipkg::selectRofile getvalue]
	    $::uipkg::selectRofile setvalue @0
	}] \
        -fill x -side left -expand 1
    setTooltip $profilebtn.create [mc "Create or save profile"]
    setTooltip $profilebtn.delete [mc "Delete profile"]

    # tmp vars for widget binding
    variable ::uipkg::rootd $profiles($config(profile):cpath)
    variable ::uipkg::pkgd $profiles($config(profile):pkgpath)
    variable ::uipkg::distd $profiles($config(profile):distpath)
    variable ::uipkg::workd $profiles($config(profile):workdir)
    variable ::uipkg::indexUrld $profiles($config(profile):indexUrl)
    variable ::uipkg::celVersiond $celVersion
    foreach {var text tooltip} 	[list rootd [mc "Root dir"] [ mc "Directory for target program"] \
				     pkgd [mc "Package db dir"] [mc "Location of installed addon's database"] \
				     distd [mc "Distribute dir"] [mc "Directory for downloads"] \
				     workd [mc "Work dir"] [mc "Temporary working directory for extracting, etc.
It make sence to use one disk partition with root dir"] ] {
	pack [set frame [frame $optfr.$var]] -fill x -anchor w -expand 0
	pack [label $frame.l -text $text] -fill x -side left -expand 0
	setTooltip $frame.l $tooltip
	pack [entry $frame.e -textvariable [namespace current]::$var]  -fill x -side left -expand 1  
	setTooltip $frame.e $tooltip
	pack [button $frame.b -text "..." \
		  -command "::uipkg::select_dir [namespace current]::$var $[namespace current]::$var"] -fill x -side left -expand 0
    }
    pack [button $optfr.recalc -text [mc "Set all dirs related to root dir"] -command {
        set ::uipkg::rootd [file nativename $::uipkg::rootd]
        set ::uipkg::pkgd [file nativename [file join $::uipkg::rootd pkg]]
        set ::uipkg::distd [file nativename [file join $::uipkg::pkgd distfiles]]
        set ::uipkg::workd [file nativename [file join $::uipkg::pkgd db]]
    }] -fill x -expand 0

    pack [set frame [labelframe $optfr.url -text [mc "Download url of index file:"]]] -fill x
    pack [entry $frame.e -textvariable ::uipkg::indexUrld]  -fill x -side left -expand 1  

    pack [set frame [labelframe $optfr.ver -text "Version of $target_program"]] -fill x
    pack [entry $frame.e -textvariable ::uipkg::celVersiond]  -fill x -side left -expand 1        

    pack [ button $buttonfr.ok -text [mc "Ok"] -command {set ::tk::Priv(button) 1}] \
        [ button $buttonfr.cancel -text [mc "Cancel"] -command {set ::tk::Priv(button) 0}] \
        -fill x -side left -expand 1


    bind $w <Destroy> {set ::tk::Priv(button) 0}
    bind $w <Escape> {set ::tk::Priv(button) 0}

    wm withdraw $w
    update idletasks
    set x [expr {[winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 - [winfo vrootx $w]}]
    set y [expr {[winfo screenheight $w]/2 - [winfo reqheight $w]/2 - [winfo vrooty $w]}]
    wm geom $w +$x+$y
    wm deiconify $w
    grab $w

    tkwait variable ::tk::Priv(button)
    bind $w <Destroy> {}


    if {$::tk::Priv(button)} {
        # apply
	set config(profile) [$::uipkg::selectRofile get]
        set cpath $::uipkg::rootd
        set distpath $::uipkg::distd
        set pkgpath $::uipkg::pkgd
        set workdir $::uipkg::workd
        set indexUrl $::uipkg::indexUrld
        set celVersion $::uipkg::celVersiond

	set profiles($config(profile):cpath) $::uipkg::rootd
	set profiles($config(profile):pkgpath) $::uipkg::pkgd
	set profiles($config(profile):distpath) $::uipkg::distd
	set profiles($config(profile):workdir) $::uipkg::workd
	set profiles($config(profile):indexUrl) $::uipkg::indexUrld
	set profiles($config(profile):celVersion) $::uipkg::celVersiond
    }

    grab release $w
    destroy $w
    focus -force $focus
    if {$grab != ""} {grab $grab}
    update idletasks
}

#-----------------------------------------------
# main window
#-----------------------------------------------

wm title . $prog_name
wm geometry . +400+400

# window geometry
set width 800
set height 600
set x [expr { ( [winfo vrootwidth .] - $width  ) / 2 }]
set y [expr { ( [winfo vrootheight .] - $height ) / 2 }]
wm geometry . ${width}x${height}+${x}+${y}

#-----------------------------
# config file
#-----------------------------
if {$loadCfg} {
    ::misc::config:open $mainConfigFile
}

::core::check-vars

# if force first run by command line param "--reset"
if {$firstRun} {
    set config(firstRun) yes
}

# startup dialog, if first run only
if {$config(firstRun)} {
    ::uipkg::startup_cfg
}

::core::check-vars


#-----------------------------------------------
# G U I 
#-----------------------------------------------

# root Notebook
pack [set nb [NoteBook .nb -side top]] -fill both -expand 1 
$nb insert 0 nb_pkg -text [mc "Addon manager"]
$nb insert 1 nb_log -text [mc "Log"]


#------------------------------
# Addon manager note
#------------------------------
set frame [$nb getframe nb_pkg]
pack [panedwindow $frame.p]

# 2 frames (left - addon tree, right - info, todo)
frame $frame.p.left -relief flat -borderwidth 1
frame $frame.p.right -relief sunken -borderwidth 1

$frame.p add $frame.p.left \
    -sticky nsew -minsize 100 -height 100 -width 200
$frame.p add $frame.p.right \
    -sticky nsew -minsize 45 -height 25 -width 100

# pkg tree
pack $frame.p -expand 1 -fill both
pack [set fr [frame $frame.p.left.fr]] -expand yes -fill both
pack [set ::uipkg::pkgTree [Tree $fr.tree -bg $config(tree:bg)]] -fill both -expand yes

# search widget
variable searchAddon {}
variable lastSearch {}
variable lastType {}
variable searchNext 0
variable ::uipkg::searchType
pack [set fr [labelframe $frame.p.left.fr.searchfr -text [mc "Search"]]] \
    -side bottom -expand no -fill x 
pack [set searchEntry [entry $fr.entr -textvariable searchAddon]] \
    [set ::uipkg::searchType [ComboBox $fr.type -editable no]] \
    -side top -expand yes -fill x

setTooltip $searchEntry [mc "Search addon by given pattern
You can use *, and ?, \[chars\] in pattern"]

foreach f "name all category description version www conflicts distfile
                unpack maintainer author 
                depend screenshot license patch backup copy
                choice options installmsg deinstallmsg install
                xpatch modified created" {
    $::uipkg::searchType insert end $f
}

$::uipkg::searchType setvalue @0

# search bind
bind $searchEntry <Return> {
    if {$lastSearch != $searchAddon ||
        $lastType != [$::uipkg::searchType get]} {
        set searchNext 0
    }
    set addons [::core::get-matched-addon-list *$searchAddon*  \
                    [$::uipkg::searchType get]]
    if {$searchNext < [llength $addons]} {
        set pkgname [lindex $addons $searchNext]
        ::uipkg::setTree-selection $::uipkg::pkgTree \
            [lindex $pkgDB($pkgname:treenodes) 0]
        ::uipkg::info-pkg-update-force
        set lastSearch $searchAddon
        set lastType [$::uipkg::searchType get]
        incr searchNext
        return
    }
    set lastSearch {}
    set searchNext 0
    bell
}

#pack [set ::uipkg::pkgTree [Tree $frame.p.left.tree -bg $config(tree:bg)]] \
#    -expand 1 -fill both

# 
pack [set fr [frame $frame.p.right.df -relief flat -borderwidth 0]] -fill both -expand 1
pack [set rpane [panedwindow $fr.pane -orient vertical]]
pack $rpane -side top -expand yes -fill both -pady 2 -padx 2m

frame $rpane.info -relief sunken -borderwidth 1
frame $rpane.todo -relief sunken -borderwidth 1

# pane for info and action buttons
$rpane add $rpane.info \
    -sticky nsew -minsize 100 -height 500 -width 200

# pane for todo list
$rpane add $rpane.todo \
    -sticky nsew -minsize 100 -height 200 -width 100

# info pane contain text of pkg and action buttons
pack [set fr [frame $rpane.info.act -height 45]] -side bottom -expand no -fill x 
pack [set installButton [button $fr.install -text [mc "Install"] -state disabled \
                             -command {
                                 ::uipkg::setTree-selection $::uipkg::pkgTree \
                                     [set node [lindex $pkgDB($currentView:treenodes) 0]]
                                 ::uipkg::toggle-mark-for-install}]] \
    [ set uninstallButton [button $fr.uninstall -text [mc "Uninstall"] -state disabled \
                               -command {
                                   ::uipkg::setTree-selection $::uipkg::pkgTree \
                                       [set node [lindex $pkgDB($currentView:treenodes) 0]]
                                   ::uipkg::toggle-mark-for-uninstall}]] \
    [ set proceedButton [button $fr.proceed -text [mc "Proceed all tasks"] \
                             -command {::uipkg::proceed-todo} ]] \
    [ set configButton [button $fr.config -text [mc "Configure"] -state normal \
                               -command { 
                                   ::uipkg::setTree-selection $::uipkg::pkgTree \
                                       [set node [lindex $pkgDB($currentView:treenodes) 0]]
                                   ::uipkg::configure-pkg $currentView }]] \
    [checkbutton $fr.more -text [mc "More info"] \
         -offvalue "no" -onvalue "yes" -variable config(moreInfo)] \
    [button $fr.updateindex -text [mc "Update index file"] \
	 -command ::core::update-index] \
    -side left -fill x

# tooltips
setTooltip $installButton [mc "Toggle install for addon"]
setTooltip $uninstallButton [mc "Toggle uninstall for addon"]
setTooltip $proceedButton [mc "Proceed all marked task.
Run uninstall before any installs(upgrades)"]
setTooltip $configButton [mc "Configure current addon"]
setTooltip $fr.more [mc "Toggle more info visible of addon"]
setTooltip $fr.updateindex [mc "Fetch index and refresh addon tree"]

# text
pack [set sw [ScrolledWindow $rpane.info.sw]] -fill both -expand yes
$sw setwidget [set ::uipkg::infoText [text $sw.text -state disabled]]

#tags of info text
foreach key [array names config text:* ] {
    set elems [split $key ":"]
    set tagname [lindex $elems 1]
    eval $::uipkg::infoText tag configure $tagname $config($key)
}

# blinked tags
$::uipkg::infoText tag configure blinkred -font {TkTextFont 12}
$::uipkg::infoText tag configure blinkgreen -font {TkTextFont 12}

# text binks
::uipkg::textToggle "$::uipkg::infoText tag configure blinkred -background \
            #ce5555 -foreground white" 400 "$::uipkg::infoText tag configure \
            blinkred -background {} -foreground {}" 200
::uipkg::textToggle "$::uipkg::infoText tag configure blinkgreen -background \
            green -foreground black" 400 "$::uipkg::infoText tag configure \
            blinkgreen -background {} -foreground {}" 200

# todo pane contains: table, cancel button
set frame $rpane.todo

pack [button $frame.b -text [mc "Cancel all task"] -command {
    foreach key [array names todo *:do] {
        if {$todo($key) != "none"} {
            # left from :do is addon name
            ::uipkg::cancel-install [lindex [split $key ":"] 0] 
        }
    }
} ] -fill x
# scrollable table
pack [set sw [ScrolledWindow $frame.sw]] -fill both -expand 1
$sw setwidget [set ::uipkg::tableIntall [tablelist::tablelist $frame.tbl \
                                             -columns {0 "addon name"   left
                                                 0      "Recursive"     center
                                                 0      "Action" center
                                                 0      "Force" center
                                                 0      "Status" right
                                             } \
                                             -labelcommand tablelist::sortByColumn \
                                             -editstartcommand editStartCmd \
                                             -stripebackground \#e0e8f0 
                                        ]]

if {[$::uipkg::tableIntall cget -selectborderwidth] == 0} {
    $::uipkg::tableIntall configure -spacing 1
}
$::uipkg::tableIntall columnconfigure 0 -sortmode ascii -name addon
$::uipkg::tableIntall columnconfigure 1 -sortmode ascii -name recursive  -editable yes -editwindow ComboBox
$::uipkg::tableIntall columnconfigure 2 -sortmode ascii -name action
$::uipkg::tableIntall columnconfigure 3 -sortmode ascii -name force -editable yes -editwindow ComboBox
set bodyTag [$::uipkg::tableIntall bodytag]
bind $bodyTag <Key-Delete> {
    set pkgname [$::uipkg::tableIntall cellcget [$::uipkg::tableIntall curselection],0 -text]
    ::uipkg::cancel-install $pkgname
}
bind $bodyTag <Key-Return> {
    # select current table's selected addon name in tree too, and
    # update info
    set pkgname [$::uipkg::tableIntall cellcget [$::uipkg::tableIntall curselection],0 -text]
    set node [lindex $pkgDB($pkgname:treenodes) 0]
    ::uipkg::setTree-selection $::uipkg::pkgTree $node
    ::uipkg::info-pkg-update-force
}

#-----------------------------------------------
# editStartCmd
#
# Applies some configuration options to the edit
# window; if the latter is a
# ComboBox, the procedure populates it.
#-----------------------------------------------
proc editStartCmd {tbl row col text} {
    set w [$tbl editwinpath]

    switch [$tbl columncget $col -name] {
        recursive {
            $w configure -values {yes no} -editable no
        }
        force {
            $w configure -values {yes no} -editable no
        }
    }
    return $text
}

#------------------------------
# log manager note
#------------------------------
set frame [$nb getframe nb_log]
pack [set sw [ScrolledWindow $frame.swl]] -fill both -expand true
$sw setwidget [set ::uilog::text [text $frame.text -wrap word -font {TkTextFont 10} -state disabled]]
# tags
foreach key [array names config txtlog:* ] {
    set elems [split $key ":"]
    set tagname [lindex $elems 1]
    eval $::uilog::text tag configure $tagname $config($key) -wrap word
}
# green and red blink
::uipkg::textToggle "$::uilog::text tag configure blinkgreen -background \
        green -foreground black;
        $::uilog::text tag configure blinkred -background \
        #ce5555 -foreground white; \
        $::uilog::text tag configure blinkyellow -background \
        #ffd700 -foreground black" 400 "$::uilog::text tag configure \
        blinkgreen -background {} -foreground {};
        $::uilog::text tag configure \
        blinkred -background {} -foreground {}; \
        $::uilog::text tag configure \
        blinkyellow -background {} -foreground {}" 200

#-----------------------------------------------
# Key and mouse binds
#-----------------------------------------------
bind . <Control-Key-1> {$nb raise nb_pkg}
bind . <Control-Key-2> {$nb raise nb_log}

#menu event for pkg show tree
proc ::uipkg::deptree {} {    
    global pkgDB ::uipkg::pkgTree
    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]

    if {![info exists pkgDB($pkgname:category)]} {
        # if selected category
        set sel [lindex [$::uipkg::pkgTree selection get] 0]
        foreach node [$::uipkg::pkgTree nodes $sel] {
            set pkgname [$::uipkg::pkgTree itemcget $node -text]
            if [info exists pkgDB($pkgname:installed)] {
                LOG [list [mc "Dependency tree for "] greenbg $pkgname\n greenbgbold ]
                ::core::deptree-recursive $pkgname
            }
        }
        return
    } else {
        LOG [list [mc "Dependency tree for "] greenbg $pkgname\n greenbgbold ]
        ::core::deptree-recursive $pkgname
    }
}

proc ::uipkg::import {} {
    global config pkgpath
    # notebook
    global nb
    set importdir {}
    if [info exist config(import-dir)] {
        set importdir $config(import-dir) }
    
    set filename [ tk_getOpenFile -filetypes {{Archives {.tar.gz}}} \
                       -defaultextension .tar.gz \
                       -initialdir $importdir \
                       -title [mc "Select archive for import"] ]

    if {$filename != "" } {
        set all [tk_messageBox -parent . -title [mc "Import options"] -icon question \
                     -type yesno -default no \
                     -message [mc "Do you want import configuration of addons"]]

        LOG [list "===>  " prefix [mc "Importing configuration from "] normal \"$filename\"\n bold]
        $nb raise nb_log
        ::core::import-configuration $filename $all
        set config(import-dir) [file dirname $filename]

        # read imported index file for update db and pkg tree
        LOG [list "===>  " prefix [mc "Reload index files\n" normal]]
        ::core::load-index-recursive [file join $pkgpath userindex] no
        read_pkg no
    }
}

proc ::uipkg::export {} {
    global config
    # notebook
    global nb

    set importdir {}
    if [info exist config(import-dir)] {
        set importdir $config(import-dir) }

    set filename [ tk_getSaveFile -filetypes {{Archives {.tar.gz}}} \
                       -defaultextension .tar.gz \
                       -initialdir $importdir \
                       -title [mc "Select archive for import"] ]
    # without extention
    set filename [regsub -all "(^.*)\\.tar\\.gz$" $filename "\\1"]
    if {$filename != ""} {
        LOG [list "===>  " prefix [mc "Export configuration into tar file: "] normal \"$filename.tar.gz\"\n bold]
        $nb raise nb_log
        ::core::export-configuration $filename {}
    }
}

proc _treepopup {item} {
    global icon_install icon_remove icon_reload
    global pkgDB pkgCache
    global target_program

    catch {destroy $::uipkg::pkgTree.menu}     
    set m [menu $::uipkg::pkgTree.menu]
    
    $::uipkg::pkgTree selection set $item

    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]

    $m add command -accelerator {} -label [mc "Update index file"] \
        -compound left -command ::core::update-index
    $m add separator

    $m add command -accelerator i -label [mc "Toggle install"] -image $icon_install  -compound left -command ::uipkg::toggle-mark-for-install
    $m add command -accelerator d -label [mc "Toggle deinstall"] -image $icon_remove -compound left -command ::uipkg::toggle-mark-for-uninstall
    $m add command -accelerator u -label [mc "Cancel task"] -command { 
        set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
        ::uipkg::cancel-install $pkgname }
    $m add command -accelerator g -label [mc "Configure"] -command { 
        set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
        ::uipkg::configure-pkg $pkgname }

    $m add separator
    $m add command -accelerator {Ctrl-d} -label [mc "Dist clean"] -command {
        set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
        ::core::distclean $pkgname
    }
    $m add command -accelerator F -label [mc "Fix installed addons"] -command ::uipkg::fix-pkgs
    $m add command -accelerator A -label [mc "Upgrade all"] -image $icon_reload -compound left -command ::uipkg::mark-all-upgrades
    $m add command -accelerator {Ctrl-u} -label [mc "Complete remove (not force)"] \
        -image $icon_remove -compound left -command ::uipkg::mark-compete-remove
    $m add command -accelerator T -label [mc "Dependency tree"] -compound left \
        -command { ::uipkg::deptree
            $nb raise nb_log}

    $m add separator
    $m add command -accelerator {} -label [mc "Import configuration"] \
        -compound left -command ::uipkg::import
    $m add command -accelerator {} -label [mc "Export configuration"] \
        -compound left -command ::uipkg::export

    $m add separator
    $m add command -accelerator {C-x C-l} -label [mc "Start [file tail $target_program]"] \
        -compound left -command ::misc::start_target_program
    $m add command -accelerator {C-x C-c} -label [mc "Exit"] \
        -compound left -command quit?

    tk_popup $::uipkg::pkgTree.menu [winfo pointerx [focus]] [winfo pointery [focus]]
}
$::uipkg::pkgTree bindText <Button-3> _treepopup
$::uipkg::pkgTree bindImage <Button-3> _treepopup

# update text view or scroll
$::uipkg::pkgTree bindArea <Key-Return> +::uipkg::info-pkg-update
$::uipkg::pkgTree bindArea <Key-space> +::uipkg::info-pkg-update
bind $::uipkg::infoText <Key-Return> +::uipkg::info-pkg-update
bind $::uipkg::infoText <Key-space> +::uipkg::info-pkg-update
# goto home 
$::uipkg::pkgTree bindArea <Key-g> {
    $::uipkg::infoText yview moveto 0.0
}
bind $::uipkg::infoText <Key-g> {
    $::uipkg::infoText yview moveto 0.0
}

# goto end
$::uipkg::pkgTree bindArea <Key-G> {
    $::uipkg::infoText yview moveto 1.0
}
bind $::uipkg::infoText <Key-G> {
    $::uipkg::infoText yview moveto 1.0
}

# mouse
$::uipkg::pkgTree bindText <1> +::uipkg::info-pkg-update
$::uipkg::pkgTree bindArea <Key-i> +::uipkg::toggle-mark-for-install
$::uipkg::pkgTree bindArea <Key-d> +::uipkg::toggle-mark-for-uninstall
$::uipkg::pkgTree bindArea <Key-g> { # configure
    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    ::uipkg::configure-pkg $pkgname
}
$::uipkg::pkgTree bindArea <Key-u> { # cancel todo
    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    ::uipkg::cancel-install $pkgname
}
$::uipkg::pkgTree bindArea <Control-d> { # dist clean
    set pkgname [$::uipkg::pkgTree itemcget [lindex [$::uipkg::pkgTree selection get] 0] -text]
    ::core::distclean $pkgname
}
$::uipkg::pkgTree bindArea <Key-F> +::uipkg::fix-pkgs
$::uipkg::pkgTree bindArea <Key-A> +::uipkg::mark-all-upgrades
$::uipkg::pkgTree bindArea <Control-u> +::uipkg::mark-compete-remove
$::uipkg::pkgTree bindArea <Key-T> { ::uipkg::deptree

    $nb raise nb_log }

# addotional global keys
bind . <Control-x><Control-l> +::misc::start_target_program
bind . <Control-x><Control-c> +quit?
bind . <Control-q> +quit?

$nb raise nb_pkg

#-----------------------------------------------
# load index files
::core::load-index

::uipkg::beautify_tree

set addons [llength [array names pkgDB *:category]]
::uilog::log [list $addons greenbgbold \
                  " addons available\n" greenbg]
::uilog::log [list [llength [array names pkgCache *:name]] greenbgbold \
                  " addons installed\n" greenbg]

if {![file exist [file join $pkgpath $dwnlIndexDir]] &&
    ![file exist [file join $pkgpath userindex]]} {
    if {[tk_messageBox -title [mc "Update?"] -icon question \
             -type yesno -default yes \
	     -message [mc "No index files found, do you want fetch now?"]] == yes} {
	::core::update-index
    }
}

proc quit? {} {
    global mainConfigFile
    if {[tk_messageBox -parent . -title [mc "Close?"] -icon question \
             -type yesno -default no -message [mc "Do You want to quit"]] == yes} {
        ::misc::config:save $mainConfigFile
        exit
    }
}

wm protocol . WM_DELETE_WINDOW {
    quit?
}

set config(firstRun) no

# broke on \}
#::core::apply-xpatch {-file extras/lua_edu_tools/config.lua -body {lua array "adds" rmstring {"Asteroid_Belt" Atmosphere_Composition} } }
#::core::apply-xpatch {-file extras/lua_edu_tools/config.lua -body {lua array "adds" addstring {"Asteroid_Belt" Atmosphere_Composition test_1 test2} } }
#::core::apply-xpatch {-file extras/lua_edu_tools/config.lua -body {lua variable cbubordoff set "no" } }
#::core::apply-xpatch {-file "extras/Sun-new/sun_flares/sun flares.ssc" -body {script variable {"\" \"\\s+\"Sol\"\\s*#flare 2" EllipticalOrbit SemiMajorAxis} set "[ 0 1 1]" } }

#::core::apply-xpatch {-file "extras/Sun-new/sun_flares/sun flares.ssc" -body {script array {"\" \"\\s+\"Sol\"\\s*#flare 2" EllipticalOrbit SemiMajorAxis} addstring "11 2 3 4 5 6 7" } }

#::core::apply-xpatch {-file "extras/Sun-new/sun_flares/sun flares.ssc" -body {script array {"\" \"\\s+\"Sol\"\\s*#flare 2" EllipticalOrbit SemiMajorAxis} rm {3 1 3} } }
#::core::apply-xpatch {-file "extras/Sun-new/sun_flares/sun flares.ssc" -body {script array {"\" \"\\s+\"Sol\"\\s*#flare 2" EllipticalOrbit SemiMajorAxis1} rmstring {3 1 3} } }

#::core::apply-xpatch {-file "extras/Sun-new/sun_flares/sun flares.ssc" -body {script array {"\" \"\\s+\"Sol\"\\s*#flare 2" EllipticalOrbit SemiMajorAxis1} add {3 1 3} } }
