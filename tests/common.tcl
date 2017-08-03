# vim: ft=tcl ts=4 sw=4 expandtab tw=79 colorcolumn=80

tcl::tm::path add [file dirname [file dirname [info script]]]

package require tcltest

namespace eval common {
    namespace eval data {}

    proc checkLeakedObjects {} {
        package require dav::addressbook
        package require dav::vcard

        set abooks [info class instances AddressBook]
        if {$abooks ne {}} {
            puts [tcltest::errorChannel] "Leaked AddressBook objects: $abooks"
        }
        set vcards [info class instances VCard]
        if {$vcards ne {}} {
            puts [tcltest::errorChannel] "Leaked VCard objects: $vcards"
        }
    }
}

set common::data::v1 {BEGIN:VCARD
VERSION:3.0
N:Myself;;;;
FN:Myself
Family.EMAIL;PREF=1;TYPE=other,home,\"whokn,owsbla\":me@example.com
END:VCARD
}


set common::data::v2 {BEGIN:VCARD
VERSION:3.0
FN:Pietro Cerutti
N:Cerutti;Pietro;;;
EMAIL;TYPE=other:gahr@gahr.ch
END:VCARD
}

set common::data::v3 {BEGIN:VCARD
VERSION:3.0
FN:Pietro Cerutti (FreeBSD)
N:Cerutti;Pietro;;;
EMAIL;PREF=1;TYPE=freebsd:gahr@FreeBSD.org
END:VCARD
}

set common::data::v4 {BEGIN:VCARD
VERSION:3.0
FN:John Doe
N:Doe;John;;Mr;
EMAIL:john@doe.com
END:VCARD
}

set common::data::v5 {BEGIN:VCARD
VERSION:3.0
FN:Unnamed Guy
N:Unnamed;Guy;;;Jr
EMAIL:john@doe.com
END:VCARD
}
