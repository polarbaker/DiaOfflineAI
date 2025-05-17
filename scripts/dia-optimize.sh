#!/bin/bash
#
# Dia Performance Optimizer
# Fine-tune Dia's performance and resource usage

set -e

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Bold text
BOLD='\033[1m'
NOBOLD='\033[0m'

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Please run as root (use sudo)${NC}"
        exit 1
    fi
}

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}${BOLD}===== $1 =====${NOBOLD}${NC}\n"
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error messages and exit
print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
    exit 1
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
}

# Check system specs
check_system() {
    print_header "System Specifications"
    
    echo -e "${BOLD}CPU:${NOBOLD}"
    echo "Model: $(cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d ':' -f2 | xargs)"
    echo "Cores: $(nproc)"
    
    echo -e "\n${BOLD}Memory:${NOBOLD}"
    echo "Total: $(free -h | grep Mem | awk '{print $2}')"
    echo "Available: $(free -h | grep Mem | awk '{print $7}')"
    
    echo -e "\n${BOLD}Storage:${NOBOLD}"
    if [ -d "/mnt/nvme" ]; then
        echo "NVMe: $(df -h /mnt/nvme | awk 'NR==2 {print $2}') total, $(df -h /mnt/nvme | awk 'NR==2 {print $4}') available"
    else
        echo "Internal: $(df -h / | awk 'NR==2 {print $2}') total, $(df -h / | awk 'NR==2 {print $4}') available"
    fi
    
    echo -e "\n${BOLD}Temperature:${NOBOLD}"
    echo "CPU: $(vcgencmd measure_temp | cut -d '=' -f2)"
}

# Monitor memory usage
monitor_memory() {
    print_header "Memory Usage Monitoring"
    
    echo "Monitoring memory usage for 10 seconds..."
    echo "Press Ctrl+C to stop earlier."
    echo ""
    
    timeout 10 bash -c '
    echo "Time | Total Used | Dia Process | Top Process"
    echo "--------------------------------------------"
    for i in {1..10}; do
        total=$(free -m | grep Mem | awk "{print \$3}")
        dia_mem=$(ps aux | grep -v grep | grep "dia_assistant.py" | awk "{print \$6/1024}" | awk "{printf \"%.1f\", \$1}")
        top_proc=$(ps aux --sort=-%mem | head -2 | tail -1)
        top_proc_name=$(echo "$top_proc" | awk "{print \$11}" | cut -d "/" -f 3)
        top_proc_mem=$(echo "$top_proc" | awk "{print \$6/1024}" | awk "{printf \"%.1f\", \$1}")
        
        printf "%02d:%02d | %6s MB | %7s MB | %s (%s MB)\n" $(date +%H) $(date +%M) "$total" "${dia_mem:-0.0}" "$top_proc_name" "$top_proc_mem"
        sleep 1
    done
    '
}

