source remote/common.tcl

namespace eval remote {
    namespace eval daemon {

        proc start { } {

            remote::daemon::loadRunningExperiments
            remote::daemon::startServer

            remote::common::myIp
            remote::common::debug
            vwait forever
        }

        proc startServer {} {
            ## starting the server
            puts -nonewline "Starting daemon ...."
            socket -server remote::daemon::connectionHandler $remote::common::DAEMON_PORT
            puts "STARTED on port $remote::common::DAEMON_PORT"
        }

## when starting the daemon ->
## read all the experiments running on current mashine into namespaces 
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

## handles all new incomming connections
## one connection per client
        proc connectionHandler { channel clientAddress clientPort } {

            puts "New client $clientAddress:$clientPort $channel"
            fconfigure $channel -buffering none
            fileevent $channel readable [list remote::daemon::dataHandler $clientAddress $channel]
remote::common::debug
        }

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

        proc disconnect {} {
            remote::common::removeConnectionsFromCfg $::curcfg $remote::common::currChan
        }

        proc sendCfgs { } {
            foreach cfg $::cfg_list {
                remote::common::sendCfg $remote::common::currIp $remote::common::currChan $cfg
            }
        }

        proc writeToAll { procedure } {
            upvar 0 ::cf::[set ::curcfg]::remote remote
            foreach client $remote {
                lassign $client ip channel remoteCfgId
                remote::common::write $channel "$remoteCfgId#false#$procedure"
            }
        }

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

remote::daemon::start
