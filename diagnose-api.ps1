$ErrorActionPreference = 'Stop'
go mod vendor
if ($LASTEXITCODE -ne 0) { throw 'go mod vendor fehlgeschlagen.' }

$path = 'vendor\github.com\onyx-and-iris\voicemeeter\v2\base.go'
if (-not (Test-Path $path)) { throw "Datei nicht gefunden: $path" }

$content = [System.IO.File]::ReadAllText((Resolve-Path $path))

# Match the API result handling independent of tabs/spaces and Windows/Unix line endings.
$pattern = '(?m)^[\t ]*if int32\(res\) != 0 \{\r?\n[\t ]*err := fmt\.Errorf\("VBVMR_GetParameterFloat returned %d", int32\(res\)\)\r?\n[\t ]*return 0, err\r?\n[\t ]*\}\r?\n[\t ]*return math\.Round\(float64\(value\)\*10\) / 10, nil'
$matches = [regex]::Matches($content, $pattern)
if ($matches.Count -ne 1) {
    throw "Patch-Anker muss genau einmal vorkommen; gefunden: $($matches.Count). Datei wurde nicht geändert."
}

$replacement = @'
	if len(name) >= 9 && name[:4] == "Bus[" && name[len(name)-5:] == ".Gain" && (int32(res) != 0 || value == -60) {
		fmt.Printf("[GAIN-API-DIAG] %s result=%d raw=%.1f\n", name, int32(res), value)
	}
	if int32(res) != 0 {
		err := fmt.Errorf("VBVMR_GetParameterFloat returned %d", int32(res))
		return 0, err
	}
	return math.Round(float64(value)*10) / 10, nil
'@

$regex = [System.Text.RegularExpressions.Regex]::new($pattern)
$content = $regex.Replace($content, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
[System.IO.File]::WriteAllText((Resolve-Path $path), $content, [System.Text.UTF8Encoding]::new($false))
Write-Host 'API-Diagnosepatch angewendet.'
