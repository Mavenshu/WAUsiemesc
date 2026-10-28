<#
.SYNOPSIS
    Compares two semantic version strings.

.DESCRIPTION
    Compares two version strings following semantic versioning rules.
    Handles pre-release versions (e.g., "1.0.0-beta1").
    Numeric suffixes in pre-release labels are compared numerically, and
    pre-release versions are considered less than their release counterparts.

.PARAMETER Version1
    The first version string to compare.

.PARAMETER Version2
    The second version string to compare.

.OUTPUTS
    Integer: -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2

.EXAMPLE
    Compare-SemVer -Version1 "1.0.0" -Version2 "1.1.0"  # Returns -1

.EXAMPLE
    Compare-SemVer -Version1 "2.0.0" -Version2 "2.0.0-beta"  # Returns 1
#>
function Compare-SemVer {
    param (
        [string]$Version1,
        [string]$Version2
    )

    # Ignore build metadata when determining version precedence.
    $v1Text = ($Version1 -split '\+', 2)[0]
    $v2Text = ($Version2 -split '\+', 2)[0]

    $v1Separator = $v1Text.IndexOf('-')
    $v2Separator = $v2Text.IndexOf('-')
    $v1Core = if ($v1Separator -ge 0) { $v1Text.Substring(0, $v1Separator) } else { $v1Text }
    $v2Core = if ($v2Separator -ge 0) { $v2Text.Substring(0, $v2Separator) } else { $v2Text }
    $v1PreRelease = if ($v1Separator -ge 0) { $v1Text.Substring($v1Separator + 1) } else { $null }
    $v2PreRelease = if ($v2Separator -ge 0) { $v2Text.Substring($v2Separator + 1) } else { $null }

    # Parse main version numbers
    $v1 = [Version]$v1Core
    $v2 = [Version]$v2Core

    # Compare major version
    if ($v1.Major -ne $v2.Major) {
        return [Math]::Sign($v1.Major - $v2.Major)
    }

    # Compare minor version
    if ($v1.Minor -ne $v2.Minor) {
        return [Math]::Sign($v1.Minor - $v2.Minor)
    }

    # Compare build version
    if ($v1.Build -ne $v2.Build) {
        return [Math]::Sign($v1.Build - $v2.Build)
    }

    # Compare revision
    if ($v1.Revision -ne $v2.Revision) {
        return [Math]::Sign($v1.Revision - $v2.Revision)
    }

    # Handle pre-release comparison according to SemVer identifier ordering.
    if ($null -ne $v1PreRelease -and $null -ne $v2PreRelease) {
        $v1Identifiers = $v1PreRelease.Split('.')
        $v2Identifiers = $v2PreRelease.Split('.')

        for ($i = 0; $i -lt [Math]::Min($v1Identifiers.Length, $v2Identifiers.Length); $i++) {
            $v1Identifier = $v1Identifiers[$i]
            $v2Identifier = $v2Identifiers[$i]
            $v1IsNumeric = $v1Identifier -match '^\d+$'
            $v2IsNumeric = $v2Identifier -match '^\d+$'

            if ($v1IsNumeric -and $v2IsNumeric) {
                $v1Number = [System.Numerics.BigInteger]::Parse($v1Identifier, [Globalization.CultureInfo]::InvariantCulture)
                $v2Number = [System.Numerics.BigInteger]::Parse($v2Identifier, [Globalization.CultureInfo]::InvariantCulture)
                $identifierComparison = $v1Number.CompareTo($v2Number)
            }
            elseif ($v1IsNumeric) {
                return -1
            }
            elseif ($v2IsNumeric) {
                return 1
            }
            else {
                $v1Segments = [regex]::Matches($v1Identifier, '\d+|\D+') | ForEach-Object { $_.Value }
                $v2Segments = [regex]::Matches($v2Identifier, '\d+|\D+') | ForEach-Object { $_.Value }
                $identifierComparison = 0

                for ($segmentIndex = 0; $segmentIndex -lt [Math]::Min($v1Segments.Count, $v2Segments.Count); $segmentIndex++) {
                    $v1Segment = $v1Segments[$segmentIndex]
                    $v2Segment = $v2Segments[$segmentIndex]
                    if ($v1Segment -match '^\d+$' -and $v2Segment -match '^\d+$') {
                        $v1Number = [System.Numerics.BigInteger]::Parse($v1Segment, [Globalization.CultureInfo]::InvariantCulture)
                        $v2Number = [System.Numerics.BigInteger]::Parse($v2Segment, [Globalization.CultureInfo]::InvariantCulture)
                        $identifierComparison = $v1Number.CompareTo($v2Number)
                    }
                    else {
                        $identifierComparison = [String]::CompareOrdinal($v1Segment, $v2Segment)
                    }

                    if ($identifierComparison -ne 0) {
                        break
                    }
                }

                if ($identifierComparison -eq 0) {
                    $identifierComparison = $v1Segments.Count.CompareTo($v2Segments.Count)
                }
            }

            if ($identifierComparison -ne 0) {
                return [Math]::Sign($identifierComparison)
            }
        }

        return [Math]::Sign($v1Identifiers.Length - $v2Identifiers.Length)
    }
    elseif ($null -ne $v1PreRelease) {
        # Version1 has pre-release, Version2 doesn't (pre-release < release)
        return -1
    }
    elseif ($null -ne $v2PreRelease) {
        # Version2 has pre-release, Version1 doesn't (release > pre-release)
        return 1
    }

    # Versions are equal
    return 0
}