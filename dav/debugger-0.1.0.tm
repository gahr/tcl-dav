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
package provide debugger 0.1.0

oo::class create Debugger {
    ##
    # Debug filter
    method Debug {args} {
        variable d_indent
        incr d_indent
        set indent [join [lrepeat $d_indent " "]]
        puts stderr "$indent -> [self target]: $args"
        set res [next {*}$args]
        puts stderr "$indent <- $res"
        incr d_indent -1
        set res
    }

    method debug {obj} {
        oo::objdefine $obj mixin -append [self class]
        oo::objdefine $obj filter Debug
    }

    method undebug {obj} {
        oo::objdefine $obj mixin -set \
            {*}[lsearch -all -inline -not -exact \
                [info object mix $obj] [self class]]
        oo::objdefine $obj filter -set \
            {*}[lsearch -all -inline -not -exact \
                [info object fil $obj] Debug]
    }
}
