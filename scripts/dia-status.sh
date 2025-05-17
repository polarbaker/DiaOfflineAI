#!/bin/bash
#
# Dia Assistant Status Script
# Shows the current status of the Dia assistant and system resources

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}===== Dia Assistant Status =====${NC}\n"

# Check if Dia service is running
echo -e "${BLUE}Service Status:${NC}"
if systemctl is-active --quiet dia.service; then
  echo -e "${GREEN}✓ Dia Assistant is running${NC}"
else
  echo -e "${RED}✗ Dia Assistant is not running${NC}"
fi

# Memory usage
echo -e "\n${BLUE}Memory Usage:${NC}"
free -h | grep -E "total|Mem|Swap"

# Disk usage 
echo -e "\n${BLUE}Disk Usage:${NC}"
df -h | grep -E "Filesystem|/mnt/nvme|/$"

# CPU temperature
echo -e "\n${BLUE}CPU Temperature:${NC}"
vcgencmd measure_temp

# Check if key hardware is detected
echo -e "\n${BLUE}Hardware Status:${NC}"

# Coral TPU
if lsusb | grep -q "Google"; then
  echo -e "${GREEN}✓ Coral TPU detected${NC}"
else
  echo -e "${YELLOW}⚠ Coral TPU not detected${NC}"
fi

# Check audio devices
echo -e "\n${BLUE}Audio Devices:${NC}"
aplay -l

# Show log snippet
echo -e "\n${BLUE}Recent Logs:${NC}"
journalctl -u dia.service -n 5 --no-pager

echo -e "\n${BLUE}===============================${NC}"
echo -e "Visit http://bakerpi.local for dashboard"
echo -e "Visit https://bakerpi.local:9090 for system management"
