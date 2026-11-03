# Read-only discovery; accept only directories containing the actual game EXE.
function Find-PBZSteamGameRoot {
    param([string[]]$SteamRoots)
    $libraries=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $games=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    if (!$PSBoundParameters.ContainsKey('SteamRoots')) {
        $SteamRoots=@()
        foreach($key in @('HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam')) {
            $entry=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
            foreach($name in @('SteamPath','InstallPath')) {if($entry -and $entry.$name){$SteamRoots+=[string]$entry.$name}}
        }
        foreach($base in @(${env:ProgramFiles(x86)},$env:ProgramFiles)) {if($base){$SteamRoots+=Join-Path $base 'Steam'}}
    }
    foreach($root in $SteamRoots) {
        if (!$root) {continue}
        try {$full=[IO.Path]::GetFullPath($root).TrimEnd('\')} catch {continue}
        if (!(Test-Path -LiteralPath $full -PathType Container)) {continue}
        [void]$libraries.Add($full)
        foreach($relative in @('steamapps\libraryfolders.vdf','config\libraryfolders.vdf')) {
            $vdf=Join-Path $full $relative
            if (!(Test-Path -LiteralPath $vdf -PathType Leaf)) {continue}
            try {
                foreach($match in [regex]::Matches([IO.File]::ReadAllText($vdf),'(?m)^\s*"(?:path|\d+)"\s+"((?:\\.|[^"\\])*)"\s*$')) {
                    $path=$match.Groups[1].Value.Replace('\\','\').Replace('\"','"')
                    try {$path=[IO.Path]::GetFullPath($path).TrimEnd('\')} catch {continue}
                    if (Test-Path -LiteralPath $path -PathType Container) {[void]$libraries.Add($path)}
                }
            } catch {Write-Verbose ('Cannot read Steam library list: '+$vdf)}
        }
    }
    foreach($library in $libraries) {
        $apps=Join-Path $library 'steamapps'
        $common=Join-Path $apps 'common'
        $folders=@('PBZ')
        foreach($manifest in @(Get-ChildItem -LiteralPath $apps -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)) {
            try {
                $match=[regex]::Match([IO.File]::ReadAllText($manifest.FullName),'"installdir"\s+"((?:\\.|[^"\\])*)"')
                if($match.Success){$folders+=$match.Groups[1].Value.Replace('\\','\').Replace('\"','"')}
            } catch {Write-Verbose ('Cannot read Steam manifest: '+$manifest.FullName)}
        }
        foreach($folder in $folders) {
            if ([IO.Path]::IsPathRooted($folder)) {continue}
            try {$candidate=[IO.Path]::GetFullPath((Join-Path $common $folder))} catch {continue}
            if (!$candidate.StartsWith($common.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) {continue}
            if (Test-Path -LiteralPath (Join-Path $candidate 'platform\steam\PBZ.exe') -PathType Leaf) {[void]$games.Add($candidate)}
        }
    }
    $games | Sort-Object
}
