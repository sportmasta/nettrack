# 2026-09-12 19:36:49 by RouterOS 7.21.5
# software id = REDACTED
#
# model = CCR2004-16G-2S+
# serial number = REDACTED
/interface bridge
add name=VPN-bridge
add name=bridge1 vlan-filtering=yes
/interface ethernet
set [ find default-name=ether12 ] comment="NAS-02 BMC (Supermicro)"
set [ find default-name=ether13 ] comment="NAS-01 BMC (Supermicro)"
set [ find default-name=ether14 ] comment="esxi-01 BMC (Lenovo SR650)"
set [ find default-name=ether15 ] comment="VipNet Coordinator HW100"
set [ find default-name=ether16 ] comment=ISP-PHY-Rostelecom
set [ find default-name=sfp-sfpplus1 ] comment=N9K-A.kvanteng.internal
set [ find default-name=sfp-sfpplus2 ] comment=N9K-B.kvanteng.internal
/interface gre
add allow-fast-path=no comment="CAFAP R1" local-address=90.188.224.225 mtu=\
    1400 name=Tun01 remote-address=93.94.178.33
add comment="CAFAP R2" keepalive=5s,3 local-address=90.188.224.225 mtu=1400 \
    name=Tun02 remote-address=176.215.238.126
add comment=toDirect keepalive=5s,3 local-address=90.188.224.225 mtu=1400 \
    name=Tun04 remote-address=95.189.32.202
add allow-fast-path=no comment="Rezviakov S. home office R1" keepalive=5s,3 \
    local-address=90.188.224.225 mtu=1400 name=Tun10 remote-address=\
    5.183.147.235
/interface vlan
add disabled=yes interface=bridge1 name=VLAN1 vlan-id=1
add comment=Networking_OOB_mgmt interface=bridge1 name=VLAN2 vlan-id=2
add comment=Servers_OOB_mgmt interface=bridge1 name=VLAN3 vlan-id=3
add comment=Routing interface=bridge1 name=VLAN9 vlan-id=9
add comment="VipNet coordinator" interface=bridge1 name=VLAN100 vlan-id=100
add disabled=yes interface=bridge1 name=VLAN110 vlan-id=110
/interface bonding
add lacp-rate=1sec mode=802.3ad name=LACP1 slaves=sfp-sfpplus1,sfp-sfpplus2 \
    transmit-hash-policy=layer-3-and-4
/interface list
add name=LAN
add name=WAN
add name=VPN-S2S
add name=VPN-RAS
add name=VPN-Complex
add name=DMZ
add name=VPN-RAS-Employees
add name=VPN-RAS-Contractors
/ip ipsec policy group
add name=VPN-RAS
/ip ipsec profile
set [ find default=yes ] dh-group=modp2048,modp1536,modp1024 dpd-interval=2m \
    dpd-maximum-failures=5 enc-algorithm=aes-256,aes-192,aes-128
add dh-group=modp1024 dpd-interval=2m dpd-maximum-failures=5 enc-algorithm=\
    3des hash-algorithm=md5 name=ipsec
add dh-group=modp4096 dpd-interval=30s dpd-maximum-failures=6 enc-algorithm=\
    aes-256 hash-algorithm=sha256 lifetime=12h name=AES256-SHA256-G16 \
    nat-traversal=no proposal-check=exact
add dh-group=modp4096,modp2048,modp1024,modp768 dpd-interval=10s \
    dpd-maximum-failures=3 enc-algorithm=aes-256,aes-128 lifetime=6h name=\
    VPN-RAS
/ip ipsec peer
add address=176.215.238.126/32 comment="CAFAP R2" exchange-mode=ike2 \
    local-address=90.188.224.225 name=peer2 profile=AES256-SHA256-G16
add address=95.189.32.202/32 comment=Direction exchange-mode=ike2 \
    local-address=90.188.224.225 name=peer4 profile=AES256-SHA256-G16
add address=93.94.178.33/32 comment="CAFAP R1" exchange-mode=ike2 \
    local-address=90.188.224.225 name=peer1 profile=AES256-SHA256-G16
add address=5.183.147.235/32 comment="Rezviakov S.V. home office R1" \
    exchange-mode=ike2 local-address=90.188.224.225 name=peer3 passive=yes \
    profile=AES256-SHA256-G16
add comment="Remote access service" exchange-mode=ike2 name=VPN-RAS passive=\
    yes profile=VPN-RAS send-initial-contact=no
/ip ipsec proposal
add auth-algorithms=md5 enc-algorithms=3des name=ipsec_prop
add auth-algorithms=sha256 enc-algorithms=aes-256-cbc name=\
    AES256CBC-SHA256-G16 pfs-group=modp4096
add auth-algorithms=sha256,sha1 enc-algorithms=aes-256-cbc,aes-128-cbc name=\
    VPN-RAS pfs-group=none
/ip pool
add name=dhcp ranges=192.168.1.10-192.168.1.200,10.110.0.20-10.110.0.25
add name=ovpn ranges=10.10.0.10-10.10.0.100
add name=ipsec ranges=9.0.0.2-9.0.0.20
add comment="VPN Remote access service pool" name=VPN-RAS-Complex ranges=\
    172.16.250.1-172.16.253.250
add name=VPN-RAS-Employees ranges=172.16.255.0/27
add name=VPN-RAS-Contractors ranges=172.16.255.32/27
/ip dhcp-server
# Interface not running
add address-pool=dhcp interface=VLAN1 lease-time=1h name=defconf
/ip ipsec mode-config
add address-pool=VPN-RAS-Employees address-prefix-length=32 name=VPN-RAS \
    split-dns=adds.kvanteng.ru static-dns=10.255.63.210 system-dns=no
/ppp profile
set *0 bridge-learning=no interface-list=VPN-Complex local-address=\
    172.16.255.254 only-one=no use-compression=no use-encryption=yes \
    use-ipv6=no use-mpls=no use-upnp=no
add change-tcp-mss=yes interface-list=VPN-RAS local-address=172.16.0.1 name=\
    SSTPSERVER only-one=no use-compression=yes use-encryption=yes use-mpls=no \
    use-upnp=no
add change-tcp-mss=yes interface-list=VPN-S2S local-address=10.10.0.1 name=\
    ovpn only-one=no remote-address=ovpn use-ipv6=no
add change-tcp-mss=yes name=PPTP only-one=yes use-compression=yes \
    use-encryption=yes use-upnp=no
add change-tcp-mss=yes name=SSTP_client only-one=no use-compression=yes \
    use-encryption=yes use-mpls=no use-upnp=no
add change-tcp-mss=yes idle-timeout=0s name=L2TP_encryption only-one=yes \
    session-timeout=1d use-compression=yes use-encryption=yes use-mpls=no \
    use-upnp=no
add bridge-learning=no change-tcp-mss=yes name=PPP-Rostelecom remote-address=\
    169.254.0.1 use-compression=no use-encryption=no use-ipv6=no use-mpls=no \
    use-upnp=no
add address-list=ACL-RAS-KvantEng change-tcp-mss=yes dns-server=10.255.63.210 \
    idle-timeout=10m interface-list=VPN-RAS name=RAS-Emloyees only-one=no \
    session-timeout=12h use-compression=no use-encryption=yes use-ipv6=no \
    use-mpls=no use-upnp=no wins-server=10.255.63.210
add change-tcp-mss=yes idle-timeout=10m interface-list=VPN-Complex name=\
    10Mbps_limit only-one=no rate-limit=10M/10M session-timeout=12h \
    use-compression=no use-encryption=yes use-ipv6=no use-mpls=no use-upnp=no
add bridge-learning=no change-tcp-mss=yes dns-server=10.255.63.210 \
    interface-list=VPN-RAS-Employees local-address=172.16.255.254 name=\
    VPN-RAS-Employees only-one=no use-compression=no use-encryption=yes \
    use-ipv6=no use-mpls=no use-upnp=no wins-server=10.255.63.210
add bridge-learning=no change-tcp-mss=yes interface-list=VPN-RAS-Contractors \
    local-address=172.16.255.254 name=VPN-RAS-Contractors only-one=no \
    session-timeout=12h use-compression=no use-encryption=yes use-ipv6=no \
    use-mpls=no use-upnp=no
add bridge-learning=no change-tcp-mss=yes interface-list=VPN-Complex \
    local-address=172.16.253.254 name=VPN-RAS-Complex only-one=no \
    session-timeout=12h use-compression=no use-encryption=yes use-ipv6=no \
    use-mpls=no use-upnp=no
set *FFFFFFFE idle-timeout=10m only-one=yes session-timeout=12h \
    use-compression=no use-ipv6=no use-mpls=no use-upnp=no
/interface pppoe-client
add add-default-route=yes comment=WAN-Rostelecom disabled=no interface=\
    ether16 name=PPP-Rostelecom profile=PPP-Rostelecom user=REDACTED
/queue type
add kind=pcq name=queue1 pcq-rate=10M
/routing table
add fib name=via-direct
/snmp community
set [ find default=yes ] name=REDACTED
/system logging action
set 0 memory-lines=65535
/interface bridge port
add bridge=bridge1 interface=ether1 pvid=2
add bridge=bridge1 interface=ether2 pvid=2
add bridge=bridge1 interface=ether3 pvid=2
add bridge=bridge1 interface=ether4 pvid=2
add bridge=bridge1 interface=ether5 pvid=2
add bridge=bridge1 interface=ether7
add bridge=bridge1 interface=LACP1
add bridge=bridge1 interface=ether15 pvid=100
add bpdu-guard=yes bridge=bridge1 edge=yes interface=ether14 pvid=3 \
    restricted-tcn=yes
add bpdu-guard=yes bridge=bridge1 edge=yes interface=ether13 pvid=3 \
    restricted-tcn=yes
add bridge=bridge1 interface=ether12 pvid=3
/ip firewall connection tracking
set enabled=yes liberal-tcp-tracking=yes tcp-established-timeout=5m
/ip neighbor discovery-settings
set discover-interface-list=!WAN lldp-mac-phy-config=yes lldp-max-frame-size=\
    yes lldp-vlan-info=yes
/ip settings
set ipv4-multipath-hash-policy=l4
/ipv6 settings
set disable-ipv6=yes
/interface bridge vlan
add bridge=bridge1 tagged=LACP1 vlan-ids=9
add bridge=bridge1 tagged=LACP1 vlan-ids=30
add bridge=bridge1 tagged=LACP1 vlan-ids=110
/interface l2tp-server server
set default-profile=default enabled=yes max-mru=1400 max-mtu=1400 \
    one-session-per-host=yes use-ipsec=yes
/interface list member
add interface=bridge1 list=LAN
add interface=VLAN2 list=LAN
add interface=ether16 list=WAN
add interface=ether1 list=LAN
add interface=ether2 list=LAN
add interface=ether3 list=LAN
add interface=ether4 list=LAN
add interface=ether5 list=LAN
add interface=ether6 list=LAN
add interface=ether7 list=LAN
add interface=LACP1 list=LAN
add interface=sfp-sfpplus1 list=LAN
add interface=sfp-sfpplus2 list=LAN
add interface=VLAN1 list=LAN
add interface=VLAN9 list=LAN
add interface=PPP-Rostelecom list=WAN
add interface=VLAN100 list=LAN
add interface=Tun01 list=VPN-S2S
add interface=Tun02 list=VPN-S2S
add interface=Tun10 list=VPN-S2S
add interface=VLAN3 list=LAN
add interface=ether14 list=LAN
add interface=ether13 list=LAN
add interface=Tun04 list=VPN-S2S
add interface=VLAN110 list=LAN
/interface ovpn-server server
add auth=sha1,md5,sha256,sha384,sha512 certificate=OVPN-Server cipher="blowfis\
    h128,aes128-cbc,aes192-cbc,aes256-cbc,aes128-gcm,aes192-gcm,aes256-gcm" \
    default-profile=ovpn mac-address=FE:6E:4C:72:8D:72 name=ovpn-server1 \
    redirect-gateway=def1
/interface pptp-server server
# PPTP connections are considered unsafe, it is suggested to use a more modern VPN protocol instead
set authentication=pap,chap,mschap1,mschap2 default-profile=default enabled=\
    yes keepalive-timeout=60 max-mru=1400 max-mtu=1400
/interface sstp-server server
set certificate="Lets encrypt1786839898" enabled=yes keepalive-timeout=30 \
    max-mru=1400 max-mtu=1400 pfs=yes
/ip address
add address=10.255.63.62/26 interface=VLAN2 network=10.255.63.0
add address=10.255.63.254/28 interface=VLAN9 network=10.255.63.240
add address=192.168.0.1/24 disabled=yes interface=VLAN1 network=192.168.0.0
add address=192.168.100.1/24 interface=VLAN100 network=192.168.100.0
add address=172.16.2.37/30 interface=Tun10 network=172.16.2.36
add address=172.16.3.10/30 interface=Tun01 network=172.16.3.8
add address=10.255.63.126/26 interface=VLAN3 network=10.255.63.64
add address=172.16.3.14/30 interface=Tun02 network=172.16.3.12
add address=172.16.255.254/22 interface=VPN-bridge network=172.16.252.0
add address=172.16.3.18/30 interface=Tun04 network=172.16.3.16
add address=10.110.0.254/24 disabled=yes interface=VLAN110 network=10.110.0.0
/ip dhcp-server lease
add address=192.168.1.25 comment="Eltex Switch\r\
    \n" mac-address=CC:9D:A2:66:DD:C0 server=defconf
add address=10.110.0.25 always-broadcast=yes comment="Eltex Switch\
    \n" disabled=yes mac-address=CC:9D:A2:66:DD:C0 server=defconf
/ip dhcp-server network
add address=10.110.0.0/24 dns-server=10.255.63.254 gateway=10.110.0.1 \
    netmask=24
add address=192.168.1.0/24 dns-server=10.255.63.193 gateway=192.168.1.1 \
    ntp-server=192.168.1.1
/ip dns
set allow-remote-requests=yes cache-max-ttl=10m cache-size=8192KiB servers=\
    77.88.8.8,77.88.8.88 verify-doh-cert=yes
/ip dns static
add address=10.235.12.1 name=38.pautina.gibdd.ru type=A
add address=10.235.12.1 name=38.pautina.mvd.ru type=A
add address=192.168.1.22 name=video1.ru type=A
add address=192.168.1.22 name=video2.ru type=A
add address=192.168.1.22 name=video3.ru type=A
add address=192.168.1.22 name=video4.ru type=A
add address=192.168.1.22 name=video5.ru type=A
add address=192.168.1.22 name=video6.ru type=A
add address=192.168.1.10 name=vidos1.ru type=A
add address=192.168.1.10 name=vidos2.ru type=A
add address=192.168.1.10 name=vidos3.ru type=A
add address=192.168.1.10 name=vidos4.ru type=A
add address=10.110.0.250 name=vcsa-01.kvanteng.internal ttl=1h type=A
add address=45.90.28.0 name=dns.nextdns.io type=A
add address=45.90.30.0 name=dns.nextdns.io type=A
add address=2a07:a8c0:: name=dns.nextdns.io type=AAAA
add address=2a07:a8c1:: name=dns.nextdns.io type=AAAA
add address=10.255.63.194 name=netbox.kvanteng.ru type=A
add address=10.255.63.201 name=zabbix.kvanteng.ru type=A
/ip firewall address-list
add address=0.0.0.0/8 comment="RFC 1122 'this' network" list=BOGONS4
add address=10.0.0.0/8 comment="RFC 1918 private space" list=BOGONS4
add address=100.64.0.0/10 comment="RFC 6598 CG-NAT space" list=BOGONS4
add address=127.0.0.0/8 comment="RFC 1122 localhost" list=BOGONS4
add address=169.254.0.0/16 comment="RFC 3927 link local" list=BOGONS4
add address=172.16.0.0/12 comment="RFC 1918 private space" list=BOGONS4
add address=192.0.2.0/24 comment="RFC 5737 TEST-NET-1" list=BOGONS4
add address=192.88.99.0/24 comment="RFC 7526 6to4 anycast relay" list=BOGONS4
add address=192.168.0.0/16 comment="RFC 1918 private space" list=BOGONS4
add address=198.18.0.0/15 comment="RFC 2544 benchmarking" list=BOGONS4
add address=198.51.100.0/24 comment="RFC 5737 TEST-NET-2" list=BOGONS4
add address=203.0.113.0/24 comment="RFC 5737 TEST-NET-3" list=BOGONS4
add address=224.0.0.0/4 comment=Multicast list=BOGONS4
add address=240.0.0.0/4 comment=Reserved list=BOGONS4
add address=78.109.34.84 comment="Rezvyakov S.V. HomeOffice (WAN MTS)" list=\
    ACL-Mgmt-WAN
