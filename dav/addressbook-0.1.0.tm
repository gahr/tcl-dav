# vim: ft=tcl ts=4 sw=4 expandtab tw=79 colorcolumn=80

##
#  Copyright (C) 2017 Pietro Cerutti <gahr@gahr.ch>
#  
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#  1. Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#  2. Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in the
#     documentation and/or other materials provided with the distribution.
#  
#  THIS SOFTWARE IS PROVIDED BY AUTHOR AND CONTRIBUTORS ``AS IS'' AND
#  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
#  ARE DISCLAIMED.  IN NO EVENT SHALL AUTHOR OR CONTRIBUTORS BE LIABLE
#  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
#  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
#  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
#  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
#  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
#  SUCH DAMAGE.

package require Tcl 8.6
package provide addressbook 0.1.0

package require dav::vcard 0.1.0

oo::class create AddressBook {
    variable m_uid
    variable m_name
    variable m_vcards

    ##
    # Construct an address book with a given name and possibly unique id. If
    # the unique id is not specified, it will default to the name.
    constructor {name {uid {}}} {
        set m_name $name
        set m_uid [expr {$uid ne {} ? $uid : $name}]
        set m_vcards [list]
    }

    ##
    # Destruct an address book.
    destructor {
        foreach v $m_vcards {
            $v destroy
        }
    }

    method <cloned> {src} {
        set src_ns [info object namespace $src]
        set m_vcards [lmap vc [namespace eval $src_ns set m_vcards] {
            oo::copy $vc
        }]
    }

    ##
    # Get the name of this address book.
    method getName {} {
        set m_name
    }

    ##
    # Set the name of this address book.
    method setName {name} {
        set m_name $name
    }

    ##
    # Get the unique id of this address book.
    method getUId {} {
        set m_uid
    }

    ##
    # Set the unique id of this address book.
    method setUId {uid} {
        set m_uid $uid
    }

    ##
    # Add a VCard to the address book. The addressbook takes ownership of this
    # VCard object and will destroy it on destruction.
    method addVCard {vcard} {
        lappend m_vcards $vcard
    }

    ##
    # Get all the VCards in this address book. The addressbook still maintains
    # ownership on the VCards. Please use oo::copy if you need their lifetimes
    # to span beyond that of the AddressBook object.
    method getVCards {} {
        set m_vcards
    }

    ##
    # Return all the VCards having a property matching a value. The property is
    # interpreted verbatim, while the value is a regular expression.
    method searchVCards {prop val} {
        lmap vc $m_vcards {
            set found 0
            foreach fn [$vc getItems $prop] {
                if {[regexp $val [$fn getValue]]} {
                    set found 1
                    break
                }
            }
            expr {$found ? $vc : [continue]}
        }
    }
}
