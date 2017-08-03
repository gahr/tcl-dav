#!/usr/bin/env tclsh

package require tcltest
set dir [file dirname [info script]]

::tcltest::configure {*}$argv \
    -testdir $dir \
    -loadfile [file join $dir common.tcl] \
    -file "t.*.tcl"

::tcltest::runAllTests
