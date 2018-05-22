#!/bin/sh

CBSD_WORKDIR=`sysrc -n cbsd_workdir`
SERVICE="${1}"
shift

if [ -z "${SERVICE}" ]; then
  echo "Usage: ${0} <jail>" 2>&1
  exit 1
fi

PLAYBOOK_DIR="${PWD}/playbook"

init() {
  mount_nullfs "${PWD}/puppet/manifests" "${CBSD_WORKDIR}/jails/${SERVICE}/usr/local/etc/puppet/manifests"
}

cleanup() {
  umount "${CBSD_WORKDIR}/jails/${SERVICE}/usr/local/etc/puppet/manifests"
}

trap "cleanup" HUP INT ABRT BUS TERM  EXIT

init
cbsd jexec "jname=${SERVICE}" 'puppet apply /usr/local/etc/puppet/manifests/site.pp'
