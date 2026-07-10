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
echo -e "${WHITE}[${RED}!${WHITE}] ${GREEN}Proton Auto Install Arch Linux ${WHITE}[${RED}!${WHITE}]${NC}"
echo ""

if [[ $EUID -ne 0 ]]; then
   echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Error: Please run as root (sudo)${NC}" 
   exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking supporting folders...${NC}"

FOLDERS=("auth-setup" "update-resolv-conf" "killswitch-on" "killswitch-off" "systemd-override")
MISSING_FOLDERS=()

for folder in "${FOLDERS[@]}"; do
    if [[ ! -d "$SCRIPT_DIR/$folder" ]]; then
        MISSING_FOLDERS+=("$folder")
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}$folder not found!${NC}"
    else
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}$folder found${NC}"
    fi
done

if [[ ${#MISSING_FOLDERS[@]} -gt 0 ]]; then
    echo -e "${RED}[✗] Missing folders: ${MISSING_FOLDERS[*]}${NC}"
    echo -e "${YELLOW}Please make sure all folders exist in: $SCRIPT_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Copying supporting folders to /etc/openvpn/client/...${NC}"

for folder in "${FOLDERS[@]}"; do
    sudo cp -rf "$SCRIPT_DIR/$folder" /etc/openvpn/client/
    if [[ -d "/etc/openvpn/client/$folder" ]]; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}$folder copied${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}$folder failed to copy!${NC}"
        exit 1
    fi
done

LIB_DIR="/etc/openvpn/client"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${GREEN}All folders copied to $LIB_DIR${NC}"

echo ""
echo -e "${YELLOW}Enter the path to your .ovpn file:${NC}"
echo -e "Example: /home/username/Downloads/mx-free-5.protonvpn.udp.ovpn"
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

export OVPN_PATH
export AUTH_PATH
export VPN_NAME
export REMOTE_IPS
export REMOTE_PORTS
export LIB_DIR
export RED GREEN YELLOW BLUE WHITE NC

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${GREEN}INFORMATION${NC}"
echo -e "    VPN Name: ${YELLOW}$VPN_NAME${NC}"
echo -e "    Remote IPs: ${YELLOW}$REMOTE_IPS${NC}"
echo -e "    Remote Ports: ${YELLOW}$REMOTE_PORTS${NC}"
echo -e "    Scripts Directory: ${YELLOW}$LIB_DIR${NC}"
echo ""

run_script() {
    local script_name=$1
    local script_path="$LIB_DIR/$script_name/$script_name.sh"
    
    if [[ -f "$script_path" ]]; then
        echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Running $script_name...${NC}"
        bash "$script_path"
        if [[ $? -ne 0 ]]; then
            echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}$script_name failed!${NC}"
            exit 1
        fi
    else
        echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Script not found: $script_path${NC}"
        exit 1
    fi
}

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
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Editing configuration...${NC}"
CONF="/etc/openvpn/client/$VPN_NAME.conf"

sed -i 's/^dev tun$/dev tun0/' "$CONF"

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

echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Configuration complete${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Resetting resolvconf...${NC}"
chattr -i /etc/resolv.conf 2>/dev/null
rm -f /etc/resolv.conf 2>/dev/null
resolvconf -u 2>/dev/null
systemctl restart systemd-resolved 2>/dev/null
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}resolvconf reset${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Removing temporary systemd override...${NC}"
sudo rm -f /etc/systemd/system/openvpn-client@$VPN_NAME.service.d/override.conf 2>/dev/null
sudo systemctl daemon-reload
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Override removed${NC}"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Enabling service...${NC}"
systemctl enable "openvpn-client@$VPN_NAME" > /dev/null 2>&1
echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Service enabled${NC}"

run_script "auth-setup"

run_script "update-resolv-conf"

check_error() {
    local ERROR_MSG=$(sudo journalctl -xeu "openvpn-client@$VPN_NAME.service" --no-pager 2>/dev/null | tail -20)
    
    if echo "$ERROR_MSG" | grep -q "No such file or directory"; then
        echo "MISSING_FILE"
    elif echo "$ERROR_MSG" | grep -q "auth failed"; then
        echo "AUTH_FAILED"
    elif echo "$ERROR_MSG" | grep -q "connection refused\|connection timed out"; then
        echo "CONNECTION_FAILED"
    elif echo "$ERROR_MSG" | grep -q "resolvconf: signature mismatch"; then
        echo "RESOLVCONF_ERROR"
    elif echo "$ERROR_MSG" | grep -q "options error"; then
        echo "OPTIONS_ERROR"
    else
        echo "UNKNOWN_ERROR"
    fi
}

fix_error() {
    local ERROR_TYPE=$1
    
    case $ERROR_TYPE in
        "MISSING_FILE")
            echo -e "${YELLOW}    [!] Fix: Missing file detected${NC}"
            [[ ! -f "/etc/openvpn/client/$VPN_NAME.conf" ]] && cp -f "$OVPN_PATH" "/etc/openvpn/client/$VPN_NAME.conf" 2>/dev/null
            [[ ! -f "/etc/openvpn/client/auth.txt" ]] && cp -f "$AUTH_PATH" /etc/openvpn/client/auth.txt 2>/dev/null && chmod 600 /etc/openvpn/client/auth.txt
            echo -e "${GREEN}        [✓] Files restored${NC}"
            ;;
        "AUTH_FAILED")
            echo -e "${YELLOW}    [!] Fix: Authentication failed${NC}"
            echo -e "${YELLOW}        Please re-enter your credentials:${NC}"
            read -p "Username: " VPN_USER
            read -s -p "Password: " VPN_PASS
            echo ""
            echo "$VPN_USER" > /etc/openvpn/client/auth.txt
            echo "$VPN_PASS" >> /etc/openvpn/client/auth.txt
            chmod 600 /etc/openvpn/client/auth.txt
            echo -e "${GREEN}        [✓] auth.txt recreated${NC}"
            ;;
        "CONNECTION_FAILED")
            echo -e "${YELLOW}    [!] Fix: Connection failed${NC}"
            systemctl restart NetworkManager 2>/dev/null
            systemctl restart systemd-resolved 2>/dev/null
            for i in 0 1 2 3 4; do ip link delete tun$i 2>/dev/null; done
            echo -e "${GREEN}        [✓] Network reset${NC}"
            ;;
        "RESOLVCONF_ERROR")
            echo -e "${YELLOW}    [!] Fix: resolvconf error${NC}"
            chattr -i /etc/resolv.conf 2>/dev/null
            rm -f /etc/resolv.conf 2>/dev/null
            resolvconf -u 2>/dev/null
            systemctl restart systemd-resolved 2>/dev/null
            echo -e "${GREEN}        [✓] resolvconf reset${NC}"
            ;;
        "OPTIONS_ERROR")
            echo -e "${YELLOW}    [!] Fix: Options error${NC}"
            sed -i 's/^up \/etc\/openvpn\/update-resolv-conf/#up \/etc\/openvpn\/update-resolv-conf/' "$CONF"
            sed -i 's/^down \/etc\/openvpn\/update-resolv-conf/#down \/etc\/openvpn\/update-resolv-conf/' "$CONF"
            echo -e "${GREEN}        [✓] up/down scripts disabled${NC}"
            ;;
        *)
            echo -e "${YELLOW}    [!] Generic fix...${NC}"
            for i in 0 1 2 3 4; do ip link delete tun$i 2>/dev/null; done
            chattr -i /etc/resolv.conf 2>/dev/null
            rm -f /etc/resolv.conf 2>/dev/null
            systemctl restart systemd-resolved 2>/dev/null
            echo -e "${GREEN}        [✓] Generic fix applied${NC}"
            ;;
    esac
}

