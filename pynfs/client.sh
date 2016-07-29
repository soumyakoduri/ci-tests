#!/bin/sh
#
# Prepare a NFS-client for pynfs testing
# - install needed tools and libs
# - checkout pynfs from git
# - build pynfs
# - run the NFSv4.0 tests
#

EXPORT=pynfs

# bail out if there is an error
set -e

# enable some debugging
set -x

# variables we expect
[ -n "${NFS_SERVER}" ]
[ -n "${EXPORT}" ]
[ -n "${PYNFS_GIT_REPO}" ]
[ -n "${PYNFS_GIT_BRANCH}" ]

yum -y install git gcc nfs-utils redhat-rpm-config python-devel krb5-devel

#install pynfs test suite
git clone --branch ${PYNFS_GIT_BRANCH} ${PYNFS_GIT_REPO}
cd pynfs
yes  | python setup.py build
cd nfs4.0
./testserver.py \
	${NFS_SERVER}:/${EXPORT} \
	--verbose \
	--maketree \
	--showomit \
	--rundeps all

# implicit exit status from ./testserver.py
