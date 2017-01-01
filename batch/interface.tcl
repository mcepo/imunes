#!/usr/bin/env tclsh

## batch

namespace eval interface {


## All output from runtime comes here
## statCode - is a flag stating what type of a message is beeing recieved,
##              and at what step is the runtime when starting and terminating experiment
## msg - the message
## Same is with the GUI interface and remove interface

    proc output { statCode {msg ""} } {

        switch $statCode {
        
            INFO {
                msg::info $msg
            }
            WARN {
                msg::warning $msg
            }
            ERR {
               msg::error $msg
            }
            STARTING_EXP {
                progress::instantiate    "Starting experiment..." \
                                                "Starting up virtual nodes and links." \
                                                $msg \
                                                0 
            }
            INCR {
                progress::increment $msg
            }
            EXP_STARTED {
                progress::kill $msg
                upvar 0 ::cf::[set ::curcfg]::eid eid
                puts "Experiment ID = $eid"
            }
            TERMINATING_EXP {
                progress::instantiate    "Terminating experiment ..." \
                                                "Deleting virtual nodes and links." \
                                                $msg \
                                                $msg
            }
            DECR {
                progress::decrement $msg
            }
            EXP_TERMINATED {
                progress::kill $msg
            }
        }
    }
}