# Output file
$outputFile = "system_info.txt"

# Function to execute a command and write its output to the file
function Execute-And-Write {
    param(
        [string]$command
    )

    Add-Content -Path $outputFile -Value ("-" * 50)
    Add-Content -Path $outputFile -Value "Command: $command"
    Add-Content -Path $outputFile -Value ("-" * 50)
    Invoke-Expression $command | Out-File -Append -FilePath $outputFile
    Add-Content -Path $outputFile -Value "`r`n`r`n"
}

# Run commands and write to the output file
Execute-And-Write "systeminfo"
Execute-And-Write "hostname"
Execute-And-Write "systeminfo | Select-String 'BIOS Version'"
Execute-And-Write "Get-WmiObject -Class Win32_ComputerSystem | Format-List *"
Execute-And-Write "Get-WmiObject -Class Win32_Baseboard | Format-List *"
Execute-And-Write "Get-WmiObject -Class Win32_PhysicalMemory | Format-List *"

# Add more commands as needed

Write-Host "Script executed successfully. Output saved to: $outputFile"