run_full_check() {
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking VPN status...${NC}"
    if systemctl is-active --quiet "openvpn-client@$VPN_NAME"; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}VPN active${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}VPN failed!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking tun0 interface...${NC}"
    if ip a | grep -q "tun0:.*UP"; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}tun0 UP${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}tun0 not UP!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking routing...${NC}"
    if ip route show | grep -q "dev tun0"; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Routing via tun0${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Routing not via tun0!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking gateway...${NC}"
    if ping -c 3 -W 2 10.96.0.1 > /dev/null 2>&1; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Gateway reachable${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Gateway not responding!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Setting up DNS...${NC}"
    chattr -i /etc/resolv.conf 2>/dev/null
    rm -f /etc/resolv.conf
    echo "nameserver 10.96.0.1" > /etc/resolv.conf
    chattr +i /etc/resolv.conf 2>/dev/null
    echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}DNS set to 10.96.0.1${NC}"
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking DNS...${NC}"
    if dig @10.96.0.1 google.com +short > /dev/null 2>&1; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}DNS 10.96.0.1 working${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}DNS not working!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking internet...${NC}"
    if ping -c 2 -W 3 google.com > /dev/null 2>&1; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Internet connected${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}No internet!${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking public IP...${NC}"
    PUBLIC_IP=$(curl -s --max-time 10 ifconfig.me)
    if [[ -n "$PUBLIC_IP" ]]; then
        echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Public IP: $PUBLIC_IP${NC}"
    else
        echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Failed to get IP!${NC}"
        return 1
    fi
    
    return 0
}

