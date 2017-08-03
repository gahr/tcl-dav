package require tcltest
::tcltest::loadTestedCommands

package require dav::addressbook

tcltest::test add-get-1.1 {add/get} -body {
    AddressBook create abook mybook
    set v1 [VCard new $::common::data::v1]
    abook addVCard $v1
    set v2 [abook getVCards]
    expr {$v1 eq $v2}
} -cleanup {
    abook destroy
    common::checkLeakedObjects
} -result 1

tcltest::test search-1.1 {search} -body {
    AddressBook create abook mybook
    abook addVCard [VCard new $::common::data::v2]
    abook addVCard [VCard new $::common::data::v3]
    abook addVCard [VCard new $::common::data::v4]
    abook addVCard [VCard new $::common::data::v5]
    set matching [abook searchVCards FN Pietro]
    set out {}
    foreach m $matching {
        append out "[[lindex [$m getItems FN] 0] getValue] "
        append out "<[[lindex [$m getItems EMAIL] 0] getValue]>\n"
    }
    set out
} -cleanup {
    abook destroy
    common::checkLeakedObjects
} -result "Pietro Cerutti <gahr@gahr.ch>\nPietro Cerutti (FreeBSD) <gahr@FreeBSD.org>\n"

tcltest::test copy-1.1 {deep copy} -body {
    AddressBook create abook mybook
    abook addVCard [VCard new $::common::data::v2]
    abook addVCard [VCard new $::common::data::v3]
    abook addVCard [VCard new $::common::data::v4]
    abook addVCard [VCard new $::common::data::v5]
    set v1_txt [lmap vc [abook getVCards] {
        $vc serialize
    }]
    oo::copy abook abook2
    abook destroy
    set v2_txt [lmap vc [abook2 getVCards] {
        $vc serialize
    }]
    expr {$v1_txt eq $v2_txt}
} -cleanup {
    abook2 destroy
    common::checkLeakedObjects
} -result 1

tcltest::cleanupTests
