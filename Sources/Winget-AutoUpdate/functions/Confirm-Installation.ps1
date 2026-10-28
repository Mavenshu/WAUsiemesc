<#
.SYNOPSIS
    Verifies application installation at expected version.

.PARAMETER AppName
    WinGet package identifier.

.PARAMETER AppVer
    Expected version prefix.

.PARAMETER src
    The WinGet source to query (e.g. "winget", "msstore"). Defaults to
    "winget".

.OUTPUTS
    Boolean: True if installed at version.
#>
Function Confirm-Installation ($AppName, $AppVer, $src = "winget") {
    if ([string]::IsNullOrWhiteSpace($src)) {
        $src = "winget"
    }
    else {
        $src = $src.Trim()
    }

    $JsonFile = Join-Path $env:TEMP "InstalledApps_$([guid]::NewGuid().ToString('N')).json"
    try {
        & $Winget export -s $src -o $JsonFile --include-versions | Out-Null
        $ExportExitCode = $LASTEXITCODE
        if ($ExportExitCode -ne 0) {
            throw "WinGet export failed with exit code $ExportExitCode."
        }

        if (-not (Test-Path -LiteralPath $JsonFile -PathType Leaf)) {
            throw "WinGet export did not create its result file."
        }

        $Export = Get-Content -LiteralPath $JsonFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $Export.Sources -or $null -eq $Export.Sources.Packages) {
            $Packages = @()
        }
        else {
            $Packages = @($Export.Sources.Packages)
        }

        $match = $Packages | Where-Object { $_.PackageIdentifier -eq $AppName -and $_.Version -like "$AppVer*" }
        return [bool]$match
    }
    finally {
        if (Test-Path -LiteralPath $JsonFile) {
            Remove-Item -LiteralPath $JsonFile -Force -ErrorAction Stop
        }
    }
}
