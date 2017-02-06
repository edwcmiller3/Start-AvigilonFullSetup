<#
May not need this?
function Get-District {
    #TODO: List school districts, handle selection, pass to Install-AvigilonSoftware
}
#>

function Install-CentraStage {
    <#
    .SYNOPSIS
        Runs the CentraStage installer.

    .DESCRIPTION
        Installs CentraStage on the device and places the device under the TEMP site.
        Requires manually moving device to the site to which it belongs.

    .EXAMPLE
        Called from Run-Main function. Can be run as standalone with Install-CentraStage.

    .LINK
        "Press any key to continue..." snippet taken from:
        https://technet.microsoft.com/en-us/library/ff730938.aspx
    #>
    [CmdletBinding()]
    param(
    )
    
    begin {
        try {
            Test-Path "Path\to\Centrastage\clients" -ErrorAction Stop
            $CentraStagePath = "Path\to\Centrastage\clients" 
            #$CentraStageInstallers = Get-ChildItem "Path\to\Centrastage\clients" -File
            #$CentraStageList = $CentraStageInstallers | Sort-Object | ForEach-Object { $_.BaseName.Substring(11).Replace('+', ' ') }
            $CentraStageDefaultInstaller = "Path\to\Centrastage\clients\default.exe"
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
        
        Write-Host "Press any key to continue..."
        $x = $Host.UI.RawUI.ReadKey("NoEcho, IncludeKeyDown")
    }
}

function Remove-AvigilonStartupItem {
    [CmdletBinding()]
    param(
    )

    begin {
        try {
            Test-Path "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Avigilon Control Center 5 Client.lnk" -ErrorAction Stop
            $AvigilonStartupItem = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\Avigilon Control Center 5 Client.lnk"
        } catch {
            Write-Error "No Avigilon startup item found"
        }
    }

    process {
        Remove-Item $AvigilonStartupItem
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

    .LINK
        "Press any key to continue..." snippet taken from:
        https://technet.microsoft.com/en-us/library/ff730938.aspx
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
            #Run the default installer if District not passed/NotListed selected
            #Relies on default installer folder with name '[Default] X.X.X.X'
            $AvigilonInstallerPath = $AvigilonSoftwarePath | Sort-Object | Select-Object -First 1
            $ACCSInstaller = Get-ChildItem $AvigilonInstallerPath | Where-Object { $_.Name -like "*Server*" }
            & ($ACCSInstaller) | Out-Null
        } else {
            #TODO: District based selection
        }
    }

    end {
        Remove-AvigilonStartupItem
    }
}


function Rename-NetworkAdapters {
    [CmdletBinding()]
    param(
    )

    begin {
        $IntelCameraAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Manufacturer -like "Intel*" }
        $RealtekLANAdapter = Get-WmiObject -Class Win32_NetworkAdapter | Where-Object { $_.Manufacturer -like "Real*" }
    }

    process {
        $IntelCameraAdapter.NetConnectionID = Read-Host "Enter the name for the Intel (camera) adapter"
        $RealtekLANAdapter.NetConnectionID = Read-Host "Enter the name for the Realtek (LAN) adapter" 
    }

    end {
        $IntelCameraAdapter.Put() | Out-Null
        $RealtekLANAdapter.Put() | Out-Null
    }
}

function Disable-Firewall {
    [CmdletBinding()]
    param(
    )

    process {
        netsh advfirewall set allprofiles state off
    }
}

function Disable-WindowsUpdate {
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
    }
}

function Run-WindowsUpdate {
    [CmdletBinding()]
    param(
    )

    begin {
        #Need to restart the Windows Update service before running the update for Windows Update.
        #Create temporary folder and download the update installer to it.
        Stop-Service wuauserv
        mkdir "C:\tmp"
        Invoke-WebRequest -Uri "https://download.microsoft.com/download/B/7/C/B7CD3A70-1EA7-486A-9585-F6814663F1A9/Windows6.1-KB3138612-x64.msu" 
                          -UseBasicParsing 
                          -OutFile "C:\tmp\update.msu"
    }

    process {
        #Start Windows Update service, run the update, then check for any other updates.
        Start-Service wuauserv
        & ("C:\tmp\update.msu")
        wuauclt.exe /ShowWUAutoScan
    }

    end {
        #Cleanup temporary directory and files.
        Remove-Item -Recurse "C:\tmp"
    }
}

function Run-Main {
    [CmdletBinding()]
    param(
    )

    begin {
        $MenuOptions = @("1. Select school district",
                         "2. Install CentraStage",
                         "3. Install Avigilon Control Center client",
                         "4. Rename network adapters",
                         "5. Set camera adapter network configuration",#TODO
                         "6. Configure & run Windows Update",
                         "Q. QUIT")

        $District = "NotListed"
    }

    process {
        do {
            Clear-Host
            $MenuOptions
            $MenuSelection = Read-Host "Make a selection"
            switch ($MenuSelection) {
                '1' { $District = Get-District }
                '2' { Install-CentraStage }
                '3' { Install-AvigilonSoftware -District $District }
                '4' { Rename-NetworkAdapters }
                #'5' { TODO: Configure network }
                '6' { Run-WindowsUpdate }
                'Q' { return }
                default { "Invalid selection" }
            }
            pause
        } until ($MenuSelection -eq 'Q')
    }
}

Run-Main