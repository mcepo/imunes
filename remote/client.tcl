
source ./remote/common.tcl

namespace eval remote {
    namespace eval client {
        
        set IMUNES_SSH_KEY_FILE imunes

        set recieved 0

#****f* client.tcl/connect
# NAME
#   connect -- connect to server
# SYNOPSIS
#   remote::client::connect $newServer
# FUNCTION
#   Checks if the connection to the requested server exists, if so reuses it
#   else open a new TCP connection to the server
# INPUTS
#   * newServer -- ip of the server that we are trying to connect to
# RESULT
#   * channel -- TCP socket to the server or -1 if connection doesn't exists
#****
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

#****f* client.tcl/dataHandler
# NAME
#   dataHandler -- handles all incomming messages from server
# SYNOPSIS
#   remote::client::dataHandler $ip $channel
# FUNCTION
#   Since the server must be able to send information and commands to the client,
#   client must maintain open two way connectin to server
#   This procedure handles all incomming messages from server
# INPUTS
#   * ip -- ip of server connected to
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
## returning the response, if required
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

#****f* client.tcl/disconnect
# NAME
#   disconnect -- disconnects client from server
# SYNOPSIS
#   remote::client::disconnect
# FUNCTION
#   Disconnects the client and all the topologies from the server
#****
        proc disconnect {} {
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] ip channel remoteCfg
            remote::common::write $channel "$remoteCfg#false#remote::daemon::disconnect"
            set remote {}
            updateProjectMenu
            remote::common::debug
        }

#****f* client.tcl/updateCurCfg
# NAME
#   updateCurCfg -- sends current config to the server if connected
# SYNOPSIS
#   remote::client::updateCurCfg
# FUNCTION
#   Checks if the current configuration is connected to the server, and if so sends
#   configuration to the server
#   Call this procedure whenever there are changes made to the current configuration
#****

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

#****f* client.tcl/updateCfg
# NAME
#   updateCfg -- receives new configuration for an existing topology from server 
# SYNOPSIS
#   remote::client::updateCfg $base64EncodedCfg
# FUNCTION
#   When there is a change in the topology that client is connected to on the server side
#   the server sends this command and updates the topology on client
#****

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

#****f* client.tcl/sendCfg
# NAME
#   sendCfg - sends the current configuration in $curCfg to the server
# SYNOPSIS
#   remote::client::sendCfg $server
# FUNCTION
#   Sends the current configuration in $curCfg to the server
# INPUTS
#   * server -- ip of the server that we are sending the configuration to
#****

        proc sendCfg { server } {
            set channel [ remote::client::connect $server]
            if { $channel == -1 } return

            remote::common::sendCfg $server $channel $::curcfg
            set ::cf::[set ::curcfg]::buff {}
            interface::output "INFO" "Configuration connected to $server"
        }

#****f* client.tcl/setExpParam
# NAME
#   setExpParam - helper function for setting current config execution parameters
# SYNOPSIS
#   remote::client::setExpParam $eid
# FUNCTION
#   Sets current configuration parameters for execution mode. Used when a remote client
#   changes the oper_mode of a topology. The server then sends this command to
#   all the clients connected to the topology to inform them of topology operation
#   mode change
# INPUTS
#   * eid -- experiment id
#****

        proc setExpParam { eid } {
            set ::cf::[set ::curcfg]::eid $eid
            set ::cf::[set ::curcfg]::oper_mode exec
        }

#****f* client.tcl/removeExpParam
# NAME
#   removeExpParam - helper function for setting current config edit parameters
# SYNOPSIS
#   remote::client::removeExpParam
# FUNCTION
#   Sets current configuration parameters for edit mode. Used when a remote client
#   changes the oper_mode of a topology. The server then sends this command to
#   all the clients connected to the topology to inform them of topology operation
#   mode change
#****

        proc removeExpParam {} {
            set ::cf::[set ::curcfg]::eid ""
            set ::cf::[set ::curcfg]::oper_mode edit
        }

#****f* client.tcl/startWiresharkOnNodeIfc
# NAME
#   startWiresharkOnNodeIfc - starts a wireshark on specified node
# SYNOPSIS
#   remote::client::startWiresharkOnNodeIfc $node $ifc
# FUNCTION
#   Opens a ssh connection to the server where the node is located
#   and starts a tcpdump on the connected node and pipes the tcpdump output
#   back to wireshark
#   wireshark is executed localy on the client mashine and displayes the tcpdump output
# INPUTS
#   * node -- id of the node being used
#   * ifc -- interface on which to monitor traffic with tcpdump
#****

## for wireshark to work special privileges need to be set on client side
## the easiest way is to run client imunes with root privileges
        proc startWiresharkOnNodeIfc { node ifc } {
            upvar 0 ::cf::[set ::curcfg]::eid eid
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lassign [lindex $remote 0] server channel remoteCfgId
            upvar 0 remote::client::IMUNES_SSH_KEY_FILE KEY_FILE 

            exec ssh -i $::env(HOME)/.ssh/$KEY_FILE $remote::common::IMUNES_USER@$server \
                    "sudo docker exec $eid.$node tcpdump -s 0 -U -w - -i $ifc" 2>/dev/null |\
                     wireshark -k -i - &
        }

#****f* client.tcl/startTcpdumpOnNodeIfc
# NAME
#   startTcpdumpOnNodeIfc - starts a tcpdump on specified node
# SYNOPSIS
#   remote::client::startTcpdumpOnNodeIfc $node $ifc
# FUNCTION
#   Opens a ssh connection to the server where the node is located
#   and starts a tcpdump on the connected node and displays the dump in a shell
# INPUTS
#   * node -- id of the node being used
#   * ifc -- interface on which to monitor traffic with tcpdump
#****

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

#****f* client.tcl/spawnShell
# NAME
#   spawnShell - opens a shell on a remote node
# SYNOPSIS
#   remote::client::spawnShell $node $shell
# FUNCTION
#   Opens a ssh connection to the server where the node is located
#   and opens on interactive shell on that node
# INPUTS
#   * node -- id of the node being used
#   * shell -- type of shell to open
#****

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
