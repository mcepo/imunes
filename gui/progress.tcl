#!/usr/bin/env tclsh


## Takes care of the display of progress when starting and terminating the experiment

## also stateline messages are beeing processed here

namespace eval progress {

    set window ""
    set startedCount 0

    proc instantiate { title msg count startedCountL } {

        set progress::startedCount $startedCountL
        set progress::window .progressBar
        catch {destroy $progress::window}
        toplevel $progress::window -takefocus 1
        wm transient $progress::window .
        wm title $progress::window $title
        message $progress::window.msg -justify left -aspect 1200 -text $msg
        pack $progress::window.msg
        ttk::progressbar $progress::window.p -orient horizontal -length 250 \
        -mode determinate -maximum $count -value $progress::startedCount
        pack $progress::window.p
        grab $progress::window
        wm protocol $progress::window WM_DELETE_WINDOW {
        }
    }

    proc increment { msg } {
        progress::statline $msg
        incr progress::startedCount
        catch {$progress::window.p configure -value $progress::startedCount}
        update
    }

    proc decrement {{msg ""} } {
        progress::statline $msg
        incr progress::startedCount -1
        catch {$progress::window.p configure -value $progress::startedCount}
        update
    }

    proc kill { msg } {
        progress::statline $msg
        catch {destroy $progress::window}
    }

    proc statline { line } {
        .bottom.textbox config -text "$line"
        animateCursor
    }
}