source ./remote/common.tcl

namespace eval remote {
    namespace eval client {
        
        set IMUNES_SSH_KEY_FILE imunes

        set recieved 0

        proc connect { newServer } {
    ## check if the connection to the server already exists
            set channel [ remote::common::isConnected $newServer]
            if { $channel == -1 } {
    ## openning new channel to server
                if { [ catch { set channel [ socket $newServer $remote::common::DAEMON_PORT ] } ] } {

                    interface::output "ERR" "Can't connect to server $newServer:$remote::common::DAEMON_PORT, is the server running?"
                    return -1
                }
                fconfigure $channel -buffering none

    ## saving current connection
                puts "New connection established:\n\tConnection:$channel "
                puts -nonewline "Setting up fileevent ... "
    ## keeping the connection opened
                fileevent $channel readable [ list remote::client::dataHandler $newServer $channel ]
                puts "OK"

## exchanging public keys used for SSH communication with server
                upvar 0 remote::client::IMUNES_SSH_KEY_FILE KEY_FILE

                puts -nonewline "Exchanging public keys with server ... " 

                if {    [file exists $::env(HOME)/.ssh/$KEY_FILE.pub] == 0 
                    ||  [file exists $::env(HOME)/.ssh/$KEY_FILE] == 0 } {
                    exec ssh-keygen -q -t rsa -N "" -f $::env(HOME)/.ssh/$KEY_FILE
                    catch { exec ssh-add $::env(HOME)/.ssh/$KEY_FILE }
                }

                remote::common::write $channel "#false#remote::daemon::addSshKey \
                                                [ remote::common::encode \
                                                    [ readDataFromFile \
                                                        $::env(HOME)/.ssh/$KEY_FILE.pub ] ]"
                puts "OK"
            }
            return $channel
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

            set saved_curcfg $::curcfg
            lassign [split $msg "#" ] ::curcfg requireResponse procedure
            if { $procedure == "" } { 
                return 
            }
            if { [string match "interface::output*" $procedure] } {
                upvar 0 ::cf::[set ::curcfg]::buff buff
                if { $::curcfg != $saved_curcfg } {
                    if {[llength $buff] > 0} {
                        lappend buff $procedure
                    }
                } else {
                    foreach buffedProcedure $buff {
                        eval $buffedProcedure
                    }
                    set buff {}
                    eval $procedure
                }
                if {[string match "*TERMINATING*" $procedure] 
                    || [string match "*STARTING*" $procedure] } {
                    set buff {}
                    lappend buff $procedure
                }
                if {[string match "*TERMINATED*" $procedure] 
                    || [string match "*STARTED*" $procedure] } {
                    set buff {}
                }
                set ::curcfg $saved_curcfg
                return
            }
## returnning the response, if required
            if {$requireResponse} {
                remote::common::write $channel [ eval $procedure ]
            } else {
                eval $procedure
            }
            if { $::curcfg == $saved_curcfg } {
                redrawAll
            }
            updateProjectMenu
            set ::curcfg $saved_curcfg
            return
        }
        
        proc disconnect {} {
## TODO when a client disconnects u must put all configurations in edit mode
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] ip channel remoteCfg
            remote::common::write $channel "$remoteCfg#false#remote::daemon::disconnect"
            set remote {}
            updateProjectMenu
            remote::common::debug
        }

        proc updateCurCfg { } {
            if { $remote::client::recieved == 1 } {
                set remote::client::recieved 0
                return
            }
            upvar 0 ::cf::[set ::curcfg]::remote remote
            if { [llength $remote] == 0 } { return }
            lassign [lindex $remote 0] ip channel remoteCfgId
            set remote::common::cfg ""
            dumpCfg string remote::common::cfg

            set base64EncodedCfg [ remote::common::encode $remote::common::cfg ]
            remote::common::write $channel "$remoteCfgId#false#remote::daemon::updateCfg $base64EncodedCfg"
            return
        }

        proc updateCfg { base64EncodedCfg } {

            set remote::client::recieved 1
            set cfg [ remote::common::decode $base64EncodedCfg ]
            loadCfg $cfg
            return
        }

        proc downloadCfgs { server } {
            set channel [ remote::client::connect $server]
            if { $channel == -1 } return
            remote::common::write $channel "#false#remote::daemon::sendCfgs"
        }

        proc sendCfg { server } {
            set channel [ remote::client::connect $server]
            if { $channel == -1 } return

            remote::common::sendCfg $server $channel $::curcfg
            set ::cf::[set ::curcfg]::buff {}
            interface::output "INFO" "Configuration connected to $server"
        }

        proc setExpParam { eid } {
            set ::cf::[set ::curcfg]::eid $eid
            set ::cf::[set ::curcfg]::oper_mode exec
        }

        proc removeExpParam {} {
            set ::cf::[set ::curcfg]::eid ""
            set ::cf::[set ::curcfg]::oper_mode edit
        }

## it seems like wireshark only works when the client has root priv, when he doesn't
## wireshark starts with error ~"can't read pcap ..." , something like that
#  TODO
        proc startWiresharkOnNodeIfc { node ifc } {
            upvar 0 ::cf::[set ::curcfg]::eid eid
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] server channel remoteCfgId
            upvar 0 remote::client::IMUNES_SSH_KEY_FILE KEY_FILE 

            exec ssh -i $::env(HOME)/.ssh/$KEY_FILE $remote::common::IMUNES_USER@$server \
                    "sudo docker exec $eid.$node tcpdump -s 0 -U -w - -i $ifc" 2>/dev/null |\
                     wireshark -k -i - &
        }
## seems like its working
        proc startTcpdumpOnNodeIfc { node ifc } {
            upvar 0 ::cf::[set ::curcfg]::eid eid
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] server channel remoteCfgId
            upvar 0 remote::client::IMUNES_SSH_KEY_FILE KEY_FILE

#puts "sudo docker exec -it $eid\.$node tcpdump -ni $ifc"

            exec xterm -sb -rightbar -T "IMUNES: $eid\.$node (console)" \
                -e "ssh -t -i $::env(HOME)/.ssh/$KEY_FILE $remote::common::IMUNES_USER@$server \
                    sudo docker exec -it $eid\.$node tcpdump -ni $ifc"  2> /dev/null &
        }
## seems like its working
        proc spawnShell { node shell } {
            upvar 0 ::cf::[set ::curcfg]::eid eid
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] server channel remoteCfgId
            upvar 0 remote::client::IMUNES_SSH_KEY_FILE KEY_FILE

#puts "ssh -t -i $::env(HOME)/.ssh/$KEY_FILE $remote::common::IMUNES_USER@$server sudo docker exec -it $eid\.$node $shell"

            exec xterm -sb -rightbar -T "IMUNES: $eid\.$node (console)" \
                -e "ssh -t -i $::env(HOME)/.ssh/$KEY_FILE $remote::common::IMUNES_USER@$server \
                    sudo docker exec -it $eid\.$node $shell"  2> /dev/null &
        }
    }
}
