#!/usr/bin/env tclsh

global argv


## starting an experiment in batch mode
if { $argv != ""} {
    if { ![file exists $argv] } {
        msg::error "file '$argv' doesn't exist"
        exit
    }

    initCfg
    set ::cf::[set ::curcfg]::currentFile $argv
    loadCfg [ readDataFromFile $argv ]
    deployCfg

} else {
## terminating an experiment in batch mode

    global batch_eid
    global runtimeDir
    global regular_termination

    if { [info exists batch_eid] == 0 } {
        msg::warning "You have to specifie Eid."
        return 1
    }

    set configFile "$runtimeDir/$batch_eid/config.imn"
    set ngmapFile "$runtimeDir/$batch_eid/ngnodemap"
    if { [file exists $configFile] && [file exists $ngmapFile] \
        && $regular_termination } {

        initCfg
        upvar 0 ::cf::[set ::curcfg]::ngnodemap ngnodemap
        upvar 0 ::cf::[set ::curcfg]::eid eid

        set eid $batch_eid

        set fileId [open $ngmapFile r]
        array set ngnodemap [gets $fileId]
        close $fileId

        loadCfg [readDataFromFile $configFile]
        terminateAllNodes
    } else {
        vimageCleanup $eid
    }
}