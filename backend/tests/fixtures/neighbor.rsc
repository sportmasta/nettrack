# model = RB4011iGS+
/interface ethernet
set [ find default-name=ether1 ] comment=WAN-PHY
set [ find default-name=ether2 ] comment=Office
/interface gre
add comment="to MTK-WAN-R1" local-address=93.94.178.33 name=gre-hub remote-address=\
    90.188.224.225
/interface vlan
add comment=Office interface=bridge1 name=VLAN10 vlan-id=10
/interface list
add name=LAN
add name=WAN
/interface list member
add interface=ether1 list=WAN
add interface=VLAN10 list=LAN
add interface=ether2 list=LAN
/ip address
add address=172.16.3.9/30 interface=gre-hub network=172.16.3.8
add address=10.20.0.1/24 interface=VLAN10 network=10.20.0.0
/ip route
add comment="hub LAN" dst-address=10.255.63.0/26 gateway=gre-hub
add comment="transit unknown" dst-address=192.168.50.0/24 gateway=gre-hub
/system identity
set name=CAFAP-R1
