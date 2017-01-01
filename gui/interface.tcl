#!/usr/bin/env tclsh

## gui

namespace eval interface {

    proc output { statCode {msg ""} } {

        switch $statCode {
        
            INFO {
                progress::statline $msg
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
## here a decision will be made where the requested procedure will be executed
## locally or remotlly
## dispatch dosn't expect a return value
    proc dispatch { procedure } {

            eval $procedure
    }

## here a decision will be made where the requested procedure will be executed
## locally or remotlly
## get expects a return value from executed procedure
    proc get { procedure {params ""}} {

            return [eval $procedure $params]
    }
}