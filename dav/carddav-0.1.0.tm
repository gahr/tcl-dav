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
package require base64
package require http 2
package require tls
package require tdom

package require dav::addressbook 0.1.0

# This class provides functionality to query a CardDAV server.
#
::http::register https 443 ::tls::socket

oo::class create CardDAV {

    variable m_host
    variable m_path
    variable m_user
    variable m_pass
    variable m_head
    variable m_verb
    variable m_abooks ;# Dictionary of (uid -> AddressBook) mappings
    variable m_selectedAddressbook

    ##
    # Construct a CardDAV handler.
    constructor {host} {
        lassign [my ParseSimpleRef $host] m_host m_path
        set m_user {}
        set m_pass {}
        set m_head {}
        set m_verb 0
        set m_abooks [dict create]
        set m_selectedAddressbook {}
        my RebuildHeaders
    }

    ##
    # Cleanup.
    destructor {
        foreach abook [dict values $m_abooks] {
            $abook destroy
        }
    }

    ##
    # Invoked when copying a CardDAV object. Make sure to deep copy all the
    # AddressBook objects.
    method <cloned> {src} {
        set src_ns [info object namespace $src]
        dict for {k v} [namespace eval $src_ns set m_abooks] {
            dict set m_abooks $k [oo::copy $v]
        }
    }

    ##
    # Setters and getters.
    method getHost {} {
        set m_host
    }

    method setPath {path} {
        set m_path $path
    }

    method getPath {} {
        set m_path
    }

    method setUser {user} {
        set m_user $user
        my RebuildHeaders
    }

    method getUser {} {
        set m_user
    }

    method setPass {pass} {
        set m_pass $pass
        my RebuildHeaders
    }

    method getPass {} {
        set m_pass
    }

    method setVerbose {v} {
        set m_verb [string is true -strict $v]
    }

    method getVerbose {} {
        set m_verb
    }

    ##
    # Get a list of addressbooks on the server.
    method getAddressBooks {} {
        my FindEntryPoint
        my GetAddressBooks $m_path
        dict values $m_abooks
    }

    #
    # Fill an addressbook with a list of props.  Optionally, only the VCards
    # for people in the contact list will be filled.
    method fillAddressBook {abook props {contact {}}} {
        my FillAddressBook $abook $props $contact
    }

    ###########################################################################
    ## PRIVATE METHODS
    ###########################################################################

    ##
    # Log a message to stderr, if verbose true appears in the config
    method Log {msg} {
        set fmt {%H:%M:%S}
        if {$m_verb} {
            set t [clock milliseconds]
            set s  [expr {$t / 1000}]
            set ms [format %03d [expr {$t % 1000}]]
            set method [uplevel 1 self method]
            puts stderr "[clock format $s -format $fmt].$ms $method - $msg"
        }
    }

    ##
    # Perform an XPath expression against a node, using the predefined
    # namespaces
    method XPath {node path} {
        $node selectNodes \
            -namespaces {d DAV: card urn:ietf:params:xml:ns:carddav} \
            $path
    }

    method RebuildHeaders {} {
        set m_head [list Content-Type {application/xml; charset=utf-8} Depth 1]
        if {$m_user ne {} && $m_pass ne {}} {
            lappend m_head \
                Authorization "Basic [base64::encode ${m_user}:${m_pass}]"
        }
    }

    ##
    # Parse a Simple-ref, as defined in RFC4918, §8.3. WebDAV only recognizes
    # two form or URLs, absolute URIs and absolute paths. This method extracts
    # the host (formally Scheme + Authority) and the path (formally Path +
    # Query + Fragment) parts of a URI, where the host part could be missing.
    # The path is always returned with a leading slash, even if empty in the
    # original URI.
    # https://tools.ietf.org/html/rfc4918#section-8.3
    method ParseSimpleRef {uri} {
        if {![regexp {([^:]+://[^/]+)?(/.*)?} $uri _ host path]} {
            return -code error "Invalid URI: $uri"
        }
        if {$path eq {}} {
            set path /
        }
        list $host $path
    }

    ##
    # Make an HTTP request against a path specified on the host set via the
    # setHost method.
    method MakeHttpReq {path {method GET} {query {}}} {
        set tok [::http::geturl ${m_host}${path} -method $method \
                                -headers $m_head \
                                -query $query -keepalive 1]
        list [::http::ncode $tok] [::http::code $tok] \
             [::http::meta  $tok] [::http::data $tok]
    }

    ##
    # Find the CardDAV entry point
    method FindEntryPoint {} {
        # If a path was not given, use the .well-known method, otherwise assume
        # it's the correct one
        if {$m_path ne {/}} {
            my Log "using already defined $m_path"
            return
        }

        lassign [my MakeHttpReq "/.well-known/carddav"] ncode _ head
        if {$ncode == 302} {
            if {[catch {dict get $head Location} location]} {
                return -code error \
                    "Response 302 missing Location header"
            }
            lassign [my ParseSimpleRef $location] host m_path
            if {$host eq {}} {
                return -code error \
                    "Response 302's Location header missing absolute URI:\
                    $location"
            }
            my Log "found $m_path"
        }
    }

    ## 
    # Find all addressbook resources within the collection starting at the
    # absolute path specified. The return value is a list of (name href) pairs.
    method GetAddressBooks {path {recursing 1}} {
        set query {
            <propfind xmlns="DAV:">
                <prop>
                    <resourcetype/>
                    <displayname/>
                </prop>
            </propfind>
        }
        lassign [my MakeHttpReq $path PROPFIND $query] ncode code head body
        if {$ncode != 207} {
            return -code error $code
        }

        dom parse $body doc
        $doc documentElement root
        set respPath {/d:multistatus/d:response}
        set collPath {d:propstat/d:prop/d:resourcetype/d:collection}
        set addrPath {d:propstat/d:prop/d:resourcetype/card:addressbook}
        set namePath {d:propstat/d:prop/d:displayname}

        foreach respNode [my XPath $root $respPath] {
            if {[my XPath $respNode $collPath] eq {}} {
                # Not a collection, skip
                continue
            }
            set href [[my XPath $respNode d:href] text]
            if {[my XPath $respNode $addrPath] eq {}} {
                if {$href eq $path} {
                    # Self, skip
                    my Log "Skipping already visited $href"
                    continue
                }
                # Not an addressbook, recurse
                my Log "Recursing at $href"
                my GetAddressBooks $href [incr recursing 3]
            } else {
                # An addressbook, store
                my Log "Found addressbook at $href"
                set name [[my XPath $respNode $namePath] text]
                dict set m_abooks $href [AddressBook new $name $href]
            }
        }
    }

    ##
    # Execute a REPORT request
    method FillAddressBook {abook props contacts} {

        # Open the C:addressbook-query
        set query {
            <C:addressbook-query xmlns:D="DAV:"
                                 xmlns:C="urn:ietf:params:xml:ns:carddav">
         }

         # Open the D:prop and C:address-data elements
         append query {
            <D:prop><C:address-data content-type="text/vcard" version="4.0">
        }

        # Add C:prop elements
        foreach p $props {
            append query {<C:prop name="} $p {"/>}
        }

        # Close the C:address-data and D:prop elements
        append query {</C:address-data></D:prop>}

        # Add C:filter and C:prop-filter elements
        if {$contacts ne {}} {
            append query {<C:filter test="anyof">}
            foreach c $contacts {
                append query {
                    <C:prop-filter name="FN">
                        <C:text-match collation="i;unicode-casemap"
                                      match-type="contains"
                        >} $c {</C:text-match>
                    </C:prop-filter>
                }
            }
            append query {</C:filter>}
        }

        # Close the C:addressbook-query element
        append query {
            </C:addressbook-query>
        }

        my Log "Sending\n$query"

        # Make the request
        lassign [my MakeHttpReq [$abook getUId] REPORT $query] ncode code head body
        if {$ncode != 207} {
            return -code error $code
        }

        my Log "Got response\n$body"

        # Parse the XML response of a REPORT request into a list of VCard
        # objects
        dom parse $body doc
        $doc documentElement root
        set vcards [list]
        set xp {/d:multistatus/d:response/d:propstat/d:prop/card:address-data}
        foreach node [my XPath $root $xp] {
            $abook addVCard [VCard new [$node text]]
        }
    }
}

