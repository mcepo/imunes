source remote/common.tcl

namespace eval remote {
    namespace eval daemon {

#****f* daemon.tcl/start
# NAME
#   start -- starts the daemon
# SYNOPSIS
#   remote::daemon::start
# FUNCTION
#   Starts daemon and enters in a forever loop.
#****  

        proc start { } {

            remote::daemon::loadRunningExperiments
            remote::daemon::startServer

            remote::common::myIp
            remote::common::debug
            vwait forever
        }

#****f* daemon.tcl/startServer
# NAME
#   startServer -- opens a tcp port and starts listening for incomming connections
# SYNOPSIS
#   remote::daemon::startServer
# FUNCTION
#   Opens a tcp port and starts listening for incomming connections
#****  

        proc startServer {} {
            ## starting the server
            puts -nonewline "Starting daemon ...."
            socket -server remote::daemon::connectionHandler $remote::common::DAEMON_PORT
            puts "STARTED on port $remote::common::DAEMON_PORT"
        }

#****f* daemon.tcl/loadRunningExperiments
# NAME
#   loadRunningExperiments -- loads running experiment for host mashine
# SYNOPSIS
#   remote::daemon::loadRunningExperiments
# FUNCTION
#   When the daemon is started it checks if there are any running experiments
#   on current mashine and it loads all of them in namespaces.
#****  
        proc loadRunningExperiments { } {

            puts -nonewline "Loading running experiments on mashine ..."

            set resumableExperiments [ getResumableExperiments ]
            set count 0
            foreach eid $resumableExperiments {
                set cfg [readDataFromFile "$::runtimeDir/$eid/config.imn"]
                initCfg
                loadCfg $cfg
                set ::cf::[set ::curcfg]::eid $eid
                set ::cf::[set ::curcfg]::oper_mode exec
                incr count
            }
            set ::curcfg ""
            puts "LOADED -> $count running experiments"
        }

#****f* daemon.tcl/connectionHandler
# NAME
#   connectionHandler -- handles new connections from client
# SYNOPSIS
#   remote::daemon::connectionHandler
# FUNCTION
#   When a new client connects to the server this function is called to open a channel
#****  
        proc connectionHandler { channel clientAddress clientPort } {

            puts "New client $clientAddress:$clientPort $channel"
            fconfigure $channel -buffering none
            fileevent $channel readable [list remote::daemon::dataHandler $clientAddress $channel]
remote::common::debug
        }

#****f* daemon.tcl/dataHandler
# NAME
#   dataHandler -- handles all incomming messages from client
# SYNOPSIS
#   remote::daemon::dataHandler $ip $channel
# FUNCTION
#   Server constantly listens for messages from client.
# INPUTS
#   * ip -- ip of client connected to
#   * channel -- TCP socket id
#****

        proc dataHandler { ip channel } {
## setting connection info 
            set remote::common::currChan $channel
            set remote::common::currIp $ip
## getting the data from channel
            set msg [ remote::common::read $channel ]
            if { $msg == -1 || $msg == "" } {
                return
            }
## executing the procedure
            lassign [split $msg "#" ] ::curcfg requireResponse procedure
            set response [ eval $procedure ]
            if {$requireResponse} {
                remote::common::write $channel [ remote::common::encode $response ]
            }

## returnning the response, if any
# two edge cases, when starting a experiment and when terminating experiment
# they need to be evaluated separately
# this could have been done in the procedures deployCfg and terminateAllNodes
# but instead it was done here to avoide aditional change to the imunes core
            if { $procedure == "deployCfg" && $response != -1 } {
                upvar 0 ::cf::[set ::curcfg]::eid eid
                set ::cf::[set ::curcfg]::oper_mode exec
                remote::daemon::writeToAll "remote::client::setExpParam $eid"
    remote::common::debug
            }
            if { $procedure == "terminateAllNodes" && $response != -1 } {
                set ::cf::[set ::curcfg]::oper_mode edit
                remote::daemon::writeToAll "remote::client::removeExpParam" 
    remote::common::debug
            }
            set ::curcfg ""
            return
        }

#****f* daemon.tcl/disconnect
# NAME
#   disconnect -- handles all incomming messages from client
# SYNOPSIS
#   remote::daemon::disconnect $ip $channel
# FUNCTION
#   Server constantly listens for messages from client.
# INPUTS
#   * ip -- ip of client connected to
# RESULT
#   * channel -- TCP socket id
#****

        proc disconnect {} {
            remote::common::removeConnectionsFromCfg $::curcfg $remote::common::currChan
        }

#****f* daemon.tcl/sendCfgs
# NAME
#   sendCfgs -- sends all cfg to client
# SYNOPSIS
#   remote::daemon::sendCfgs
# FUNCTION
#   Sends all topologies currently on server to client when requested from the client.
#****

        proc sendCfgs { } {
            foreach cfg $::cfg_list {
                remote::common::sendCfg $remote::common::currIp $remote::common::currChan $cfg
            }
        }

#****f* daemon.tcl/writeToAll
# NAME
#   writeToAll -- sends a command to all clients connected to current topology
# SYNOPSIS
#   remote::daemon::writeToAll $procedure
# FUNCTION
#   Server sends a procedure call to all clients connected to current topology
# INPUT
#   procedure - to be executed on clients
#****

        proc writeToAll { procedure } {
            upvar 0 ::cf::[set ::curcfg]::remote remote
            foreach client $remote {
                lassign $client ip channel remoteCfgId
                remote::common::write $channel "$remoteCfgId#false#$procedure"
            }
        }

#****f* daemon.tcl/updateCfg
# NAME
#   updateCfg -- when a change is made it updates the configuration
# SYNOPSIS
#   remote::daemon::updateCfg $base64EncodedCfg
# FUNCTION
#   Update the configuration rewriting it with new configuration and sending
#   the new configuration to all clients connected to it.
# INPUT
#   base64EncodedCfg - base64 encoded topology
#****

        proc updateCfg { base64EncodedCfg } {
        
            set cfg [ remote::common::decode $base64EncodedCfg ]
            loadCfg $cfg
            upvar 0 ::cf::[set ::curcfg]::remote remote
            foreach client $remote {
                lassign $client ip channel remoteCfgId
                if {$channel == $remote::common::currChan } { 
                    continue 
                }
                remote::common::write $channel "$remoteCfgId#false#remote::client::updateCfg $base64EncodedCfg"
            }
            return
        }

#****f* daemon.tcl/addSshKey
# NAME
#   addSshKey -- adding a new ssh key from the client
# SYNOPSIS
#   remote::daemon::addSshKey $encodedData
# FUNCTION
#   Adds a ssh key from the client. This is used for connecting 
#   to the nodes in experiment
# INPUT
#   encodedData - base64 encoded ssh key
#****

        proc addSshKey { encodedData } {

            set data [remote::common::decode $encodedData]

            puts -nonewline "Adding new ssh key ... "
            set newPublicKey $data
            lassign [ split $newPublicKey " " ] encType keyHash Comment
            regsub -all {\+} $keyHash "\\+" keyHash

            set existingPublicKeys [readDataFromFile "/home/$remote::common::IMUNES_USER/.ssh/authorized_keys"]
            set fileId [open "/home/$remote::common::IMUNES_USER/.ssh/authorized_keys" a ]

            if { [ regexp "$keyHash" $existingPublicKeys ] == 0 } {
               puts $fileId $newPublicKey
               puts "ADDED"
            } else {
                puts "DUPLICATE (didn't add it)"
            }
            close $fileId
        }
    }
}


# entry point for the daemon
remote::daemon::start
