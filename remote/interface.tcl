#!/usr/bin/env tclsh

## remote

namespace eval interface {

#****f* interface.tcl/output
# NAME
#   output -- procedure being invoked from runtime when sending messages
#       about running experiments to user
# SYNOPSIS
#   output $statCode $msg
# FUNCTION
#   Sends the message to all clients that are connected to the give topology
# INPUTS
#   * statCode -- message status code, what type of the message is it
#   * msg -- the message that should be displayed to the user
#****

    proc output { statCode {msg ""} } {
        
        upvar 0 ::cf::[set ::curcfg]::remote remote
        foreach client $remote {
            lassign $client ip channel remoteCfgId
            remote::common::write $channel "$remoteCfgId#false#interface::output $statCode \"$msg\""
        }
    }
}