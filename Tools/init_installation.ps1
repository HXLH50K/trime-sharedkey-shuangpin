[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Windows', 'Android')]
    [string]$Platform,
    [string]$RimeDir,
    [string]$SyncDir,
    [string]$DistributionVersion,
    [string]$RimeVersion
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$temporaryDirectory = $null

function Invoke-Adb {
    param([string[]]$Arguments)
    $output = & adb @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
    return ($output -join "`n").Trim()
}

function Get-AndroidDeviceName {
    $modelNames = foreach ($property in @('ro.product.model', 'ro.product.marketname', 'ro.product.vendor.marketname', 'ro.product.odm.marketname')) {
        $value = Invoke-Adb @('shell', 'getprop', $property)
        if ($value -and $value -ne 'null') { $value }
    }
    $sources = [ordered]@{
        'secure/bluetooth_name' = @('shell', 'settings', 'get', 'secure', 'bluetooth_name')
        'system/bluetooth_name' = @('shell', 'settings', 'get', 'system', 'bluetooth_name')
        'global/bluetooth_name' = @('shell', 'settings', 'get', 'global', 'bluetooth_name')
        'system/device_name' = @('shell', 'settings', 'get', 'system', 'device_name')
        'persist.sys.device_name' = @('shell', 'getprop', 'persist.sys.device_name')
    }
    foreach ($source in $sources.Keys) {
        $name = Invoke-Adb $sources[$source]
        if ($name -and $name -ne 'null' -and $modelNames -notcontains $name) {
            Write-Host "Device name source: $source"
            return $name
        }
    }
    throw 'Cannot read a custom Android device name distinct from the product/model name. Set the device/Bluetooth name before retrying.'
}

try {
    if ($Platform -eq 'Android') {
        $OutputEncoding = $utf8
        [Console]::OutputEncoding = $utf8
        if (-not $RimeDir) { $RimeDir = '/sdcard/rime' }
        if ($RimeDir -notmatch '^/[a-zA-Z0-9_./-]+$') {
            throw 'Unsupported Android Rime directory.'
        }
        $deviceName = Get-AndroidDeviceName
        $destination = $RimeDir.TrimEnd('/') + '/installation.yaml'
        $temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
        [IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
        $localFile = Join-Path $temporaryDirectory 'installation.yaml'
        $pathKind = Invoke-Adb @('shell', "if [ -f '$destination' ]; then echo FILE; elif [ -e '$destination' ]; then echo OTHER; else echo MISSING; fi")
        if ($pathKind -eq 'FILE') {
            Invoke-Adb @('pull', $destination, $localFile) | Out-Null
        } elseif ($pathKind -ne 'MISSING') {
            throw "Cannot read installation file: $destination"
        }
    } else {
        if (-not $RimeDir) { $RimeDir = Join-Path $env:APPDATA 'Rime' }
        $deviceName = [Environment]::MachineName
        $destination = Join-Path $RimeDir 'installation.yaml'
        $localFile = $destination
    }

    if (-not $deviceName -or $deviceName -match '[\x00-\x1f\x7f<>:"/\\|?*]' -or $deviceName -match '[. ]$' -or $deviceName -in @('.', '..')) {
        throw 'Device name is empty or unsafe as a Rime sync directory name.'
    }
    $content = ''
    if (Test-Path -LiteralPath $localFile) {
        $content = [IO.File]::ReadAllText($localFile, $utf8)
    }
    if ($SyncDir) {
        if (($Platform -eq 'Android' -and -not $SyncDir.StartsWith('/')) -or
            ($Platform -eq 'Windows' -and $SyncDir -notmatch '^(?:[a-zA-Z]:[\\/]|\\\\[^\\]+\\[^\\]+)') -or
            $SyncDir -match '[\x00-\x1f\x7f]') {
            throw 'SyncDir must be an absolute path on the target platform.'
        }
    }
    $overwriteSyncDir = [bool]$SyncDir
    if ($Platform -eq 'Android') {
        if (-not $SyncDir) { $SyncDir = '/sdcard/com.hxlh/Rime' }
        if (-not $DistributionVersion) { $DistributionVersion = 'v3.3.8-0-gf3f5c923' }
        if (-not $RimeVersion) { $RimeVersion = '1.15.0' }
        $distributionCodeName = 'trime'
        $distributionName = 'Trime'
    } else {
        if (-not $SyncDir) { $SyncDir = Join-Path $env:APPDATA 'RimeSync' }
        if (-not $DistributionVersion) { $DistributionVersion = '0.17.4' }
        if (-not $RimeVersion) { $RimeVersion = '1.13.1' }
        $distributionCodeName = 'Weasel'
        $distributionName = -join ([char[]]@(0x5c0f, 0x72fc, 0x6beb))
    }
    $fields = [ordered]@{
        distribution_code_name = $distributionCodeName
        distribution_name = $distributionName
        distribution_version = $DistributionVersion
        install_time = (Get-Date).ToString('ddd MMM dd HH:mm:ss yyyy', [Globalization.CultureInfo]::InvariantCulture)
        rime_version = $RimeVersion
        name = $deviceName
        installation_id = $deviceName
        sync_dir = $SyncDir
    }
    $newline = "`n"
    if ($content.Contains("`r`n")) { $newline = "`r`n" }
    $updated = $content
    foreach ($key in $fields.Keys) {
        $keyPattern = '(?m)^(?:{0}|"{0}"|''{0}'')[ \t]*:[^\r\n]*' -f [regex]::Escape($key)
        $entries = [regex]::Matches($updated, $keyPattern)
        if ($entries.Count -gt 1) {
            throw "Multiple $key entries found; refusing to overwrite the file."
        }
        $entry = $key + ': ' + (ConvertTo-Json -InputObject $fields[$key] -Compress)
        if ($entries.Count -eq 1) {
            $existing = $entries[0]
            if ($existing.Value -match ':[ \t]*[>|]' -or $updated.Substring($existing.Index + $existing.Length) -match '^\r?\n[ \t]+[^#\s]') {
                throw "Multiline $key is not supported; refusing to overwrite the file."
            }
            $emptyValue = $existing.Value -match '(?i):[ \t]*(?:null|~|""|'''')?[ \t]*(?:#.*)?$'
            if ($key -notin @('name', 'installation_id') -and -not ($key -eq 'sync_dir' -and $overwriteSyncDir) -and -not $emptyValue) {
                continue
            }
            $updated = $updated.Substring(0, $existing.Index) + $entry + $updated.Substring($existing.Index + $existing.Length)
        } else {
            if ($updated -and -not $updated.EndsWith("`n")) { $updated += $newline }
            $updated += $entry + $newline
        }
    }

    Write-Host "Device name: $deviceName"
    if ($PSCmdlet.ShouldProcess($destination, "Initialize installation metadata for $deviceName")) {
        if ($Platform -eq 'Windows') {
            [IO.Directory]::CreateDirectory($RimeDir) | Out-Null
        }
        [IO.File]::WriteAllText($localFile, $updated, $utf8)
        if ($Platform -eq 'Android') {
            Invoke-Adb @('shell', 'mkdir', '-p', $RimeDir) | Out-Null
            Invoke-Adb @('push', $localFile, $destination) | Out-Null
        }
        Write-Host "Updated: $destination"
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    if ($temporaryDirectory -and (Test-Path -LiteralPath $temporaryDirectory)) {
        Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -WhatIf:$false
    }
}