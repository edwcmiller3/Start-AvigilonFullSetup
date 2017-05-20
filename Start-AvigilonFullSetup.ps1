function Install-CentraStage {
    <#
    .SYNOPSIS
        Runs the CentraStage installer.

    .DESCRIPTION
        Installs CentraStage on the device and places the device under the TEMP site.
        Requires manually moving device to the site to which it belongs.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Install-CentraStage.
    #>

    [CmdletBinding()]
    param(
    )
    
    begin {
        try {
            if (Test-Path "Path\to\Centrastage\clients" -ErrorAction Stop) {
                $CentraStagePath = "Path\to\Centrastage\clients" 
                $CentraStageDefaultInstaller = "Path\to\Centrastage\clients\default.exe"
            } else { 
            }
        } catch {
            Write-Error "CentraStage clients folder could not be reached"
        }
    }

    process {
        Write-Host "Running the CentraStage installer..."
        & ($CentraStageDefaultInstaller)
    }

    end {
        Write-Host "Done! Appliance added under TEMP site - login to CentraStage and move appliance to specific site"
        
        pause
    }
}

function Install-AvigilonSoftware {
    <#
    .SYNOPSIS
        Runs the Avigilon Control Center Server installer.

    .DESCRIPTION
        Installs Avigilon Control Center Server and Client based on user input.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with 
        Install-AvigilonSoftware
        Install-AvigilonSoftware -District "SchoolDistrictName"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true)]
        [string]$District = "NotListed"
    )
    
    begin {
        try {
            Test-Path "Path\to\Avigilon\software" -ErrorAction Stop
            $AvigilonSoftwarePath = "Path\to\Avigilon\software"
        } catch {
            Write-Error "Avigilon software folder could not be reached"
        }
    }

    process {
        if ($District -eq "NotListed") {
            # Run the default installer if District not passed/NotListed selected
            # Relies on default installer folder with name '[Default] X.X.X.X'
            $AvigilonInstallerPath = $AvigilonSoftwarePath | Sort-Object | Select-Object -First 1
            $ACCSInstaller = Get-ChildItem $AvigilonInstallerPath | Where-Object { $_.Name -like "*Server*" }
            & ($ACCSInstaller) | Out-Null
        } else {
            # TODO: District based selection
        }
    }

    end {
        # If the installer adds the client software to Startup, remove it from Startup
        if (Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\*Client*") {
            $AvigilonStartupItem = Get-ChildItem "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\*Client*"
            Remove-Item $AvigilonStartupItem
        }

        pause
    }
}


function Rename-NetworkAdapters {
    <#
    .SYNOPSIS
        Renames the network adapters on Avigilon appliances.

    .DESCRIPTION
        Renames the Intel and Realtek (U1 and U2) network adapters on Avigilon appliances.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with 
        Rename-NetworkAdapters
        Rename-NetworkAdapters -IntelAdapterName "CAMERAS" -RealtekAdapterName "LAN"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true)]
        [string]$IntelAdapterName = '',

        [Parameter(Mandatory = $false,
                   ValueFromPipelineByPropertyName = $true)]
        [string]$RealtekAdapterName = ''
    )

    begin {
        $IntelCameraAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Manufacturer -like "Intel*" }
        $RealtekLANAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Manufacturer -like "Real*" }
    }

    process {
        # If the adapters were specified via their respective switches, use the names provided
        # Else get the new names from user input
        if ($IntelAdapterName) {
            $IntelCameraAdapter.NetConnectionID = $IntelAdapterName
        } else {
            $IntelCameraAdapter.NetConnectionID = Read-Host "Enter the name for the Intel (camera) adapter"
        }

        if ($RealtekAdapterName) {
            $RealtekLANAdapter.NetConnectionID = $RealtekAdapterName
        } else {
            $RealtekLANAdapter.NetConnectionID = Read-Host "Enter the name for the Realtek (LAN) adapter" 
        }
    }

    end {
        $IntelCameraAdapter.Put() | Out-Null
        $RealtekLANAdapter.Put() | Out-Null

        pause
    }
}

function Set-CameraAdapterConfiguration {
    <#
    Stuff
    #>

    [CmdletBinding()]
    param(
    )

    begin {
        # Regular expression for checking validity of IP/subnet mask
        $ValidIPRegex = "^(?:(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)\.){3}(?:0?0?\d|0?[1-9]\d|1\d\d|2[0-5][0-5]|2[0-4]\d)$"

        # Store network configuration for Intel adapter
        $InterfaceIndex = (Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Name -like "*Intel*" }).InterfaceIndex
        $NetworkInterface = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.InterfaceIndex -eq $InterfaceIndex }

        # Accept user input for camera adapter network configuration as long as input is valid
        do {
            Write-Host "Enter all the following information in the format 'XXX.XXX.XXX.XXX'"
            $CameraAdapterIP = Read-Host -Prompt "Enter the IP address"
            $CameraAdapterSubnet = Read-Host -Prompt "Enter the subnet mask"
            $CameraAdapterGateway = Read-Host -Prompt "Enter the default gateway"
            $CameraAdapterDNS = Read-Host -Prompt "Enter the DNS server"
        } until ($CameraAdapterIP -and $CameraAdapterSubnet -and $CameraAdapterGateway -and $CameraAdapterDNS -match $ValidIPRegex)
    }

    process {
        # Apply user configuration to the camera adapter
        $NetworkInterface.EnableStatic($CameraAdapterIP, $CameraAdapterSubnet) | Out-Null
        $NetworkInterface.SetGateways($CameraAdapterGateway) | Out-Null
        $NetworkInterface.SetDNSServerSearchOrder(@($CameraAdapterDNS)) | Out-Null
    }

    end {
        pause
    }
}

