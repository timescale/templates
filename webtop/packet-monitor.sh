#!/bin/bash

# Network Packet Monitor for Top Websites Tracker
# This script captures DNS traffic, extracts domain names, and logs them to the database

# Configuration - modify these as needed
DB_URI="${DB_URI:-postgresql://postgres:password@0.0.0.0:5433/website_tracker}"
INTERFACE="auto"  # Set to a specific interface like "en0" or "eth0", or "auto" to detect
CAPTURE_COUNT="0" # 0 means capture continuously
BATCH_SIZE=50    # Number of domains to accumulate before batch insert

# Color output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root (required for packet capture)
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root (sudo) to capture packets${NC}"
  exit 1
fi

# Check for required tools
command -v tcpdump >/dev/null 2>&1 || { echo -e "${RED}Error: tcpdump is required but not installed. Install with 'brew install tcpdump' or 'apt-get install tcpdump'${NC}"; exit 1; }
command -v psql >/dev/null 2>&1 || { echo -e "${RED}Error: psql is required but not installed${NC}"; exit 1; }

# Test database connection
if ! psql "$DB_URI" -c "SELECT 1" &>/dev/null; then
  echo -e "${RED}Error: Cannot connect to database. Check if the database is running and the connection URI is correct${NC}"
  echo "Current URI: $DB_URI"
  echo "Set a custom URI with: export DB_URI=\"postgresql://username:password@host:port/database\""
  exit 1
fi

# Auto-detect network interface if set to auto
if [ "$INTERFACE" = "auto" ]; then
  # Try to find the default interface
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS specific detection
    INTERFACE=$(route -n get default 2>/dev/null | grep 'interface:' | awk '{print $2}')
    
    # Try alternative method for macOS if the first fails
    if [ -z "$INTERFACE" ]; then
      INTERFACE=$(netstat -rn | grep default | head -1 | awk '{print $4}')
    fi
  elif command -v ip >/dev/null 2>&1; then
    # Modern Linux systems
    INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
  elif command -v route >/dev/null 2>&1; then
    # Older Linux systems
    INTERFACE=$(route -n | grep '^0.0.0.0' | awk '{print $8}' | head -n1)
  elif command -v netstat >/dev/null 2>&1; then
    # BSD-like systems
    INTERFACE=$(netstat -rn | grep default | awk '{print $6}' | head -n1)
  fi

  if [ -z "$INTERFACE" ]; then
    echo -e "${RED}Error: Could not automatically detect network interface${NC}"
    echo -e "${YELLOW}Available interfaces:${NC}"
    
    if command -v ifconfig >/dev/null 2>&1; then
      # Get active interfaces
      active_interfaces=""
      for iface in $(ifconfig -l); do
        status=$(ifconfig $iface 2>/dev/null | grep "status: active" || echo "")
        has_inet=$(ifconfig $iface 2>/dev/null | grep "inet " || echo "")
        
        if [ -n "$status" ] || [ -n "$has_inet" ]; then
          if [ -n "$has_inet" ]; then
            ip_addr=$(echo "$has_inet" | awk '{print $2}')
            echo -e "  ${GREEN}$iface${NC} - $ip_addr ${GREEN}(active)${NC}"
            active_interfaces="$active_interfaces $iface"
          else
            echo -e "  $iface"
          fi
        fi
      done
      
      if [ -n "$active_interfaces" ]; then
        echo -e "\n${YELLOW}Try one of these active interfaces:${NC}$active_interfaces"
      fi
    elif command -v ip >/dev/null 2>&1; then
      ip addr show | grep -E '^[0-9]+: ' | cut -d' ' -f2 | sed 's/:$//' | while read iface; do
        ip=$(ip addr show $iface | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
        if [ -n "$ip" ]; then
          echo -e "  ${GREEN}$iface${NC} - $ip ${GREEN}(active)${NC}"
        else
          echo -e "  $iface"
        fi
      done
    fi
    
    echo -e "\n${YELLOW}To specify an interface, run:${NC}"
    echo "INTERFACE=en0 sudo -E ./packet-monitor.sh"
    exit 1
  fi
  
  echo -e "${GREEN}Automatically selected interface: ${INTERFACE}${NC}"
else
  echo -e "${GREEN}Using configured interface: ${INTERFACE}${NC}"
fi

# Create a temporary file for batch processing
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Function to insert domains into database
insert_domains() {
  local count=$(wc -l < "$TEMP_FILE")
  if [ "$count" -gt 0 ]; then
    echo -e "${BLUE}Inserting $count domains to database...${NC}"
    
    # Use psql's COPY command for efficient batch insert
    {
      echo "COPY logs (time, domain) FROM STDIN;"
      cat "$TEMP_FILE"
      echo "\\."
    } | psql "$DB_URI" >/dev/null

    # Clear the temp file for next batch
    > "$TEMP_FILE"
  fi
}

echo -e "${GREEN}Starting packet capture on interface $INTERFACE${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop capturing${NC}"

# Keep count of captures for batch processing
capture_count=0

# Use tcpdump to capture DNS packets and process them
tcpdump -i "$INTERFACE" -l -n "udp port 53" 2>/dev/null | while read -r line; do
  # Extract domain names from DNS queries (A records)
  if echo "$line" | grep -q "A?" && ! echo "$line" | grep -q "AAAA?"; then
    domain=$(echo "$line" | sed -n 's/.*A? \([^ ]*\).*/\1/p' | sed 's/\.$//g')
    
    # Skip IPs and invalid domains
    if [[ $domain =~ ^[0-9.]+$ ]] || [[ "$domain" == "localhost" ]] || [ -z "$domain" ]; then
      continue
    fi
    
    # Add timestamp and domain to temp file
    echo "$(date +"%Y-%m-%d %H:%M:%S")	$domain" >> "$TEMP_FILE"
    
    # Increment counter and display progress
    capture_count=$((capture_count + 1))
    echo -e "${GREEN}Captured domain: ${NC}$domain ${YELLOW}(total: $capture_count)${NC}"
    
    # Process in batches
    if [ $capture_count -ge $BATCH_SIZE ]; then
      insert_domains
      capture_count=0
    fi
  fi
done

# Handle any remaining domains
insert_domains

echo -e "${GREEN}Packet capture complete${NC}" 