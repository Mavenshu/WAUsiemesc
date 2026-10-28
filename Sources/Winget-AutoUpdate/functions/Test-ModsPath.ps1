<#
.SYNOPSIS
    Syncs modification scripts from a local folder.

.DESCRIPTION
    Compares the local mods folder with a source folder on a local fixed drive.
    Copies newer .ps1/.txt mod files and .exe binaries under bins, and removes
    supported local files that are no longer present in the source.

.PARAMETER ModsPath
    Absolute path to a source folder on a local fixed drive.

.PARAMETER WingetUpdatePath
    The local WAU installation directory.

.OUTPUTS
    Array: [ModsUpdated count, DeletedMods count]

.NOTES
    URL, Azure Blob, UNC, mapped-drive, relative, and non-fixed-drive sources
    are rejected. Sets script-scoped $ReachNoPath to True when a source cannot
    be used.
#>
function Test-ModsPath ($ModsPath, $WingetUpdatePath) {
    $ModsUpdated = 0
    $DeletedMods = 0

    if ([string]::IsNullOrWhiteSpace($ModsPath) -or $ModsPath -notmatch '^[A-Za-z]:[\\/]') {
        Write-ToLog "Mods source rejected: an absolute local fixed-drive folder is required." "Red"
        $Script:ReachNoPath = $True
        return $ModsUpdated, $DeletedMods
    }

    $SourceFullPath = [System.IO.Path]::GetFullPath($ModsPath).TrimEnd("\")
    $DriveRoot = [System.IO.Path]::GetPathRoot($SourceFullPath)
    $Drive = [System.IO.DriveInfo]::GetDrives() |
        Where-Object { $_.Name -ieq $DriveRoot } |
        Select-Object -First 1

    if ($SourceFullPath.TrimEnd("\") -ieq $DriveRoot.TrimEnd("\") -or
        $null -eq $Drive -or $Drive.DriveType -ne [System.IO.DriveType]::Fixed) {
        Write-ToLog "Mods source rejected: only local fixed drives are supported." "Red"
        $Script:ReachNoPath = $True
        return $ModsUpdated, $DeletedMods
    }

    if (-not (Test-Path -LiteralPath $SourceFullPath -PathType Container)) {
        Write-ToLog "Mods source folder is unavailable." "Red"
        $Script:ReachNoPath = $True
        return $ModsUpdated, $DeletedMods
    }

    $LocalMods = [System.IO.Path]::GetFullPath((Join-Path $WingetUpdatePath "mods")).TrimEnd("\")
    $SourceIsInsideDestination = $SourceFullPath.Equals($LocalMods, [System.StringComparison]::OrdinalIgnoreCase) -or
        $SourceFullPath.StartsWith("$LocalMods\", [System.StringComparison]::OrdinalIgnoreCase)
    $DestinationIsInsideSource = $LocalMods.StartsWith("$SourceFullPath\", [System.StringComparison]::OrdinalIgnoreCase)

    if ($SourceIsInsideDestination -or $DestinationIsInsideSource) {
        Write-ToLog "Mods source rejected: source and destination folders must not overlap." "Red"
        $Script:ReachNoPath = $True
        return $ModsUpdated, $DeletedMods
    }

    Write-ToLog "Synchronizing mods from local folder: $SourceFullPath" "Cyan"

    if (-not (Test-Path -LiteralPath $LocalMods -PathType Container)) {
        New-Item -ItemType Directory -Path $LocalMods -Force -ErrorAction Stop | Out-Null
    }

    $ExternalFiles = @(
        Get-ChildItem -LiteralPath $SourceFullPath -File -Recurse -ErrorAction Stop |
            Where-Object {
                $relativePath = $_.FullName.Substring($SourceFullPath.Length).TrimStart("\")
                $_.Extension -in @(".ps1", ".txt") -or
                ($relativePath -match "^bins\\.+\.exe$")
            }
    )

    if ($ExternalFiles.Count -eq 0) {
        Write-ToLog "Mods source contains no supported mod files or bins." "Yellow"
        $Script:ReachNoPath = $True
        return $ModsUpdated, $DeletedMods
    }

    $ExternalModFiles = @($ExternalFiles | Where-Object { $_.Extension -in @(".ps1", ".txt") })
    $ExternalBinFiles = @(
        $ExternalFiles | Where-Object {
            $relativePath = $_.FullName.Substring($SourceFullPath.Length).TrimStart("\")
            $relativePath -match "^bins\\.+\.exe$"
        }
    )

    $ExternalRelativePaths = @{}
    foreach ($File in $ExternalFiles) {
        $RelativePath = $File.FullName.Substring($SourceFullPath.Length).TrimStart("\")
        $ExternalRelativePaths[$RelativePath] = $true
    }

    $InternalFiles = @(
        Get-ChildItem -LiteralPath $LocalMods -File -Recurse -ErrorAction Stop |
            Where-Object {
                $relativePath = $_.FullName.Substring($LocalMods.Length).TrimStart("\")
                $_.Extension -in @(".ps1", ".txt") -or
                ($relativePath -match "^bins\\.+\.exe$")
            }
    )

    foreach ($File in $InternalFiles) {
        $RelativePath = $File.FullName.Substring($LocalMods.Length).TrimStart("\")
        $IsModFile = $File.Extension -in @(".ps1", ".txt")
        $IsBinFile = $RelativePath -match "^bins\\.+\.exe$"
        $ShouldRemove = ($IsModFile -and $ExternalModFiles.Count -gt 0) -or
            ($IsBinFile -and $ExternalBinFiles.Count -gt 0)

        if ($ShouldRemove -and -not $ExternalRelativePaths.ContainsKey($RelativePath)) {
            Remove-Item -LiteralPath $File.FullName -Force -ErrorAction Stop
            if ($IsModFile) {
                $DeletedMods++
            }
        }
    }

    foreach ($File in $ExternalFiles) {
        $RelativePath = $File.FullName.Substring($SourceFullPath.Length).TrimStart("\")
        $DestinationPath = Join-Path $LocalMods $RelativePath
        $DestinationDirectory = Split-Path -Path $DestinationPath -Parent

        if (-not (Test-Path -LiteralPath $DestinationPath -PathType Leaf) -or
            $File.LastWriteTimeUtc -gt (Get-Item -LiteralPath $DestinationPath).LastWriteTimeUtc) {
            if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $DestinationDirectory -Force -ErrorAction Stop | Out-Null
            }

            Copy-Item -LiteralPath $File.FullName -Destination $DestinationPath -Force -ErrorAction Stop
            if ($File.Extension -in @(".ps1", ".txt")) {
                $ModsUpdated++
            }
        }
    }

    return $ModsUpdated, $DeletedMods
}