MAX_RETRIES=3
ATTEMPT=1
SUCCESS=0

while [[ $ATTEMPT -le $MAX_RETRIES ]]; do
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}=== Attempt $ATTEMPT of $MAX_RETRIES ===${NC}"
    
    echo ""
    echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Starting VPN...${NC}"
    systemctl restart "openvpn-client@$VPN_NAME"
    sleep 10
    
    if run_full_check; then
        SUCCESS=1
        break
    else
        echo ""
        echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Checks failed! Diagnosing...${NC}"
        ERROR_TYPE=$(check_error)
        echo -e "    Error type: ${YELLOW}$ERROR_TYPE${NC}"
        
        echo ""
        echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Fixing error...${NC}"
        fix_error "$ERROR_TYPE"
        
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [[ $SUCCESS -eq 0 ]]; then
    echo ""
    echo -e "${WHITE}[${RED}✗${WHITE}] ${RED}Failed After $MAX_RETRIES Attemps${NC}"
    echo -e "${YELLOW}Please check manually:${NC}"
    echo -e "    sudo systemctl status openvpn-client@$VPN_NAME"
    echo -e "    sudo journalctl -xeu openvpn-client@$VPN_NAME --no-pager | tail -30"
    exit 1
fi

run_script "killswitch-on"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Checking killswitch...${NC}"
if iptables -L OUTPUT -v -n 2>/dev/null | grep -q "tun0"; then
    echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Killswitch active${NC}"
else
    echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Killswitch failed!${NC}"
    exit 1
fi

run_script "systemd-override"

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Final test...${NC}"
if ping -c 2 -W 3 google.com > /dev/null 2>&1; then
    echo -e "    ${WHITE}[${GREEN}✓${WHITE}] ${GREEN}Internet is working (via VPN)${NC}"
else
    echo -e "    ${WHITE}[${RED}✗${WHITE}] ${RED}Internet not working!${NC}"
    exit 1
fi

echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${GREEN}All Checks Passed..!${NC}"
echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}Final Status...${NC}"
echo -e "    VPN: ${YELLOW}$VPN_NAME${NC}"
echo -e "    Public IP: ${YELLOW}$PUBLIC_IP${NC}"
echo -e "    DNS: ${GREEN}10.96.0.1 (locked)${NC}"
echo -e "    Killswitch: ${GREEN}ACTIVE${NC}"
echo ""
echo -e "${WHITE}[${GREEN}✓${WHITE}] ${BLUE}COMMANDS${NC}"
echo -e "    Start VPN:  ${GREEN}sudo systemctl start openvpn-client@$VPN_NAME${NC}"
echo -e "    Stop VPN:   ${GREEN}sudo systemctl stop openvpn-client@$VPN_NAME${NC}"
echo -e "    Status:     ${GREEN}sudo systemctl status openvpn-client@$VPN_NAME${NC}"
echo -e "    Disable killswitch manually: ${GREEN}sudo /etc/openvpn/client/killswitch-off.sh${NC}"