# Optimize memory usage
optimize_memory() {
    print_header "Memory Optimization"
    
    echo "Current memory settings:"
    echo "ZRAM: $(systemctl is-active zramswap && echo "Enabled" || echo "Disabled")"
    echo "Swap: $(free -h | grep Swap | awk '{print $2}')"
    
    echo ""
    echo "Available optimization options:"
    echo "1) Enable/configure ZRAM (compressed RAM)"
    echo "2) Adjust swap settings"
    echo "3) Limit Dia's memory usage"
    echo "4) Back to main menu"
    echo ""
    
    read -p "Select an option [1-4]: " option
    
    case $option in
        1)
            # Configure ZRAM
            echo "Setting up ZRAM compression..."
            apt-get update
            apt-get install -y zram-tools
            
            # Configure ZRAM to use 50% of RAM
            ram_size=$(free -m | grep Mem | awk '{print $2}')
            zram_size=$((ram_size / 2))
            
            echo "ALGO=lz4" > /etc/default/zramswap
            echo "PERCENT=50" >> /etc/default/zramswap
            
            systemctl restart zramswap
            
            print_success "ZRAM configured to use ${zram_size}MB"
            ;;
        2)
            # Adjust swap settings
            echo "Current swappiness: $(cat /proc/sys/vm/swappiness)"
            echo ""
            echo "Recommended settings:"
            echo "- For systems with ≤4GB RAM: 100"
            echo "- For systems with >4GB RAM: 60"
            echo ""
            
            read -p "Enter new swappiness value (10-100): " swappiness
            
            if [[ "$swappiness" =~ ^[0-9]+$ ]] && [ "$swappiness" -ge 10 ] && [ "$swappiness" -le 100 ]; then
                sysctl vm.swappiness=$swappiness
                echo "vm.swappiness=$swappiness" > /etc/sysctl.d/99-dia-swappiness.conf
                print_success "Swappiness set to $swappiness"
            else
                print_warning "Invalid value. Must be between 10 and 100."
            fi
            ;;
        3)
            # Limit Dia's memory usage
            echo "Setting memory limits for Dia service..."
            
            # Create systemd override directory
            mkdir -p /etc/systemd/system/dia.service.d/
            
            # Create memory limit configuration
            ram_size=$(free -m | grep Mem | awk '{print $2}')
            dia_limit=$((ram_size * 70 / 100))
            
            echo "[Service]" > /etc/systemd/system/dia.service.d/memory.conf
            echo "MemoryHigh=${dia_limit}M" >> /etc/systemd/system/dia.service.d/memory.conf
            echo "MemoryMax=${ram_size}M" >> /etc/systemd/system/dia.service.d/memory.conf
            
            # Reload systemd and restart Dia
            systemctl daemon-reload
            
            print_success "Memory limits configured for Dia (Soft: ${dia_limit}MB, Hard: ${ram_size}MB)"
            
            if systemctl is-active --quiet dia.service; then
                read -p "Restart Dia to apply changes? (y/n): " restart
                if [[ "$restart" == "y" || "$restart" == "Y" ]]; then
                    systemctl restart dia.service
                    print_success "Dia service restarted with new memory limits"
                fi
            fi
            ;;
        4)
            return
            ;;
        *)
            print_warning "Invalid option. Please try again."
            optimize_memory
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# CPU optimization
optimize_cpu() {
    print_header "CPU Optimization"
    
    echo "Current CPU governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
    echo "Available governors: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors)"
    echo ""
    
    echo "Available optimization options:"
    echo "1) Set performance governor (maximum performance)"
    echo "2) Set ondemand governor (balanced)"
    echo "3) Set powersave governor (save power, slower)"
    echo "4) Back to main menu"
    echo ""
    
    read -p "Select an option [1-4]: " option
    
    case $option in
        1)
            echo "performance" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
            print_success "CPU governor set to performance"
            ;;
        2)
            echo "ondemand" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
            print_success "CPU governor set to ondemand"
            ;;
        3)
            echo "powersave" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
            print_success "CPU governor set to powersave"
            ;;
        4)
            return
            ;;
        *)
            print_warning "Invalid option. Please try again."
            optimize_cpu
            ;;
    esac
    
    read -p "Press Enter to continue..."
}

# Optimize startup time
optimize_startup() {
    print_header "Startup Optimization"
    
    echo "Measuring current Dia startup time..."
    
    # Stop Dia if running
    if systemctl is-active --quiet dia.service; then
        systemctl stop dia.service
    fi
    
    # Measure startup time
    start_time=$(date +%s.%N)
    systemctl start dia.service
    
    # Wait for service to be active
    while ! systemctl is-active --quiet dia.service; do
        sleep 0.1
    done
    
    end_time=$(date +%s.%N)
    startup_time=$(echo "$end_time - $start_time" | bc)
    printf "Current startup time: %.2f seconds\n" $startup_time
    
    echo ""
    echo "Applying startup optimizations..."
    
    # Create systemd override for startup optimization
    mkdir -p /etc/systemd/system/dia.service.d/
    
    cat > /etc/systemd/system/dia.service.d/startup.conf << EOF
[Service]
# Optimize startup
CPUWeight=90
IOWeight=90
TasksMax=100
TimeoutStartSec=60s
EOF
    
    # Create optimized Python cache
    if [ -d "/opt/dia" ]; then
        echo "Pre-compiling Python modules..."
        cd /opt/dia
        python3 -m compileall src
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Restart and measure again
    echo "Measuring optimized startup time..."
    systemctl stop dia.service
    
    start_time=$(date +%s.%N)
    systemctl start dia.service
    
    # Wait for service to be active
    while ! systemctl is-active --quiet dia.service; do
        sleep 0.1
    done
    
    end_time=$(date +%s.%N)
    new_startup_time=$(echo "$end_time - $start_time" | bc)
    printf "Optimized startup time: %.2f seconds\n" $new_startup_time
    
    improvement=$(echo "($startup_time - $new_startup_time) / $startup_time * 100" | bc -l)
    printf "Improvement: %.1f%%\n" $improvement
    
    print_success "Startup optimization complete"
    read -p "Press Enter to continue..."
}

# Auto-scaling based on load
configure_autoscaling() {
    print_header "Automatic Resource Scaling"
    
    echo "Configuring automatic resource scaling for Dia..."
    
    # Create auto-scaling script
    cat > /opt/dia/scripts/autoscale.sh << 'EOF'
#!/bin/bash

# Automatic resource scaling for Dia Assistant
# This script monitors system resources and adjusts Dia's configuration

# Get system resources
total_mem=$(free -m | grep Mem | awk '{print $2}')
available_mem=$(free -m | grep Mem | awk '{print $7}')
cpu_load=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
cpu_temp=$(vcgencmd measure_temp | cut -d '=' -f2 | cut -d "'" -f1)

# Log resources
echo "$(date): Mem: $available_mem/$total_mem MB, CPU: ${cpu_load}%, Temp: ${cpu_temp}°C" >> /var/log/dia-autoscale.log

# Determine resource state
if (( $(echo "$cpu_temp > 80" | bc -l) )); then
    # Critical temperature - reduce resource usage
    echo "Critical temperature detected, reducing resource usage"
    systemctl set-property dia.service CPUWeight=50 MemoryHigh=50%
elif (( $(echo "$cpu_load > 90" | bc -l) )); then
    # High CPU load - throttle
    echo "High CPU load detected, throttling"
    systemctl set-property dia.service CPUWeight=70
elif (( $(echo "$available_mem < 200" | bc -l) )); then
    # Low memory - reduce memory usage
    echo "Low memory detected, reducing memory usage"
    systemctl set-property dia.service MemoryHigh=60%
else
    # Normal operation - reset limits
    systemctl set-property dia.service CPUWeight=90 MemoryHigh=80%
fi
EOF
    
    chmod +x /opt/dia/scripts/autoscale.sh
    
    # Create systemd timer for auto-scaling
    cat > /etc/systemd/system/dia-autoscale.timer << EOF
[Unit]
Description=Dia Assistant Auto-scaling Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
EOF
    
    cat > /etc/systemd/system/dia-autoscale.service << EOF
[Unit]
Description=Dia Assistant Auto-scaling Service
After=dia.service

[Service]
Type=oneshot
ExecStart=/opt/dia/scripts/autoscale.sh

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start timer
    systemctl daemon-reload
    systemctl enable dia-autoscale.timer
    systemctl start dia-autoscale.timer
    
    print_success "Auto-scaling configured and activated"
    echo "Dia will now automatically adjust resource usage based on system load"
    read -p "Press Enter to continue..."
}

# Main menu
show_menu() {
    while true; do
        clear
        print_header "Dia Performance Optimizer"
        echo -e "${BOLD}What would you like to optimize?${NOBOLD}"
        echo ""
        echo "1) Check System Specifications"
        echo "2) Monitor Memory Usage"
        echo "3) Optimize Memory Usage"
        echo "4) Optimize CPU Performance"
        echo "5) Optimize Startup Time"
        echo "6) Configure Auto-scaling"
        echo "7) Run All Optimizations"
        echo "8) Exit"
        echo ""
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1) check_system ;;
            2) monitor_memory ;;
            3) optimize_memory ;;
            4) optimize_cpu ;;
            5) optimize_startup ;;
            6) configure_autoscaling ;;
            7)
                optimize_memory
                optimize_cpu
                optimize_startup
                configure_autoscaling
                print_success "All optimizations complete!"
                ;;
            8) exit 0 ;;
            *) print_warning "Invalid choice. Please try again." ;;
        esac
        
        read -p "Press Enter to continue..."
    done
}

# Check if running as root
check_root

# Run menu
show_menu
