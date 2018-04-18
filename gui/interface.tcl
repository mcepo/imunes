#!/usr/bin/env tclsh

## gui

namespace eval interface {

#****f* interface.tcl/output
# NAME
#   output -- procedure being invoked from runtime when sending messages
#       about running experiments to user 
# SYNOPSIS
#   output $statCode $msg
# FUNCTION
#   Outputs the info from runtime to the user
# INPUTS
#   * statCode -- message status code, what type of the message is it
#   * msg -- the message that should be displayed to the user
#****

    proc output { statCode {msg ""} } {

        switch $statCode {      
            INFO {

# Show info in the bottom of imunes gui  
                msg::statline $msg
            }
            WARN {

# Show popup warning window
                msg::window "IMUNES warning" $msg
            }
            ERR {

# Show popup error window
               msg::window "IMUNES error" $msg
            }
            STARTING_EXP {

# Show progressbar when starting experiment
                progress::instantiate  "Starting experiment..." \
                                            "Starting up virtual nodes and links." \
                                            $msg \
                                            0
            }
            INCR {
# Incremenet progress in progressbar
                progress::increment $msg
            }
            EXP_STARTED {
# When experiment is started close progressbar, and change editor mode to exec, 
# ie disable editor
                progress::kill $msg
                createExperimentScreenshot
                disableEditor
            }
            TERMINATING_EXP {
# Show progressbar when terminating experiment
                progress::instantiate  "Terminating experiment ..." \
                                            "Deleting virtual nodes and links." \
                                            $msg \
                                            $msg
            }
            DECR {
# Decrement progress in progressbar
                progress::decrement $msg
            }
            EXP_TERMINATED {
# When experiment is terminated close progressbar, and change editor mode to edit,
# ie enable editor
                progress::kill $msg
                enableEditor
            }
        }
    }

#****f* interface.tcl/dispatch
# NAME
#   dispatch -- procedure used to send commands to the runtime
# SYNOPSIS
#   dispatch $procedure
# FUNCTION
#   Sends user commands from user interface to the required runtime, depending
#   on current topology configuration
# INPUTS
#   * procedure -- procedure to be execute on runtime
#****

    proc dispatch { procedure } {

        upvar 0 ::cf::[set ::curcfg]::remote remote
        if {[llength $remote] > 0} {
            lassign [lindex $remote 0] ip channel remoteCfgId
            remote::common::write $channel "$remoteCfgId#false#$procedure"
        } else {
            eval $procedure
        }
    }

#****f* interface.tcl/get
# NAME
#   get -- same as dispatch, but requires a response from the  runtime
# SYNOPSIS
#   get $procedure $params
# FUNCTION
#   Sends user commands from user interface to the required runtime, depending
#   on current topology configuration
# INPUTS
#   * procedure -- procedure to be execute on runtime
#   * params -- parameters of the procedure
# RESULT
#   * returns the output of procedure invoked in runtime
#****

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

#****f* interface.tcl/client
# NAME
#   client -- used when connecting to topology nodes remotly using ssh
# SYNOPSIS
#   client $procedure
# FUNCTION
#   Invoke the commands in remote::client that use ssh to directly connect to topology
#   nodes on server
# INPUTS
#   * procedure -- procedure to be executed
# RESULT
#   * returns the output of procedure invoked in runtime
#****

    proc client { procedure } {
        upvar 0 ::cf::[set ::curcfg]::remote remote
        
        if {[llength $remote] > 0 } {
            return [ eval "remote::client::$procedure"]
        } else {
            return [eval $procedure ]
        } 
    }
}