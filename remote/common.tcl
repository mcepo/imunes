namespace eval remote {
    namespace eval common {
        
        set DAEMON_PORT 10000
        set IMUNES_USER imunes

        set cfg ""
        set currIp ""
        set currChan ""


# when not connected to network a docker ip will be displayed then use 127.0.0.1
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

        proc write { channel data } {
            if { [ catch { puts $channel $data } error ] } {
                remote::common::close $channel
                return -1
            }
            return 0
        }

        proc read { channel } {
            if { [ eof $channel ] || [ catch { gets $channel data } error ] } {
                remote::common::close $channel
                return -1 
            }
            return $data
        }

        proc close { channel } {
            catch { fileevent $channel readable "" 
                     ::close $channel
            }
            
            remote::common::removeConnectionsFromCfgs $channel
            puts "Current connection $channel is closed"
remote::common::debug
        }

        proc encode { data } {

            return [ binary encode base64 $data ]
        }
        proc decode { encodedData } {
            
            return [ binary decode base64 $encodedData ]
        }

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

        proc setRemote { curcfg remoteCfgId } {
            upvar 0 ::cf::[set curcfg]::remote remote
            lappend remote [ list $remote::common::currIp $remote::common::currChan $remoteCfgId ]
            remote::common::debug
        }

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

        proc removeConnectionsFromCfgs { channelSearch } {         
            foreach cfg $::cfg_list {
                remote::common::removeConnectionsFromCfg $cfg $channelSearch
            }
            return
        }
        
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

