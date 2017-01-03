#!/usr/bin/env tclsh

## gui

namespace eval interface {

    proc output { statCode {msg ""} } {

        switch $statCode {
        
            INFO {
                msg::statline $msg
            }
            WARN {
                msg::window "IMUNES warning" $msg
            }
            ERR {
               msg::window "IMUNES error" $msg
            }
            STARTING_EXP {
                progress::instantiate  "Starting experiment..." \
                                            "Starting up virtual nodes and links." \
                                            $msg \
                                            0
            }
            INCR {
                progress::increment $msg
            }
            EXP_STARTED {
                progress::kill $msg
                createExperimentScreenshot
                disableEditor
            }
            TERMINATING_EXP {
                progress::instantiate  "Terminating experiment ..." \
                                            "Deleting virtual nodes and links." \
                                            $msg \
                                            $msg
            }
            DECR {
                progress::decrement $msg
            }
            EXP_TERMINATED {
                progress::kill $msg
                enableEditor
            }
        }
    }

    proc dispatch { procedure } {

        upvar 0 ::cf::[set ::curcfg]::remote remote
        if {[llength $remote] > 0} {
            lassign [lindex $remote 0] ip channel remoteCfgId
            remote::common::write $channel "$remoteCfgId#false#$procedure"
        } else {
            eval $procedure
        }
    }

    proc get { procedure {params ""}} {

        upvar 0 ::cf::[set ::curcfg]::remote remote
        if {[llength $remote] > 0} {
            lassign [lindex $remote 0] ip channel remoteCfgId
## temporarly close the fileevent on channel, so that when the response gets here
## it doesn't trigger the fileevent on it
## it probably wouldn't happen anyway but just to be on the safe side
            fileevent $channel readable ""
            set response ""
            if { [remote::common::write $channel "$remoteCfgId#true#$procedure $params"] == 0 } {
                set response [remote::common::decode [ remote::common::read $channel ] ]
            }
            fileevent $channel readable [ list remote::client::dataHandler $ip $channel ]
            return $response
        } else {
            return [eval $procedure $params]
        }
    }

    proc client { procedure } {
        upvar 0 ::cf::[set ::curcfg]::remote remote
        
        if {[llength $remote] > 0 } {
            return [ eval "remote::client::$procedure"]
        } else {
            return [eval $procedure ]
        } 
    }
}