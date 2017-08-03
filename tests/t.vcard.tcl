package require tcltest
::tcltest::loadTestedCommands

package require dav::vcard

tcltest::test parse-1.1 {quoted param} -body {
    VCard create vc $::common::data::v1
    vc serialize
} -cleanup {
    vc destroy
    common::checkLeakedObjects
} -result $::common::data::v1

tcltest::test getNames-1.1 {getNames} -body {
    VCard create vc $::common::data::v1
    vc getNames
} -cleanup {
    vc destroy
    common::checkLeakedObjects
} -result "EMAIL FN N VERSION"

tcltest::test getParam-1.1 {getParam} -body {
    VCard create vc $::common::data::v3
    set item [vc getItems EMAIL]
    set type [$item getParam TYPE]
    expr {"[llength $item] $type"}
} -cleanup {
    vc destroy
    common::checkLeakedObjects
} -result {1 freebsd}

tcltest::test copy-1.1 {deep copy} -body {
    VCard create vc1 $::common::data::v2
    oo::copy vc1 vc2
    set vc1_txt [vc1 serialize]
    vc1 destroy
    set vc2_txt [vc2 serialize]
    expr {$vc1_txt eq $vc2_txt}
} -cleanup {
    vc2 destroy
    common::checkLeakedObjects
} -result 1

tcltest::cleanupTests
