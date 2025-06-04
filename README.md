# VPN Auto Connector

Automated Bash script for establishing OpenConnect-based VPN connections with automatic port forwarding configuration.

## Features

- 🔄 Multiple VPN configuration support
- 🔐 Secure connections via OpenConnect protocol
- 🚀 Automatic port forwarding setup
- 📝 Comprehensive logging system
- ⏱️ Timeout control for reliable connections
- 🔑 TOTP support (FEATURE)
- 🧹 Automatic cleanup of existing connections

## Requirements

- Linux operating system
- OpenConnect VPN client
- jq (JSON parser)
- iptables
- Root privileges

### Installation

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install openconnect jq iptables-persistent

# CentOS/RHEL
sudo yum install openconnect jq iptables-services

# Arch Linux
sudo pacman -S openconnect jq iptables
```

## Configuration

Create `/root/vpn.json` file:

```json
[
  {
    "VPN_NAME": "Corporate VPN",
    "VPN_SERVER": "vpn.company.com",
    "VPN_USER": "username",
    "VPN_PASSWORD": "password",
    "VPN_PROTOCOL": "fortinet",
    "SERVER_CERT_PIN": "sha256:abcd1234...",
    "TOTP": "false",
    "FORWARD": [
      {
        "protocol": "ssh",
        "ipaddress": "192.168.1.100",
        "port": "80",
        "forward": "8080"
      },
      {
        "protocol": "http", 
        "ipaddress": "192.168.1.101",
        "port": "443",
        "forward": "8443"
      }
    ]
  }
]
```

### Configuration Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `VPN_NAME` | Display name for the VPN connection | `"Office VPN"` |
| `VPN_SERVER` | VPN server address | `"vpn.example.com"` |
| `VPN_USER` | Username for authentication | `"john.doe"` |
| `VPN_PASSWORD` | Password for authentication | `"mypassword"` |
| `VPN_PROTOCOL` | Connection protocol | `"fortinet" or "any openconnect supports protocol"` |
| `SERVER_CERT_PIN` | Server certificate pin | `"sha256:..."` |
| `TOTP` | TOTP requirement flag | `"true"` or `"false"` |
| `FORWARD` | Port forwarding rules array | Array of forwarding objects |

## Usage

### Basic Usage

```bash
# Make the script executable
chmod +x vpn-connector.sh

# Run as root
sudo ./vpn-connector.sh
```

### Running as Systemd Service

Create `/etc/systemd/system/vpn-connector.service`:

```ini
[Unit]
Description=VPN Auto Connector
After=network.target

[Service]
Type=oneshot
ExecStart=/root/vpn-connector.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable the service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable vpn-connector.service
sudo systemctl start vpn-connector.service
```

## Logging

The script logs all activities to `/root/vpn.log`:

```bash
# View logs in real-time
tail -f /root/vpn.log

# Filter logs for specific VPN
grep "Corporate VPN" /root/vpn.log
```

### Log Format

```
[2024-06-04 10:30:15] Starting VPN connection process
[2024-06-04 10:30:16] --> [Corporate VPN] Connecting to VPN server vpn.company.com with user john.doe
[2024-06-04 10:30:18] --> [Corporate VPN]: Successfully connected to VPN
[2024-06-04 10:30:18] [Corporate VPN] Setting up port forwarding: tcp 192.168.1.100:80 -> localhost:8080
```

## Port Forwarding

The script automatically creates iptables rules after successful VPN connection:

- **DNAT rule**: Redirects incoming traffic to target IP
- **MASQUERADE rule**: Masks outgoing traffic

### Manual Port Forwarding Check

```bash
# View current NAT rules
sudo iptables -t nat -L -n -v

# Test specific port
curl -v http://localhost:8080
```

## Security Notes

⚠️ **Important Security Warnings:**

1. **Password Security**: Passwords in JSON file are stored in plain text
2. **File Permissions**: Secure the configuration file:
   ```bash
   chmod 600 /root/vpn.json
   ```
3. **Network Security**: Configure port forwarding rules carefully
4. **Log Security**: Log files may contain sensitive information

## Troubleshooting

### Common Issues

**1. Authentication Failed**
```bash
# Check credentials
echo "User: $VPN_USER"
# Verify server certificate
openconnect --servercert-check $VPN_SERVER
```

**2. Timeout Errors**
```bash
# Test network connectivity
ping $VPN_SERVER
# Test DNS resolution
nslookup $VPN_SERVER
```

**3. Port Forwarding Not Working**
```bash
# Check iptables rules
sudo iptables -t nat -L -n
# Verify target services are running
telnet $TARGET_IP $TARGET_PORT
```

### Debug Mode

For detailed debugging, run the script with:

```bash
bash -x ./vpn-connector.sh
```

## How It Works

1. **Cleanup**: Terminates existing OpenConnect processes
2. **Configuration**: Reads VPN settings from JSON file
3. **Connection**: Attempts to connect to each VPN server
4. **Validation**: Checks connection status and authentication
5. **Forwarding**: Sets up iptables rules for port forwarding
6. **Logging**: Records all activities with timestamps

## Supported Protocols

- AnyConnect (Cisco)
- Pulse Secure
- Other OpenConnect-compatible protocols

## Contributing

1. Fork this repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the `LICENSE` file for details.

## Support

For issues and questions:

- Create an issue on GitHub
- Check the troubleshooting section
- Verify system requirements

### Pre-flight Checklist

- [ ] Required packages installed?
- [ ] JSON configuration valid?
- [ ] Root privileges available?
- [ ] Network connectivity working?
- [ ] Firewall rules appropriate?

## Changelog

### v1.0.0
- Initial release
- Multi-VPN support
- Automatic port forwarding
- Comprehensive logging
- TOTP skip functionality
