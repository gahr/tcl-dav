#!/usr/local/bin/tclsh8.7

# This script can be used as mutt_query command to fetch contact information
# from a CalDAV server. Example:
# set query_command="~/bin/mutt-query.tcl -url https://dav.example.com -user $my_user -pass $my_pass -search %s"

tcl::tm::path add [file dirname [file dirname [info script]]]
package require dav::carddav

proc get_param {param} {
    set idx [lsearch $::argv "-$param"]
    if {$idx != -1} {
        return [lindex $::argv $idx+1]
    } else {
        return {}
    }
}

proc get_param_or_query {param msg {echo on}} {
    set txt [get_param $param]
    if {$txt eq {}} {
        if {[string is false -strict $echo]} {
            set stty_save [exec stty -g]
            exec stty -echo
        }
        puts -nonewline stderr "$msg: "
        flush stderr
        gets stdin txt
        if {[string is false -strict $echo]} {
            exec stty $stty_save
            puts stderr {}
        }
    }
    return $txt
}

set url  [get_param_or_query url "URL"]
set user [get_param_or_query user "Username"]
set pass [get_param_or_query pass "Password" off]
set search [get_param_or_query search "Search"]
set verbose [get_param verbose]

puts ""

CardDAV create cdav $url
cdav setUser $user
cdav setPass $pass
cdav setVerbose $verbose
set entries [list]
foreach abook [cdav getAddressBooks] {
    cdav fillAddressBook $abook {FN NICKNAME EMAIL} [list $search]
    foreach vcard [$abook getVCards] {
        set name [$vcard getFirstValue FN]
        foreach email [$vcard getItems EMAIL] {
            lappend entries [list [$email getValue] $name [$email getParam TYPE]]
        }
    }
}

foreach e [lsort -index 1 $entries] {
    puts [join $e "\t"]
}

# vim: set ts=4 sw=4 expandtab:
