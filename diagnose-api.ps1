$ErrorActionPreference = 'Stop'
go mod vendor
if ($LASTEXITCODE -ne 0) { throw 'go mod vendor fehlgeschlagen.' }
$path = 'vendor\github.com\onyx-and-iris\voicemeeter\v2\base.go'
if (-not (Test-Path $path)) { throw "Datei nicht gefunden: $path" }
$content = [System.IO.File]::ReadAllText((Resolve-Path $path))
$old = @'
	if int32(res) != 0 {
		err := fmt.Errorf("VBVMR_GetParameterFloat returned %d", int32(res))
		return 0, err
	}
	return math.Round(float64(value)*10) / 10, nil
'@
$new = @'
	if strings.HasPrefix(name, "bus[") && strings.HasSuffix(name, ".Gain") && (int32(res) != 0 || value == -60) {
		log.Infof("[GAIN-API-DIAG] %s result=%d raw=%.1f", name, int32(res), value)
	}
	if int32(res) != 0 {
		err := fmt.Errorf("VBVMR_GetParameterFloat returned %d", int32(res))
		return 0, err
	}
	return math.Round(float64(value)*10) / 10, nil
'@
if (-not $content.Contains($old)) { throw 'Patch-Anker nicht gefunden. Es wurde nichts geändert.' }
$content = $content.Replace($old, $new)
[System.IO.File]::WriteAllText((Resolve-Path $path), $content, [System.Text.UTF8Encoding]::new($false))
Write-Host 'API-Diagnosepatch angewendet. Protokolliert werden Bus-Gain-Lesevorgänge mit Fehlercode oder Rohwert -60.'
