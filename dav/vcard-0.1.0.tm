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
package provide vcard 0.1.0

namespace eval vcard {
    variable empty "BEGIN:VCARD\nVERSION:3.0\nFN: \nN: ;;;;\nEND:VCARD"
}

##
# This class represents an item (contentline) in a VCard
oo::class create VCardItem {
    variable m_group
    variable m_name
    variable m_params  ;# ((key val) ?(key2 val2) ...?)
    variable m_value

    construct {group name params value} {
        set m_group $group
        set m_name $name
        set m_params $params
        set m_value $value
    }

    method getGroup  {}       { set m_group          }
    method setGroup  {group}  { set m_group $group   }
    method getName   {}       { set m_name           }
    method setName   {name}   { set m_name $name     }
    method getParams {}       { set m_params         }
    method setParams {params} { set m_params $params }
    method getValue  {}       { set m_value          }
    method setValue  {value}  { set m_value $value   }

    ##
    # Return the value of a param
    method getParam {key} {
        set idx [lsearch -index 0 $m_params $key]
        if {$idx != -1} {
            lindex $m_params $idx 1
        }
    }

    ##
    # Return a textual representation of this item
    method serialize {} {
        set txt {}
        if {$m_group ne {}} {
            append txt $m_group.
        }
        append txt $m_name
        foreach param $m_params {
            append txt ";"
            append txt [join $param =]
        }
        append txt ":$m_value\n"
        set txt
    }
}

