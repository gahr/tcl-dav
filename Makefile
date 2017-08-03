TCLSH?=	/usr/local/bin/tclsh8.7
PACKAGE=	dav
VERSION=	0.1.0

test:
	${TCLSH} tests/all.tcl -verbose tp
