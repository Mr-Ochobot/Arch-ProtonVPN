#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[!] Error: Please run this script using sudo!${NC}"
  echo -e "    Example: sudo ./install.sh"
  exit 1
fi

echo ""
read -p "$(echo -e ${CYAN}[?]${NC}) Enter VPN filename : " OVPN_FILE
read -p "$(echo -e ${CYAN}[?]${NC}) Enter auth filename: " AUTH_FILE
echo ""

if [ ! -f "$OVPN_FILE" ] || [ ! -f "$AUTH_FILE" ]; then
    echo -e "${RED}[!] Error: File '$OVPN_FILE' or '$AUTH_FILE' not found!${NC}"
    exit 1
fi

SERVICE_NAME="${OVPN_FILE%.ovpn}"      
CONF_FILE="${SERVICE_NAME}.conf"             

echo -e "${GREEN}[*] SMART CHECK${NC}"
VPN_SERVER_IP=$(grep "^remote " "$OVPN_FILE" | head -1 | awk '{print $2}')
VPN_PORTS=$(grep "^remote " "$OVPN_FILE" | awk '{print $3}' | sort -u | paste -sd "," -)
[ -z "$VPN_PORTS" ] && VPN_PORTS="1194"
MAIN_IF=$(ip route | grep default | awk '{print $5}' | head -1)

echo -e "    ├─ OVPN File     : ${CYAN}$OVPN_FILE${NC}"
echo -e "    ├─ Auth File     : ${CYAN}$AUTH_FILE${NC}"
echo -e "    ├─ VPN Server IP : ${CYAN}$VPN_SERVER_IP${NC}"
echo -e "    ├─ VPN Ports     : ${CYAN}$VPN_PORTS${NC}"
echo -e "    └─ Interface     : ${CYAN}$MAIN_IF${NC}"
echo ""

echo -e "${GREEN}[*] INSTALLING OPENVPN & INJECTING CONFIG${NC}"
mkdir -p /etc/openvpn/client /etc/iptables
cp "$OVPN_FILE" "/etc/openvpn/client/$CONF_FILE"
cp "$AUTH_FILE" "/etc/openvpn/client/auth.txt"
chmod 600 "/etc/openvpn/client/auth.txt"
cd /etc/openvpn/client || exit

sed -i 's/^auth-user-pass$/auth-user-pass auth.txt/g' "$CONF_FILE"
sed -i 's|^up /etc/openvpn/update-resolv-conf|# up /etc/openvpn/update-resolv-conf|g' "$CONF_FILE"
sed -i 's|^down /etc/openvpn/update-resolv-conf|# down /etc/openvpn/update-resolv-conf|g' "$CONF_FILE"
echo -e "    └─ ${GREEN}Success:${NC} Config injected with auth.txt."
echo ""

echo -e "${GREEN}[*] CREATING UNIVERSAL KILL SWITCH${NC}"
cat > /etc/iptables/rules.v4 <<EOF
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT DROP [0:0]
-A OUTPUT -o lo -j ACCEPT
-A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A OUTPUT -o $MAIN_IF -p udp --dport 67 -j ACCEPT
-A OUTPUT -o $MAIN_IF -p udp --dport 68 -j ACCEPT
-A OUTPUT -o $MAIN_IF -p udp --dport 53 -d 10.96.0.1 -j ACCEPT
-A OUTPUT -o tun0 -j ACCEPT
-A OUTPUT -d $VPN_SERVER_IP/32 -o $MAIN_IF -p udp -m multiport --dports $VPN_PORTS -j ACCEPT
-A OUTPUT -d $VPN_SERVER_IP/32 -o $MAIN_IF -p tcp -m multiport --dports $VPN_PORTS -j ACCEPT
COMMIT
EOF
echo -e "    └─ ${GREEN}Success:${NC} Iptables rules (rules.v4) created."
echo ""

echo -e "${GREEN}[*] CREATING KILL SWITCH SERVICE${NC}"
cat > /etc/systemd/system/killswitch.service <<EOF
[Unit]
Description=Kill Switch Iptables
Before=network-pre.target
Wants=network-pre.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c '/sbin/iptables -F OUTPUT; /sbin/iptables-restore --noflush < /etc/iptables/rules.v4'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
echo -e "    └─ ${GREEN}Success:${NC} killswitch.service created."
echo ""

echo -e "${GREEN}[*] CONFIGURING DNS ANTI-LEAK${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "nameserver 10.96.0.1" > /etc/resolv.conf
echo "nameserver 10.96.0.2" >> /etc/resolv.conf
chattr +i /etc/resolv.conf
echo -e "    └─ ${GREEN}Success:${NC} DNS permanently locked to 10.96.0.1."
echo ""

echo -e "${GREEN}[*] ACTIVATING ALL SERVICES${NC}"
systemctl stop "openvpn-client@${SERVICE_NAME}" >/dev/null 2>&1
systemctl daemon-reload
systemctl enable killswitch.service >/dev/null 2>&1
systemctl start killswitch.service
echo -e "    ├─ ${GREEN}Active:${NC} Kill Switch Service"

systemctl enable "openvpn-client@${SERVICE_NAME}" >/dev/null 2>&1
systemctl start "openvpn-client@${SERVICE_NAME}"
echo -e "    └─ ${GREEN}Active:${NC} OpenVPN Service"
echo ""

echo -e "${GREEN}[*] WAITING FOR STABLE CONNECTION${NC}"
echo -ne "    ├─ Waiting for OpenVPN initialization "

for i in {1..30}; do
    if journalctl -u "openvpn-client@${SERVICE_NAME}" -n 50 --no-pager | grep -q "Initialization Sequence Completed"; then
        echo -e "${GREEN}[OK]${NC}"
        break
    fi
    sleep 2
    echo -n "."
done

echo -ne "    └─ Stabilizing routes "
for i in {1..10}; do
    sleep 2
    echo -n "."
done
echo -e " ${GREEN}[OK]${NC}"
echo ""

echo -e "${GREEN}[*] CHECKING PUBLIC IP${NC}"
IP_RESULT=$(curl -s ifconfig.me 2>/dev/null)
if [ -n "$IP_RESULT" ]; then
    echo -e "    └─ Your Public IP: ${CYAN}${BOLD}$IP_RESULT${NC}"
else
    echo -e "    └─ ${RED}Failed to retrieve IP (Check your connection)${NC}"
fi
echo ""