add address=5.183.147.235 comment="Rezvyakov S.V. HomeOffice (WAN BWC)" list=\
    ACL-Mgmt-WAN
add address=10.0.32.0/24 list=ACL-Mgmt-LAN
add address=10.255.63.240/28 list=ACL-iGBP
add address=10.110.0.0/16 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.0.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.37.0.0/16 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.39.0.0/16 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.40.0.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.44.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.46.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.47.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.48.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.49.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.50.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=10.54.0.2 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=3.0.0.0/24 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=5.0.0.0/24 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=6.0.0.0/24 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=7.0.0.0/24 comment="IP DST complex prefixes" list=ACL-Complex-DST
add address=109.194.20.13 list=ACL-Doris-Allow
add address=91.185.39.102 list=MinTransp
add address=91.185.39.102 list=ACL-Doris-Allow
add address=10.0.32.128/26 comment="KvantEng-Workstations (VLAN504)" list=\
    ACL-Inet-Allow
add address=176.215.238.126 comment="CAFAP R2" list=ACL-Whitelist
add address=95.189.32.202 comment=Direct list=ACL-Whitelist
add address=93.94.178.33 comment="CAFAP R1" list=ACL-Whitelist
add address=10.10.11.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.10.12.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.255.63.193 comment="cont-node-01 VM" list=ACL-Inet-Allow
add address=10.110.0.223 comment="VipNet NCC Autoroad" list=ACL-Inet-Allow
add address=10.235.12.1 list=ACL-Pautina-DST
add address=10.235.12.4 list=ACL-Pautina-DST
add address=10.255.63.215 comment=RDS-01 list=ACL-Pautina-Allow
add address=10.0.32.193 comment="KvantEng DAHUA NVR" list=ACL-Inet-Allow
add address=10.110.0.253 comment="VipNet NCC Kvanteng" list=ACL-Inet-Allow
add address=192.168.1.78 comment="VipNet NCC Kvanteng" list=ACL-Inet-Allow
add address=10.38.1.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.2.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.3.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.4.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.5.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.6.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.7.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.8.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.9.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.10.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.11.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.12.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.110.0.101 comment="ITS Doris" list=ACL-Inet-Allow
add address=10.110.0.107 comment="ITS PMPTP" list=ACL-Inet-Allow
add address=77.223.106.70 list=MinTransp
add address=109.194.20.13 list=MinTransp
add address=10.110.0.109 comment=\
    "IP SRC allowed to access complex prefixes (ASUDD)" list=\
    ACL-Complex-Allow
add address=10.110.0.111 comment=\
    "IP SRC allowed to access complex prefixes (Ecometeo)" list=\
    ACL-Complex-Allow
add address=10.110.0.107 comment=\
    "IP SRC allowed to access complex prefixes (PMPTP)" list=\
    ACL-Complex-Allow
add address=10.110.0.101 comment=\
    "IP SRC allowed to access complex prefixes (Doris)" list=\
    ACL-Complex-Allow
add address=10.110.0.109 comment="ITS ASU DD" list=ACL-Inet-Allow
add address=10.110.0.111 comment=Ecometeo list=ACL-Inet-Allow
add address=10.110.0.253 comment="VipNet NCC" list=KvantEng-VipNet-NCC
add address=192.168.100.2 list=KvantEng-VipNet-Coordinator
add address=192.168.110.2 comment="VipNet Coordinator" list=ACL-Pautina-Allow
add address=10.110.0.253 comment="KvantEng VipNet NCC" list=ACL-Pautina-Allow
add address=10.0.32.64/27 comment="KvantEng-WLAN-Guest (VLAN502)" list=\
    ACL-Inet-Allow
add address=10.255.63.245 comment=Keenetic list=ACL-Inet-Allow
add address=10.110.0.102 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.103 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.104 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.105 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.106 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.108 comment="ITS PMPTP" list=ACL-Inet-Allow
add address=10.110.0.112 comment="ITS PMPTP" list=ACL-Inet-Allow
add address=10.110.0.40 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.41 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.51 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.52 comment=ITS list=ACL-Inet-Allow
add address=10.255.63.209 comment=fs-01.adds.kvanteng.ru list=ACL-Inet-Allow
add address=10.255.63.200 comment=Shinobi-NVR list=ACL-Inet-Allow
add address=192.168.100.2 comment="VipNet HW500" list=ACL-Pautina-Allow
add address=10.0.32.181 comment="Python script host" list=ACL-Complex-Allow
add address=10.110.0.115 comment=ITS list=ACL-Inet-Allow
add address=10.0.32.0/27 comment="KvantEng-TestNetwork (VLAN500)" list=\
    ACL-Inet-Allow
add address=10.10.10.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.110.0.120 comment=ITS list=ACL-Inet-Allow
add address=10.110.0.150 comment=ITS list=ACL-Inet-Allow
add address=10.255.63.210 comment=dc01.adds.kvanteng.ru list=ACL-Inet-Allow
add address=10.255.63.219 comment=admgmt.adds.kvanteng.ru list=ACL-Inet-Allow
add address=10.255.63.225 comment=dc01.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.235 comment=admgmt.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.227 comment=wsfc-01.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.228 comment=wsfc-02.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.215 comment=rds-01.adds.kvanteng.ru list=ACL-Inet-Allow
add address=10.255.63.194 comment="Netbox server" list=ACL-Inet-Allow
add address=10.255.63.195 comment=RDS-02.adds.kvanteng.ru list=ACL-Inet-Allow
add address=10.244.0.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.255.63.215 comment=\
    "IP SRC allowed to access complex prefixes (RDS-01.adds.kvanteng.ru)" \
    list=ACL-Complex-Allow
add address=90.188.226.185 comment="Tankov A HomeOffice" list=ACL-Mgmt-WAN
add address=10.255.63.250 comment=CHR-01 list=ACL-Inet-Allow
add address=172.16.255.0/27 comment="Pool Kvanteng VPN-RAS-Employees" list=\
    ACL-VPN-RAS-Employees
add address=10.255.63.232 comment=rds-02.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.200 comment=\
    "IP SRC allowed to access complex prefixes (Shinobi NVR VM)" list=\
    ACL-Complex-Allow
add address=10.255.63.231 comment=\
    "IP SRC allowed to access complex prefixes (rds-01.kvant.internal VM)" \
    list=ACL-Complex-Allow
add address=10.255.63.231 comment=rds-01.kvant.internal list=ACL-Inet-Allow
add address=10.255.63.219 comment=\
    "IP SRC allowed to access complex prefixes (TEMPORARY)" list=\
    ACL-Complex-Allow
add address=10.255.63.196 comment=RDS-A.adds.kvanteng.ru list=ACL-Inet-Allow
add address=5.183.146.144 comment="GK Vmeste Irkutsk Krasnokazachia BWC" \
    list=ACL-Mgmt-WAN
add address=185.242.117.95 comment=\
    "GK Vmeste Irkutsk Krasnokazachia Interfonica" list=ACL-Mgmt-WAN
add address=10.110.0.17 comment="ITS irk-hiperv7" list=ACL-Inet-Allow
add address=10.255.63.201 list=ACL-Inet-Allow
add address=10.255.63.202 list=ACL-Inet-Allow
add address=10.255.63.202 comment=\
    "IP SRC allowed to access complex prefixes (Zabbix-server 10.255.63.202)" \
    list=ACL-Complex-Allow
add address=91.149.86.212 comment=ddos list=ACL-Blocked
add address=91.149.120.24 comment=ddos list=ACL-Blocked
add address=212.41.0.250 comment=ITS_EGTS list=ITS_EGTS
add address=5.182.226.212 comment=ITS_EGTS list=ITS_EGTS
add address=212.41.0.210 comment=ITS_EGTS list=ITS_EGTS
add address=87.242.104.247 comment=ITS_EGTS list=ITS_EGTS
add address=77.223.106.70 comment=ITS_EGTS list=ITS_EGTS
add address=10.255.62.139 comment=netvision list=ACL-Inet-Allow
add address=10.255.62.139 comment=\
    "IP SRC allowed to access complex prefixes (NetVision)" disabled=yes \
    list=ACL-Complex-Allow
add address=10.0.32.139 comment=Georgy_to_Kirensk list=ACL-Complex-Allow
add address=10.255.63.211 comment=multiotp.adds.kvanteng.ru list=\
    ACL-Inet-Allow
add address=10.0.32.179 comment=VideoWallOffice list=ACL-Complex-Allow
add address=0.0.0.0/0 comment="All IPv4 space" list=ACL-All
add address=10.255.63.129 comment=NAS-01 list=ACL-Inet-Allow
add address=10.0.32.165 comment=TankovPC list=ACL-Complex-Allow
add address=10.38.20.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.19.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.21.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.22.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.23.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.24.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.25.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.26.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.27.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.38.28.0/24 comment="IP DST complex prefixes" list=\
    ACL-Complex-DST
add address=10.255.63.193 comment=ATLAS list=ACL-Complex-Allow
add address=10.255.63.130 comment=NAS-02 list=ACL-Inet-Allow
add address=212.67.30.6 comment="GK Vmeste Alpha R1" list=ACL-Mgmt-WAN
add address=31.128.158.36 comment=ITS_Admins disabled=yes list=ACL-Mgmt-WAN
add address=185.6.47.20 list=ACL-stat.gibdd.ru-Allow
/ip firewall filter
add action=jump chain=input in-interface-list=WAN jump-target=WAN-Inbound
add action=jump chain=input in-interface-list=LAN jump-target=LAN-Inbound
add action=jump chain=input in-interface-list=DMZ jump-target=DMZ-Inbound
add action=jump chain=input in-interface-list=VPN-Complex jump-target=\
    VPN-Complex-Inbound
add action=jump chain=input in-interface-list=VPN-S2S jump-target=\
    VPN-S2S-Inbound
add action=jump chain=input in-interface-list=VPN-RAS jump-target=\
    VPN-RAS-Inbound
add action=jump chain=input in-interface-list=VPN-RAS-Employees jump-target=\
    VPN-RAS-Inbound
add action=accept chain=input in-interface=lo src-address=127.0.0.1
add action=drop chain=input
add action=jump chain=forward comment="VPN-RAS-Employees pool" jump-target=\
    VPN-RAS-Fwd src-address=172.16.255.0/27
add action=jump chain=forward in-interface-list=WAN jump-target=WAN-Fwd
add action=jump chain=forward in-interface-list=LAN jump-target=LAN-Fwd
add action=jump chain=forward in-interface-list=DMZ jump-target=DMZ-Fwd
add action=jump chain=forward in-interface-list=VPN-Complex jump-target=\
    VPN-Complex-Fwd
add action=jump chain=forward in-interface-list=VPN-RAS jump-target=\
    VPN-RAS-Fwd
add action=jump chain=forward in-interface-list=VPN-S2S jump-target=\
    VPN-S2S-Fwd
add action=drop chain=forward comment="Deny all"
add action=accept chain=WAN-Inbound comment=Established connection-state=\
    established
add action=accept chain=WAN-Inbound protocol=gre
add action=accept chain=WAN-Inbound comment=ICMP protocol=icmp
add action=accept chain=WAN-Inbound comment="SSH, Winbox from ACL-Mgmt-WAN" \
    dst-port=22,8291 protocol=tcp src-address-list=ACL-Mgmt-WAN
add action=accept chain=WAN-Inbound comment="SSTP server" dst-port=443 \
    protocol=tcp
add action=accept chain=WAN-Inbound comment=NetVision dst-port=8080 protocol=\
    tcp
add action=accept chain=WAN-Inbound comment=ISAKMP dst-port=500 protocol=udp
add action=accept chain=WAN-Inbound comment="IPSec NAT-T" dst-port=4500 \
    protocol=udp
add action=accept chain=WAN-Inbound comment="L2TP control connection" \
    dst-port=1701 protocol=udp
add action=accept chain=WAN-Inbound comment="PPTP control connection" \
    dst-port=1723 protocol=tcp
add action=accept chain=WAN-Inbound comment="IPSec ESP" protocol=ipsec-esp
add action=accept chain=WAN-Inbound comment="ACME HTTP-01 challenge" \
    connection-state=new disabled=yes dst-port=80 protocol=tcp
add action=add-src-to-address-list address-list=ACL-Blocked \
    address-list-timeout=1d chain=WAN-Inbound comment="TCP port scanning" \
    log=yes log-prefix="Block TCP ports scan" protocol=tcp psd=9,30m,3,1 \
    src-address-list=!ACL-Whitelist
add action=add-src-to-address-list address-list=ACL-Blocked \
    address-list-timeout=1d chain=WAN-Inbound comment="UDP port scanning" \
    log=yes log-prefix="Block UDP ports scan" protocol=udp psd=9,30m,3,1 \
    src-address-list=!ACL-Whitelist
add action=drop chain=WAN-Inbound psd=9,30m,3,1
add action=accept chain=WAN-Fwd comment="Established, related" \
    connection-state=established,related
add action=accept chain=WAN-Fwd comment=DST-NATed connection-nat-state=dstnat
add action=accept chain=WAN-Fwd comment=Untracked connection-state=untracked
add action=drop chain=WAN-Fwd comment="Drop all"
add action=accept chain=LAN-Inbound comment=Established connection-state=\
    established
add action=accept chain=LAN-Inbound comment=ICMP protocol=icmp
add action=accept chain=LAN-Inbound comment="SSH, Winbox from ACL-Mgmt-LAN" \
    dst-port=22,8291 protocol=tcp
add action=accept chain=LAN-Inbound comment="DNS resolver" dst-port=53 \
    protocol=udp
add action=accept chain=LAN-Inbound comment="DNS resolver" dst-port=53 \
    protocol=tcp
add action=accept chain=LAN-Inbound comment="NTP server" dst-port=123 \
    log-prefix="NTP server inbound" protocol=udp
add action=accept chain=LAN-Inbound comment="NTP server" dst-port=123 \
    protocol=tcp
add action=accept chain=LAN-Inbound comment="Mikrotik NDP" dst-port=5678 \
    protocol=udp
add action=accept chain=LAN-Inbound comment="SSTP server" dst-port=443 \
    protocol=tcp
add action=accept chain=LAN-Inbound comment="iBGP peers" dst-port=179 \
    protocol=tcp src-address-list=ACL-iGBP
add action=accept chain=LAN-Inbound comment=SNMP dst-port=161 protocol=udp
add action=drop chain=LAN-Inbound comment="Drop all"
add action=accept chain=VPN-Complex-Inbound comment="Established, related" \
    connection-state=established,related
add action=accept chain=VPN-Complex-Inbound comment=ICMP protocol=icmp
add action=accept chain=VPN-Complex-Inbound comment=New connection-state=new
add action=accept chain=VPN-Complex-Inbound comment=Untracked \
    connection-state=untracked
add action=drop chain=VPN-Complex-Inbound comment="Deny all"
add action=accept chain=LAN-Fwd comment="Established, related" \
    connection-state=established,related
