# vim: set ts=8 noexpandtab:

TCLSH?=	/usr/local/bin/tclsh8.7
REPO=	fossil info | grep ^repository | awk '{print $$2}'

test:
	${TCLSH} tests/all.tcl -verbose tp

git:
	@if [ -e git-import ]; then \
	    echo "The 'git-import' directory already exists"; \
	    exit 1; \
	fi; \
	git init git-import && cd git-import && \
	fossil export --git --rename-trunk master --repository `${REPO}` | \
	git fast-import && git reset --hard HEAD && \
	git remote add origin git@github.com:gahr/tcl-dav.git && \
	git push -f origin master && \
	cd .. && rm -rf git-import

