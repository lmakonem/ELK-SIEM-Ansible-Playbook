# ELK-SIEM-Ansible-Playbook
Ansible Playbook to install the ELK Stack. To use this playbook follow these steps:

1) Clone it in your /etc/ansible folder
2) change the ip addresses from 192.168.5.71 to your SIEM IP addresses in the site.yml file
3) Run the Playbook site.yml
4) Sign into kibana at http://yoursiemip:5601
6)Next, get some data in your siem.

Requirements:
1) Ansible on a VM or docker container.
2)Ubuntu VM for installing the ELK SIEM.
For a sample lab deployment, see mine here( and follow the whole series where i show you how to deploy ELK SIEM lab for detection):
https://www.youtube.com/watch?v=IwlV3wVX4xs&t=32s


NB we will improve this playbook in the future to include roles and variables, for now lets keep it simple and use the site.yml.
