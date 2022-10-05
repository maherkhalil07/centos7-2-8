# Upgrade CentOS 7 Hosts to CentOS 8
# Installs kernel from ElRepo for compatibility with deprecated hardware
#
# Instructions sourced from:
# https://www.centlinux.com/2020/01/how-to-upgrade-centos-7-to-8-server.html
# https://www.tecmint.com/upgrade-centos-7-to-centos-8/
#
# * We don't do rpmconf -a because this is on a clean, freshly installed 7
# * We do a package-cleanup at the end with dnf autoremove
# * Most guides have you just call package-cleanup which just lists packages
#   anyway and doesn't actually perform any action, so it wasn't included.
# * Most guides for removing old kernels with dnf will have you use 
#   dnf remove', but using rpm gets around the 'kernel is a protected package'
#   response.
# * Need to reset python location after we perform dist upgrade, otherwise
#   subsequent module execution will fail
# * Install ELRepo kernel for more driver support (I'm using legacy hardware)
#
# --- BEGIN MIT LICENSE ---
# Copyright (c) 2020 Ryan Drew 
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# --- END MIT LICENSE ---
#
- name: Upgrade CentOS 7 to CentOS 8
  hosts: all
  become: yes
  tasks:
    - name: Install dnf
      yum:
        state: latest
        name: dnf
    - name: Remove yum
      dnf:
        state: removed
        name:
          - yum
          - yum-metadata-parser
    - name: Remove yum config directory
      file:
        state: absent
        path: '/etc/yum'

    - name: Perform a dnf upgrade
      command: 'dnf upgrade -y'

    - name: Upgrade centos release, repos and gpg keys from 7 to 8
      dnf:
        state: latest
        name: 
          - 'http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/centos-repos-8.2-2.2004.0.1.el8.x86_64.rpm'
          - 'http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/centos-release-8.2-2.2004.0.1.el8.x86_64.rpm'
          - 'http://mirror.centos.org/centos/8/BaseOS/x86_64/os/Packages/centos-gpg-keys-8.2-2.2004.0.1.el8.noarch.rpm'
    - name: Remove old kernels
      shell: 'rpm -e `rpm -q kernel`'
    - name: Remove conflicting packages
      shell: 'rpm -e sysvinit-tools --nodeps'
    - name: Perform distro-sync using dnf 
      command: 'dnf -y --releasever=8 --allowerasing --skip-broken --setopt=deltarpm=false distro-sync'

    - name: Set ansible_python_interpreter variable 
      set_fact:
        ansible_python_interpreter: '/usr/libexec/platform-python'

    - name: Install ELRepo repository gpg key
      rpm_key:
        state: present
        key: 'https://www.elrepo.org/RPM-GPG-KEY-elrepo.org'
    - name: Install ELRepo for CentOS 8
      dnf:
        state: latest
        name: 'https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm'
    - name: Install ELRepo kernel
      dnf:
        enablerepo: "elrepo-kernel"
        state: latest
        name:
          - kernel-ml
          - kernel-ml-core
          - kernel-ml-devel
          - kernel-ml-headers
          - kernel-ml-modules
    - name: Reboot the machine
      reboot:
