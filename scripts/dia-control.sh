#!/bin/bash
#
# Dia Assistant Control Script
# Utility script to control the Dia Voice Assistant

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (use sudo)${NC}"
  exit 1
fi

# Command line argument
action=$1

# Print usage if no arguments
if [ -z "$action" ]; then
  echo -e "${BLUE}Usage: $0 {start|stop|restart|status}${NC}"
  exit 1
fi

# Execute the action
case "$action" in
  start)
    echo -e "${BLUE}Starting Dia Assistant...${NC}"
    systemctl start dia.service
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Dia Assistant started successfully${NC}"
    else
      echo -e "${RED}Failed to start Dia Assistant${NC}"
    fi
    ;;
  stop)
    echo -e "${BLUE}Stopping Dia Assistant...${NC}"
    systemctl stop dia.service
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Dia Assistant stopped successfully${NC}"
    else
      echo -e "${RED}Failed to stop Dia Assistant${NC}"
    fi
    ;;
  restart)
    echo -e "${BLUE}Restarting Dia Assistant...${NC}"
    systemctl restart dia.service
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}Dia Assistant restarted successfully${NC}"
    else
      echo -e "${RED}Failed to restart Dia Assistant${NC}"
    fi
    ;;
  status)
    echo -e "${BLUE}Checking Dia Assistant status:${NC}"
    systemctl status dia.service
    ;;
  *)
    echo -e "${RED}Invalid option: $action${NC}"
    echo -e "${BLUE}Usage: $0 {start|stop|restart|status}${NC}"
    exit 1
    ;;
esac

exit 0
