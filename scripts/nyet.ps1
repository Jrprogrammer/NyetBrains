# For Self Update with elevated permissions: Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File {file}" -Verb RunAs

param (
    [switch] $help,
    [string] $name,
    [switch] $noshortcut,
    [switch] $list,
    [switch] $installed,
    [string] $extensions,
    [Parameter(Position = 0)]
    [string] $variant
)

$VariantList = ((New-Object System.Net.WebClient).DownloadString('https://nyetbrains.net/variants/list.txt') -split "\n")
$HomeDir = "C:" + $env:HOMEPATH + "\.nyet"
$HelpText = "
This is the NyetBrains help screen
Check out the options below to see what's possible!

Usage:
    nyet [options] [instance]/[variant]

Arguments:
    -help              This page
    -name              Set the name of the instance
    -noshortcut        Don't generate a shortcut
    -list              List all available variants
    -installed         List all installed variants
    -extensions        List all the extensions of a given instance

Examples:
    nyet -name js-instance javascript
    nyet -noshortcut -name rust-instance rust
    nyet -list
"

function Get-Random {
    # Random word generator for folder names
    return ((invoke-webrequest -Uri "https://random-words-api.vercel.app/word").content | convertfrom-json).Word.ToLower()
}

function Get-Installed {
    return Get-ChildItem $HomeDir"\variants" | Where-Object { $_.PSIsContainer } | Foreach-Object { $_.Name }
}

function Set-Name {
    param ($NewName)

    if ($NewName -eq "") {
        $NewName = (Get-Random)
    }
    if (-not ($NewName[0] -match "[a-zA-Z]")) {
        Write-Output "A name must begin with a letter!"
        exit
    }

    return $NewName
}

function Show-Text {
    Write-Output $HelpText
    exit
}

function Show-Variants {
    Write-Output "Available variants:"
    foreach ($i in $VariantList) {
        Write-Output ("- " + $i)
    }
    exit
}

function Show-Installed {
    # Gets all folders in the home folder and stores it as an array 
    $InstalledVariants = Get-Installed

    Write-Output "Variant`t`tName"
    Write-Output "--------------------------"
    foreach ($Var in $InstalledVariants) {
        $Split = $Var.split("-")

        # Handling for non-standard names
        if (($Split.count) -gt 1 -and $VariantList -contains $Split[0]) {
            Write-Output "$($Split[0])`t`t$($Split -join "-")"
        }
        else {
            Write-Output "???`t`t$($Split -join "-")"
        }
        
    }
    exit
}

function Show-Extensions {
    param($DirName)

    if (-not $DirName) {
        Write-Output "No instance name was given"
        exit
    }

    if ((Get-Installed) -contains $DirName) {
        Write-Output (code --extensions-dir="$HomeDir\variants\$DirName\Extensions" --list-extensions)
    }
    else {
        Write-Output "Could not find instance $DirName"
    }
    
    exit
}

function New-Shortcut {
    param ($Variant, $Name)
    $DirName = $Variant + "-" + $Name

    if (-not (Test-Path -Path "$HomeDir\icons\$Variant.ico" -PathType Leaf)) {
        (New-Object System.Net.WebClient).DownloadFile("https://nyetbrains.net/icons/$variant.ico", "$HomeDir\icons\$Variant.ico")
    }

    $Shell = New-Object -ComObject ("WScript.Shell")
    $ShortCut = $Shell.CreateShortcut($env:USERPROFILE + "\Desktop\$Name.lnk")
    $ShortCut.TargetPath = "code"
    $ShortCut.Arguments = " --user-data-dir=$HomeDir\variants\$DirName --extensions-dir=$HomeDir\variants\$DirName\Extensions | exit"
    $ShortCut.IconLocation = "$HomeDir\icons\$Variant.ico"
    $ShortCut.Save()
    exit
}

function New-Variant {
    param ($Variant, $Name)
    $DirName = $Variant + "-" + $Name

    if (-not ($VariantList -contains $Variant)) {
        Write-Output "Could not find Variant $Variant`n"
        Show-Variants
        exit
    }

    try {
        New-Item -Path "$HomeDir\variants\$DirName" -ItemType Directory -ErrorAction Stop | Out-Null
        New-Item -Path "$HomeDir\variants\$DirName\Extensions" -ItemType Directory -ErrorAction Stop | Out-Null
    }
    catch {
        Write-Error -Message "Unable to create directories. Error was: $_" -ErrorAction Stop
    }

    if ($Variant -ne "blank") {
        try {
            New-Item -Path "$HomeDir\variants\$DirName\User" -ItemType Directory -ErrorAction Stop | Out-Null
            (New-Object System.Net.WebClient).DownloadFile("https://nyetbrains.net/variants/$Variant/settings.json", "$HomeDir\variants\$DirName\User\settings.json")
            (New-Object System.Net.WebClient).DownloadFile("https://nyetbrains.net/variants/$Variant/keybindings.json", "$HomeDir\variants\$DirName\User\keybindings.json")

            $BaseCommand = "code --extensions-dir=$HomeDir\variants\$DirName\Extensions"
            foreach ($Ext in ((New-Object System.Net.WebClient).DownloadString("https://nyetbrains.net/variants/$Variant/extensions.txt") -split "\n")) {
                $BaseCommand += " --install-extension $Ext"
            }

            (Invoke-Expression $BaseCommand)

        }
        catch {
            Write-Error -Message "Unable to download files. Error was: $_" -ErrorAction Stop
        }
    }

    if (-not $noshortcut) {
        New-Shortcut $Variant $Name
    }

    Write-Output "NyetBrains is done with the installation of $DirName"

}

if ($script:PSBoundParameters.keys.count -eq 0 ) { Show-Text }
switch ($script:PSBoundParameters.keys) {
    'help' { Show-Text }
    'list' { Show-Variants }
    'installed' { Show-Installed }
    'extensions' { Show-Extensions $extensions }
    'name' {}
    'noshortcut' {}
    'variant' { New-Variant $variant (Set-Name $name) }
    Default { Write-Output "Argument not found" }
}