add action=accept chain=LAN-Fwd comment="Allow inet for ACL-Inet-Allow" \
    dst-address-list=!BOGONS4 src-address-list=ACL-Inet-Allow
add action=accept chain=LAN-Fwd comment=\
    "Allow complex prefixes access from ACL-Complex-Allow" dst-address-list=\
    ACL-Complex-DST src-address-list=ACL-Complex-Allow
add action=accept chain=LAN-Fwd comment=\
    "Allow Pautina prefixes access from ACL-Pautina-Allow" dst-address-list=\
    ACL-Pautina-DST src-address-list=ACL-Pautina-Allow
add action=accept chain=LAN-Fwd comment=\
    "KvantEng VipNec NCC ---> KvantEng VipNet Coordinator" dst-address-list=\
    KvantEng-VipNet-Coordinator src-address-list=KvantEng-VipNet-NCC
add action=accept chain=LAN-Fwd dst-address=10.255.32.0/19 log=yes \
    src-address=10.0.32.0/24
add action=drop chain=LAN-Fwd comment="Deny all"
add action=accept chain=VPN-Complex-Fwd comment="Established, related" \
    connection-state=established,related
add action=accept chain=VPN-Complex-Fwd comment=New connection-state=new
add action=drop chain=VPN-Complex-Fwd comment="Drop invalid" \
    connection-state=invalid
add action=drop chain=VPN-Complex-Fwd comment="Deny all"
add action=accept chain=VPN-RAS-Fwd comment="Established, related" \
    connection-state=established,related
add action=accept chain=VPN-RAS-Fwd dst-address-list=ACL-All \
    src-address-list=ACL-VPN-RAS-Unrestricted
add action=accept chain=VPN-RAS-Fwd dst-address-list=ACL-All \
    src-address-list=ACL-VPN-RAS-Employees
add action=accept chain=VPN-RAS-Fwd comment=New connection-state=new
add action=accept chain=VPN-RAS-Fwd
add action=drop chain=VPN-RAS-Fwd
add action=accept chain=VPN-RAS-Inbound comment="Established, related" \
    connection-state=established,related
add action=accept chain=VPN-RAS-Inbound comment=New connection-state=new
add action=drop chain=VPN-RAS-Inbound
add action=accept chain=VPN-S2S-Inbound comment=Established connection-state=\
    established
add action=accept chain=VPN-S2S-Inbound comment=ICMP protocol=icmp
add action=accept chain=VPN-S2S-Inbound comment=BGP dst-port=179 protocol=tcp
add action=accept chain=VPN-S2S-Inbound comment="Mikrotik NDP" dst-port=5678 \
    protocol=udp
add action=accept chain=VPN-S2S-Inbound comment=DNS dst-port=53 protocol=udp
add action=accept chain=VPN-S2S-Inbound comment=DNS dst-port=53 protocol=tcp
add action=drop chain=VPN-S2S-Inbound comment=Drop log=yes
add action=accept chain=VPN-S2S-Fwd comment="Established, related" \
    connection-state=established,related
add action=accept chain=VPN-S2S-Fwd comment=New
add action=accept chain=output
/ip firewall mangle
add action=mark-connection chain=prerouting comment=\
    "atlas inbound via direct" dst-address=10.255.63.193 in-interface=Tun04 \
    new-connection-mark=via-direct-nat
add action=mark-routing chain=prerouting comment="atlas reply via direct" \
    connection-mark=via-direct-nat new-routing-mark=via-direct src-address=\
    10.255.63.193
add action=mark-connection chain=prerouting comment=\
    "netvision inbound via direct" dst-address=10.255.62.139 in-interface=\
    Tun04 new-connection-mark=via-direct-nat
add action=mark-routing chain=prerouting comment="netvision reply via direct" \
    connection-mark=via-direct-nat new-routing-mark=via-direct src-address=\
    10.255.62.139
/ip firewall nat
add action=redirect chain=dstnat comment=\
    "Redirect DNS TCP query  to local DNS" dst-address-type=!local dst-port=\
    53 in-interface-list=LAN protocol=tcp
add action=redirect chain=dstnat comment=\
    "Redirect DNS UDP query  to local DNS" dst-address-type=!local dst-port=\
    53 in-interface-list=LAN protocol=udp
add action=src-nat chain=srcnat comment="LAN -> INET SRC-NAT" \
    dst-address-list=!BOGONS4 ipsec-policy=out,none out-interface=\
    PPP-Rostelecom to-addresses=90.188.224.225
add action=accept chain=srcnat dst-address=10.110.0.0/24 src-address=\
    10.255.63.200
add action=accept chain=srcnat comment="No NAT RDS01 --> Pautina Web Server" \
    dst-address=10.235.12.1 src-address=10.255.63.215
add action=accept chain=srcnat dst-address-list=KvantEng-VipNet-Coordinator \
    src-address-list=KvantEng-VipNet-NCC
add action=masquerade chain=srcnat dst-address-list=ACL-Complex-DST \
    src-address=!10.255.63.219
add action=masquerade chain=srcnat comment=Pautina dst-address=10.235.12.0/24
add action=masquerade chain=srcnat comment="Direct NetVision" dst-address=\
    5.5.5.6
add action=dst-nat chain=dstnat comment=\
    "30037 \EF\F0\EE\F2\EE\EA\EE\EB\A0EGTS" dst-address=90.188.224.225 \
    dst-port=30037 protocol=tcp src-address=77.223.106.70 to-addresses=\
    10.110.0.101 to-ports=6001
add action=dst-nat chain=dstnat comment="VipNet coordinator" dst-address=\
    90.188.224.225 dst-port=55777 in-interface=PPP-Rostelecom protocol=udp \
    to-addresses=192.168.100.2 to-ports=55777
add action=dst-nat chain=dstnat comment="6333 \EF\F0\EE\F2\EE\EA\EE\EB\A0EGTS,\
    \_\E4\EE\F1\F2\F3\EF \EE\F2 81.26.83.151" dst-address=90.188.224.225 \
    dst-port=6333 protocol=tcp src-address=81.26.83.151 to-addresses=\
    10.110.0.101 to-ports=6333
add action=dst-nat chain=dstnat comment=\
    "6005 \EF\F0\EE\F2\EE\EA\EE\EB\A0EGTS" dst-address=90.188.224.225 \
    dst-port=6005 log-prefix=EGTS protocol=tcp to-addresses=10.110.0.101 \
    to-ports=6005
add action=dst-nat chain=dstnat comment=\
    "20130 \EF\F0\EE\F2\EE\EA\EE\EB\A0EGTS" dst-address=90.188.224.225 \
    dst-port=20130 protocol=tcp src-address-list=ITS_EGTS to-addresses=\
    10.110.0.101 to-ports=20130
add action=dst-nat chain=dstnat comment=\
    "20131 \EF\F0\EE\F2\EE\EA\EE\EB\A0WialonRetranslator " dst-address=\
    90.188.224.225 dst-port=20131 protocol=tcp src-address-list=ITS_EGTS \
    to-addresses=10.110.0.101 to-ports=20130
add action=dst-nat chain=dstnat comment="\C4\EE\F0\E8c" dst-address=\
    90.188.224.225 dst-port=8880 in-interface-list=WAN log=yes log-prefix=\
    DORIS_DSTNAT protocol=tcp to-addresses=10.110.0.101 to-ports=80
add action=dst-nat chain=dstnat comment="\C0\D1\D3 \C4\C4" dst-address=\
    90.188.224.225 dst-port=8889 in-interface-list=WAN log=yes log-prefix=\
    DORIS_DSTNAT protocol=tcp to-addresses=10.110.0.109 to-ports=80
add action=dst-nat chain=dstnat comment=NetVision_tehpod dst-port=6422 \
    in-interface-list=WAN log=yes log-prefix=Netvision_DSTNAT protocol=tcp \
    to-addresses=10.255.62.139 to-ports=22
add action=dst-nat chain=dstnat comment=erpweb_tankov_not_delete_it disabled=\
    yes dst-port=60588 in-interface=PPP-Rostelecom protocol=tcp to-addresses=\
    10.255.63.193 to-ports=60588
add action=dst-nat chain=dstnat comment=NetVisionDuplo2 disabled=yes \
    dst-port=8080 in-interface=PPP-Rostelecom protocol=tcp to-addresses=\
    10.255.62.139 to-ports=8080
add action=dst-nat chain=dstnat comment=erpminio_tankov_not_delete_it \
    disabled=yes dst-port=9000 in-interface=PPP-Rostelecom protocol=tcp \
    to-addresses=10.255.63.193 to-ports=9000
/ip firewall raw
add action=accept chain=prerouting comment="Inbound IPsec SA policy traffic" \
    ipsec-policy=in,ipsec
add action=accept chain=output comment="Outbound IPsec SA policy traffic" \
    ipsec-policy=out,ipsec
add action=drop chain=prerouting comment="Filter out blocked sources" \
    src-address-list=ACL-Blocked
/ip firewall service-port
set ftp disabled=yes
set tftp disabled=yes
set h323 disabled=yes
set sip disabled=yes
set pptp disabled=yes
/ip ipsec identity
add peer=peer2
add peer=peer1
add peer=peer3
add auth-method=eap-radius certificate="Lets encrypt1786839898" \
    generate-policy=port-strict mode-config=VPN-RAS peer=VPN-RAS \
    policy-template-group=VPN-RAS
add peer=peer4
/ip ipsec settings
set interim-update=1m
/ip ipsec policy
add dst-address=172.16.255.0/24 group=VPN-RAS proposal=VPN-RAS src-address=\
    0.0.0.0/0 template=yes
add dst-address=93.94.178.33/32 peer=peer1 proposal=AES256CBC-SHA256-G16 \
    protocol=gre src-address=90.188.224.225/32
add dst-address=176.215.238.126/32 peer=peer2 proposal=AES256CBC-SHA256-G16 \
    protocol=gre src-address=90.188.224.225/32
add dst-address=95.189.32.202/32 peer=peer4 proposal=AES256CBC-SHA256-G16 \
    protocol=gre src-address=90.188.224.225/32
add peer=peer3 proposal=AES256CBC-SHA256-G16 protocol=gre
/ip route
add comment="Kvanteng office network" disabled=no distance=250 dst-address=\
    10.0.32.0/24 gateway=10.255.63.241 routing-table=main scope=30 \
    target-scope=10
add comment="Kvanteng office network" disabled=no distance=250 dst-address=\
    10.0.32.0/24 gateway=10.255.63.242 routing-table=main scope=30 \
    target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" disabled=yes distance=1 dst-address=10.110.120.0/24 gateway=5.0.0.77 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=yes distance=1 dst-address=5.0.0.78/32 gateway=0.0.0.0 pref-src=\
    "" routing-table=main scope=30 target-scope=10
add comment=5.0.0.144 disabled=yes distance=1 dst-address=10.47.0.2/32 \
    gateway=5.0.0.144 pref-src="" routing-table=main scope=30 target-scope=10
add disabled=yes distance=1 dst-address=10.46.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=10 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" disabled=yes distance=1 dst-address=10.110.31.0/24 gateway=\
    192.168.100.2 pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 20" disabled=yes distance=1 dst-address=10.110.99.0/24 \
    gateway=5.0.0.197 routing-table=main scope=30 target-scope=10
add disabled=yes distance=1 dst-address=192.168.0.206/32 gateway=5.0.0.33 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=5.5.5.6/32 gateway=Tun04 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=6.0.0.0/24 gateway=5.0.0.72 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.10.11.0/24 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.10.12.0/24 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.10.99.1/32 gateway=172.16.0.2 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.37.0.0/16 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\BD\
    \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD - \EF\BF\
    \BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\
    \BD SSTP \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD" disabled=no \
    distance=1 dst-address=10.38.0.0/16 gateway=Tun04 routing-table=main \
    scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.1.0/24 gateway=172.16.0.2 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.38.2.0/24 gateway=172.16.0.2 \
    routing-table=main scope=30 target-scope=10
add disabled=yes distance=1 dst-address=10.38.3.0/24 gateway=3.0.0.1 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.38.4.0/24 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.5.0/24 gateway=3.0.0.201 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.38.6.0/24 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.7.0/24 gateway=3.0.0.203 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.8.0/24 gateway=3.0.0.202 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.10.0/24 gateway=5.0.0.32 \
    routing-table=main scope=30 target-scope=10
add comment="AUR-1906004 (via cafap-r2)" disabled=no distance=10 dst-address=\
    10.38.11.0/24 gateway=172.16.0.2 pref-src="" routing-table=main scope=30 \
    target-scope=10
add disabled=no distance=10 dst-address=10.38.12.0/24 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.39.0.0/16 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.39.43.0/24 gateway=5.0.0.138 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.39.67.0/24 gateway=6.0.0.17 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.94/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.106/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.113/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.114/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.118/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.122/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.134/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.40.0.138/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.44.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=10 target-scope=10
add disabled=no distance=1 dst-address=10.46.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=10 target-scope=10
add disabled=no distance=1 dst-address=10.47.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=10 target-scope=10
add disabled=no distance=1 dst-address=10.48.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.49.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.50.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.54.0.2/32 gateway=192.168.100.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \E1\F3\EB\FC\E2\E0\F0 \D0\FF\E1\
    \E8\EA\EE\E2\E0 \E2 \F0\E0\E9\EE\ED\E5 \F0\FB\ED\EA\E0 \D0\F3\F7\E5\E9\r\
    \n" disabled=no distance=1 dst-address=10.110.1.0/24 gateway=5.0.0.97 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3 \EA\EC \
    9 + 700\r\
    \n" disabled=no distance=1 dst-address=10.110.2.0/24 gateway=5.0.0.96 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\E5\F0\E3\E5\E5\E2\E0 (3/1) \E8 \F3\EB. \C0\F0\E3\F3\ED\EE\
    \E2\E0\r\
    \n" disabled=no dst-address=10.110.3.0/24 gateway=5.0.0.98 routing-table=\
    main
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF \E8 \F3\EB. \CB\E5\F0\
    \EC\EE\ED\F2\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.4.0/24 gateway=5.0.0.99 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\F2\E0\F0\EE-\CA\F3\E7\FC\EC\E8\F5\E8\ED\F1\EA\E0\FF \E8 \
    \F3\EB. \C1\E5\E7\E1\EE\EA\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.5.0/24 gateway=5.0.0.101 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA - \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\
    \EA\E8\E9, \EA\EC. 6+900\r\
    \n" disabled=no distance=1 dst-address=10.110.6.0/24 gateway=5.0.0.102 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment=\
    "\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA - \C8\F1\EA\F0\E0, \EA\EC 2+800\r\
    \n" disabled=no distance=1 dst-address=10.110.7.0/24 gateway=5.0.0.103 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="MM \CE\B8\EA - \CA\F3\E4\E0\F0\E5\E9\EA\E0, \E2\FA\E5\E7\E4 \E2 \
    \CE\B8\EA\r\
    \n" disabled=no distance=1 dst-address=10.110.8.0/24 gateway=5.0.0.104 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \D5\EE\EC\F3\F2\EE\E2\EE - \D3\F0\E8\EA - \D3\F1\F2\FC-\
    \CA\F3\E4\E0, \E2\FA\E5\E7\E4 \E2 \D3\F1\F2\FC-\CA\F3\E4\F3, (\CE\CE\D2 \
    \D3\F1\F2\FC-\CA\F3\E4\E0-1)\r\
    \n" disabled=no distance=1 dst-address=10.110.9.0/24 gateway=5.0.0.105 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3 \EF\EE\E4\F5\EE\E4\E0 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EE\F2\E2\EE\
    \F0\EE\F2 \ED\E0 \EF. \CC\E0\F0\EA\EE\E2\E0.\r\
    \n" disabled=no distance=1 dst-address=10.110.10.0/24 gateway=5.0.0.83 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\E5\F0\E3\E5\E5\E2\E0 (3/1) \E8 \F3\EB. \C0\F0\E3\F3\ED\EE\
    \E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.11.0/24 gateway=5.0.0.84 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \EE\E1\FA\E5\E7\E4\ED\EE\E9 \CF\E5\F0\E2\EE\EC\E0\E9\F1\EA\EE\E3\EE \
    \E8 \F3\EB. \C2\E0\EC\EF\E8\EB\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.12.0/24 gateway=5.0.0.85 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \EE\E1\FA\E5\E7\E4\ED\EE\E9 \EC-\ED \CF\E5\F0\E2\EE\EC\E0\E9\F1\EA\E8\
    \E9 \E8 \F3\EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF\r\
    \n" disabled=no dst-address=10.110.13.0/24 gateway=5.0.0.86 \
    routing-table=main
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \E4\EE\F0\EE\E3\E8 \EC-\ED \DE\E1\E8\EB\E5\E9\ED\FB\E9 \96 \CC\E5\EB\
    \FC\ED\E8\F7\ED\E0\FF \EF\E0\E4\FC\r\
    \n" disabled=no distance=1 dst-address=10.110.14.0/24 gateway=5.0.0.87 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\
    \ED\EE\E2\E0.\r\
    \n" disabled=no dst-address=10.110.15.0/24 gateway=5.0.0.88 \
    routing-table=main
