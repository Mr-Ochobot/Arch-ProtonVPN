# Arch-ProtonVPN

Automated ProtonVPN OpenVPN deployment for Arch Linux with integrated DNS hardening, traffic leak protection, automatic systemd management, and iptables-based killswitch.

[Arch-ProtonVPN Screenshot](proton.png)

## Overview

Arch-ProtonVPN is a Bash-based installer designed to simplify ProtonVPN OpenVPN deployment on Arch Linux systems.

The project automates the entire setup process, including OpenVPN installation, credential configuration, DNS protection, service management, connectivity verification, and network leak prevention through a dedicated killswitch.

The goal is to provide a fully operational ProtonVPN connection with minimal manual configuration while maintaining a security-focused deployment.

---

## Features

### Automatic Installation

* Installs required packages automatically
* Creates OpenVPN client directories
* Imports ProtonVPN configuration files
* Configures authentication credentials

### OpenVPN Configuration

* Converts `.ovpn` files into systemd-managed client profiles
* Automatically configures `auth-user-pass`
* Enables credential cache protection using `auth-nocache`
* Forces VPN interface to `tun0`

### DNS Protection

* Creates a dedicated `update-resolv-conf` helper
* Resets previous DNS configurations
* Locks DNS to ProtonVPN DNS server (`10.96.0.1`)
* Prevents DNS leaks by protecting `/etc/resolv.conf`

### Killswitch Protection

* Generates dynamic iptables-based killswitch rules
* Blocks all traffic outside the VPN tunnel
* Allows communication only through:

  * Loopback interface
  * Established connections
  * ProtonVPN server endpoints
  * `tun0` interface

### Automatic Service Integration

* Enables OpenVPN systemd services
* Creates automatic killswitch activation hooks
* Automatically enables killswitch when VPN starts
* Automatically disables killswitch when VPN stops

### Connectivity Verification

The installer performs several validation steps:

* OpenVPN service status
* Tunnel interface status
* Routing verification
* VPN gateway reachability
* DNS resolution checks
* Internet connectivity tests
* Public IP verification
* Killswitch validation

---

## Requirements

### Operating System

* Arch Linux

### Privileges

Root privileges are required.

```bash
sudo ./install.sh
```

### ProtonVPN Files

Before running the installer, obtain the following files from your ProtonVPN account:

```text
protonvpn.ovpn
auth.txt
```

Example:

```text
auth.txt

username
password
```

---

## Installation

Clone the repository:

```bash
git clone https://github.com/Mr-Ochobot/Arch-ProtonVPN.git
cd Arch-ProtonVPN
```

Make the installer executable:

```bash
chmod +x install.sh
```

Run the installer:

```bash
sudo ./install.sh
```

The installer will ask for:

```text
Path to .ovpn file
Path to auth.txt file
```

Example:

```text
protonvpn.udp.ovpn
auth.txt
```

---

## What the Installer Does

1. Removes unused tun interfaces
2. Installs OpenVPN dependencies
3. Creates OpenVPN directories
4. Imports VPN configuration
5. Configures authentication
6. Configures DNS helper scripts
7. Modifies OpenVPN configuration
8. Resets DNS state
9. Enables OpenVPN systemd service
10. Starts VPN connection
11. Verifies connectivity
12. Locks DNS configuration
13. Creates and activates killswitch
14. Integrates killswitch with systemd
15. Performs final validation checks

---

## Directory Structure

```text
Arch-ProtonVPN/
├── install.sh
├── auth-setup/
│   └── auth-setup.sh
├── update-resolv-conf/
│   └── update-resolv-conf.sh
├── killswitch-on/
│   └── killswitch-on.sh
├── killswitch-off/
│   └── killswitch-off.sh
└── systemd-override/
    └── systemd-override.sh
```

---

## Service Management

Start VPN:

```bash
sudo systemctl start openvpn-client@<vpn-name>
```

Stop VPN:

```bash
sudo systemctl stop openvpn-client@<vpn-name>
```

Restart VPN:

```bash
sudo systemctl restart openvpn-client@<vpn-name>
```

Check status:

```bash
sudo systemctl status openvpn-client@<vpn-name>
```

---

## Killswitch Management

Disable killswitch manually:

```bash
sudo /etc/openvpn/client/killswitch-off.sh
```

Enable killswitch manually:

```bash
sudo /etc/openvpn/client/killswitch.sh
```

---

## Security Notes

This project includes several security-focused mechanisms:

* Authentication file permissions set to `600`
* DNS leak mitigation
* Tunnel-only traffic enforcement
* Automatic firewall restrictions
* Service lifecycle integration with killswitch
* Public IP validation after connection

Users should review generated firewall rules before deployment in production environments.

---

## Disclaimer

This project is an independent automation utility and is not affiliated with, endorsed by, or maintained by Proton AG.

Users are responsible for reviewing and understanding the generated network and firewall configurations before deployment.

---

## License

MIT License

---

## Author

Mr-Ochobot

GitHub: https://github.com/Mr-Ochobot
