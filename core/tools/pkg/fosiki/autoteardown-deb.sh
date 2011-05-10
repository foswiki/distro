#!/bin/sh

#
# This script is run as root on the build host after the Debian
# package is built.  It may be used to test installing the resulting
# binaries or to clean up.
#

branchdir="$1"
debdir="$2"