add comment="\CC\D2\CF \D1\E0\E4-\E2\EE \"\C4\EE\F0\EE\E6\ED\FB\E9 \F1\F2\F0\
    \EE\E8\F2\E5\EB\FC\", \EA\EC 3+800\r\
    \n" disabled=no distance=1 dst-address=10.110.16.0/24 gateway=5.0.0.106 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \CC\E0\FF\EA\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. 2-\FF \C6\E5\EB\
    \E5\E7\ED\EE\E4\EE\F0\EE\E6\ED\E0\FF" disabled=no distance=1 dst-address=\
    10.110.17.0/24 gateway=5.0.0.107 pref-src="" routing-table=main scope=30 \
    target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C4\E6\E0\EC\E1\F3\EB\E0 \E8 \EF\E5\F0. \D1\EF\EE\F0\F2\E8\E2\
    \ED\FB\E9\r\
    \n" disabled=no distance=1 dst-address=10.110.18.0/24 gateway=5.0.0.108 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \D2\F0\E0\EA\F2\EE\E2\E0\
    \FF \E2 \F0\E0\E9\EE\ED\E5 \CE\CE\D2 \"\C1\E0\EA\E0\EB\E5\FF\"\r\
    \n" disabled=no distance=1 dst-address=10.110.19.0/24 gateway=5.0.0.109 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \CE\EB\E5\E3\E0 \CA\EE\
    \F8\E5\E2\EE\E3\EE 61\r\
    \n" disabled=no distance=1 dst-address=10.110.20.0/24 gateway=5.0.0.110 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA - \CE\F1\E0 - \D3\F1\F2\FC-\D3\E4\
    \E0, \EA\EC. 1+500\r\
    \n" disabled=no distance=1 dst-address=10.110.21.0/24 gateway=5.0.0.111 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF" disabled=no distance=1 dst-address=10.110.22.0/24 gateway=\
    5.0.0.112 pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\
    \EA\E0\FF 291\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.23.0/24 gateway=5.0.0.113 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF\r\
    \n" disabled=no distance=1 dst-address=10.110.24.0/24 gateway=5.0.0.114 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\F0\F0\E8\EA\E0\E4 \E8 \F3\EB. \DE\EB\E8\F3\F1\E0 \D4\F3\
    \F7\E8\EA\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.25.0/24 gateway=5.0.0.115 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA-\C1\EE\EB\FC\F8\EE\E5 \C3\EE\EB\
    \EE\F3\F1\F2\ED\EE\E5 \EA\EC 1+500\r\
    \n" disabled=no distance=1 dst-address=10.110.26.0/24 gateway=5.0.0.116 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \E1\F3\EB\FC\E2\E0\F0 \D0\FF\E1\E8\EA\EE\E2\E0 \E2 \F0\E0\E9\EE\ED\E5 \F0\
    \FB\ED\EA\E0 \D0\F3\F7\E5\E9\r\
    \n" disabled=no distance=1 dst-address=10.110.27.0/24 gateway=5.0.0.60 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\ED\E8\E5 \F3\
    \EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.28.0/24 gateway=5.0.0.74 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \D4\E0\E2\EE\F0\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\ED\F2\
    \EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.29.0/24 gateway=5.0.0.75 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CC\E5\EB\E5\ED\F2\FC\E5\E2\E0 \E8 \F3\EB. \CB\E5\F0\EC\EE\ED\F2\
    \EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.30.0/24 gateway=5.0.0.76 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\
    \EF\BF\BD\EF\BF\BD, \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\
    \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\BD. \EF\BF\
    \BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\
    \BD\EF\BF\BD\EF\BF\BD\EF\BF\BD \EF\BF\BD \EF\BF\BD\EF\BF\BD. \EF\BF\BD\EF\
    \BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\
    \BF\BD\
    \n" disabled=no distance=1 dst-address=10.110.31.0/24 gateway=Tun04 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \D1\F2\E0\F0\EE-\CA\F3\E7\FC\EC\E8\F5\E8\ED\F1\EA\E0\FF \E8 \F3\EB\
    . \C1\E5\E7\E1\EE\EA\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.32.0/24 gateway=5.0.0.82 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CB\E5\F0\EC\EE\ED\F2\EE\E2\E0 \E8 \F3\EB. \C6\F3\EA\EE\E2\F1\EA\
    \EE\E3\EE\r\
    \n" disabled=no distance=1 dst-address=10.110.33.0/24 gateway=5.0.0.89 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB.\C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \C4\EE\ED\F1\EA\E0\FF\
    \r\
    \n" disabled=no distance=1 dst-address=10.110.34.0/24 gateway=5.0.0.73 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\ED\
    \EE\E2\E0\r\
    \n" disabled=no dst-address=10.110.35.0/24 gateway=5.0.0.90 \
    routing-table=main
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F1\F2\
    \EA\E0\FF\r\
    \n" disabled=no distance=1 dst-address=10.110.36.0/24 gateway=5.0.0.91 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EA\E0\E1\F0\FC\F1\EA\E8\F5 \F1\EE\E1\FB\F2\E8\E9 \E8 \F3\EB\
    . \D0\E0\E1\EE\F7\E0\FF\r\
    \n" disabled=no distance=1 dst-address=10.110.37.0/24 gateway=5.0.0.92 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EA\E0\E1\F0\FC\F1\EA\E8\F5 \F1\EE\E1\FB\F2\E8\E9 \E8 \F3\EB\
    . \CD\E8\E6\ED\FF\FF \CD\E0\E1\E5\F0\E5\E6\ED\E0\FF\r\
    \n" disabled=no dst-address=10.110.38.0/24 gateway=5.0.0.93 \
    routing-table=main
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CA\F0\E0\F1\ED\EE\FF\F0\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF\r\
    \n" disabled=no distance=1 dst-address=10.110.39.0/24 gateway=5.0.0.94 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\E0\F0\F2\E8\E7\E0\ED\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\
    \ED\EE\E2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.40.0/24 gateway=5.0.0.95 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EA\EC 16\
    +250 (\EC\EE\F1\F2 \F7\E5\F0\E5\E7 \F0. \CE\EB\F5\E0)\r\
    \n" disabled=no distance=1 dst-address=10.110.41.0/24 gateway=5.0.0.117 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, 15 \EA\EC\
    \_\E2 \F0\E0\E9\EE\ED\E5 \EA\E0\F4\E5 \C2\FB\F1\EE\F2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.42.0/24 gateway=5.0.0.118 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3 \EA\EC 9 +\
    \_700\r\
    \n" disabled=no distance=1 dst-address=10.110.43.0/24 gateway=5.0.0.119 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment=\
    "\C2\CD \CF\EE\E4\FA\E5\E7\E4 \EA \CF\EB\E8\F8\EA\E8\ED\EE, \EA\EC 7+900" \
    disabled=no distance=1 dst-address=10.110.44.0/24 gateway=5.0.0.120 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \C8\F0\EA\F3\F2\F1\EA - \CE\F1\E0 - \D3\F1\F2\FC-\D3\E4\E0\
    , \EA\EC. 0+000\r\
    \n\r\
    \n\r\
    \n" disabled=no distance=1 dst-address=10.110.45.0/24 gateway=5.0.0.121 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \C8\F0\EA\F3\F2\F1\EA - \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\EA\
    \E8\E9, \EA\EC. 10+750\r\
    \n" disabled=no distance=1 dst-address=10.110.46.0/24 gateway=5.0.0.78 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\C2\CD \C8\F0\EA\F3\F2\F1\EA-\C1\EE\EB\FC\F8\EE\E5 \C3\EE\EB\EE\
    \F3\F1\F2\ED\EE\E5, \EA\EC 0 + 900" disabled=no distance=1 dst-address=\
    10.110.47.0/24 gateway=5.0.0.122 pref-src="" routing-table=main scope=30 \
    target-scope=10
add comment="\CC\CC \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EA\EC 16\
    +450 (\EC\EE\F1\F2 \F7\E5\F0\E5\E7 \F0. \CE\EB\F5\E0)\r\
    \n" disabled=no distance=1 dst-address=10.110.48.0/24 gateway=5.0.0.81 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \F0.\EF. \CC\E0\F0\EA\EE\E2\E0, \F3\EB. \CC\E8\F0\E0 \E2 \
    \F0\E0\E9\EE\ED\E5 \EC\EE\F1\F2\E0 \F7\E5\F0\E5\E7 \F0. \CA\E0\FF" \
    disabled=no distance=1 dst-address=10.110.49.0/24 gateway=5.0.0.123 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \CF\EE\E4\FA\E5\E7\E4 \EA \CD\EE\E2\EE\E3\F0\F3\E4\E8\ED\
    \E8\ED\E0, \EA\EC 5+900, \E2\FA\E5\E7\E4 \E2 \CD\EE\E2\EE\E3\F0\F3\E4\E8\
    \ED\E8\ED\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.50.0/24 gateway=5.0.0.124 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \C8\F0\EA\F3\F2\F1\EA - \F1\E0\E4\EE\E2\EE\E4\F1\F2\E2\EE \
    \"\C4\EE\F0\EE\E6\ED\FB\E9 \F1\F2\F0\EE\E8\F2\E5\EB\FC\", \EA\EC. 12+300, \
    \EE\F2\E2\EE\F0\EE\F2 \ED\E0 \E4. \CD\EE\E2\EE\E3\F0\F3\E4\E8\ED\E8\ED\E0\
    \r\
    \n" disabled=no distance=1 dst-address=10.110.51.0/24 gateway=5.0.0.125 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \CD\EE\E2\EE-\CB\E5\ED\E8\ED\EE - \CC\E0\EA\F1\E8\EC\EE\E2\
    \F9\E8\ED\E0, \EA\EC 3+300\r\
    \n" disabled=no distance=1 dst-address=10.110.52.0/24 gateway=5.0.0.126 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \C1\E0\E9\EA\E0\EB\FC\F1\EA\E8\E9 \F2\F0\E0\EA\F2. \C8\F0\
    \EA\F3\F2\F1\EA -\CB\E8\F1\F2\E2\FF\ED\EA\E0 \EA\EC.21+025, \EF. \CF\E0\F2\
    \F0\EE\ED\FB\r\
    \n\r\
    \n" disabled=no distance=1 dst-address=10.110.53.0/24 gateway=5.0.0.127 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \D5\F3\E4\FF\EA\EE\E2\E0, \F3\EB. \C5\E2\F1\E5\E5\E2\F1\EA\
    \E0\FF, \E4.11\r\
    \n" disabled=no distance=1 dst-address=10.110.54.0/24 gateway=5.0.0.128 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \CF\EE\E4\FA\E5\E7\E4 \EA \CF\EB\E8\F8\EA\E8\ED\EE, \EA\EC\
    \_7+900\r\
    \n\r\
    \n" disabled=no distance=1 dst-address=10.110.55.0/24 gateway=5.0.0.129 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \D5\EE\EC\F3\F2\EE\E2\EE-\D3\F1\F2\FC-\CE\F0\E4\E0, \EA\EC\
    \_20+100\r\
    \n\r\
    \n\r\
    \n" disabled=no distance=1 dst-address=10.110.56.0/24 gateway=5.0.0.130 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \C8\F0\EA\F3\F2\F1\EA - \CE\F1\E0 - \D3\F1\F2\FC-\D3\E4\E0\
    , \EA\EC 15+950\r\
    \n\r\
    \n\r\
    \n\r\
    \n" disabled=no distance=1 dst-address=10.110.57.0/24 gateway=5.0.0.131 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD - \EF\BF\
    \BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD \EF\BF\
    \BD\EF\BF\BD\EF\BF\BD\EF\BF\BD, \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\
    \BD \EF\BF\BD \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\
    \BD\
    \n" disabled=no distance=1 dst-address=10.110.58.0/24 gateway=5.0.0.132 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CC\CC \CC\EE\F1\EA\EE\E2\F9\E8\ED\E0, \EC\EE\F1\F2 \F7\E5\F0\E5\
    \E7 \F0. \CC\F5\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.59.0/24 gateway=5.0.0.133 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \CC\E5\F7\F2\E0\r\
    \n" disabled=no distance=1 dst-address=10.110.60.0/24 gateway=5.0.0.80 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \CA\E0\F0\EB\F3\EA" disabled=no dst-address=\
    10.110.61.0/24 gateway=5.0.0.134 routing-table=main
add comment="\CF\D3\C8\C4 1 \AB\C8\F0\EA\F3\F2\F1\EA \96 \CB\E8\F1\F2\E2\FF\ED\
    \EA\E0\BB" disabled=no distance=1 dst-address=10.110.62.0/24 gateway=\
    5.0.0.159 pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CF\D3\C8\C4 2" disabled=no dst-address=10.110.63.0/24 gateway=\
    5.0.0.160 routing-table=main
add comment="\CF\D3\C8\C4 3" disabled=no dst-address=10.110.64.0/24 gateway=\
    5.0.0.161 routing-table=main
add comment="\CF\D3\C8\C4 4" disabled=no dst-address=10.110.65.0/24 gateway=\
    5.0.0.162 routing-table=main
add comment="\CF\D3\C8\C4 5" disabled=no distance=1 dst-address=\
    10.110.66.0/24 gateway=5.0.0.163 routing-table=main scope=30 \
    target-scope=10
add comment="\CF\D3\C8\C4 6" disabled=no dst-address=10.110.67.0/24 gateway=\
    5.0.0.164 routing-table=main
add comment="\CF\D3\C8\C4 7" disabled=no distance=1 dst-address=\
    10.110.68.0/24 gateway=5.0.0.165 routing-table=main scope=30 \
    target-scope=10
add comment="\CF\D3\C8\C4 8" disabled=no distance=1 dst-address=\
    10.110.69.0/24 gateway=5.0.0.166 routing-table=main scope=30 \
    target-scope=10
add comment="\CF\D3\C8\C4 9" disabled=no dst-address=10.110.70.0/24 gateway=\
    5.0.0.167 routing-table=main
add comment="\CF\D3\C8\C4 10 \AB\D3\F1\F2\FC-\CA\F3\F2 \96 \D3\EE\FF\ED\BB" \
    disabled=no distance=1 dst-address=10.110.71.0/24 gateway=5.0.0.168 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="\CF\D3\C8\C4 11 \AB\D3\F1\F2\FC-\CA\F3\F2 \96 \D3\EE\FF\ED\BB \D3\
    \EB\FC\EA\E0\ED" disabled=no distance=1 dst-address=10.110.72.0/24 \
    gateway=5.0.0.169 routing-table=main scope=30 target-scope=10
add comment="\CF\D3\C8\C4 12 \AB\D3\F1\F2\FC-\CA\F3\F2 \96 \CA\E8\F0\E5\ED\F1\
    \EA\BB \CC\E0\EA\E0\F0\EE\E2\E0" disabled=no distance=1 dst-address=\
    10.110.73.0/24 gateway=5.0.0.170 routing-table=main scope=30 \
    target-scope=10
add comment="\CF\D3\C8\C4 13 \AB\C8\F0\EA\F3\F2\F1\EA \96 \C1\EE\EB\FC\F8\EE\
    \E5 \C3\EE\EB\EE\F3\F1\F2\ED\EE\E5\BB" disabled=no dst-address=\
    10.110.74.0/24 gateway=5.0.0.171 routing-table=main
add comment="\CF\D3\C8\C4 14 \AB\C1\E0\FF\ED\E4\E0\E9 \96 \C5\EB\E0\ED\F6\FB \
    \96 \D5\F3\E6\E8\F0\BB" disabled=no distance=1 dst-address=10.110.75.0/24 \
    gateway=5.0.0.172 routing-table=main scope=30 target-scope=10
add comment="\CF\D3\C8\C4 15 \AB\C1\E0\FF\ED\E4\E0\E9 \96 \C5\EB\E0\ED\F6\FB \
    \96 \D5\F3\E6\E8\F0\BB" disabled=no distance=1 dst-address=10.110.76.0/24 \
    gateway=5.0.0.173 routing-table=main scope=30 target-scope=10
add comment="\CF\D3\C8\C4 16 \AB\CA\F3\F2\F3\EB\E8\EA \96 \C0\EB\FF\F2\FB\BB, \
    \C0\EB\E5\EA\F1\E0\ED\E4\F0\EE\E2\F1\EA" disabled=no distance=1 \
    dst-address=10.110.77.0/24 gateway=5.0.0.174 routing-table=main scope=30 \
    target-scope=10
add comment="\CF\D3\C8\C4 17 \AB\D7\E5\F0\E5\EC\F5\EE\E2\EE \96 \C3\EE\EB\F3\
    \EC\E5\F2\FC \96 \CE\ED\EE\F2\BB" disabled=no distance=1 dst-address=\
    10.110.78.0/24 gateway=5.0.0.175 routing-table=main scope=30 \
    target-scope=10
add comment="\CC\D2\CF 1 \AB\D7\EA\E0\EB\EE\E2\E0 - \CC\E0\F0\E0\F2\E0\BB" \
    disabled=no distance=1 dst-address=10.110.79.0/24 gateway=5.0.0.176 \
    routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 2 \AB\D1\F2\E5\EF\E0\ED\E0 \D0\E0\E7\E8\ED\E0 - \D0\EE\
    \F1\F1\E8\E9\F1\EA\E0\FF\BB" disabled=no distance=1 dst-address=\
    10.110.80.0/24 gateway=5.0.0.177 routing-table=main scope=30 \
    target-scope=10
add comment="\CC\D2\CF 3 \AB\D1\F2\E5\EF\E0\ED\E0 \D0\E0\E7\E8\ED\E0 - \D1\E2\
    \E5\F0\E4\EB\EE\E2\E0\BB" disabled=no distance=1 dst-address=\
    10.110.81.0/24 gateway=5.0.0.178 routing-table=main scope=30 \
    target-scope=10
add comment="\CC\D2\CF 4" disabled=no distance=1 dst-address=10.110.82.0/24 \
    gateway=5.0.0.179 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 5" disabled=no distance=1 dst-address=10.110.83.0/24 \
    gateway=5.0.0.180 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 6" disabled=no distance=1 dst-address=10.110.84.0/24 \
    gateway=5.0.0.181 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 7" disabled=no distance=1 dst-address=10.110.85.0/24 \
    gateway=5.0.0.182 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 8" disabled=no distance=1 dst-address=10.110.86.0/24 \
    gateway=5.0.0.183 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 9" disabled=no distance=1 dst-address=10.110.87.0/24 \
    gateway=5.0.0.184 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 10" disabled=no distance=1 dst-address=10.110.88.0/24 \
    gateway=5.0.0.185 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 11" disabled=no distance=1 dst-address=10.110.89.0/24 \
    gateway=5.0.0.186 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 12" disabled=no distance=1 dst-address=10.110.90.0/24 \
    gateway=5.0.0.187 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 13" disabled=no distance=1 dst-address=10.110.91.0/24 \
    gateway=5.0.0.188 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 14" disabled=no distance=1 dst-address=10.110.92.0/24 \
    gateway=5.0.0.189 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 15" disabled=no distance=1 dst-address=10.110.93.0/24 \
    gateway=5.0.0.190 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 16" disabled=no distance=1 dst-address=10.110.94.0/24 \
    gateway=5.0.0.191 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 17" disabled=no distance=1 dst-address=10.110.95.0/24 \
    gateway=5.0.0.192 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 18" disabled=no distance=1 dst-address=10.110.96.0/24 \
    gateway=5.0.0.193 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 19" disabled=no distance=1 dst-address=10.110.97.0/24 \
    gateway=5.0.0.194 routing-table=main scope=30 target-scope=10
add comment="\CC\D2\CF 20" disabled=no distance=1 dst-address=10.110.98.0/24 \
    gateway=5.0.0.195 routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.235.12.1/32 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=10.235.12.4/32 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=172.20.3.12/32 gateway=172.16.0.2 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=10 dst-address=192.168.4.100/32 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=192.168.10.222/32 gateway=\
    192.168.100.2 pref-src="" routing-table=main scope=30 target-scope=10
add check-gateway=ping comment="Rezviakov S. home office" disabled=no \
    dst-address=192.168.255.0/24 gateway=172.16.2.38 routing-table=main
add comment="Kvanteng Alpha DC prefix" disabled=no distance=250 dst-address=\
    10.255.32.0/19 gateway=10.255.63.241 routing-table=main scope=30 \
    target-scope=10
add comment="Kvanteng Alpha DC prefix" disabled=no distance=250 dst-address=\
    10.255.32.0/19 gateway=10.255.63.242 routing-table=main scope=30 \
    target-scope=10
add disabled=no distance=10 dst-address=10.101.0.1/32 gateway=172.16.0.2 \
    pref-src="" routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.39.62.0/24 gateway=6.0.0.19 \
    pref-src="" routing-table=main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.10.11.0/24 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.10.12.0/24 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.10.99.1/32 gateway=172.16.3.13 routing-table=main scope=30 \
    target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.37.0.0/16 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.38.2.0/24 gateway=172.16.3.13 routing-table=main scope=30 \
    target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.38.4.0/24 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.38.6.0/24 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.38.12.0/24 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.39.0.0/16 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=10.101.0.1/32 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add comment="CAFAP-R2 Tun02" disabled=no distance=1 dst-address=\
    10.235.12.1/32 gateway=172.16.3.13 pref-src="" routing-table=main scope=\
    30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=no distance=1 \
    dst-address=10.235.12.4/32 gateway=172.16.3.13 pref-src="" routing-table=\
    main scope=30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=172.20.3.12/32 gateway=172.16.3.13 routing-table=main scope=\
    30 target-scope=10
add check-gateway=ping comment="CAFAP-R2 Tun02" disabled=yes distance=1 \
    dst-address=192.168.4.100/32 gateway=172.16.3.13 pref-src="" \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.10.10.0/24 gateway=5.0.0.198 \
    routing-table=main scope=30 target-scope=10
add comment=AUR-1906004 disabled=no distance=1 dst-address=10.38.11.0/24 \
    gateway=5.0.0.206 pref-src="" routing-table=main scope=30 target-scope=10
add comment="\D1\D3 \CC\E0\F0\EA\EE\E2\E0" disabled=no distance=1 \
    dst-address=10.110.100.0/24 gateway=5.0.0.199 routing-table=main scope=30 \
    target-scope=10
add disabled=yes distance=10 dst-address=10.38.4.0/24 gateway=10.10.11.207 \
    pref-src="" routing-table=main scope=30 target-scope=10
add comment="atlas NAT reply via direct" dst-address=0.0.0.0/0 gateway=Tun04 \
    routing-table=via-direct
add comment="ITS servers" disabled=no distance=250 dst-address=10.110.0.0/24 \
    gateway=10.255.63.242 routing-table=main scope=30 target-scope=10
add comment="ITS servers" disabled=no distance=250 dst-address=10.110.0.0/24 \
    gateway=10.255.63.241 routing-table=main scope=30 target-scope=10
add disabled=no distance=250 dst-address=192.168.1.0/24 gateway=10.255.63.242 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=250 dst-address=192.168.1.0/24 gateway=10.255.63.241 \
    routing-table=main scope=30 target-scope=10
add comment="Faktor 1953 via CAFAP" disabled=no distance=10 dst-address=\
    10.38.20.0/24 gateway=172.16.0.2 routing-table=main scope=30 \
    target-scope=10
add comment="Faktor 1953" disabled=no distance=1 dst-address=10.38.20.0/24 \
    gateway=5.0.0.222 routing-table=main scope=30 target-scope=10
add comment="Faktor 1954" disabled=no distance=1 dst-address=10.38.19.0/24 \
    gateway=5.0.0.223 routing-table=main scope=30 target-scope=10
add comment="Faktor 1954 via CAFAP" disabled=no distance=10 dst-address=\
    10.38.19.0/24 gateway=172.16.0.2 routing-table=main scope=30 \
    target-scope=10
add disabled=no distance=1 dst-address=10.38.23.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.24.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.25.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.26.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.27.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=no distance=1 dst-address=10.38.28.0/24 gateway=Tun02 \
    routing-table=main scope=30 target-scope=10
add disabled=yes distance=5 dst-address=10.38.4.0/24 gateway=3.0.0.204 \
    routing-table=main scope=30 target-scope=10
add disabled=yes distance=1 dst-address=10.38.6.0/24 gateway=5.0.0.29 \
    routing-table=main scope=30 target-scope=10
add disabled=no dst-address=176.16.4.0/24 gateway=Tun01 routing-table=main
/ip service
set ftp disabled=yes
set telnet disabled=yes
set www disabled=yes
set www-ssl certificate="Lets encrypt1786839898"
/ipv6 nd
set [ find default=yes ] advertise-dns=yes
/ppp aaa
set interim-update=1m use-circuit-id-in-nas-port-id=yes use-radius=yes
/ppp secret
add local-address=4.0.0.1 name=ARENA-1407125 remote-address=3.0.0.7
add comment="Movable complex" local-address=4.0.0.1 name=ARENA-1407125-SOFT \
    remote-address=3.0.0.37
add comment="Movable complex" local-address=4.0.0.1 name=2402009-SOFT \
    remote-address=3.0.0.35
add local-address=4.0.0.1 name=2402009 remote-address=3.0.0.5
add comment="Movable complex" local-address=4.0.0.1 name=2402008-SOFT \
    remote-address=3.0.0.34
add local-address=4.0.0.1 name=2402007 remote-address=3.0.0.8
add local-address=4.0.0.1 name=ARENA-1906002 remote-address=3.0.0.6
add disabled=yes local-address=4.0.0.1 name=ARENA-1906004 remote-address=\
    3.0.0.3
add comment="Movable complex" local-address=4.0.0.1 name=ARENA-1906002-SOFT \
    remote-address=3.0.0.36
add comment="Movable complex" local-address=4.0.0.1 name=ARENA-1906004-SOFT \
    remote-address=3.0.0.33
add local-address=4.0.0.1 name=2402008 remote-address=3.0.0.4
add comment="Movable complex" local-address=4.0.0.1 name=2402007-SOFT \
    remote-address=3.0.0.38
add local-address=4.0.0.1 name=svet_mon remote-address=3.0.0.101
add local-address=4.0.0.5 name=ITS5 remote-address=4.0.0.6
add local-address=4.0.0.3 name=ITS7 remote-address=4.0.0.4
add local-address=4.0.0.1 name=ITS1 remote-address=3.0.0.224
add local-address=4.0.0.1 name=ITS2 remote-address=3.0.0.118
add local-address=4.0.0.1 name=ITS3 remote-address=3.0.0.119
add local-address=4.0.0.1 name=ITS4 remote-address=4.0.0.2
add local-address=4.0.0.1 name=ITS6 remote-address=3.0.0.220
add local-address=4.0.0.1 name=ITS8 remote-address=3.0.0.221
add local-address=4.0.0.1 name=ITS9 remote-address=3.0.0.222
add local-address=4.0.0.1 name=ITS10 remote-address=3.0.0.223
add local-address=4.0.0.1 name=ARENA-1407116 remote-address=3.0.0.9
add comment="Movable complex" local-address=4.0.0.1 name=ARENA-1407116-SOFT \
    remote-address=3.0.0.39
add local-address=4.0.0.1 name=AUR-1809001 remote-address=3.0.0.10
add local-address=4.0.0.1 name=SKAT-1901016 remote-address=3.0.0.11
add local-address=4.0.0.1 name=mechta remote-address=3.0.0.50
add name=SSTP-CAFAP profile=SSTPSERVER remote-address=172.16.0.2
add name=SSTP-DIRECT profile=SSTPSERVER remote-address=172.16.0.3
add disabled=yes local-address=4.0.0.1 name=GOL_RESESRV remote-address=\
    3.0.0.105
add comment=Check local-address=4.0.0.1 name=ATOM-2145201 remote-address=\
    5.0.0.1
add comment=Check local-address=4.0.0.1 name=ATOM-2329202 remote-address=\
    5.0.0.3
add comment=Check local-address=4.0.0.1 name=ATOM-2145205 remote-address=\
    5.0.0.2
add comment=Check local-address=4.0.0.1 name=ATOM-2329204 remote-address=\
    5.0.0.4
add comment=Check local-address=4.0.0.1 name=ATOM-2329206 remote-address=\
    5.0.0.5
add comment=Check local-address=4.0.0.1 name=ATOM-2329207 remote-address=\
    5.0.0.6
add comment=Check local-address=4.0.0.1 name=ATOM-2329208 remote-address=\
    5.0.0.7
add comment=Check local-address=4.0.0.1 name=ATOM-2329210 remote-address=\
    5.0.0.8
add disabled=yes local-address=4.0.0.1 name=SKATM-2110004 remote-address=\
    5.0.0.9
add comment=Check disabled=yes local-address=4.0.0.1 name=ATOM-2329211 \
    remote-address=5.0.0.10
add comment=Check local-address=4.0.0.1 name=ATOM-2329212 remote-address=\
    5.0.0.11
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308012 remote-address=\
    5.0.0.27
add comment=Check local-address=4.0.0.1 name=ORAKUL-2307001 remote-address=\
    5.0.0.13
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308032 remote-address=\
    5.0.0.14
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308044 remote-address=\
    5.0.0.15
add comment=Check local-address=4.0.0.1 name=ATOM-2329214 remote-address=\
    5.0.0.16
add comment=Check local-address=4.0.0.1 name=ATOM-2329215 remote-address=\
    5.0.0.17
add comment=Check local-address=4.0.0.1 name=ATOM-2329216 remote-address=\
    5.0.0.18
add comment=Check local-address=4.0.0.1 name=ATOM-2329219 remote-address=\
    5.0.0.19
add comment=Check local-address=4.0.0.1 name=ATOM-2329220 remote-address=\
    5.0.0.20
add comment=Check local-address=4.0.0.1 name=ATOM-2329203 remote-address=\
    5.0.0.21
add comment=Check local-address=4.0.0.1 name=ORAKUL-2106038 remote-address=\
    5.0.0.22
add comment=Check local-address=4.0.0.1 name=ORAKUL-2106039 remote-address=\
    5.0.0.23
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308017 remote-address=\
    5.0.0.24
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308008 remote-address=\
    5.0.0.25
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308009 remote-address=\
    5.0.0.26
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308013 remote-address=\
    5.0.0.28
add comment=Check local-address=4.0.0.1 name=SVK-UST-KUT remote-address=\
    5.0.0.29
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308015 remote-address=\
    5.0.0.30
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308031 remote-address=\
    5.0.0.31
add comment=Check local-address=4.0.0.1 name=AUR-1809004 remote-address=\
    5.0.0.32
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308018 remote-address=\
    5.0.0.33
add local-address=4.0.0.1 name=ORAKUL-2308019 remote-address=5.0.0.34
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308021 remote-address=\
    5.0.0.35
add comment=Check local-address=4.0.0.1 name=ORAKUL-2310022 remote-address=\
    5.0.0.36
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308025 remote-address=\
    5.0.0.37
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308026 remote-address=\
    5.0.0.38
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308027 remote-address=\
    5.0.0.39
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308028 remote-address=\
    5.0.0.40
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308030 remote-address=\
    5.0.0.41
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308033 remote-address=\
    5.0.0.42
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308035 remote-address=\
    5.0.0.43
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308037 remote-address=\
    5.0.0.44
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308039 remote-address=\
    5.0.0.45
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308040 remote-address=\
    5.0.0.46
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308041 remote-address=\
    5.0.0.47
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308042 remote-address=\
    5.0.0.48
add comment=Check local-address=4.0.0.1 name=ORAKUL-2310012 remote-address=\
    5.0.0.49
add comment=Check local-address=4.0.0.1 name=SKAT-1809036 remote-address=\
    5.0.0.50
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308034 remote-address=\
    5.0.0.51
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308011 remote-address=\
    5.0.0.53
add local-address=5.0.1.1 name=VOCORD remote-address=5.0.1.57
add local-address=4.0.0.1 name=ORAKUL-2308022 remote-address=5.0.0.52
add local-address=4.0.0.1 name=ORAKUL-2308020 remote-address=5.0.0.54
add local-address=4.0.0.1 name=SKAT-1811144 remote-address=5.0.0.55
add local-address=4.0.0.1 name=SKAT-1901020 remote-address=5.0.0.56
add disabled=yes local-address=9.9.9.9 name=egor remote-address=99.88.77.66
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \E1\F3\EB\FC\E2\E0\F0 \D0\FF\E1\E8\EA\EE\E2\E0 \E2 \F0\E0\E9\EE\ED\E5 \F0\
    \FB\ED\EA\E0 \D0\F3\F7\E5\E9\r\
    \n" local-address=4.0.0.1 name=ITS_SU_40 remote-address=5.0.0.60
add local-address=4.0.0.1 name=ANGELS-IT remote-address=172.16.0.20
add local-address=4.0.0.1 name=SKAT-1804008 remote-address=5.0.0.70
add local-address=4.0.0.1 name=KBUH remote-address=5.0.0.71
add local-address=4.0.0.1 name=Factor remote-address=5.0.0.72
add local-address=4.0.0.1 name=SKAT-1809055 remote-address=5.0.0.59
add local-address=4.0.0.1 name=Pomyalovskogo remote-address=5.0.0.61
add local-address=4.0.0.1 name=BEZBOKOVA remote-address=5.0.0.62
add comment="\C8\E3\EE\F0\FC \D2\E0\F0\E0\F5\EE\E2\F1\EA\E8\E9. \CD\C5 \D3\C4\
    \C0\CB\DF\D2\DC!!!!" disabled=yes local-address=2.2.2.2 name=client22 \
    remote-address=20.20.20.20
add comment=\
    "\D2\E0\F0\E0\F5\EE\E2\F1\EA\E8\E9! \ED\E5 \F3\E4\E0\EB\FF\F2\FC!!!!" \
    disabled=yes local-address=2.2.2.33 name=client23 remote-address=\
    20.20.20.20
add local-address=4.0.0.1 name=ARENA-1906005 remote-address=3.0.0.5
add comment="\C4\D3\C1\CB\DC!" disabled=yes local-address=4.0.0.1 name=\
    KUDA_meteo remote-address=10.110.26.1
add disabled=yes local-address=4.0.0.1 name=ISKRA_meteo remote-address=\
    10.110.24.1
add disabled=yes local-address=4.0.0.1 name=ISKRA_meteo_CAM remote-address=\
    10.110.24.2
add comment="\C4\D3\C1\CB\DC!" disabled=yes local-address=4.0.0.1 name=\
    KUDA_meteo_CAM remote-address=10.110.26.2
add comment="\C2\CD \C8\F0\EA\F3\F2\F1\EA - \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\EA\
    \E8\E9, \EA\EC. 10+750" local-address=4.0.0.1 name=ITS_VN_79 \
    remote-address=5.0.0.78
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\ED\E8\E5 \F3\
    \EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_49 remote-address=5.0.0.74
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \D4\E0\E2\EE\F0\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\ED\F2\
    \EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_50 remote-address=5.0.0.75
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CC\E5\EB\E5\ED\F2\FC\E5\E2\E0 \E8 \F3\EB. \CB\E5\F0\EC\EE\ED\F2\
    \EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_51 remote-address=5.0.0.76
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_52 remote-address=5.0.0.77
add comment="\D1\D3 \CC\E5\F7\F2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_22 remote-address=5.0.0.80
add local-address=4.0.0.1 name=SKAT-1809053 remote-address=5.0.0.57
add comment="\CC\CC \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EA\EC 16\
    +450 (\EC\EE\F1\F2 \F7\E5\F0\E5\E7 \F0. \CE\EB\F5\E0)\r\
    \n" local-address=4.0.0.1 name=ITS_MM_6 remote-address=5.0.0.81
add comment="\C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \F3\EB.\
    \C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \C4\EE\ED\F1\EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_104 remote-address=5.0.0.73
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \D1\F2\E0\F0\EE-\CA\F3\E7\FC\EC\E8\F5\E8\ED\F1\EA\E0\FF \E8 \F3\EB\
    . \C1\E5\E7\E1\EE\EA\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_59 remote-address=5.0.0.82
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3 \EF\EE\E4\F5\EE\E4\E0 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EE\F2\E2\EE\
    \F0\EE\F2 \ED\E0 \EF. \CC\E0\F0\EA\EE\E2\E0.\r\
    \n" local-address=4.0.0.1 name=ITS_SU_31r remote-address=5.0.0.83
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\E5\F0\E3\E5\E5\E2\E0 (3/1) \E8 \F3\EB. \C0\F0\E3\F3\ED\EE\
    \E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_43 remote-address=5.0.0.84
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \EE\E1\FA\E5\E7\E4\ED\EE\E9 \CF\E5\F0\E2\EE\EC\E0\E9\F1\EA\EE\E3\EE \
    \E8 \F3\EB. \C2\E0\EC\EF\E8\EB\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_45 remote-address=5.0.0.85
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \EE\E1\FA\E5\E7\E4\ED\EE\E9 \EC-\ED \CF\E5\F0\E2\EE\EC\E0\E9\F1\EA\E8\
    \E9 \E8 \F3\EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_46 remote-address=5.0.0.86
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \E4\EE\F0\EE\E3\E8 \EC-\ED \DE\E1\E8\EB\E5\E9\ED\FB\E9 \96 \CC\E5\EB\
    \FC\ED\E8\F7\ED\E0\FF \EF\E0\E4\FC\r\
    \n" local-address=4.0.0.1 name=ITS_SU_60r remote-address=5.0.0.87
add comment="\D1\D3 \E3. \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\
    \ED\EE\E2\E0.\r\
    \n" local-address=4.0.0.1 name=ITS_SU_103 remote-address=5.0.0.88
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CB\E5\F0\EC\EE\ED\F2\EE\E2\E0 \E8 \F3\EB. \C6\F3\EA\EE\E2\F1\EA\
    \EE\E3\EE" local-address=4.0.0.1 name=ITS_SU_82 remote-address=5.0.0.89
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\ED\
    \EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_116 remote-address=5.0.0.90
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F1\F2\
    \EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_122r remote-address=5.0.0.91
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EA\E0\E1\F0\FC\F1\EA\E8\F5 \F1\EE\E1\FB\F2\E8\E9 \E8 \F3\EB\
    . \D0\E0\E1\EE\F7\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_126 remote-address=5.0.0.92
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \C4\E5\EA\E0\E1\F0\FC\F1\EA\E8\F5 \F1\EE\E1\FB\F2\E8\E9 \E8 \F3\EB\
    . \CD\E8\E6\ED\FF\FF \CD\E0\E1\E5\F0\E5\E6\ED\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_128 remote-address=5.0.0.93
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CA\F0\E0\F1\ED\EE\FF\F0\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_SU_145 remote-address=5.0.0.94
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\E0\F0\F2\E8\E7\E0\ED\F1\EA\E0\FF \E8 \F3\EB. \CF\E8\F1\EA\F3\
    \ED\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_149 remote-address=5.0.0.95
add comment="\CC\D2\CF \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3 \EA\EC \
    9 + 700\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_33 remote-address=5.0.0.96
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \E1\F3\EB\FC\E2\E0\F0 \D0\FF\E1\
    \E8\EA\EE\E2\E0 \E2 \F0\E0\E9\EE\ED\E5 \F0\FB\ED\EA\E0 \D0\F3\F7\E5\E9\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_38 remote-address=5.0.0.97
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\E5\F0\E3\E5\E5\E2\E0 (3/1) \E8 \F3\EB. \C0\F0\E3\F3\ED\EE\
    \E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_41 remote-address=5.0.0.98
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D3\EB\E0\ED-\C1\E0\F2\EE\F0\F1\EA\E0\FF \E8 \F3\EB. \CB\E5\F0\
    \EC\EE\ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_47 remote-address=5.0.0.99
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \D1\F2\E0\F0\EE-\CA\F3\E7\FC\EC\E8\F5\E8\ED\F1\EA\E0\FF \E8 \
    \F3\EB. \C1\E5\E7\E1\EE\EA\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_56 remote-address=5.0.0.101
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA - \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\
    \EA\E8\E9, \EA\EC. 6+900\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_78 remote-address=5.0.0.102
add comment=\
    "\CC\CC \C8\F0\EA\F3\F2\F1\EA - \C8\F1\EA\F0\E0, \EA\EC 2+800\r\
    \n" local-address=4.0.0.1 name=ITS_MM_11 remote-address=5.0.0.103
add comment="\CC\CC \CE\B8\EA - \CA\F3\E4\E0\F0\E5\E9\EA\E0, \E2\FA\E5\E7\E4 \
    \E2 \CE\B8\EA\r\
    \n" local-address=4.0.0.1 name=ITS_MM_16 remote-address=5.0.0.104
add comment="\CC\CC \D5\EE\EC\F3\F2\EE\E2\EE - \D3\F0\E8\EA - \D3\F1\F2\FC-\CA\
    \F3\E4\E0, \E2\FA\E5\E7\E4 \E2 \D3\F1\F2\FC-\CA\F3\E4\F3, (\CE\CE\D2 \D3\
    \F1\F2\FC-\CA\F3\E4\E0-1)\r\
    \n" local-address=4.0.0.1 name=ITS_MM_20 remote-address=5.0.0.105
add comment="\CC\D2\CF \D1\E0\E4-\E2\EE \"\C4\EE\F0\EE\E6\ED\FB\E9 \F1\F2\F0\
    \EE\E8\F2\E5\EB\FC\", \EA\EC 3+800" local-address=4.0.0.1 name=ITS_MTP_61 \
    remote-address=5.0.0.106
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \CC\E0\FF\EA\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. 2-\FF \C6\E5\EB\
    \E5\E7\ED\EE\E4\EE\F0\EE\E6\ED\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_66 remote-address=5.0.0.107
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C4\E6\E0\EC\E1\F3\EB\E0 \E8 \EF\E5\F0. \D1\EF\EE\F0\F2\E8\E2\
    \ED\FB\E9\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_68 remote-address=5.0.0.108
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \D2\F0\E0\EA\F2\EE\E2\E0\
    \FF \E2 \F0\E0\E9\EE\ED\E5 \CE\CE\D2 \"\C1\E0\EA\E0\EB\E5\FF\"" \
    local-address=4.0.0.1 name=ITS_MTP_70 remote-address=5.0.0.109
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \CE\EB\E5\E3\E0 \CA\EE\
    \F8\E5\E2\EE\E3\EE 61\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_72 remote-address=5.0.0.110
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA - \CE\F1\E0 - \D3\F1\F2\FC-\D3\E4\
    \E0, \EA\EC. 1+500\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_74r remote-address=5.0.0.111
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_99 remote-address=5.0.0.112
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \F3\EB. \C1\E0\E9\EA\E0\EB\FC\F1\
    \EA\E0\FF 291\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_112 remote-address=5.0.0.113
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C4\E5\EF\F3\F2\E0\F2\F1\EA\E0\FF \E8 \F3\EB. \D1\EE\E2\E5\F2\
    \F1\EA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_117 remote-address=5.0.0.114
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\
    \E5 \F3\EB. \C1\E0\F0\F0\E8\EA\E0\E4 \E8 \F3\EB. \DE\EB\E8\F3\F1\E0 \D4\F3\
    \F7\E8\EA\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MTP_135 remote-address=5.0.0.115
add comment="\C2\CD \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, \EA\EC 16\
    +250 (\EC\EE\F1\F2 \F7\E5\F0\E5\E7 \F0. \CE\EB\F5\E0)\r\
    \n" local-address=4.0.0.1 name=ITS_VN_28 remote-address=5.0.0.117
add comment="\C2\CD \CF\EE\E4\F5\EE\E4 \EA \C8\F0\EA\F3\F2\F1\EA\F3, 15 \EA\EC\
    \_\E2 \F0\E0\E9\EE\ED\E5 \EA\E0\F4\E5 \C2\FB\F1\EE\F2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_VN_30 remote-address=5.0.0.118
add local-address=4.0.0.1 name=ITS_VN_34 profile=10Mbps_limit remote-address=\
    5.0.0.119
add comment="\C2\CD \CF\EE\E4\FA\E5\E7\E4 \EA \CF\EB\E8\F8\EA\E8\ED\EE, \EA\EC\
    \_7+900\r\
    \n" disabled=yes local-address=4.0.0.1 name=ITS_VN_62 remote-address=\
    5.0.0.120
add comment="\C2\CD \C8\F0\EA\F3\F2\F1\EA - \CE\F1\E0 - \D3\F1\F2\FC-\D3\E4\E0\
    , \EA\EC. 0+000\r\
    \n" local-address=4.0.0.1 name=ITS_VN_75 remote-address=5.0.0.121
add local-address=4.0.0.1 name=ITS_VN_143 profile=10Mbps_limit \
    remote-address=5.0.0.122
add comment="\CC\CC \F0.\EF. \CC\E0\F0\EA\EE\E2\E0, \F3\EB. \CC\E8\F0\E0 \E2 \
    \F0\E0\E9\EE\ED\E5 \EC\EE\F1\F2\E0 \F7\E5\F0\E5\E7 \F0. \CA\E0\FF\r\
    \n" local-address=4.0.0.1 name=ITS_MM_7 remote-address=5.0.0.123
add local-address=4.0.0.1 name=ITS_MM_8 remote-address=5.0.0.124 service=pptp
add comment="\CC\CC \C8\F0\EA\F3\F2\F1\EA - \F1\E0\E4\EE\E2\EE\E4\F1\F2\E2\EE \
    \"\C4\EE\F0\EE\E6\ED\FB\E9 \F1\F2\F0\EE\E8\F2\E5\EB\FC\", \EA\EC. 12+300, \
    \EE\F2\E2\EE\F0\EE\F2 \ED\E0 \E4. \CD\EE\E2\EE\E3\F0\F3\E4\E8\ED\E8\ED\E0\
    \r\
    \n" local-address=4.0.0.1 name=ITS_MM_9 remote-address=5.0.0.125
add comment="\CC\CC \CD\EE\E2\EE-\CB\E5\ED\E8\ED\EE - \CC\E0\EA\F1\E8\EC\EE\E2\
    \F9\E8\ED\E0, \EA\EC 3+300\r\
    \n" local-address=4.0.0.1 name=ITS_MM_10 remote-address=5.0.0.126
add comment="\CC\CC \C1\E0\E9\EA\E0\EB\FC\F1\EA\E8\E9 \F2\F0\E0\EA\F2. \C8\F0\
    \EA\F3\F2\F1\EA -\CB\E8\F1\F2\E2\FF\ED\EA\E0 \EA\EC.21+025, \EF. \CF\E0\F2\
    \F0\EE\ED\FB\r\
    \n" local-address=4.0.0.1 name=ITS_MM_12 remote-address=5.0.0.127
add comment="\CC\CC \D5\F3\E4\FF\EA\EE\E2\E0, \F3\EB. \C5\E2\F1\E5\E5\E2\F1\EA\
    \E0\FF, \E4.11\r\
    \n" local-address=4.0.0.1 name=ITS_MM_13 remote-address=5.0.0.128
add comment="\CC\CC \CF\EE\E4\FA\E5\E7\E4 \EA \CF\EB\E8\F8\EA\E8\ED\EE, \EA\EC\
    \_7+900\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_MM_14 remote-address=5.0.0.129
add comment="\CC\CC \D3\F0\E8\EA - \D2\E8\F5\EE\ED\EE\E2\E0 \CF\E0\E4\FC, \E2\
    \FA\E5\E7\E4 \E2 \D8\E8\F0\FF\E5\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MM_18 remote-address=5.0.0.132
add comment="\CC\CC \D5\EE\EC\F3\F2\EE\E2\EE-\D3\F1\F2\FC-\CE\F0\E4\E0, \EA\EC\
    \_20+100\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_MM_15 remote-address=5.0.0.130
add comment="\EF\BF\BD\EF\BF\BD \EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\EF\BF\BD\
    \EF\BF\BD\EF\BF\BD - \EF\BF\BD\EF\BF\BD\EF\BF\BD - \EF\BF\BD\EF\BF\BD\EF\
    \BF\BD\EF\BF\BD-\EF\BF\BD\EF\BF\BD\EF\BF\BD, \EF\BF\BD\EF\BF\BD 15+950\
    \n\
    \n\
    \n\
    \n\
    \n" local-address=4.0.0.1 name=ITS_MM_17 remote-address=5.0.0.131 \
    service=pptp
add comment="\CC\CC \CC\EE\F1\EA\EE\E2\F9\E8\ED\E0, \EC\EE\F1\F2 \F7\E5\F0\E5\
    \E7 \F0. \CC\F5\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MM_19 remote-address=5.0.0.133
add comment="\D1\D3 \CA\E0\F0\EB\F3\EA\r\
    \n" local-address=4.0.0.1 name=ITS_SU_21 remote-address=5.0.0.134
add local-address=4.0.0.1 name=A021-2 remote-address=5.0.0.151
add local-address=4.0.0.1 name=A017-1 remote-address=5.0.0.137
add comment="\CC\D2\CF \C8\F0\EA\F3\F2\F1\EA-\C1\EE\EB\FC\F8\EE\E5 \C3\EE\EB\
    \EE\F3\F1\F2\ED\EE\E5 1 \EA\EC+500" local-address=4.0.0.1 name=\
    ITS_MTP_142 remote-address=5.0.0.116
add comment="\C2\CF\CD \D5\E0\EB\FF\E2\E8\ED \C8\D2\D1" disabled=yes \
    local-address=4.0.0.1 name=Halyavin remote-address=5.0.0.142
add comment=Check local-address=4.0.0.1 name=SKAT-1901017 remote-address=\
    5.0.0.150
add comment=Check local-address=4.0.0.1 name=VNB180031K remote-address=\
    5.0.0.153
add local-address=4.0.0.1 name=SKAT-1601041 remote-address=5.0.0.144
add local-address=4.0.0.1 name=ORAKUL-2308023 remote-address=5.0.0.145
add disabled=yes local-address=4.0.0.1 name=SVK-GOLOUST remote-address=\
    3.0.0.1
add disabled=yes local-address=4.0.0.1 name=OVPN-DIRECT remote-address=\
    172.16.0.3 service=ovpn
add local-address=4.0.0.1 name=SKAT-1809047 remote-address=6.0.0.13
add local-address=4.0.0.1 name=ORAKUL-2310021 remote-address=6.0.0.10
add local-address=4.0.0.1 name=T066 remote-address=6.0.0.8
add local-address=4.0.0.1 name=T069 remote-address=6.0.0.5
add local-address=4.0.0.1 name=SKAT-1901019 remote-address=6.0.0.4
add local-address=4.0.0.1 name=SKAT-2107039 remote-address=6.0.0.3
add comment="VPN \CF\E0\F3\EA" local-address=4.0.0.1 name=Pulsar \
    remote-address=5.0.0.158
add comment="\AB\C8\F0\EA\F3\F2\F1\EA \96 \CB\E8\F1\F2\E2\FF\ED\EA\E0\BB\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_1 remote-address=5.0.0.159
add comment=\
    "\AB\C8\F0\EA\F3\F2\F1\EA \96 \D8\E5\EB\E5\F5\EE\E2\BB\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_2 remote-address=5.0.0.160
add comment="\AB\C8\F0\EA\F3\F2\F1\EA \96 \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\EA\
    \E8\E9 \96 \C6\E8\E3\E0\EB\EE\E2\EE\BB \EA\EC 14+700\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_3 remote-address=5.0.0.161
add comment="\AB\C8\F0\EA\F3\F2\F1\EA \96 \D3\F1\F2\FC-\CE\F0\E4\FB\ED\F1\EA\
    \E8\E9 \96 \C6\E8\E3\E0\EB\EE\E2\EE\BB 282\EA\EC \C2\E5\F0\F5\EE\EB\E5\ED\
    \F1\EA\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_4 remote-address=5.0.0.162
add comment="\AB\CF\EE\EB\F3\EA\EE\EB\FC\F6\EE\BB \96 \AB\D2\F3\EB\F3\ED \96 \
    \C1\F0\E0\F2\F1\EA\BB            \CB\E5\EE\ED\EE\E2\E0" local-address=\
    4.0.0.1 name=ITS_PUID_5 remote-address=5.0.0.163
add comment=\
    "\AB\C1\F0\E0\F2\F1\EA \96 \D3\F1\F2\FC-\C8\EB\E8\EC\F1\EA\BB 43\EA\EC" \
    local-address=4.0.0.1 name=ITS_PUID_6 remote-address=5.0.0.164
add comment="\AB\C1\F0\E0\F2\F1\EA \96 \D3\F1\F2\FC-\C8\EB\E8\EC\F1\EA\BB 94\
    \EA\EC \D1\E5\E4\E0\ED\EE\E2\EE\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_7 remote-address=5.0.0.165
add comment="\AB\D2\E0\E9\F8\E5\F2 \96 \D7\F3\ED\E0 \96 \C1\F0\E0\F2\F1\EA\BB \
    \CA\E2\E8\F2\EE\EA\r\
    \n\r\
    \n\r\
    \n\r\
    \n" local-address=4.0.0.1 name=ITS_PUID_8 remote-address=5.0.0.166
add comment=\
    "\AB\D2\E0\E9\F8\E5\F2 \96 \D7\F3\ED\E0 \96 \C1\F0\E0\F2\F1\EA\BB" \
    local-address=4.0.0.1 name=ITS_PUID_9 remote-address=5.0.0.167
add comment="\AB\D3\F1\F2\FC-\CA\F3\F2 \96 \D3\EE\FF\ED\BB" local-address=\
    4.0.0.1 name=ITS_PUID_10 remote-address=5.0.0.168
add comment=\
    "\AB\D3\F1\F2\FC-\CA\F3\F2 \96 \D3\EE\FF\ED\BB \D3\EB\FC\EA\E0\ED" \
    local-address=4.0.0.1 name=ITS_PUID_11 remote-address=5.0.0.169
add comment="\AB\D3\F1\F2\FC-\CA\F3\F2 \96 \CA\E8\F0\E5\ED\F1\EA\BB \CC\E0\EA\
    \E0\F0\EE\E2\E0" local-address=4.0.0.1 name=ITS_PUID_12 remote-address=\
    5.0.0.170
add comment="\AB\C8\F0\EA\F3\F2\F1\EA \96 \C1\EE\EB\FC\F8\EE\E5 \C3\EE\EB\EE\
    \F3\F1\F2\ED\EE\E5\BB" local-address=4.0.0.1 name=ITS_PUID_13 \
    remote-address=5.0.0.171
add comment=\
    "\AB\C1\E0\FF\ED\E4\E0\E9 \96 \C5\EB\E0\ED\F6\FB \96 \D5\F3\E6\E8\F0\BB" \
    local-address=4.0.0.1 name=ITS_PUID_14 remote-address=5.0.0.172
add comment=\
    "\AB\C1\E0\FF\ED\E4\E0\E9 \96 \C5\EB\E0\ED\F6\FB \96 \D5\F3\E6\E8\F0\BB" \
    local-address=4.0.0.1 name=ITS_PUID_15 remote-address=5.0.0.173
add comment="\AB\CA\F3\F2\F3\EB\E8\EA \96 \C0\EB\FF\F2\FB\BB, \C0\EB\E5\EA\F1\
    \E0\ED\E4\F0\EE\E2\F1\EA" local-address=4.0.0.1 name=ITS_PUID_16 \
    remote-address=5.0.0.174
add comment="\AB\D7\E5\F0\E5\EC\F5\EE\E2\EE \96 \C3\EE\EB\F3\EC\E5\F2\FC \96 \
    \CE\ED\EE\F2\BB" local-address=4.0.0.1 name=ITS_PUID_17 remote-address=\
    5.0.0.175
add local-address=4.0.0.1 name=ITS_MTP_1 remote-address=5.0.0.176
add local-address=4.0.0.1 name=ITS_MTP_2 remote-address=5.0.0.177
add local-address=4.0.0.1 name=SVK-K remote-address=3.0.0.202
add local-address=4.0.0.1 name=SVK-66606 remote-address=3.0.0.201
add local-address=4.0.0.1 name=SVK-Chuna remote-address=3.0.0.203
add local-address=4.0.0.1 name=ITS_MTP_3 remote-address=5.0.0.178
add local-address=4.0.0.1 name=ITS_MTP_4 remote-address=5.0.0.179
add local-address=4.0.0.1 name=ITS_MTP_5 remote-address=5.0.0.180
add local-address=4.0.0.1 name=ITS_MTP_6 remote-address=5.0.0.181
add local-address=4.0.0.1 name=ITS_MTP_7 remote-address=5.0.0.182
add local-address=4.0.0.1 name=ITS_MTP_8 remote-address=5.0.0.183
add local-address=4.0.0.1 name=ITS_MTP_9 remote-address=5.0.0.184
add local-address=4.0.0.1 name=ITS_MTP_10 remote-address=5.0.0.185
add local-address=4.0.0.1 name=ITS_MTP_11 remote-address=5.0.0.186
add local-address=4.0.0.1 name=ITS_MTP_12 remote-address=5.0.0.187
add local-address=4.0.0.1 name=ITS_MTP_13 remote-address=5.0.0.188
add local-address=4.0.0.1 name=ITS_MTP_14 remote-address=5.0.0.189
add local-address=4.0.0.1 name=ITS_MTP_15 remote-address=5.0.0.190
add local-address=4.0.0.1 name=ITS_MTP_16 remote-address=5.0.0.191
add local-address=4.0.0.1 name=ITS_MTP_17 remote-address=5.0.0.192
add local-address=4.0.0.1 name=ITS_MTP_18 remote-address=5.0.0.193
add local-address=4.0.0.1 name=ITS_MTP_19 remote-address=5.0.0.194
add local-address=4.0.0.1 name=ITS_MTP_20 remote-address=5.0.0.195
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_52m remote-address=5.0.0.196
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ppp1_test remote-address=5.0.0.197
add comment="\CF\F3\EB\FC\F1\E0\F0" local-address=4.0.0.1 name=Pauk \
    remote-address=5.0.0.157
add comment="\CF\E0\F3\EA 489 \F0\E5\E7\E5\F0\E2" local-address=4.0.0.1 name=\
    Pauk489 remote-address=6.0.0.7
add local-address=4.0.0.1 name=SKAT-1809095 remote-address=6.0.0.11
add local-address=4.0.0.1 name=SKAT-1811103 remote-address=6.0.0.16
add local-address=4.0.0.1 name=SVK-CHEREM remote-address=3.0.0.204
add local-address=4.0.0.1 name=ORAKUL-2310023 remote-address=5.0.0.201
add local-address=4.0.0.1 name=T065 remote-address=6.0.0.6
add comment=Check local-address=4.0.0.1 name=VNB180028K remote-address=\
    5.0.0.146
add local-address=4.0.0.1 name=F1736 remote-address=6.0.0.14
add comment="\C4\E8\F0\E5\EA\F2\EE\F0 \CE\C3\CA\D3 \"\D6\E5\ED\F2\F0 \F2\F0\E0\
    \ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\F1\EA\EE\E9 \EE\E1\EB\E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport1 remote-address=\
    7.0.0.15
add comment="\C7\E0\EC\E5\F1\F2\E8\F2\E5\EB\FC \E4\E8\F0\E5\EA\F2\EE\F0\E0 \CE\
    \C3\CA\D3 \"\D6\E5\ED\F2\F0 \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\
    \F1\EA\EE\E9 \EE\E1\EB\E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport2 remote-address=\
    7.0.0.16
add comment=\
    "\CC\E8\ED\E8\F1\F2\E5\F0\F1\F2\E2\EE \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0" \
    disabled=yes local-address=4.0.0.1 name=MTransport remote-address=\
    7.0.0.17
add comment="\C2\E5\E4\F3\F9\E8\E9 \E8\ED\E6\E5\ED\E5\F0 \EE\F2\E4\E5\EB\E0 \
    \EF\E0\F1\F1\E0\E6\E8\F0\F1\EA\E8\F5 \EF\E5\F0\E5\E2\EE\E7\EE\EA \CE\C3\CA\
    \D3 \"\D6\E5\ED\F2\F0 \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\F1\EA\
    \EE\E9 \EE\E1\EB\E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport4 remote-address=\
    7.0.0.19
add comment="\D1\D3 \C8\F0\EA\F3\F2\F1\EA, \EF\E5\F0\E5\F1\E5\F7\E5\ED\E8\E5 \
    \F3\EB. \CF\EE\EC\FF\EB\EE\E2\F1\EA\EE\E3\EE \E8 \F3\EB. \CB\E5\F0\EC\EE\
    \ED\F2\EE\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_SU_52s remote-address=5.0.0.196
add comment="\CD\E0\F7\E0\EB\FC\ED\E8\EA \EE\F2\E4\E5\EB\E0 \EF\E0\F1\F1\E0\E6\
    \E8\F0\F1\EA\E8\F5 \EF\E5\F0\E5\E2\EE\E7\EE\EA \CE\C3\CA\D3 \"\D6\E5\ED\F2\
    \F0 \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\F1\EA\EE\E9 \EE\E1\EB\
    \E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport3 remote-address=\
    7.0.0.18
add comment="\C2\E5\E4\F3\F9\E8\E9 \E8\ED\E6\E5\ED\E5\F0 \EE\F2\E4\E5\EB\E0 \
    \EF\E0\F1\F1\E0\E6\E8\F0\F1\EA\E8\F5 \EF\E5\F0\E5\E2\EE\E7\EE\EA \CE\C3\CA\
    \D3 \"\D6\E5\ED\F2\F0 \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\F1\EA\
    \EE\E9 \EE\E1\EB\E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport5 remote-address=\
    7.0.0.20
