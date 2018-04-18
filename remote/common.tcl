namespace eval remote {
    namespace eval common {
        
        set DAEMON_PORT 10000
        set IMUNES_USER imunes

        set cfg ""
        set currIp ""
        set currChan ""

#****f* common.tcl/myIp
# NAME
#   myIp -- returns my ip
# SYNOPSIS
#   remote::common::myIp
# FUNCTION
#   Returns my ip address. Used for server.
# RESULT
#   * returns my ip address
#****
        proc myIp {} {
            if { [ catch {
                set myIp 127.0.0.1
                set sid [socket -server none -myaddr [ info hostname ] 0]
                set myIp [lindex [ fconfigure $sid -sockname ] 0]
                ::close $sid
                puts "My IP address is $myIp"
            } err ] } {
                catch { ::close $sid }
                puts stderr "Getting my IP error '$err', using 127.0.0.1"
            }
            return $myIp
        }

#****f* common.tcl/write
# NAME
#   write -- write data to socket
# SYNOPSIS
#   remote::common::write $channel $data
# FUNCTION
#   Writes specified data to specified tcp socket. Also checkes if the socket
#   is closed
# INPUTS
#   * channel -- TCP socket for writing
#   * data -- payload that is being writen to the socket
# RESULT
#   * -1 if failed, 0 if success
#****

        proc write { channel data } {
            if { [ catch { puts $channel $data } error ] } {
                remote::common::close $channel
                return -1
            }
            return 0
        }

#****f* common.tcl/read
# NAME
#   read -- read data from socket
# SYNOPSIS
#   remote::common::read $channel
# FUNCTION
#   Reads data from passed socket. Also checkes if the socket
#   is closed
# INPUTS
#   * channel -- TCP socket for writing
# RESULT
#   * data - that was read from the socket, -1 if failed
#****

        proc read { channel } {
            if { [ eof $channel ] || [ catch { gets $channel data } error ] } {
                remote::common::close $channel
                return -1 
            }
            return $data
        }

#****f* common.tcl/close
# NAME
#   close -- close the socket
# SYNOPSIS
#   remote::common::close $channel
# FUNCTION
#   Close the specified socket
# INPUTS
#   * channel -- TCP socket to be closed
#****

        proc close { channel } {
            catch { fileevent $channel readable "" 
                     ::close $channel
            }
            
            remote::common::removeConnectionsFromCfgs $channel
            puts "Current connection $channel is closed"
remote::common::debug
        }

#****f* common.tcl/encode
# NAME
#   encode -- base64 encoder 
# SYNOPSIS
#   remote::common::encode $cfg 
# FUNCTION
#   Base64 encode topology configuration that is being sent over the network
# INPUTS
#   * data - topology configuration
# RESULT
#   * base64 encoded topology configuration
#****

        proc encode { data } {

            return [ binary encode base64 $data ]
        }

#****f* common.tcl/decode
# NAME
#   decode -- base64 decode
# SYNOPSIS
#   remote::common::decode $encodedData 
# FUNCTION
#   Base64 decode topology configuration that was recieved over the network
# INPUTS
#   * data - encoded topology configuration
# RESULT
#   * base64 decoded topology configuration
#****
        proc decode { encodedData } {
            
            return [ binary decode base64 $encodedData ]
        }

#****f* common.tcl/sendCfg
# NAME
#   sendCfg -- send the topology throu socket 
# SYNOPSIS
#   remote::common::sendCfg $ip $channel $cfgId
# FUNCTION
#   Sending base64 encoded topology to specified socket, checks if the topology
#   is already connected to prevent looping
# INPUTS
#   * ip -- ip of the server that we are sending the topology to
#   * channel -- TCP socket to the server
#   * cfgId -- id of topology being sent to the server
#
#****

        proc sendCfg { ip channel cfgId } {

            upvar 0 ::cf::[set cfgId]::remote remote
            foreach conn $remote {
                lassign $conn connIp connChannel connCfgId
                if { $channel == $connChannel } {
                    return
                }
            }
            set ::curcfg $cfgId
            set remote::common::cfg ""
            dumpCfg string remote::common::cfg
            upvar 0 ::cf::[set cfgId]::eid eid
            upvar 0 ::cf::[set cfgId]::oper_mode oper_mode

            set base64EncodedCfg [ remote::common::encode $remote::common::cfg ]
            remote::common::write $channel "#false#remote::common::addCfg $cfgId $base64EncodedCfg $oper_mode $eid "
            return
        }

#****f* common.tcl/setRemote
# NAME
#   setRemote -- set the remove configuration id to the current configuration
# SYNOPSIS
#   remote::common::setRemote $curCfg $remoteCfgId
# FUNCTION
#   Sets the remove configuration id to the current configuration id. This is basiclly
#   the link between local configuration and the remote configuration
# INPUTS
#   * curCfg -- configuration id on the location from where it was sent
#   * remoteCfgId -- encoded configuration
#
#****

        proc setRemote { curcfg remoteCfgId } {
            upvar 0 ::cf::[set curcfg]::remote remote
            lappend remote [ list $remote::common::currIp $remote::common::currChan $remoteCfgId ]
            remote::common::debug
        }

#****f* common.tcl/addCfg
# NAME
#   addCfg -- add new topology configuration to imunes
# SYNOPSIS
#   remote::common::addCfg $ip $channel $cfgId
# FUNCTION
#   After receiving the new topology configuration from the network
#   this function adds it to the rest of local configurations
# INPUTS
#   * cfgId -- configuration id on the location from where it was sent
#   * base64EncodedCfg -- encoded configuration
#   * oper_mode -- operation mode of the configuration edit/exec used heavily in GUI
#   * eid -- if operation mode is exec eid is set - experiment id
#
#****

        proc addCfg { cfgId base64EncodedCfg  oper_mode {eid ""} } {

            set cfg [ remote::common::decode $base64EncodedCfg ]
            initCfg
            loadCfg $cfg
            set ::cf::[set ::curcfg]::eid $eid
            set ::cf::[set ::curcfg]::oper_mode $oper_mode
            set ::cf::[set ::curcfg]::buff {}
            upvar 0 ::cf::[set ::curcfg]::remote remote
            lappend remote [list $remote::common::currIp $remote::common::currChan $cfgId ]
            remote::common::write $remote::common::currChan "#false#remote::common::setRemote $cfgId $::curcfg"
            return
        }

#****f* common.tcl/isConnected
# NAME
#   isConnected -- check if a client is already connected to the requested server 
# SYNOPSIS
#   remote::common::isConnected $newServer
# FUNCTION
#   Connection information is stored with the topology configuration
#   so when a new topology is being connected to the server first we check
#   if we already have connected topologies to that server, if so we reuse 
#   that same connection for the new topologie being connected to that server
# INPUTS
#   * newServer -- ip of the server that we are trying to connect to
# RESULT
#   * channel -- TCP socket or -1 if connection doesn't exists
#****
        proc isConnected { newServer } {
            foreach cfg $::cfg_list {
                upvar 0 ::cf::[set cfg]::remote remote
                foreach con $remote {
                    lassign $con ip channel cfgId
                    if {$ip == $newServer} {
                        return $channel
                    }
                }
            }
            return -1
        }

#****f* common.tcl/removeConnectionsFromCfgs
# NAME
#   removeConnectionsFromCfgs -- removing closed socket from configurations
# SYNOPSIS
#   remote::common::removeConnectionsFromCfgs $channelSearch
# FUNCTION
#   When a closed socket is detected, this function is called to remove closed socket
#   information from all configurations
# INPUTS
#   * channelSearch -- information of the closed socket
#****

        proc removeConnectionsFromCfgs { channelSearch } {         
            foreach cfg $::cfg_list {
                remote::common::removeConnectionsFromCfg $cfg $channelSearch
            }
            return
        }

#****f* common.tcl/removeConnectionsFromCfg
# NAME
#   removeConnectionsFromCfg -- removing closed socket from configuration
# SYNOPSIS
#   remote::common::removeConnectionsFromCfg $cfg $channelSearch
# FUNCTION
#   When a closed socket is detected, this function is called to remove closed socket
#   information from a given coniguration
# INPUTS
#   * cfg - configuration from which the socket information is being removed
#   * channelSearch -- information of the closed socket
#****
        
        proc removeConnectionsFromCfg { cfg channelSearch } {
            set newRemote {}
            upvar 0 ::cf::[set cfg]::remote remote
            foreach con $remote {
                lassign $con ip channel cfgId
                if {$channelSearch != $channel} {
                    lappend newRemote $con
                }
            }
            set remote $newRemote
            return
        }

#****f* common.tcl/debug
# NAME
#   debug -- for debugging puposes
# SYNOPSIS
#   remote::common::debug
# FUNCTION
#   Dump current configuration information
#****  

        proc debug {} {
            puts "\n *********** DEBUG ************ "
  #          puts "*** List of configurations on this mashine ***" 
  #          puts "cfg_list: $::cfg_list"
  #          puts "curcfg: $::curcfg"
           
            foreach cfg $::cfg_list {
                upvar 0 ::cf::[set cfg]::remote remote
                upvar 0 ::cf::[set cfg]::eid eid
                upvar 0 ::cf::[set cfg]::oper_mode oper_mode
                puts "$cfg $eid $oper_mode -> $remote "
           }

 #           puts "\n*** List of all opened channels, and connected servers ***" 
            puts "cfg_list: $::cfg_list"
            puts "curcfg: $::curcfg"

            puts " *********** DEBUG ************ \n"
        }
    }
}

