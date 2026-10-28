<#
.SYNOPSIS
    Downloads the latest WAU release and performs self-update.

.DESCRIPTION
    Downloads the WAU MSI package from GitHub and installs it to update
    WAU to the latest version. Sends notifications before and after
    the update process.

.EXAMPLE
    Update-WAU

.NOTES
    Exits the script after update to allow the new version to run.
    Uses MSI installer with silent installation parameters.
#>
function Update-WAU {

    # Setup notification action and button
    $OnClickAction = "https://github.com/$($GitHub_Owner)/$($GitHub_Repo)/releases"
    $Button1Text = $NotifLocale.local.outputs.output[10].message

    # Send "update available" notification
    $Title = $NotifLocale.local.outputs.output[2].title -f "Winget-AutoUpdate"
    $Message = $NotifLocale.local.outputs.output[2].message -f $WAUCurrentVersion, $WAUAvailableVersion
    $MessageType = "info"
    Start-NotifTask -Title $Title -Message $Message -MessageType $MessageType -Button1Action $OnClickAction -Button1Text $Button1Text

    $MsiFolder = $null
    try {
        Write-ToLog "Downloading the GitHub Repository version $WAUAvailableVersion" "Cyan"

        $MsiFolder = Join-Path $env:TEMP "WAU_$([guid]::NewGuid().ToString('N'))"
        New-Item -ItemType Directory -Path $MsiFolder -ErrorAction Stop | Out-Null

        # Download the MSI package
        $MsiFile = Join-Path $MsiFolder "WAU.msi"
        Invoke-RestMethod -Uri "https://github.com/$($GitHub_Owner)/$($GitHub_Repo)/releases/download/v$($WAUAvailableVersion)/WAU.msi" -OutFile $MsiFile
        if (-not (Test-Path -LiteralPath $MsiFile -PathType Leaf) -or (Get-Item -LiteralPath $MsiFile).Length -eq 0) {
            throw "Downloaded WAU MSI is missing or empty."
        }

        # Install the update
        Write-ToLog "Updating WAU..." "Yellow"
        $InstallerLog = Join-Path $WorkingDir "logs\WAU-Installer.log"
        $InstallerProcess = Start-Process msiexec.exe `
            -ArgumentList "/i `"$MsiFile`" /qn /L*v `"$InstallerLog`" RUN_WAU=YES INSTALLDIR=`"$WorkingDir`"" `
            -Wait -PassThru -ErrorAction Stop

        if ($InstallerProcess.ExitCode -notin @(0, 1641, 3010)) {
            throw "WAU MSI installer failed with exit code $($InstallerProcess.ExitCode)."
        }

        # Send success notification
        Write-ToLog "WAU Update completed with installer exit code $($InstallerProcess.ExitCode). Rerunning WAU..." "Green"
        $Title = $NotifLocale.local.outputs.output[3].title -f "Winget-AutoUpdate"
        $Message = $NotifLocale.local.outputs.output[3].message -f $WAUAvailableVersion
        $MessageType = "success"
        Start-NotifTask -Title $Title -Message $Message -MessageType $MessageType -Button1Action $OnClickAction -Button1Text $Button1Text

        exit 0
    }

    catch {
        # Send error notification
        $Title = $NotifLocale.local.outputs.output[4].title -f "Winget-AutoUpdate"
        $Message = $NotifLocale.local.outputs.output[4].message
        $MessageType = "error"
        Start-NotifTask -Title $Title -Message $Message -MessageType $MessageType -Button1Action $OnClickAction -Button1Text $Button1Text
        Write-ToLog "WAU Update failed: $_" "Red"
    }
    finally {
        if ($MsiFolder -and (Test-Path -LiteralPath $MsiFolder)) {
            try {
                Remove-Item -LiteralPath $MsiFolder -Recurse -Force -ErrorAction Stop
            }
            catch {
                Write-ToLog "Failed to clean up WAU update files at '$MsiFolder': $_" "Red"
            }
        }
    }

}