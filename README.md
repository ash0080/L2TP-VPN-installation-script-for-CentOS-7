L2TP-VPN-installation-script-for-CentOS-7
=========================================

Test in Azure VM 

How to use:

1. Create a new VM [CENTOS-BASED] -> [Openlogic 7.0]

2. Enable endpoints UDP500, UDP1701, UDP4500

3. Putty to SSH console
4. Run: Sudo yum install wget -y
5. Run: Sudo wget https://raw.githubusercontent.com/twilightgod/L2TP-VPN-installation-script-for-CentOS-7/master/l2tp-ipsec-install-script-for-centos7.sh
6. Run: Sudo chmod +x l2tp-ipsec-install-script-for-centos7.sh
7. Run: Sudo ./l2tp-ipsec-install-script-for-centos7.sh
