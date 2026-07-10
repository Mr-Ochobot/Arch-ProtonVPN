#!/bin/bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[0;37m'
NC='\033[0m'

echo -e "${BLUE}"
cat << "EOF"
                  -`
                 .o+`
                `ooo/
               `+oooo:
              `+oooooo:
              -+oooooo+:
            `/:-:++oooo+:
           `/++++/+++++++:
          `/++++++++++++++:
         `/+++ooooooooooooo/`
        ./ooosssso++osssssso+`
       .oossssso-````/ossssss+`
      -osssssso.      :ssssssso.
     :osssssss/        osssso+++.
    /ossssssss/        +ssssooo/-
  `/ossssso+/:-        -:/+osssso+-
 `+sso+:-`                 `.-/+oso:
`++:.                           `-/+/
.`                                 `/
EOF
echo -e "${NC}"

echo ""
echo -e "${WHITE}[${RED}!${WHITE}] ${GREEN}Proton VPN TCP Auto Install Arch Linux ${WHITE}[${RED}!${WHITE}]${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Error: Please run as root (sudo)${NC}" 
   exit 1
fi

echo ""
echo -e "${YELLOW}Enter the path to your TCP .ovpn file:${NC}"
echo -e "Example: /home/username/Downloads/no-free-2.protonvpn.tcp.ovpn"
read -p "Path: " OVPN_PATH

if [[ ! -f "$OVPN_PATH" ]]; then
    echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Error: .ovpn file not found!${NC}"
    exit 1
fi

echo -e "${YELLOW}Enter the path to your auth.txt file:${NC}"
echo -e "Example: /home/username/Downloads/auth.txt"
read -p "Path: " AUTH_PATH

if [[ ! -f "$AUTH_PATH" ]]; then
    echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Error: auth.txt file not found!${NC}"
    exit 1
fi

OVPN_FILE=$(basename "$OVPN_PATH")
VPN_NAME=$(echo "$OVPN_FILE" | sed 's/\.ovpn$//')
REMOTE_IPS=$(grep "^remote" "$OVPN_PATH" | awk '{print $2}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u)
REMOTE_PORTS=$(grep "^remote" "$OVPN_PATH" | awk '{print $3}' | sort -u)

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${GREEN}INFORMATION${NC}"
echo -e "    VPN Name: ${YELLOW}$VPN_NAME${NC}"
echo -e "    Remote IPs: ${YELLOW}$REMOTE_IPS${NC}"
echo -e "    Remote Ports: ${YELLOW}$REMOTE_PORTS${NC}"
echo -e "    Protocol: ${GREEN}TCP${NC}"
echo ""

echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Cleaning old tun interfaces...${NC}"
for i in 0 1 2 3 4; do
    ip link delete tun$i 2>/dev/null
done
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Clean${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Installing packages...${NC}"
pacman -Syu --noconfirm openvpn openresolv wget bind > /dev/null 2>&1
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Packages installed${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Creating directory...${NC}"
mkdir -p /etc/openvpn/client
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Directory ready${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Copying configuration files...${NC}"
cp -f "$OVPN_PATH" "/etc/openvpn/client/$VPN_NAME.conf"
cp -f "$AUTH_PATH" /etc/openvpn/client/auth.txt 2>/dev/null || true
chmod 600 /etc/openvpn/client/auth.txt 2>/dev/null || true
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}auth.txt permission 600${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Creating update-resolv-conf...${NC}"
cat > /etc/openvpn/update-resolv-conf << 'EOF'
#!/bin/bash
case $script_type in
  up)
    if [ -n "$foreign_option_1" ]; then
      echo "Setting DNS from OpenVPN"
      for optionname in ${!foreign_option_*} ; do
        option="${!optionname}"
        if [[ "$option" =~ "dhcp-option DOMAIN" ]] ; then
          echo "domain ${option#dhcp-option DOMAIN }"
        elif [[ "$option" =~ "dhcp-option DNS" ]] ; then
          echo "nameserver ${option#dhcp-option DNS }"
        fi
      done | resolvconf -a tun.${dev}
    fi
    ;;
  down)
    resolvconf -d tun.${dev}
    ;;
esac
EOF
chmod +x /etc/openvpn/update-resolv-conf
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}update-resolv-conf ready${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Editing configuration for TCP...${NC}"
CONF="/etc/openvpn/client/$VPN_NAME.conf"

sed -i 's/^dev tun$/dev tun0/' "$CONF"

sed -i 's/^proto udp$/proto tcp/' "$CONF"

if grep -q "^auth-user-pass$" "$CONF"; then
    sed -i 's/^auth-user-pass$/auth-user-pass \/etc\/openvpn\/client\/auth.txt/' "$CONF"
elif grep -q "^auth-user-pass /" "$CONF"; then
    sed -i 's|^auth-user-pass .*|auth-user-pass /etc/openvpn/client/auth.txt|' "$CONF"
else
    sed -i '/^remote-cert-tls server/a auth-user-pass /etc/openvpn/client/auth.txt' "$CONF"
fi

if ! grep -q "auth-nocache" "$CONF"; then
    sed -i '/auth-user-pass/a auth-nocache' "$CONF"
fi

sed -i 's/^up \/etc\/openvpn\/update-resolv-conf/#up \/etc\/openvpn\/update-resolv-conf/' "$CONF"
sed -i 's/^down \/etc\/openvpn\/update-resolv-conf/#down \/etc\/openvpn\/update-resolv-conf/' "$CONF"

if ! grep -q "keepalive" "$CONF"; then
    echo "keepalive 10 60" >> "$CONF"
fi

if ! grep -q "tcp-nodelay" "$CONF"; then
    echo "tcp-nodelay" >> "$CONF"
fi

echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Configuration complete (TCP)${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Resetting resolvconf...${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf 2>/dev/null
resolvconf -u 2>/dev/null
systemctl restart systemd-resolved 2>/dev/null
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}resolvconf reset${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Removing temporary systemd override...${NC}"
rm -f /etc/systemd/system/openvpn-client@$VPN_NAME.service.d/override.conf 2>/dev/null
systemctl daemon-reload
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Override removed${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Enabling service...${NC}"
systemctl enable "openvpn-client@$VPN_NAME" > /dev/null 2>&1
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Service enabled${NC}"

is_vpn_connected() {
    if ! systemctl is-active --quiet "openvpn-client@$VPN_NAME"; then
        return 1
    fi
    
    if ! ip a | grep -q "tun0:.*UP"; then
        return 1
    fi
    
    if ! ip route show | grep -q "dev tun0"; then
        return 1
    fi
    
    if ! ping -c 2 -W 2 10.96.0.1 > /dev/null 2>&1; then
        return 1
    fi
    
    if ! dig @10.96.0.1 google.com +short > /dev/null 2>&1; then
        return 1
    fi
    
    if ! ping -c 2 -W 3 google.com > /dev/null 2>&1; then
        return 1
    fi
    
    if ! curl -s --max-time 5 ifconfig.me > /dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

fix_error() {
    echo -e "${YELLOW}    [!] Applying generic fix...${NC}"
    
    for i in 0 1 2 3 4; do
        ip link delete tun$i 2>/dev/null
    done
    
    chattr -i /etc/resolv.conf 2>/dev/null
    rm -f /etc/resolv.conf 2>/dev/null
    resolvconf -u 2>/dev/null
    systemctl restart systemd-resolved 2>/dev/null
    
    systemctl restart NetworkManager 2>/dev/null
    
    if [[ ! -f "/etc/openvpn/client/auth.txt" ]]; then
        cp -f "$AUTH_PATH" /etc/openvpn/client/auth.txt 2>/dev/null
        chmod 600 /etc/openvpn/client/auth.txt
    fi
    
    if [[ $(wc -l < /etc/openvpn/client/auth.txt 2>/dev/null) -lt 2 ]]; then
        echo -e "${YELLOW}        auth.txt is invalid. Please re-enter credentials:${NC}"
        read -p "Username: " VPN_USER
        read -s -p "Password: " VPN_PASS
        echo ""
        echo "$VPN_USER" > /etc/openvpn/client/auth.txt
        echo "$VPN_PASS" >> /etc/openvpn/client/auth.txt
        chmod 600 /etc/openvpn/client/auth.txt
    fi
    
    echo -e "${GREEN}        [✓] Fix applied${NC}"
}

MAX_RETRIES=10
ATTEMPT=1
SUCCESS=0

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Starting VPN (TCP) - Retry until connected...${NC}"

while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}[*] Attempt $ATTEMPT of $MAX_RETRIES [*]${NC}"
    
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Starting OpenVPN...${NC}"
    systemctl restart "openvpn-client@$VPN_NAME"
    
    for i in {1..10}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking connection...${NC}"
    if is_vpn_connected; then
        PUBLIC_IP=$(curl -s --max-time 5 ifconfig.me)
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}VPN connected! Public IP: $PUBLIC_IP${NC}"
        SUCCESS=1
        break
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Not connected yet${NC}"
        
        ERROR_MSG=$(journalctl -xeu "openvpn-client@$VPN_NAME.service" --no-pager 2>/dev/null | tail -10)
        if echo "$ERROR_MSG" | grep -q "Connection refused\|Connection timed out"; then
            echo -e "${YELLOW}    [!] Connection issue detected (server may be slow)${NC}"
        elif echo "$ERROR_MSG" | grep -q "auth failed"; then
            echo -e "${YELLOW}    [!] Auth failed! Please check credentials${NC}"
        fi
        
        if [[ $ATTEMPT -gt 3 ]]; then
            fix_error
        fi
        
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [[ $SUCCESS -eq 0 ]]; then
    echo ""
    echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}[!] FAILED AFTER $MAX_RETRIES ATTEMPTS [!]${NC}"
    echo -e "${YELLOW}Please check manually:${NC}"
    echo -e "    sudo systemctl status openvpn-client@$VPN_NAME"
    echo -e "    sudo journalctl -xeu openvpn-client@$VPN_NAME --no-pager | tail -30"
    echo -e "    sudo openvpn --config /etc/openvpn/client/$VPN_NAME.conf"
    exit 1
fi

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Locking DNS to 10.96.0.1...${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf
echo "nameserver 10.96.0.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf 2>/dev/null
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}DNS locked${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Building killswitch...${NC}"

cat > /etc/openvpn/client/killswitch.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -o tun0 -j ACCEPT
EOF

for ip in $REMOTE_IPS; do
    for port in $REMOTE_PORTS; do
        echo "iptables -A OUTPUT -d $ip -p tcp --dport $port -j ACCEPT" >> /etc/openvpn/client/killswitch.sh
    done
done

cat >> /etc/openvpn/client/killswitch.sh << 'EOF'
iptables -A OUTPUT -o tun0 -p icmp -j ACCEPT
echo "Killswitch active"
EOF

chmod +x /etc/openvpn/client/killswitch.sh

cat > /etc/openvpn/client/killswitch-off.sh << 'EOF'
#!/bin/bash
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "Killswitch disabled"
EOF

chmod +x /etc/openvpn/client/killswitch-off.sh

/etc/openvpn/client/killswitch.sh
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Killswitch applied${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking killswitch...${NC}"
if iptables -L OUTPUT -v -n 2>/dev/null | grep -q "tun0"; then
    echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Killswitch active${NC}"
else
    echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Killswitch failed!${NC}"
    exit 1
fi

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Setting up systemd override...${NC}"
mkdir -p /etc/ststemd/system/openvpn-client@$VPN_NAMEPN_NAME.services.d
cat > /etc/systemcd/system/openvpn-client@$VPN_NAME.services.d/override.conf << 'EOF'
[Services]
ExecStartPre=/etc/openvpn/client/killswitch.sh
ExecStopPost=/etc/openvpn/client/killswitch-off.sh
EOF
systemctl daemond-reload
echo -e "  ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}systemd override ready${NC}"

echo "" 
echo -e  "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Final test...${NC}"
if ping -c 2 -w 3 google.com > /dev/null 2>&1; then
    echo -e "  ${WHITE}[${GREEN}✓${WHITE}] ${GREEN} Internet is working${NC}"
else
    echo -e "  ${WHITE}[${RED}✗${WHITE}] ${RED} Internet not working!${NC}"
    exit 1
fi

echo "" 
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${GREEN} Buat Hotu lao diak no kompletu{NC}"
echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Status Final${NC}"
echo -e "  VPN: ${YELLOW}$VPN_NAME{NC}"
echo -e "  Protocol: ${GREEN}TCP${NC}"
echo -e "  Public Ip: ${YELLOW}$PUBLIC_IP${NC}"
echo -e "  DNS: ${GREEN}10.96.0.1 yes${NC}"
echo -e "  Killswitch: ${GREEN}Activo{N}"
echo -e "  Killswitch: ${GREEN}Hahu Lao${NC}"
echo ""
echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Command Atu Hahu${NC}"
echo -e "  Start VPN:  ${GREEN}sudo systemctl start openvpn-client@$VPN_NAME${NC}"
echo -e "  Stop VPN:   ${GREEN}sudo systemctl stop openvpn-client@$VPN_NAME${N}"
echo -e "  Status:     ${GREEN}sudo systemctl status openvpn-client@$VPN_NAME${NC}"
echo -e "  Disable Killswitch Manual:  ${GREEN}sudo /etc/openvpn/client/killswitch-off.sh${N}"
echo -e "  Final:  ${GREEN}HET MALU${N}"