#!/bin/bash

# Output file
OUTPUT_FILE="system_fingerprint.txt"

# Function to append key-value pair to output file
append_to_output() {
    echo "$1: $2" >> $OUTPUT_FILE
}

# Function to append a section header to output file
append_section_header() {
    echo -e "\n$1\n$(printf '%.0s=' {1..60})\n" >> $OUTPUT_FILE
}

# Clear the output file
> $OUTPUT_FILE

# Function to get installed packages for Debian-based systems
get_installed_packages_debian() {
    dpkg-query -W -f='${binary:Package}\t${Version}\t${Status}\n' | while read -r line; do
        pkg_name=$(echo "$line" | awk '{print $1}')
        version=$(echo "$line" | awk '{print $2}')
        status=$(echo "$line" | awk '{print $3}')
        install_date=$(stat -c %y "/var/lib/dpkg/info/$pkg_name.list" 2>/dev/null | cut -d' ' -f1)
        append_to_output "$pkg_name" "Version: $version, Status: $status, Installed Date: $install_date"
    done
}

# Function to get installed packages for RPM-based systems
get_installed_packages_rpm() {
    rpm -qa --queryformat '%{NAME}\t%{VERSION}-%{RELEASE}\t%{INSTALLTIME:date}\n' | while read -r line; do
        pkg_name=$(echo "$line" | awk '{print $1}')
        version=$(echo "$line" | awk '{print $2}')
        install_date=$(echo "$line" | awk '{print $3 " " $4 " " $5}')
        append_to_output "$pkg_name" "Version: $version, Installed Date: $install_date"
    done
}

# Ask user for system type
echo "Is the system Debian-based or RPM-based?"
select sys_type in "Debian-based" "RPM-based"; do
    case $sys_type in
        "Debian-based" ) SYS_TYPE="debian"; break;;
        "RPM-based" ) SYS_TYPE="rpm"; break;;
    esac
done

# Hostname
append_section_header "Hostname"
append_to_output "Hostname" "$(hostname)"

# UUID
append_section_header "UUID"
append_to_output "UUID" "$(cat /sys/class/dmi/id/product_uuid)"

# Laptop or Desktop
append_section_header "Type"
chassis_type=$(dmidecode -s chassis-type 2>/dev/null | head -n 1 | tr '[:upper:]' '[:lower:]')
if [[ "$chassis_type" =~ (laptop|notebook|portable|hand\ held|sub\ notebook|netbook) ]]; then
    append_to_output "Type" "Laptop"
else
    append_to_output "Type" "Desktop"
fi

#Systemtime
append_section_header "Time"
append_to_output "Time" "$(timedatectl)"
# Boot ID
append_section_header "Boot ID"
append_to_output "Boot ID" "$(cat /proc/sys/kernel/random/boot_id)"

# Operating System
append_section_header "Operating System"
append_to_output "Operating System" "$(lsb_release -d | cut -f2)"

# Kernel
append_section_header "Kernel"
append_to_output "Kernel" "$(uname -r)"

# Architecture
append_section_header "Architecture"
append_to_output "Architecture" "$(uname -m)"

# Hardware Vendor
append_section_header "Hardware Vendor"
append_to_output "Hardware Vendor" "$(cat /sys/class/dmi/id/sys_vendor)"

# Hardware Model
append_section_header "Hardware Model"
append_to_output "Hardware Model" "$(cat /sys/class/dmi/id/product_name)"

# BIOS Information
append_section_header "BIOS Information"
dmidecode -t bios | grep -E "Vendor:|Version:|Release Date:|Revision:" | while read -r line; do
    append_to_output "$(echo "$line" | cut -d: -f1)" "$(echo "$line" | cut -d: -f2-)"
done

# RAM Information
append_section_header "RAM Information"
free -h | grep -E "Mem:|Swap:" | while read -r line; do
    append_to_output "$(echo "$line" | awk '{print $1}')" "$(echo "$line" | awk '{print $2 " total, " $3 " used, " $4 " free"}')"
done

# Mounted Devices
append_section_header "Mounted Devices"
df -h | while read -r line; do
    append_to_output "$(echo "$line" | awk '{print $1}')" "$(echo "$line" | awk '{print $2 " size, " $3 " used, " $4 " available, mounted on " $6}')"
done

# Installed Programs
append_section_header "Installed Programs"
if [ "$SYS_TYPE" == "debian" ]; then
    get_installed_packages_debian
else
    get_installed_packages_rpm
fi

# blkid command output
append_section_header "blkid Command Output"
blkid | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# dmidecode system
append_section_header "System Information"
dmidecode -t system | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# dmidecode baseboard
append_section_header "Baseboard Information"
dmidecode -t baseboard | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# Network Interfaces
append_section_header "Network Interfaces"
ip -o addr show | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# DHCP or Static IP
append_section_header "DHCP or Static IP"
for iface in $(ls /sys/class/net/); do
    if [ -f /etc/network/interfaces ]; then
        if grep -q "iface $iface inet dhcp" /etc/network/interfaces; then
            append_to_output "$iface" "DHCP"
        elif grep -q "iface $iface inet static" /etc/network/interfaces; then
            append_to_output "$iface" "Static IP"
        else
            append_to_output "$iface" "Unknown"
        fi
    elif [ -d /etc/NetworkManager/system-connections/ ]; then
        for config_file in /etc/NetworkManager/system-connections/*; do
            if [ -f "$config_file" ]; then
                if grep -q "$iface" "$config_file" 2>/dev/null; then
                    if grep -q "method=auto" "$config_file"; then
                        append_to_output "$iface" "DHCP"
                    elif grep -q "method=manual" "$config_file"; then
                        append_to_output "$iface" "Static IP"
                    else
                        append_to_output "$iface" "Unknown"
                    fi
                fi
            fi
        done
    else
        append_to_output "$iface" "Unknown"
    fi
done

# IP Routes
append_section_header "IP Routes"
ip route | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# Open Ports and Services
append_section_header "Open Ports and Services"
ss -tuln | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# Users
append_section_header "Users"
getent passwd | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# Groups
append_section_header "Groups"
getent group | while read -r line; do
    echo "$line" >> $OUTPUT_FILE
done

# Scheduled Tasks (cron jobs)
append_section_header "Scheduled Tasks"
for user in $(cut -f1 -d: /etc/passwd); do
    echo "Cron jobs for $user:" >> $OUTPUT_FILE
    crontab -u "$user" -l 2>/dev/null | while read -r line; do
        echo "$line" >> $OUTPUT_FILE
    done
done

# OS Installation Date
append_section_header "OS Installation Date"
os_install_date=$(ls -ld --time=ctime / | awk '{print $6, $7, $8}')
append_to_output "OS Installation Date" "$os_install_date"

echo "System fingerprint generated and saved to $OUTPUT_FILE"
