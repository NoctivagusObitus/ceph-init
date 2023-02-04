#!/bin/bash

# create ceph keys

CLUSTER_NAME=ceph
HOSTNAME=$(hostname -s)
IP_ADDR=$(hostname -i | tr ' ' '\n' | grep ':' | head -n 1)
FSID=$(uuidgen)
DATA_DIR="/var/lib/ceph/mon/${CLUSTER_NAME}-${HOSTNAME}"

# create minimal ceph config
echo "[global]
		fsid = ${FSID}
		mon initial members = ${HOSTNAME}
        mon host = ${IP_ADDR}
		ms bind ipv6 = true # when using ipv6
		ms bind ipv4 = false
		auth_cluster_required = cephx
		auth_service_required = cephx
		auth_client_required = cephx

[mon.${HOSTNAME}]
        host = ${IP_ADDR}
        mon addr = ${HOSTNAME}:6789
" > /etc/ceph/ceph.conf

ADMIN_KEY_PATH="/etc/ceph/${CLUSTER_NAME}.client.admin.keyring"
BOOTSTRAP_KEY_PATH="/var/lib/ceph/bootstrap-osd/${CLUSTER_NAME}.keyring"
CLUSTER_KEY_PATH=/tmp/ceph.mon.keyring
MONMAP=/tmp/monmap

ceph-authtool --create-keyring "${CLUSTER_KEY_PATH}" --gen-key -n mon. --cap mon 'allow *'
ceph-authtool --create-keyring "${ADMIN_KEY_PATH}" --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
ceph-authtool --create-keyring "${BOOTSTRAP_KEY_PATH}" --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'
ceph-authtool "${CLUSTER_KEY_PATH}" --import-keyring "${ADMIN_KEY_PATH}"
ceph-authtool "${CLUSTER_KEY_PATH}" --import-keyring "${BOOTSTRAP_KEY_PATH}"

chown ceph:ceph "${CLUSTER_KEY_PATH}"

monmaptool --create --add "${HOSTNAME}" "${IP_ADDR}" --fsid "${FSID}" "${MONMAP}"

mkdir -p "${DATA_DIR}"
chown -R ceph:ceph "${DATA_DIR}"

ceph-mon --mkfs -i "${HOSTNAME}" --monmap "${MONAP}" --keyring "${CLUSTER_KEY_PATH}"

# start ceph
ceph-mon --id "${HOSTNAME}" --cluster "${CLUSTER_NAME}" --setuser ceph --setgroup ceph