function Disable-Firewall {
    <#
    .SYNOPSIS
        Disables Windows Firewall.

    .DESCRIPTION
        Sets all Windows Firewall profiles to off.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Disable-Firewall.
    #>

    [CmdletBinding()]
    param(
    )

    process {
        # For Windows 7 without PowerShell 3.0
        netsh advfirewall set allprofiles state off
    }

    end {
        pause
    }
}

function Register-CCleanerScheduledTask {
    <#
    .SYNOPSIS
        Creates a scheduled task to run CCleaner.

    .DESCRIPTION
        Downloads CCleaner, runs the installer, then schedules an automatic run
        at 3:00PM the first of every month.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Disable-WindowsUpdate.

    .NOTES
        Need to find a way to get the newest version of CCleaner.
        Currently just downloads version 5.27.
    #>

    [CmdletBinding()]
    param(
    )

    begin {
        # Create temporary directory for CCleaner download
        $DownloadPath = New-Item -ItemType Directory -Path "C:\tmp"
        $Destination = $DownloadPath.FullName + "\ccleaner.exe"
        
        # PowerShell 2.0 version of Invoke-WebRequest
        # Some appliances may not have latest version of PowerShell
        $CCleanerURL = "http://download.piriform.com/ccsetup530.exe"
        $Client = New-Object System.Net.WebClient
        $Client.DownloadFile($CCleanerURL, $Destination)

        & ("C:\tmp\ccleaner.exe")
    }

    process {
        # Creates scheduled task that runs CCleaner once a month at 3:00pm
        schtasks /CREATE /TN "Run CCleaner" /SC MONTHLY /M * /ST 15:00 /TR "C:\Program Files\CCleaner\CCleaner.exe /AUTO"
    }

    end {
        # Clean up temporary download directory
        Remove-Item -Recurse -Path "C:\tmp"

        pause
    }
}

function Disable-WindowsUpdate {
    <#
    .SYNOPSIS
        Turns off automatic updating.

    .DESCRIPTION
        Sets the Windows Update scheduling and notification to disabled.
        Avoids appliance auto restarting to install updates which may interrupt camera recording.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Disable-WindowsUpdate.

    .NOTES
        Recommend manually updating the appliance or schedule updates for planned downtime.
    #>

    [CmdletBinding()]
    param(
    )

    begin {
        $WUSettings = (New-Object -ComObject "Microsoft.Update.AutoUpdate").Settings
    }

    process {
        <#
        Set NotificationLevel to Disabled to turn off automatic updating
        1 = Disabled
        2 = Notify before download
        3 = Notify before installation
        4 = Scheduled installation
        #>
        $WUSettings.NotificationLevel = 1
    }

    end {
        $WUSettings.Save()

        pause
    }
}

function Run-WindowsUpdate {
    <#
    .SYNOPSIS
        Configures and runs Windows Update.

    .DESCRIPTION
        Downloads and runs the update for Windows Update for Windows 7 systems, then starts checking for updates.
        Update for Windows Update can fail if the Windows Update service has not been restarted before running.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Run-WindowsUpdate.
    #>

    [CmdletBinding()]
    param(
    )

    begin {
        # Need to restart the Windows Update service before running the update for Windows Update.
        # Create temporary folder and download the update installer to it.
        Stop-Service wuauserv
        
        New-Item -ItemType Directory -Path "C:\tmp"

        Invoke-WebRequest -Uri "https://download.microsoft.com/download/B/7/C/B7CD3A70-1EA7-486A-9585-F6814663F1A9/Windows6.1-KB3138612-x64.msu" -UseBasicParsing -OutFile "C:\tmp\update.msu"
    }

    process {
        # Start Windows Update service, run the update, then check for any other updates.
        Start-Service wuauserv
        & ("C:\tmp\update.msu")
        wuauclt.exe /ShowWUAutoScan
    }

    end {
        # Cleanup temporary directory and files.
        Remove-Item -Recurse -Path "C:\tmp"

        pause
    }
}

function Run-Main {
    <#
    .SYNOPSIS
        Main loop function for Start-AvigilonFullSetup script.

    .DESCRIPTION
        Clears the screen, displays menu for available configuration options, and accepts user input to run respective functions.
    #>

    [CmdletBinding()]
    param(
    )

    begin {
        $MenuOptions = @("1. Select school district",
                         "2. Install CentraStage",
                         "3. Install Avigilon Control Center client",
                         "4. Rename network adapters",
                         "5. Set camera adapter network configuration",
                         "6. Create CCleaner scheduled task",
                         "7. Disable automatic Windows updates",
                         "8. Run Windows Update",
                         "Q. QUIT")

        $District = "NotListed"
    }

    process {
        do {
            Clear-Host     # Each iteration through loop will clear the display
            $MenuOptions   # and write the main menu to the screen.

            $MenuSelection = Read-Host "Make a selection"
            switch ($MenuSelection) {
                '1' { $District = Get-District }
                '2' { Install-CentraStage }
                '3' { Install-AvigilonSoftware -District $District }
                '4' { Rename-NetworkAdapters }
                '5' { Set-CameraAdapterConfiguration }
                '6' { Register-CCleanerScheduledTask }
                '7' { Disable-WindowsUpdate }
                '8' { Run-WindowsUpdate }
                'Q' { return }
                default { "Invalid selection" }
            }
            pause
        } until ($MenuSelection -eq 'Q')
    }
}

Run-Main