oo::class create VCard {

    ##
    # The only data member of a VCard object a list of VCardItem objects.
    variable m_items

    ##
    # Construct a VCard object from text representing a VCard.
    constructor {text} {
        my Parse $text
    }

    ##
    # Destruct a VCard object
    destructor {
        foreach item $m_items {
            $item destroy
        }
    }

    ##
    # Invoked when copying a VCard object. Make sure to deep copy all the
    # VCardItem objects.
    method <cloned> {src} {
        set m_items [lmap item \
            [namespace eval [info object namespace $src] set m_items] {
            oo::copy $item
        }]
    }

    ##
    # Return a textual representation of this VCard object.
    method serialize {} {
        # TODO - escape
        set txt {}
        foreach item $m_items {
            append txt [$item serialize]
        }
        set txt
    }

    ##
    # Return a list with the names of all properties defined in this VCard
    # object, with the exception of the VCARD:BEGIN and VCARD:END items, which
    # are not included. Names are returned in sorted order.
    method getNames {} {
        lsort -unique [lmap item [lrange $m_items 1 end-1] {
            $item getName
        }]
    }

    ##
    # Return a list of VCardItem objects having a certain name.
    method getItems {name} {
        lmap item $m_items {
            expr {$name eq [$item getName] ? $item : [continue]}
        }
    }

    ##
    # Return the value of the first item matching a certain name.
    method getFirstValue {name} {
        foreach item $m_items {
            if {$name eq [$item getName]} {
                return [$item getValue]
            }
        }
    }

    ###########################################################################
    ## PRIVATE METHODS
    ###########################################################################

    ##
    # This method produces a regexp to validate and extract tokens from a VCard
    # line, as specified in https://tools.ietf.org/html/rfc2426#section-4.
    method LineRegexp {} {
        string map {
            PNAME  {[-a-zA-Z0-9]+}
            PTEXT  {[\s\x21\x23-\x2b\x2d-\x39\x3c-\x7e\x80-\xff]*}
            QSTR   {"[\s\x21\x23-\x7e\x80-\xff]*"}
            VAL    {[\s\x21-\x7e\x80-\xff]*}
        } {(?x)
            # The above modifier allows for extended syntax.
            ^
            # An optional group followed by a dot. The dot is not captured.
            (?:(PNAME)\.)?

            # Name
            (PNAME)

            # Optional parameters, separated from the name by a semicolon.
            # Parameters can have multiple values, separated by commas. The
            # initial semicolon is not captured.
            (
                (?:
                    ;
                    # Param name
                    PNAME
                    =
                    # One or more param values (ptext or quoted-string),
                    # separated by commas
                    (?:PTEXT|QSTR)(?:,PTEXT|QSTR)*
                )*
            )
            # A colon followed by the value
            : (VAL)
            $
        }
    }

    ##
    # Parse the text of a VCard
    method Parse {vcard} {
        set m_items [list]

        # Split into lines
        set lines [lmap l [split [string map {"\r\n" "\n"} $vcard] "\n"] {
            if {![llength $l]} { 
                continue
            }
            set l
        }]

        # Unfold continuation lines
        for {set i 0} {$i < [llength $lines]} {incr i} {
            set line [lindex $lines $i]
            if {[regexp {^\s} $line]} {
                incr i -1
                lset lines $i "[lindex $lines $i][string trimleft $line]"
                set lines [lreplace $lines $i+1 $i+1]
            }
        }

        foreach l $lines {
            my ParseLine $l group name params value

            # Unescape value
            set value [string map { \\n \n \\, , \\ \ } $value]

            # Split params
            set plist [list]
            if {[llength $params]} {
                set pitems [split $params {;=}]
                # Make sure we have an odd number of elements and that the
                # first item is empty (params begin with a ;)
                if {[expr {[llength $pitems] % 2 == 0}] ||
                    [lindex $pitems 0] ne {}} {
                    return -code error "Invalid VCard params: $params"
                }
                for {set i 1} {$i < [llength $pitems]} {incr i 2} {
                    lappend plist [lrange $pitems $i $i+1]
                }
            }

            # Some props's values need post-processing
            my PostProcess group name plist value
            lappend m_items [VCardItem new $group $name $plist $value]
        }

        my Validate
    }

    ##
    # Extract information from a VCard line
    method ParseLine {line groupVar nameVar paramsVar valueVar} {
        upvar $groupVar  group
        upvar $nameVar   name
        upvar $paramsVar params
        upvar $valueVar  value

        if {![regexp [my LineRegexp] $line _ group name params value]} {
            return -code error "Invalid VCard line: $line"
        }
        if {0} {
            puts "Parsed: <$line>"
            puts "\tregexp: <[my LineRegexp]>"
            puts "\tgroup : <$group>"
            puts "\tname  : <$name>"
            puts "\tparams: <$params>"
            puts "\tvalue : <$value>"
        }
    }

    ##
    # Some VCard need post-processing. Do it here.
    method PostProcess {groupVar nameVar paramsVar valueVar} {
        upvar $groupVar group $nameVar name $paramsVar params $valueVar value
        switch $name {
            BDAY {
                # Apple worksaround the lack of mm-dd only BDAYs in vCard 3 by
                # defaulting to year 1604. See
                # https://github.com/nextcloud/3rdparty/blob/ae67e91/sabre/vobject/lib/VCardConverter.php#L107-L119
                if {![string compare -length 5 $value {1604-}]} {
                    set value [string replace $value 0 3 -]
                }
            }
        }
    }

    ##
    # Semantically validate a VCard, according to the specification at
    # https://tools.ietf.org/html/rfc6350#section-6
    method Validate {} {

        # 6.1.1 BEGIN
        eval {
            set begin [lindex $m_items 0]
            if {[$begin getName] ne {BEGIN} ||
                [$begin getParams] ne {} ||
                ![string equal -nocase [$begin getValue] VCARD]} {
                return -code error "6.1.1 - Invalid BEGIN: $begin"
            }
        }

        # 6.1.2 END
        eval {
            set end [lindex $m_items end]
            if {[$end getName] ne {END} ||
                [$end getParams] ne {} ||
                ![string equal -nocase [$end getValue] VCARD]} {
                return -code error "6.1.2 - Invalid END: $end"
            }
        }

        # 6.1.3 SOURCE
        eval {
            foreach s [my getItems SOURCE] {
                # TODO
            }
        }

        # 6.2.1 FN
        eval {
            set fns [my getItems FN]
            if {![llength $fns]} {
                return -code error "6.2.1 - FN not found"
            }
            foreach fn $fns {
                # TODO
            }
        }

        # 6.2.2 N
        eval {
            set ns [my getItems N]
            if {[llength $ns] > 1} {
                return -code error "6.2.2 - Multiple N lines found"
            }
            foreach n $ns {
                if {![regexp {.*;.*;.*;.*;.*} [$n getValue]]} {
                    return -code error "6.2.2 - Invalid value: [$n serialize]"
                }
            }
        }
    }

}
