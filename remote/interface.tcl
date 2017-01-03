#!/usr/bin/env tclsh

## remote

namespace eval interface {

    proc output { statCode {msg ""} } {
        
        upvar 0 ::cf::[set ::curcfg]::remote remote
        foreach client $remote {
            lassign $client ip channel remoteCfgId
            remote::common::write $channel "$remoteCfgId#false#interface::output $statCode \"$msg\""
        }
    }
}