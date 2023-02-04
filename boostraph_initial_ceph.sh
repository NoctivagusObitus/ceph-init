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
		ms bind ipv4 = false
		mon initial members = ${HOSTNAME}
        mon host = ${IP_ADDR}
		public network = fdff:f:f:e::/64
		ms bind ipv6 = true # when using ipv6
		auth_cluster required = cephx
		auth service required = cephx
		auth client required = cephx
		auth allow insecure global id reclaim = false
		osd journal size = 1024
		osd pool default size = 3
		osd pool default min size = 2
		osd pool default pg num = 333
		osd pool default pgp num = 333
		osd crush chooseleaf type = 1

#[mon.${HOSTNAME}]
#        host = ${IP_ADDR}
#        mon addr = ${HOSTNAME}:6789
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

sudo -u ceph mkdir "${DATA_DIR}"
sudo -u ceph ceph-mon --mkfs -i "${HOSTNAME}" --monmap "${MONAP}" --keyring "${CLUSTER_KEY_PATH}"

# start ceph
ceph-mon --id "${HOSTNAME}" --cluster "${CLUSTER_NAME}" --setuser ceph --setgroup ceph
