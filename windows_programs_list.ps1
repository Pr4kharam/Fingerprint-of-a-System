# Function to get a list of installed programs from various Windows Registry locations
function Get-InstalledProgramsFromRegistry {
    $registryLocations = @(
        "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    $programs = @()

    foreach ($location in $registryLocations) {
        try {
            $key = Get-Item -LiteralPath "HKLM:\$location"
            $subkeyCount = $key.SubKeyCount

            for ($i = 0; $i -lt $subkeyCount; $i++) {
                $subkeyName = $key.GetSubKeyNames()[$i]
                $subkey = Get-Item -LiteralPath "HKLM:\$location\$subkeyName"

                $program = @{
                    "Name" = $subkey.GetValue("DisplayName")
                    "Version" = $subkey.GetValue("DisplayVersion")
                    "InstallLocation" = $subkey.GetValue("InstallLocation")
                }

                if ($program["Name"]) {
                    $programs += $program
                }
            }
        } catch {
            # Handle exceptions if required
        }
    }

    return $programs
}

# Function to get a list of installed programs from user-specific Windows Registry locations
function Get-InstalledProgramsFromUserRegistry {
    $programs = @()

    try {
        $userHive = Get-Item -LiteralPath "HKU:"
        $userSubkeys = $userHive.GetSubKeyNames()

        foreach ($userSubkeyName in $userSubkeys) {
            $userRegistryPath = "$userSubkeyName\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"

            try {
                $key = Get-Item -LiteralPath "HKU:\$userRegistryPath"
                $subkeyCount = $key.SubKeyCount

                for ($i = 0; $i -lt $subkeyCount; $i++) {
                    $subkeyName = $key.GetSubKeyNames()[$i]
                    $subkey = Get-Item -LiteralPath "HKU:\$userRegistryPath\$subkeyName"

                    $program = @{
                        "Name" = $subkey.GetValue("DisplayName")
                        "Version" = $subkey.GetValue("DisplayVersion")
                        "InstallLocation" = $subkey.GetValue("InstallLocation")
                    }

                    if ($program["Name"]) {
                        $programs += $program
                    }
                }
            } catch {
                # Handle exceptions if required
            }
        }
    } catch {
        # Handle exceptions if required
    }

    return $programs
}

# Function to get a list of installed programs using WMIC
function Get-InstalledProgramsWithWmic {
    try {
        $wmicOutput = Invoke-Expression -Command "wmic product get Name,Version,InstallLocation /format:csv"
        $lines = $wmicOutput -split '\r?\n' | ForEach-Object { $_.Trim() }
        $fieldnames = $lines[0] -split ',' | ForEach-Object { $_.Trim() }
        $programs = @()

        for ($i = 1; $i -lt $lines.Count; $i++) {
            $values = $lines[$i] -split ',' | ForEach-Object { $_.Trim() }
            $program = @{
                "Name" = $values[$fieldnames.IndexOf("Name")]
                "Version" = $values[$fieldnames.IndexOf("Version")]
                "InstallLocation" = $values[$fieldnames.IndexOf("InstallLocation")]
            }

            $programs += $program
        }

        return $programs
    } catch {
        # Handle exceptions if required
    }
}

# Function to get a list of installed UWP apps using PowerShell Get-AppxPackage
function Get-InstalledUwpApps {
    try {
        $powershellOutput = Get-AppxPackage | Select-Object Name, Version, InstallLocation | Format-Table -HideTableHeaders -AutoSize
        $lines = $powershellOutput -split '\r?\n' | ForEach-Object { $_.Trim() }
        $programs = @()

        foreach ($line in $lines) {
            $values = $line -split '\s+' | ForEach-Object { $_.Trim() }

            if ($values.Count -ge 3) {
                $program = @{
                    "Name" = $values[0]
                    "Version" = $values[1]
                    "InstallLocation" = $values[2]
                }

                $programs += $program
            }
        }

        return $programs
    } catch {
        # Handle exceptions if required
    }
}

# Merge and remove duplicates from four lists of installed programs
function Merge-AndRemoveDuplicates {
    param (
        [array]$programs1,
        [array]$programs2,
        [array]$programs3,
        [array]$programs4
    )

    $mergedPrograms = $programs1 + $programs2 + $programs3 + $programs4
    $uniquePrograms = @()

    foreach ($program in $mergedPrograms) {
        if ($program -notin $uniquePrograms) {
            $uniquePrograms += $program
        }
    }

    return $uniquePrograms
}

# Export the list of installed programs to a CSV file
function Export-ToCsv {
    param (
        [array]$programs,
        [string]$csvFilename
    )

    $programs | Export-Csv -Path $csvFilename -NoTypeInformation -Encoding UTF8
}

# Helper function to enumerate subkeys under a registry key
function Iter-Subkeys {
    param (
        [Microsoft.Win32.RegistryKey]$key
    )

    $subkeys = @()
    $index = 0

    while ($true) {
        try {
            $subkeyName = $key.GetSubKeyNames()[$index]
            $subkeys += $subkeyName
            $index++
        } catch [System.Management.Automation.ItemNotFoundException] {
            break
        }
    }

    return $subkeys
}

# Export the list of installed programs to a TXT file
function Export-ToTxt {
    param (
        [array]$programs,
        [string]$txtFilename
    )

    $content = $programs | ForEach-Object {
        "Name: $($_.Name)`r`nVersion: $($_.Version)`r`nInstallLocation: $($_.InstallLocation)`r`n"
    }

    $content | Out-File -FilePath $txtFilename -Encoding UTF8
}


# Run commands and write to the output file
#Execute-And-Write "systeminfo"
#Execute-And-Write "hostname"
#Execute-And-Write "systeminfo | Select-String 'BIOS Version'"
#Execute-And-Write "Get-WmiObject -Class Win32_ComputerSystem | Format-List *"
#Execute-And-Write "Get-WmiObject -Class Win32_Baseboard | Format-List *"
#Execute-And-Write "Get-WmiObject -Class Win32_PhysicalMemory | Format-List *"



# Main script
$registryPrograms = Get-InstalledProgramsFromRegistry
$userRegistryPrograms = Get-InstalledProgramsFromUserRegistry
$wmicPrograms = Get-InstalledProgramsWithWmic
$uwpPrograms = Get-InstalledUwpApps
$allPrograms = Merge-AndRemoveDuplicates -programs1 $registryPrograms -programs2 $userRegistryPrograms -programs3 $wmicPrograms -programs4 $uwpPrograms
$txtFilename = "installed_programs.txt"
Export-ToTxt -programs $allPrograms -txtFilename $txtFilename
Write-Host "Exported $($allPrograms.Count) unique installed programs to $txtFilename."

# Write a summary to the output file
Add-Content -Path $outputFile -Value ("=" * 50)
Add-Content -Path $outputFile -Value "Summary: Exported $($allPrograms.Count) unique installed programs to $txtFilename."
Add-Content -Path $outputFile -Value ("=" * 50)