add local-address=4.0.0.1 name=F1733 remote-address=6.0.0.15
add disabled=yes local-address=4.0.0.1 name=Faktor2 remote-address=5.0.0.202
add local-address=4.0.0.1 name=AUR-2004001 remote-address=3.0.0.12
add local-address=4.0.0.1 name=F1741 remote-address=3.0.0.128
add local-address=4.0.0.1 name=F1742 remote-address=3.0.0.129
add comment=Check local-address=4.0.0.1 name=VNB180038K remote-address=\
    5.0.0.147
add comment="\C2\E5\E4\F3\F9\E8\E9 \E8\ED\E6\E5\ED\E5\F0 \EE\F2\E4\E5\EB\E0 \
    \EF\E0\F1\F1\E0\E6\E8\F0\F1\EA\E8\F5 \EF\E5\F0\E5\E2\EE\E7\EE\EA \CE\C3\CA\
    \D3 \"\D6\E5\ED\F2\F0 \F2\F0\E0\ED\F1\EF\EE\F0\F2\E0 \C8\F0\EA\F3\F2\F1\EA\
    \EE\E9 \EE\E1\EB\E0\F1\F2\E8\r\
    \n" disabled=yes local-address=4.0.0.1 name=CTransport6 remote-address=\
    7.0.0.19
add local-address=4.0.0.1 name=T061 remote-address=6.0.0.17
add local-address=4.0.0.1 name=ORAKUL-2308038 remote-address=6.0.0.9
add local-address=4.0.0.1 name=A017-2 remote-address=5.0.0.138
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308026_REAL \
    remote-address=5.0.0.63
add comment="\C2\CD \CF\EE\E4\FA\E5\E7\E4 \EA \CF\EB\E8\F8\EA\E8\ED\EE, \EA\EC\
    \_7+900\r\
    \n" local-address=4.0.0.1 name=ITS_VN_62v2 remote-address=5.0.0.120
add disabled=yes local-address=4.0.0.1 name=C20-999 remote-address=\
    172.16.0.11
add local-address=4.0.0.1 name=SKAT-2107042 remote-address=6.0.0.12
add local-address=4.0.0.1 name=SKAT-2510038 remote-address=5.0.0.203
add local-address=4.0.0.1 name=SKAT-2510037 remote-address=5.0.0.204
add comment="\CC\CC \D3\F0\E8\EA - \D2\E8\F5\EE\ED\EE\E2\E0 \CF\E0\E4\FC, \E2\
    \FA\E5\E7\E4 \E2 \D8\E8\F0\FF\E5\E2\E0\r\
    \n" local-address=4.0.0.1 name=ITS_MM_18v2 remote-address=5.0.0.205
add local-address=4.0.0.1 name=SKATM-2006040 remote-address=6.0.0.18
add local-address=4.0.0.1 name=SVK-ZHERDOVKA remote-address=3.0.0.205
add local-address=4.0.0.1 name=T053 remote-address=6.0.0.19
add local-address=4.0.0.1 name=poberezhnyuk.ivan remote-address=172.16.0.12
add local-address=4.0.0.1 name=astafyev.maksim remote-address=172.16.0.13
add local-address=4.0.0.1 name=sirotkin.andrei remote-address=172.16.0.14
add local-address=4.0.0.1 name=khaliavin.dmitrii remote-address=172.16.0.16
add local-address=4.0.0.1 name=vasiliugin.roman remote-address=172.16.0.15
add local-address=4.0.0.1 name=SP475 remote-address=6.0.0.1
add comment=Check local-address=4.0.0.1 name=VNB180030K remote-address=\
    5.0.0.148
add local-address=4.0.0.1 name=SP482 remote-address=6.0.0.2
add local-address=4.0.0.1 name=SP483 remote-address=6.0.0.20
add local-address=4.0.0.1 name=akulov.stepan remote-address=172.16.0.19
add local-address=4.0.0.1 name=SKAT-2110005 remote-address=6.0.0.21
add comment="\D1\CE \D3\F0\E8\EA" local-address=4.0.0.1 name=ITS_SO_109 \
    remote-address=5.0.0.198
add local-address=4.0.0.1 name=SVK-OSA remote-address=3.0.0.200
add local-address=4.0.0.1 name=SKAT-1611010 remote-address=5.0.0.143
add comment=Check local-address=4.0.0.1 name=C20-681 remote-address=5.0.0.154
add comment=Check local-address=4.0.0.1 name=C20-682 remote-address=5.0.0.155
add local-address=4.0.0.1 name=F1735 remote-address=3.0.0.130
add local-address=4.0.0.1 name=SKAT-2006041 remote-address=6.0.0.22
add local-address=4.0.0.1 name=SKAT-2107040 remote-address=6.0.0.23
add local-address=4.0.0.1 name=atomtech remote-address=172.16.0.9
add local-address=4.0.0.1 name=smetanin.vadim remote-address=172.16.0.17
add comment=AUR-1906004 local-address=4.0.0.1 name=AUR-1906004 \
    remote-address=5.0.0.206
add comment=VNB180042K local-address=4.0.0.1 name=VNB180042K remote-address=\
    5.0.0.149
add local-address=4.0.0.1 name=VNB180036K remote-address=5.0.0.152
add disabled=yes local-address=4.0.0.1 name=test1 remote-address=5.0.0.211
add comment=Check local-address=4.0.0.1 name=ORAKUL-2308016 remote-address=\
    5.0.0.64
add local-address=4.0.0.1 name=A022 remote-address=5.0.0.207
add local-address=4.0.0.1 name=A023-1 remote-address=5.0.0.208
add local-address=4.0.0.1 name=A023-2 remote-address=5.0.0.209
add local-address=4.0.0.1 name=F222 remote-address=5.0.0.210
add local-address=172.16.0.254 name=ostashevskaia.ekaterina remote-address=\
    172.16.0.21
add local-address=172.16.0.254 name=volkov.evgenii remote-address=172.16.0.22
add local-address=172.16.0.254 name=sergeev.dmitrii remote-address=\
    172.16.0.23
add local-address=4.0.0.1 name=F220 remote-address=5.0.0.212
add local-address=4.0.0.1 name=VNB180032K remote-address=5.0.0.214
add local-address=4.0.0.1 name=F225 remote-address=5.0.0.213
add local-address=4.0.0.1 name=F219 remote-address=5.0.0.215
add local-address=4.0.0.1 name=F224 remote-address=5.0.0.216
add local-address=4.0.0.1 name=SKAT-1805040 remote-address=5.0.0.217
add local-address=4.0.0.1 name=C20-207 remote-address=6.0.0.24
add local-address=4.0.0.1 name=SKAT-1901018 remote-address=5.0.0.218
add local-address=4.0.0.1 name=A015-2 remote-address=5.0.0.219
add local-address=4.0.0.1 name=mukha.dmitrii remote-address=172.16.0.24
add local-address=172.16.0.254 name=sitnov.andrei profile=RAS-Emloyees \
    remote-address=172.16.0.25
add local-address=172.16.0.254 name=tankov remote-address=172.16.0.26
add local-address=4.0.0.1 name=T059 remote-address=6.0.0.25
add local-address=4.0.0.1 name=ORAKUL-2308010 remote-address=5.0.0.141
add local-address=4.0.0.1 name=VNB180022K remote-address=5.0.0.140
add comment="\D1\D3 \CC\E0\F0\EA\EE\E2\E0" local-address=4.0.0.1 name=\
    ITS_SU_2026 remote-address=5.0.0.199
add local-address=4.0.0.1 name=SKAT-1806021 remote-address=6.0.0.26
add disabled=yes local-address=4.0.0.1 name=T045 remote-address=5.0.0.220
add local-address=4.0.0.1 name=leonidov.aleksei remote-address=172.16.0.18
add comment=Check local-address=4.0.0.1 name=ATOM-2329213 remote-address=\
    5.0.0.12
add local-address=4.0.0.1 name=F223 remote-address=5.0.0.221
add disabled=yes local-address=4.0.0.1 name=TABLO_INF remote-address=\
    7.0.0.200
add local-address=4.0.0.1 name=F1953 remote-address=5.0.0.222
add local-address=4.0.0.1 name=F1954 remote-address=5.0.0.223
add local-address=4.0.0.1 name=A015-2-2 remote-address=5.0.0.211
add local-address=4.0.0.1 name=F226 remote-address=5.0.0.224
add local-address=4.0.0.1 name=ATOM-2145202 remote-address=5.0.0.225
add local-address=4.0.0.1 name=SKAT-1809084 remote-address=5.0.0.226
add comment="test mtp" name=office12 remote-address=5.0.0.227
add comment=andry_zabiyaka_codd disabled=yes local-address=172.16.0.254 name=\
    zabiyaka remote-address=172.16.0.27
add local-address=4.0.0.1 name=ATOM-2145203 remote-address=5.0.0.228
add disabled=yes local-address=4.0.0.1 name=ITS_MTP_2026_11 remote-address=\
    5.0.0.229
add local-address=4.0.0.1 name=ITS_MTP_2026_11_1 remote-address=5.0.0.230
add comment="\CF\E0\F0\EA\EE\E2\E0\FF, 4" local-address=172.16.0.254 name=\
    osipova.inga remote-address=172.16.0.28
add local-address=4.0.0.1 name=Kordon1127 remote-address=6.0.0.27
/radius
add address=10.255.63.250 service=ppp,ipsec
/routing settings
set check-gateway-ping-count=3
/snmp
set enabled=yes
/system clock
set time-zone-autodetect=no time-zone-name=Asia/Irkutsk
/system identity
set name=MTK-WAN-R1
/system logging
set 0 topics=info,!pptp,!ipsec,!l2tp,!sstp
add disabled=yes topics=debug,radius
/system ntp client
set enabled=yes
/system ntp server
set enabled=yes
/system ntp client servers
add address=ntp1.niiftri.irkutsk.ru
add address=ntp2.niiftri.irkutsk.ru
/system package update
set channel=long-term
/system routerboard settings
set enter-setup-on=delete-key
/system scheduler
add interval=10m name=Drop-PPP-duplicate-sessions on-event=\
    "/system script run Drop-PPP-duplicate-session" policy=\
    read,write,test,sensitive start-date=2026-01-22 start-time=14:24:48
/system script
add dont-require-permissions=no name=Drop-PPP-duplicate-session owner=toor \
    policy=read,write,test,sensitive source=":foreach i in [/ppp secret find] \
    do={\r\
    \n:local username [/ppp secret get \$i name]\r\
    \n:local sessions [/ppp active print count-only where name=\$username]\r\
    \n:if ( \$sessions > 1) do={:log warning (\"Disconnecting username: \94\$u\
    sername \94 as duplicate entry was found in active connection table.\")\r\
    \n/ppp active remove [find where name=\$username]\r\
    \n}\r\
    \n}"
add dont-require-permissions=no name=LE-ACME-Certificate-Update owner=toor \
    policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon \
    source=":log info \"Script - Certificate renewal start\"\
    \n\
    \n:local commName \"office-r1.kvanteng.ru\"\
    \n:local acmeUrl \"https://acme-v02.api.letsencrypt.org/directory\"\
    \n\
    \n:local oldCert [/certificate find where common-name=\$commName]\
    \nif ([:len \$oldCert] > 0) do={\
    \n    :log info \"Script - Certificate renewal | Removing old certificate/\
    request to avoid conflict.\"\
    \n    /certificate remove \$oldCert\
    \n}\
    \n\
    \n/ip service set www disabled=no\
    \n/ip firewall filter enable [find where comment=\"ACME HTTP-01 challenge\
    \"]\
    \n\
    \n/certificate add-acme domain-names=\$commName directory-url=\$acmeUrl\
    \n\
    \n\
    \n:local timeout 180\
    \n:local step 5\
    \n:local elapsed 0\
    \n:local certReady false\
    \n:local certInternalID\
    \n\
    \n:while (\$certReady = false) do={\
    \n    :set certInternalID [/certificate find where common-name=\$commName \
    and invalid=no]\
    \n    \
    \n    if ([:len \$certInternalID] > 0) do={\
    \n        :set certReady true\
    \n    } else={\
    \n        if (\$elapsed >= \$timeout) do={\
    \n            :set certReady false\
    \n            :set \$elapsed (\$timeout + 1)\
    \n        } else={\
    \n            :delay (\$step . \"s\")\
    \n            :set elapsed (\$elapsed + \$step)\
    \n        }\
    \n    }\
    \n}\
    \n\
    \n\
    \nif (\$certReady = true) do={\
    \n    :log info \"Script - Certificate renewal | Certificate found. Making\
    \_it trusted...\"\
    \n    /certificate set \$certInternalID trusted=yes\
    \n    :local certName [/certificate get \$certInternalID name]\
    \n    :log info \"Script - Certificate renewal | Applying cert '\$certName\
    ' to services...\"\
    \n    /interface/sstp-server/server set certificate=\$certName\
    \n    /ip/ipsec/identity set [find where peer=RemoteAccess] certificate=\$\
    certName\
    \n    /user-manager set certificate=\$certName\
    \n    :log info \"Script - Certificate renewal | Services updated successf\
    ully!\"\
    \n} else={\
    \n    :log error \"Script - Certificate renewal | ERROR: ACME timeout or v\
    alidation failed!\"\
    \n}\
    \n\
    \n/interface/sstp-server/server\
    \nset certificate=\$certName\
    \n\
    \n/ip service set www disabled=yes\
    \n/ip firewall filter disable [find where comment=\"ACME HTTP-01 challenge\
    \"]\
    \n\
    \n:log info \"Script - Certificate renewal end\""
add dont-require-permissions=no name=script1 owner=toor policy=\
    ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source=":\
    log info \"Script - Certificate renewal start\"\
    \n\
    \n:local commName \"office-r1.kvanteng.ru\"\
    \n:local dnsName  \"office-r1.kvanteng.ru\"\
    \n\
    \n/ip service\
    \nset www disabled=no\
    \n\
    \n/ip firewall filter\
    \nenable [find where comment=\"ACME HTTP-01 challenge\"]\
    \n\
    \n/certificate\
    \nremove [find where common-name=\$commName]\
    \nenable-ssl-certificate dns=\$dnsName\
    \n\
    \n# better insert here a loop that check when cert is ready, or timeout af\
    ter x seconds\
    \n:delay 30s\
    \n\
    \n/certificate\
    \n:local certName [get [find where common-name=\$commName] name]\
    \n\
    \n:log info \"Script - Certificate renewal | SSTP server certificate updat\
    e\"\
    \n/interface/sstp-server/server\
    \nset certificate=\$certName\
    \n:log info \"Script - Certificate renewal | SSTP server certificate updat\
    e done!\"\
    \n\
    \n:log info \"Script - Certificate renewal | IPSec certificate update\"\
    \n/ip/ipsec/identity\
    \nset [find where peer=VPN-RAS] certificate=\$certName\
    \n:log info \"Script - Certificate renewal | IPSec certificate update done\
    !\"\
    \n\
    \n#:log info \"Script - Certificate renewal | IP Services certificate upda\
    te\"\
    \n#/ip service\
    \n#set www-ssl certificate=\$certName\
    \n#:log info \"Script - Certificate renewal | IP Services certificate upda\
    te done!\"\
    \n\
    \n/ip service\
    \nset www disabled=yes\
    \n\
    \n/ip firewall filter\
    \ndisable [find where comment=\"ACME HTTP-01 challenge\"]\
    \n\
    \n:log info \"Script - Certificate renewal end\""
/tool bandwidth-server
set authenticate=no enabled=no
/tool mac-server
set allowed-interface-list=LAN
/tool mac-server mac-winbox
set allowed-interface-list=LAN
/tool sniffer
set filter-interface=*F0291B streaming-server=10.0.32.165
