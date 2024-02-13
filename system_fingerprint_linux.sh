#!/bin/bash

# Output file
output_file="system_info.txt"

# Function to execute a command and write its output to the file
function execute_and_write {
    echo "--------------------------------------------------" >> "$output_file"
    echo "Command: $1" >> "$output_file"
    echo "--------------------------------------------------" >> "$output_file"
    eval "$1" >> "$output_file" 2>&1
    echo -e "\n\n" >> "$output_file"
}

# Run commands and write to the output file
execute_and_write "hostnamectl"
#execute_and_write "lscpu"
execute_and_write "sudo dmidecode -t bios"
execute_and_write "sudo apt list --installed"
#execute_and_write "cat /proc/cpuinfo"
execute_and_write "cat /proc/meminfo"
execute_and_write "sudo blkid"
execute_and_write "sudo dmidecode -t system"
execute_and_write "sudo dmidecode -t baseboard"
execute_and_write "sudo dmidecode -t memory"
#execute_and_write "ifconfig"
execute_and_write "ip addr show"
execute_and_write "ip route show"
execute_and_write "sudo ss -tulpn"

# Add more commands as needed

echo "Script executed successfully. Output saved to: $output_file"

