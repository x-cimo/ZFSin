#! /bin/ksh -p
#
# CDDL HEADER START
#
# The contents of this file are subject to the terms of the
# Common Development and Distribution License (the "License").
# You may not use this file except in compliance with the License.
#
# You can obtain a copy of the license at usr/src/OPENSOLARIS.LICENSE
# or http://www.opensolaris.org/os/licensing.
# See the License for the specific language governing permissions
# and limitations under the License.
#
# When distributing Covered Code, include this CDDL HEADER in each
# file and include the License file at usr/src/OPENSOLARIS.LICENSE.
# If applicable, add the following below this CDDL HEADER, with the
# fields enclosed by brackets "[]" replaced with your own identifying
# information: Portions Copyright [yyyy] [name of copyright owner]
#
# CDDL HEADER END
#

#
# Copyright 2007 Sun Microsystems, Inc.  All rights reserved.
# Use is subject to license terms.
#

#
# Copyright (c) 2013 by Delphix. All rights reserved.
#

. $STF_SUITE/include/libtest.shlib
. $STF_SUITE/tests/functional/snapshot/snapshot.cfg

#
# DESCRIPTION:
# An archive of a zfs file system and an archive of its snapshot
# is identical even though the original file system has
# changed sinced the snapshot was taken.
#
# STRATEGY:
# 1) Create files in all of the zfs file systems
# 2) Create a tarball of the file system
# 3) Create a snapshot of the dataset
# 4) Remove all the files in the original file system
# 5) Create a tarball of the snapshot
# 6) Extract each tarball and compare directory structures
#

verify_runnable "both"

function cleanup
{
	if [[ -d $CWD ]]; then
		cd $CWD || log_fail "Could not cd $CWD"
	fi

	destroy_dataset $SNAPFS

        if [[ -e $SNAPDIR ]]; then
                log_must $RM -rf $SNAPDIR > /dev/null 2>&1
        fi

        if [[ -e $TESTDIR ]]; then
                log_must $RM -rf $TESTDIR/* > /dev/null 2>&1
        fi

	if [[ -e /tmp/zfs_snapshot2.$$ ]]; then
		log_must $RM -rf /tmp/zfs_snapshot2.$$ > /dev/null 2>&1
	fi

}

log_assert "Verify an archive of a file system is identical to " \
    "an archive of its snapshot."

log_onexit cleanup

typeset -i COUNT=21
typeset OP=create

[[ -n $TESTDIR ]] && \
    $RM -rf $TESTDIR/* > /dev/null 2>&1

log_note "Create files in the zfs filesystem..."

typeset i=1
while [ $i -lt $COUNT ]; do
	log_must $FILE_WRITE -o $OP -f $TESTDIR/file$i \
	    -b $BLOCKSZ -c $NUM_WRITES -d $DATA

	(( i = i + 1 ))
done

log_note "Create a tarball from $TESTDIR contents..."
CWD=$PWD
cd $TESTDIR || log_fail "Could not cd $TESTDIR"
log_must $TAR $pack_opts $TESTDIR/tarball.original.tar file*
cd $CWD || log_fail "Could not cd $CWD"

log_note "Create a snapshot and mount it..."
log_must $ZFS snapshot $SNAPFS

log_note "Remove all of the original files..."
log_must $RM -f $TESTDIR/file* > /dev/null 2>&1

log_note "Create tarball of snapshot..."
CWD=$PWD
cd $SNAPDIR || log_fail "Could not cd $SNAPDIR"
log_must $TAR $pack_opts $TESTDIR/tarball.snapshot.tar file*
cd $CWD || log_fail "Could not cd $CWD"

log_must $MKDIR $TESTDIR/original
log_must $MKDIR $TESTDIR/snapshot

CWD=$PWD
cd $TESTDIR/original || log_fail "Could not cd $TESTDIR/original"
log_must $TAR $unpack_opts $TESTDIR/tarball.original.tar

cd $TESTDIR/snapshot || log_fail "Could not cd $TESTDIR/snapshot"
log_must $TAR $unpack_opts $TESTDIR/tarball.snapshot.tar

cd $CWD || log_fail "Could not cd $CWD"

$DIRCMP $TESTDIR/original $TESTDIR/snapshot > /tmp/zfs_snapshot2.$$
$GREP different /tmp/zfs_snapshot2.$$ >/dev/null 2>&1
if [[ $? -ne 1 ]]; then
	log_fail "Directory structures differ."
fi

log_pass "Directory structures match."
