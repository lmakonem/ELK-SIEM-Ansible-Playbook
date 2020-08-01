#!/bin/sh
#TODO.md

if [ "$1" = "-v" ]; then
  ANSIBLE_VERSION="${2}"
fi

yum_makecache_retry() {
  tries=0
  until [ $tries -ge 5 ]
  do
    yum makecache && break
    let tries++
    sleep 1
  done
}

wait_for_cloud_init() {
  while pgrep -f "/usr/bin/python /usr/bin/cloud-init" >/dev/null 2>&1; do
    echo "Waiting for cloud-init to complete"
    sleep 1
  done
}

dpkg_check_lock() {
  while fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
    echo "Waiting for dpkg lock release"
    sleep 1
  done
}

apt_install() {
  dpkg_check_lock && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    -o DPkg::Options::=--force-confold -o DPkg::Options::=--force-confdef "$@"
}

if [ "x$KITCHEN_LOG" = "xDEBUG" ] || [ "x$OMNIBUS_ANSIBLE_LOG" = "xDEBUG" ]; then
  export PS4='(${BASH_SOURCE}:${LINENO}): - [${SHLVL},${BASH_SUBSHELL},$?] $ '
  set -x
fi

if [ ! "$(which ansible-playbook)" ]; then
  if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ] || [ -f /etc/oracle-release ] || [ -f /etc/system-release ]; then

    # Install required Python libs and pip
    # Fix EPEL Metalink SSL error
    # - workaround: https://community.hpcloud.com/article/centos-63-instance-giving-cannot-retrieve-metalink-repository-epel-error
    # - SSL secure solution: Update ca-certs!!
    #   - http://stackoverflow.com/q/26734777/645491#27667111
    #   - http://serverfault.com/q/637549/77156
    #   - http://unix.stackexchange.com/a/163368/7688
    yum -y install ca-certificates nss
    yum clean all
    rm -rf /var/cache/yum
    yum_makecache_retry
    yum -y install epel-release
    # One more time with EPEL to avoid failures
    yum_makecache_retry

    yum -y install python-pip PyYAML python-jinja2 python-httplib2 python-keyczar python-paramiko git
    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      yum -y install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi

    # Install passlib for encrypt
    yum -y groupinstall "Development tools"
    yum -y install sshpass libffi-devel openssl-devel && pip install pyrax pysphere boto passlib dnspython

    # Install Ansible module dependencies
    yum -y install bzip2 file findutils git gzip hg svn sudo tar which unzip xz zip
    [ ! -n "$(grep ':8' /etc/system-release-cpe)" ] && yum -y install libselinux-python python-devel MySQL-python
    [ -n "$(grep ':8' /etc/system-release-cpe)" ] && yum -y install python36-devel python3-PyMySQL python3-pip
    [ -n "$(yum search procps-ng)" ] && yum -y install procps-ng || yum -y install procps

  elif [ -f /etc/debian_version ] || grep -qi ubuntu /etc/lsb-release || grep -qi ubuntu /etc/os-release; then
    wait_for_cloud_init
    dpkg_check_lock && apt-get update -q

    # Install required Python libs and pip
    apt_install python-pip python-yaml python-jinja2 python-httplib2 python-netaddr python-paramiko python-pkg-resources libffi-dev
    [ -n "$( dpkg_check_lock && apt-cache search python-keyczar )" ] && apt_install python-keyczar
    dpkg_check_lock && apt-cache search ^git$ | grep -q "^git\s" && apt_install git || apt_install git-core

    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      apt_install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi
    # If python-keyczar apt package does not exist, use pip
    [ -z "$( apt-cache search python-keyczar )" ] && sudo pip install python-keyczar

    # Install passlib for encrypt
    apt_install build-essential
    # [ X`lsb_release -c | grep trusty | wc -l` = X1 ] && pip install cryptography==2.0.3
    apt_install python-all-dev python-mysqldb sshpass && pip install pyrax pysphere boto passlib dnspython pyopenssl

    # Install Ansible module dependencies
    apt_install bzip2 file findutils git gzip mercurial procps subversion sudo tar debianutils unzip xz-utils zip python-selinux python-boto

  elif [ -f /etc/SuSE-release ] || grep -qi opensuse /etc/os-release; then
    zypper --quiet --non-interactive refresh

    # Install required Python libs and pip
    zypper --quiet --non-interactive install libffi-devel openssl-devel python-devel perl-Error python-xml rpm-python
    zypper --quiet --non-interactive install git || zypper --quiet --non-interactive install git-core

    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      zypper --quiet --non-interactive install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi

  elif [ -f /etc/fedora-release ]; then
    # Install required Python libs and pip
    dnf -y install gcc libffi-devel openssl-devel python-devel

    # If python-pip install failed and setuptools exists, try that
    if [ -z "$(which pip)" ] && [ -z "$(which easy_install)" ]; then
      dng -y install python-setuptools
      easy_install pip
    elif [ -z "$(which pip)" ] && [ -n "$(which easy_install)" ]; then
      easy_install pip
    fi

  else
    echo 'WARN: Could not detect distro or distro unsupported'
    echo 'WARN: Trying to install ansible via pip without some dependencies'
    echo 'WARN: Not all functionality of ansible may be available'
  fi

  pip install -q six --upgrade
  mkdir -p /etc/ansible/
  printf "%s\n" "[local]" "localhost" > /etc/ansible/hosts
  set -x
  if [ -z "$ANSIBLE_VERSION" -a -n "$(which pip3)" ]; then
    pip3 install -q ansible
  elif [ -n "$(which pip3)" ]; then
    pip3 install -q ansible=="$ANSIBLE_VERSION"
  elif [ -z "$ANSIBLE_VERSION" ]; then
    pip install -q ansible
  else
    pip install -q ansible=="$ANSIBLE_VERSION"
  fi
  [ -n "$(grep ':8' /etc/system-release-cpe)" ] && ln -s /usr/local/bin/ansible /usr/bin/
  [ -n "$(grep ':8' /etc/system-release-cpe)" ] && ln -s /usr/local/bin/ansible-playbook /usr/bin/
  set +x
  if [ -f /etc/centos-release ] || [ -f /etc/redhat-release ] || [ -f /etc/oracle-release ] || [ -f /etc/system-release ]; then
    # Fix for pycrypto pip / yum issue
    # https://github.com/ansible/ansible/issues/276
    if  ansible --version 2>&1  | grep -q "AttributeError: 'module' object has no attribute 'HAVE_DECL_MPZ_POWM_SEC'" ; then
      echo 'WARN: Re-installing python-crypto package to workaround ansible/ansible#276'
      echo 'WARN: https://github.com/ansible/ansible/issues/276'
      pip uninstall -y pycrypto
      yum erase -y python-crypto
      yum install -y python-crypto python-paramiko
    fi
  fi

fi
