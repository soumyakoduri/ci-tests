#!/bin/bash

artifact()
{
	[ -e ~/rsync.passwd ] || return 0
	rsync -av --password-file ~/rsync.passwd ${@} gluster@artifacts.ci.centos.org::gluster/nightly/
}

# if anything fails, we'll abort
set -e

# install basic dependencies for building the tarball and srpm
# yum -y install git autoconf automake gcc libtool bison flex make rpm-build mock createrepo_c
yum -y install git autoconf automake gcc libtool bison flex make rpm-build mock createrepo_c
# gluster repositories contain additional -devel packages
yum -y install centos-release-gluster
yum -y install cmake krb5-devel

# clone the repository, github is faster than our Gerrit
#git clone https://review.gluster.org/glusterfs
# git clone https://github.com/gluster/glusterfs
git clone https://github.com/nfs-ganesha/ntirpc.git
pushd ntirpc

# switch to the branch we want to build
# git checkout ${GERRIT_BRANCH}
# repo is configured to checkout latest devel branch, e.g. duplex-13

# generate a version based on branch.date.last-commit-hash
GIT_VERSION="$(git branch | sed 's/^\* //' | sed 's/-//')"
GIT_HASH="$(git log -1 --format=%h)"
VERSION="${GIT_VERSION}.$(date +%Y%m%d).${GIT_HASH}"

# generate the tar.gz archive
sed s/XXVERSIONXX/${VERSION}/ < ../libntirpc.spec.in > libntirpc.spec
tar czf ../ntirpc-${VERSION}.tar.gz --exclude-vcs ../ntirpc
popd

# build the SRPM
rm -f *.src.rpm
SRPM=$(rpmbuild --define 'dist .autobuild' --define "_srcrpmdir ${PWD}" \
	--define '_source_payload w9.gzdio' \
	--define '_source_filedigest_algorithm 1' \
	-ts ntirpc-${VERSION}.tar.gz | cut -d' ' -f 2)

# do the actual RPM build in mock
# TODO: use a CentOS Storage SIG buildroot
RESULTDIR=/srv/gluster/nightly/${GERRIT_BRANCH}/${CENTOS_VERSION}/${CENTOS_ARCH}
/usr/bin/mock \
	--root epel-${CENTOS_VERSION}-${CENTOS_ARCH} \
	--resultdir ${RESULTDIR} \
	--rebuild ${SRPM}

pushd ${RESULTDIR}
createrepo_c .
popd

pushd /srv/gluster/nightly
artifact ${GERRIT_BRANCH}
popd

exit ${RET}

