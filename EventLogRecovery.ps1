# EventLogRecovery.ps1
# Script to recover deleted Windows Event Log files
# Provides both optimized (memory-mapped) and traditional recovery methods

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseTraditional,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseParallel,
    
    [Parameter(Mandatory=$false)]
    [int]$BufferSize = 64MB
)

# EVTX Header signature
$script:EVTX_SIGNATURE = [byte[]]@(0x45, 0x6C, 0x66, 0x46, 0x69, 0x6C, 0x65, 0x00)

# Verify administrative privileges
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "This script must be run as Administrator."
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Function to validate EVTX header
function Test-EventLogHeader {
    param([byte[]]$Buffer)
    
    # Check magic number
    for($i = 0; $i -lt $EVTX_SIGNATURE.Length; $i++) {
        if($Buffer[$i] -ne $EVTX_SIGNATURE[$i]) {
            return $false
        }
    }
    
    # Check chunk size
    $chunkSize = [BitConverter]::ToInt32($Buffer[40..43], 0)
    if($chunkSize -ne 65536) {
        return $false
    }
    
    return $true
}

# Traditional recovery method
function Find-EventLogSignaturesTraditional {
    param(
        [string]$DrivePath,
        [int]$BufferSize
    )
    
    Write-Host "Using traditional scanning method..."
    $offsets = [System.Collections.ArrayList]::new()
    
    try {
        $stream = [System.IO.File]::OpenRead($DrivePath)
        $buffer = New-Object byte[] $BufferSize
        $position = 0
        
        while($true) {
            $read = $stream.Read($buffer, 0, $buffer.Length)
            if($read -eq 0) { break }
            
            for($i = 0; $i -lt ($read - $EVTX_SIGNATURE.Length); $i++) {
                $found = $true
                for($j = 0; $j -lt $EVTX_SIGNATURE.Length; $j++) {
                    if($buffer[$i + $j] -ne $EVTX_SIGNATURE[$j]) {
                        $found = $false
                        break
                    }
                }
                if($found) {
                    $offsets.Add($position + $i) | Out-Null
                }
            }
            
            $position += $read
            Write-Progress -Activity "Scanning for event logs" `
                         -Status "Processed: $([math]::Round($position/1GB, 2)) GB" `
                         -PercentComplete (($position/$stream.Length) * 100)
        }
    }
    finally {
        if($stream) { $stream.Dispose() }
    }
    
    return $offsets
}

# Optimized recovery using memory mapping
function Find-EventLogSignaturesOptimized {
    param(
        [System.IO.MemoryMappedFiles.MemoryMappedFile]$MappedFile,
        [long]$FileSize,
        [int]$ChunkSize = 64MB,
        [switch]$UseParallel
    )
    
    Write-Host "Using optimized memory-mapped method..."
    $offsets = [System.Collections.ArrayList]::new()
    $numChunks = [math]::Ceiling($FileSize / $ChunkSize)
    
    if($UseParallel) {
        Write-Host "Parallel processing enabled..."
        $jobs = for($i = 0; $i -lt $numChunks; $i++) {
            $startPosition = $i * $ChunkSize
            $currentChunkSize = [math]::Min($ChunkSize, $FileSize - $startPosition)
            
            Start-Job -ScriptBlock {
                param($mappedFile, $start, $size, $signature)
                
                $accessor = $mappedFile.CreateViewAccessor($start, $size)
                $buffer = New-Object byte[] $size
                $accessor.ReadArray(0, $buffer, 0, $size)
                
                $matches = @()
                for($j = 0; $j -lt ($size - $signature.Length); $j++) {
                    $found = $true
                    for($k = 0; $k -lt $signature.Length; $k++) {
                        if($buffer[$j + $k] -ne $signature[$k]) {
                            $found = $false
                            break
                        }
                    }
                    if($found) {
                        $matches += ($start + $j)
                    }
                }
                return $matches
                
            } -ArgumentList $MappedFile, $startPosition, $currentChunkSize, $EVTX_SIGNATURE
        }
        
        $results = $jobs | Wait-Job | Receive-Job
        $jobs | Remove-Job
        return $results
    }
    else {
        Write-Host "Sequential processing..."
        for($i = 0; $i -lt $numChunks; $i++) {
            $startPosition = $i * $ChunkSize
            $currentChunkSize = [math]::Min($ChunkSize, $FileSize - $startPosition)
            
            $accessor = $MappedFile.CreateViewAccessor($startPosition, $currentChunkSize)
            $buffer = New-Object byte[] $currentChunkSize
            $accessor.ReadArray(0, $buffer, 0, $currentChunkSize)
            
            for($j = 0; $j -lt ($currentChunkSize - $EVTX_SIGNATURE.Length); $j++) {
                $found = $true
                for($k = 0; $k -lt $EVTX_SIGNATURE.Length; $k++) {
                    if($buffer[$j + $k] -ne $EVTX_SIGNATURE[$k]) {
                        $found = $false
                        break
                    }
                }
                if($found) {
                    $offsets.Add($startPosition + $j) | Out-Null
                }
            }
            
            Write-Progress -Activity "Scanning for event logs" `
                         -Status "Processed: $([math]::Round($startPosition/1GB, 2)) GB" `
                         -PercentComplete (($i/$numChunks) * 100)
        }
        return $offsets
    }
}

