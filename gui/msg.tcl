#!/usr/bin/env tclsh

namespace eval msg {

    proc window { level msg } {
        after idle {.dialog1.msg configure -wraplength 4i}
        tk_dialog .dialog1 $level $msg info 0 Dismiss
    }
}