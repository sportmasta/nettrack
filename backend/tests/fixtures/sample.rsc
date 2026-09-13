# 2026-09-12 by RouterOS 7.21.5
# model = CCR2004-16G-2S+
/interface bridge
add name=VPN-bridge
add name=bridge1 vlan-filtering=yes
/interface ethernet
set [ find default-name=ether15 ] comment="VipNet Coordinator HW100"
set [ find default-name=ether16 ] comment=ISP-PHY-Rostelecom
set [ find default-name=sfp-sfpplus1 ] comment=N9K-A
set [ find default-name=sfp-sfpplus2 ] comment=N9K-B
/interface gre
add comment="CAFAP R1" local-address=90.188.224.225 mtu=\
    1400 name=Tun01 remote-address=93.94.178.33
add comment=toDirect name=Tun04 local-address=90.188.224.225 remote-address=\
    95.189.32.202
/interface vlan
add comment=Networking_OOB_mgmt interface=bridge1 name=VLAN2 vlan-id=2
add comment=Routing interface=bridge1 name=VLAN9 vlan-id=9
/interface bonding
add name=LACP1 slaves=sfp-sfpplus1,sfp-sfpplus2
/interface list
add name=LAN
add name=WAN
add name=VPN-S2S
/routing table
add fib name=via-direct
/interface list member
add interface=ether16 list=WAN
add interface=PPP-Rostelecom list=WAN
add interface=VLAN2 list=LAN
add interface=VLAN9 list=LAN
add interface=Tun01 list=VPN-S2S
add interface=Tun04 list=VPN-S2S
/interface pppoe-client
add add-default-route=yes comment=WAN-Rostelecom interface=ether16 name=\
    PPP-Rostelecom user=secret-user password=super-secret
/ip address
add address=10.255.63.62/26 interface=VLAN2 network=10.255.63.0
add address=10.255.63.254/28 interface=VLAN9 network=10.255.63.240
add address=172.16.3.10/30 interface=Tun01 network=172.16.3.8
add address=172.16.3.18/30 interface=Tun04 network=172.16.3.16
/ip firewall mangle
add action=mark-routing chain=prerouting comment="atlas reply via direct" \
    new-routing-mark=via-direct src-address=10.255.63.193
/ip firewall nat
add action=src-nat chain=srcnat comment="LAN -> INET SRC-NAT" \
    out-interface=PPP-Rostelecom to-addresses=90.188.224.225
add action=dst-nat chain=dstnat comment="VipNet coordinator" dst-port=55777 \
    in-interface=PPP-Rostelecom protocol=udp to-addresses=192.168.100.2 \
    to-ports=55777
/ip route
add comment="office" dst-address=10.0.32.0/24 gateway=10.255.63.241 \
    routing-table=main
add dst-address=10.38.0.0/16 gateway=Tun04 routing-table=main
add comment="atlas NAT reply via direct" dst-address=0.0.0.0/0 gateway=Tun04 \
    routing-table=via-direct
/system identity
set name=MTK-WAN-R1
