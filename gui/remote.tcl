proc setServerPopup { } {

    upvar 0 ::cf::[set ::curcfg]::remote remote
    lassign [lindex $remote 0] server channel remoteCfg
## DEBUG - to ease up the development
if { $server != "" } {
    set tempServer $server
} else {
    set tempServer 127.0.0.1
}

    set w .entry1
    catch {destroy $w}
    toplevel $w
    wm transient $w .
    #wm resizable $w 0 0
    wm title $w "Set server IP"
    wm iconname $w "Server IP"
    grab $w

    #dodan glavni frame "ipv4frame"
    ttk::frame $w.ipv4frame
    pack $w.ipv4frame -fill both -expand 1

    ttk::label $w.ipv4frame.msg -text "Server IP:"
    pack $w.ipv4frame.msg -side top

    ttk::entry $w.ipv4frame.e1 -width 27 -validate focus -invalidcommand "gui::editor::focusAndFlash %W"
    $w.ipv4frame.e1 insert 0 $tempServer
    pack $w.ipv4frame.e1 -side top -pady 5 -padx 10 -fill x

 #   $w.ipv4frame.e1 configure -invalidcommand {checkIPv4Net %P}

    ttk::frame $w.ipv4frame.buttons
    pack $w.ipv4frame.buttons -side bottom -fill x -pady 2m
    if { $server == "" } {
        ttk::button $w.ipv4frame.buttons.connect -text "Connect configuration" -command "connectToServer $w"
        pack $w.ipv4frame.buttons.connect -side left -expand 1 -anchor e -padx 2
        bind $w <Key-Return> "connectToServer $w"
    } else {
        bind $w <Key-Return> "disconnectFromServer $w"
        ttk::button $w.ipv4frame.buttons.disconnect -text "Disconnect configuration" -command "disconnectFromServer $w"
        pack $w.ipv4frame.buttons.disconnect -side left -expand 1 -anchor e -padx 2
    }
    ttk::button $w.ipv4frame.buttons.download -text "Download configurations" -command "downloadConfigurations $w"
    ttk::button $w.ipv4frame.buttons.cancel -text "Cancel" -command "destroy $w"

    bind $w <Key-Escape> "destroy $w"

    pack $w.ipv4frame.buttons.download -side left -expand 1 -anchor e -padx 2
    pack $w.ipv4frame.buttons.cancel -side right -expand 1 -anchor w -padx 2
}

proc connectToServer { w } {

    set newServer [$w.ipv4frame.e1 get]

    if { [ string length $newServer ] == 0 } {
        focusAndFlash .entry1.ipv4frame.e1
        return
    }
    interface::output "INFO" "Conecting to server $newServer ..."
    remote::client::sendCfg $newServer
    destroy $w
}

proc disconnectFromServer { w } {

    remote::client::disconnect
    destroy $w

    interface::output "INFO" "Configuration disconnected from server."
}

proc downloadConfigurations { w } {
    set newServer [$w.ipv4frame.e1 get]

    if { [ string length $newServer ] == 0 } {
        focusAndFlash .entry1.ipv4frame.e1
        return
    }
    remote::client::downloadCfgs $newServer
    destroy $w
    
    interface::output "INFO" "Downloaded all configurations from $newServer:10000."

}

