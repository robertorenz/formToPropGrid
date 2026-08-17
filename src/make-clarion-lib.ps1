# =====================================================================
# make-clarion-lib.ps1 - generate a Clarion (TopSpeed OMF) import
# library straight from propgrid.def, so no version of LibMaker is
# ever needed.  The output format is byte-identical to what Clarion's
# LibMaker produces: one COMENT/IMPDEF record per export, imported by
# ordinal (ordinals are pinned in propgrid.def and never change).
#
#   record: 88 <len:word LE> 00 A0 01 01 <cnt>Name <cnt>DllName <ord:word LE>
#
# Works for every Clarion version (9 through 12) - the OMF import
# format predates them all and has never changed.
# =====================================================================
param(
    [string]$DefFile = "$PSScriptRoot\propgrid.def",
    [string]$DllName = "propgrid.dll",
    [string]$OutFile = "$PSScriptRoot\..\clarion\propgrid.lib"
)

$exports = @()
foreach ($line in Get-Content $DefFile) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s+@(\d+)\s*$') {
        $exports += [pscustomobject]@{ Name = $Matches[1]; Ordinal = [int]$Matches[2] }
    }
}
if ($exports.Count -eq 0) { throw "no exports with ordinals found in $DefFile" }

$ms  = New-Object System.IO.MemoryStream
$enc = [System.Text.Encoding]::ASCII
foreach ($e in $exports) {
    $name = $enc.GetBytes($e.Name)
    $dll  = $enc.GetBytes($DllName)
    # payload = attrib(00) A0 01 flag(01=by ordinal) cntName name cntDll dll ordLo ordHi
    $len  = 4 + 1 + $name.Length + 1 + $dll.Length + 2
    $ms.WriteByte(0x88)                              # COMENT record type
    $ms.WriteByte($len -band 0xFF)
    $ms.WriteByte(($len -shr 8) -band 0xFF)
    $ms.WriteByte(0x00)                              # comment attrib
    $ms.WriteByte(0xA0)                              # class: OMF extension
    $ms.WriteByte(0x01)                              # subtype: IMPDEF
    $ms.WriteByte(0x01)                              # import by ordinal
    $ms.WriteByte($name.Length); $ms.Write($name, 0, $name.Length)
    $ms.WriteByte($dll.Length);  $ms.Write($dll, 0, $dll.Length)
    $ms.WriteByte($e.Ordinal -band 0xFF)
    $ms.WriteByte(($e.Ordinal -shr 8) -band 0xFF)
}
$dir = Split-Path -Parent $OutFile
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
[System.IO.File]::WriteAllBytes((Join-Path (Resolve-Path $dir) (Split-Path -Leaf $OutFile)), $ms.ToArray())
Write-Host "Wrote $($exports.Count) imports -> $OutFile ($($ms.Length) bytes)"
