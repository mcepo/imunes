#!/usr/bin/env tclsh

# batch

namespace eval msg {

    proc error { msg } {
        puts "\rIMUNES error: $msg"
    }

    proc warning { msg } {
        puts "\rIMUNES warning: $msg"
    }

    proc info { msg } {
        puts "\rIMUNES information: $msg"
    }
}