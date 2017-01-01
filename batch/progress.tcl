#!/usr/bin/env tclsh

# batch


## Takes care of the progress when staring and terminating the experiment

namespace eval progress {

    set startedCount 0
    set maxCount 0

    proc instantiate { title msg tot prgs } {

        progress::statline $title
        progress::statline $msg
        set progress::startedCount $prgs
        set progress::maxCount $tot 
    }

    proc increment { {msg ""} } {

        incr progress::startedCount
        puts -nonewline "\r                                                "
        puts -nonewline "[format "\r%.1f" "[expr {100.0 * $progress::startedCount/$progress::maxCount}]"]%\t\t$msg"
        flush stdout
    }

    proc decrement { {msg ""}} {
        incr progress::startedCount -1
        puts -nonewline "\r                                                "
        puts -nonewline "[format "\r%.1f" "[expr {100.0 * $progress::startedCount/$progress::maxCount}]"]%\t\t$msg"
        flush stdout
    }

    proc kill { {msg ""} } {
        progress::statline $msg
    }

    proc statline { line } { 
        puts -nonewline "\r                                                  "
        puts "\r$line"
        flush stdout
    }
}