# Extract event log
function Extract-EventLog {
    param(
        [string]$DrivePath,
        [long]$Offset,
        [string]$OutputPath
    )
    
    $extractPath = Join-Path $OutputPath "recovered_eventlog_$Offset.evtx"
    $chunkSize = 64KB
    
    try {
        $stream = [System.IO.File]::OpenRead($DrivePath)
        $stream.Position = $Offset
        $buffer = New-Object byte[] $chunkSize
        $read = $stream.Read($buffer, 0, $buffer.Length)
        
        if(Test-EventLogHeader $buffer) {
            [System.IO.File]::WriteAllBytes($extractPath, $buffer)
            Write-Host "Extracted event log to: $extractPath"
            return $true
        }
        
        return $false
    }
    catch {
        Write-Error "Failed to extract event log at offset $Offset: $_"
        return $false
    }
    finally {
        if($stream) { $stream.Dispose() }
    }
}

# Main execution
try {
    $drivePath = "\\.\$DriveLetter"
    $driveInfo = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='$DriveLetter'"
    
    if(-not $driveInfo) {
        throw "Drive $DriveLetter not found."
    }
    
    Write-Host "Starting event log recovery on drive $DriveLetter..."
    Write-Host "Drive Size: $([math]::Round($driveInfo.Size/1GB, 2)) GB"
    
    if($UseTraditional) {
        $offsets = Find-EventLogSignaturesTraditional -DrivePath $drivePath -BufferSize $BufferSize
    }
    else {
        $mappedFile = [System.IO.MemoryMappedFiles.MemoryMappedFile]::CreateFromFile(
            $drivePath,
            [System.IO.FileMode]::Open,
            $null,
            0,
            [System.IO.MemoryMappedFiles.MemoryMappedFileAccess]::Read
        )
        
        try {
            $offsets = Find-EventLogSignaturesOptimized -MappedFile $mappedFile `
                                                       -FileSize $driveInfo.Size `
                                                       -ChunkSize $BufferSize `
                                                       -UseParallel:$UseParallel
        }
        finally {
            if($mappedFile) { $mappedFile.Dispose() }
        }
    }
    
    Write-Host "`nFound $($offsets.Count) potential event logs."
    foreach($offset in $offsets) {
        Extract-EventLog -DrivePath $drivePath -Offset $offset -OutputPath $OutputPath
    }
    
    Write-Host "`nRecovery complete. Check $OutputPath for recovered logs."
}
catch {
    Write-Error "Recovery failed: $_"
    exit 1
}
