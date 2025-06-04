#!/bin/bash

LOG_FILE="/root/vpn.log"

# Function for logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}
rm -rf vpn.log
# Function to terminate all openconnect processes
terminate_openconnect() {
    log "Terminating all existing openconnect processes"
    if pgrep openconnect > /dev/null; then
        pkill openconnect
        sleep 1
        if pgrep openconnect > /dev/null; then
            log "Forcefully terminating remaining openconnect processes"
            pkill -9 openconnect
        fi
        log "All openconnect processes terminated"
    else
        log "No running openconnect processes found"
    fi
}

# Terminate any existing openconnect processes before starting
terminate_openconnect

iptables -t nat -F PREROUTING
iptables -t nat -F POSTROUTING

log "Starting VPN connection process"

# Read the VPN configuration from vpn.json
jq -c '.[]' /root/vpn.json | while read -r vpn_config; do
    VPN_NAME=$(echo "$vpn_config" | jq -r '.VPN_NAME')
    VPN_PASSWORD=$(echo "$vpn_config" | jq -r '.VPN_PASSWORD')
    VPN_SERVER=$(echo "$vpn_config" | jq -r '.VPN_SERVER')
    VPN_USER=$(echo "$vpn_config" | jq -r '.VPN_USER')
    VPN_PROTOCOL=$(echo "$vpn_config" | jq -r '.VPN_PROTOCOL')
    SERVER_CERT_PIN=$(echo "$vpn_config" | jq -r '.SERVER_CERT_PIN')
    TOTP=$(echo "$vpn_config" | jq -r '.TOTP')
    FORWARD=$(echo "$vpn_config" | jq -r '.FORWARD')
    
    log "[$VPN_NAME] Attempting to connect to $VPN_SERVER with user $VPN_USER"
    
    # Add timestamp to log with new format
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] --> [$VPN_NAME] Connecting to VPN server $VPN_SERVER with user $VPN_USER" >> "$LOG_FILE"

    # Method 1: Use timeout and separate log file for openconnect output
    TEMP_LOG="/tmp/openconnect_${VPN_NAME}_$$.log"
    

    if [ "$TOTP" = "true" ]; then
        log "[$VPN_NAME] Skipping VPN that requires TOTP authentication"
        continue
    else
        # Start openconnect in background with output redirected to temp file
        timeout 30s bash -c "echo '$VPN_PASSWORD' | openconnect --background --protocol='$VPN_PROTOCOL' '$VPN_SERVER' --user='$VPN_USER' --passwd-on-stdin --servercert '$SERVER_CERT_PIN' > '$TEMP_LOG' 2>&1" &
    fi
    
    # Wait for the command to complete or timeout
    wait $!
    CONNECT_RESULT=$?
    
    # Read the output from temp file
    if [ -f "$TEMP_LOG" ]; then
        OUTPUT=$(cat "$TEMP_LOG")
        rm -f "$TEMP_LOG"
    else
        OUTPUT="No output captured"
    fi

    # Check connection result
    if [ $CONNECT_RESULT -eq 0 ]; then
        # Check for authentication failure in output
        if echo "$OUTPUT" | grep -q "Failed to complete authentication"; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]  --> [$VPN_NAME]: Failed to complete authentication" | tee -a "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')]  --> [$VPN_NAME]: Successfully connected to VPN" | tee -a "$LOG_FILE"
            # Debug output to verify vpn_config content before forwarding
            log "[$VPN_NAME] Forwarding configuration: $(echo $vpn_config | jq -r '.FORWARD | length') rules found"
            
            # Process each forwarding rule
            echo "$vpn_config" | jq -c '.FORWARD[]' | while read -r forward_rule; do
            protocol=$(echo "$forward_rule" | jq -r '.protocol')
            ipaddress=$(echo "$forward_rule" | jq -r '.ipaddress')
            port=$(echo "$forward_rule" | jq -r '.port')
            forward_port=$(echo "$forward_rule" | jq -r '.forward')
            
            log "[$VPN_NAME] Setting up port forwarding: $protocol $ipaddress:$port -> localhost:$forward_port"
            
            # Create iptables rules for this forwarding
            iptables -t nat -A PREROUTING -p tcp --dport $forward_port -j DNAT --to-destination $ipaddress:$port
            iptables -t nat -A POSTROUTING -d $ipaddress -p tcp --dport $port -j MASQUERADE
            done
        fi
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]  --> [$VPN_NAME]: Connection attempt timed out or failed" | tee -a "$LOG_FILE"
    fi

    # Log the complete output
    echo "$OUTPUT" | tee -a "$LOG_FILE"
done
