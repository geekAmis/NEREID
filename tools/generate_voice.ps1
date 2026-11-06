<#
.SYNOPSIS
    NEREID — генерация голосовых реплик через Windows SAPI (Microsoft Irina, ru-RU).

.DESCRIPTION
    Читает game/data/radio.json и game/data/tapes.json, озвучивает каждую реплику
    в 22.05 kHz / 16-bit / mono WAV и кладёт в game/assets/voice/<id>.wav.

    Голос Веры — сухой, ровный, чуть медленнее обычного.
    Голос Гринберга (ленты) — медленнее и ниже (SSML prosody), с лёгкой усталостью.

    Скрипт идемпотентен: существующие файлы не перезаписываются без -Force.
    После генерации Godot нужно переимпортировать:
        godot --headless --path game --import

.PARAMETER Force
    Перезаписать уже существующие WAV.

.PARAMETER Id
    Сгенерировать только указанные id (через запятую).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools/generate_voice.ps1 -Force
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string[]]$Id = @()
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$root      = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root 'game'))) {
    $root = (Get-Location).Path
}
$radioPath = Join-Path $root 'game/data/radio.json'
$tapesPath = Join-Path $root 'game/data/tapes.json'
$outDir    = Join-Path $root 'game/assets/voice'

if (-not (Test-Path $radioPath)) { throw "Не найден $radioPath" }
if (-not (Test-Path $tapesPath)) { throw "Не найден $tapesPath" }
if (-not (Test-Path $outDir))    { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

Add-Type -AssemblyName System.Speech

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice = $synth.GetInstalledVoices() |
    Where-Object { $_.VoiceInfo.Culture.Name -eq 'ru-RU' -and $_.Enabled } |
    Select-Object -First 1
if (-not $voice) {
    throw 'Не найден русский голос SAPI (ожидался Microsoft Irina Desktop, ru-RU).'
}
$synth.SelectVoice($voice.VoiceInfo.Name)
Write-Host ("Голос: {0} ({1})" -f $voice.VoiceInfo.Name, $voice.VoiceInfo.Culture)

# 22.05 kHz, 16-bit PCM, mono — достаточно для рации и экономит место.
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
    22050,
    [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
    [System.Speech.AudioFormat.AudioChannel]::Mono
)

function ConvertTo-SsmlText([string]$text) {
    $escaped = $text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;')
    # Тире и многоточия SAPI читает плохо в некоторых движках — заменяем на паузы.
    $escaped = $escaped.Replace(' — ', '. ').Replace('—', ', ').Replace('...', '…')
    return $escaped
}

function New-Ssml([string]$text, [int]$rate, [int]$pitch) {
    $body = ConvertTo-SsmlText $text
    return @"
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="ru-RU">
  <prosody rate="$rate%" pitch="$pitch%">$body</prosody>
</speak>
"@
}

$radio = Get-Content -Raw -Encoding UTF8 $radioPath | ConvertFrom-Json
$tapes = Get-Content -Raw -Encoding UTF8 $tapesPath | ConvertFrom-Json

$jobs = New-Object System.Collections.Generic.List[object]
foreach ($line in $radio.lines) {
    $jobs.Add([pscustomobject]@{
        Id     = [string]$line.id
        Text   = [string]$line.text
        Rate   = -6
        Pitch  = -4
        Kind   = 'radio'
    })
}
foreach ($tape in $tapes.tapes) {
    $jobs.Add([pscustomobject]@{
        Id     = [string]$tape.id
        Text   = [string]$tape.text
        Rate   = -14
        Pitch  = -22
        Kind   = 'tape'
    })
}

if ($Id.Count -gt 0) {
    $wanted = @{}
    foreach ($w in $Id) { foreach ($p in $w.Split(',')) { $wanted[$p.Trim()] = $true } }
    $jobs = $jobs | Where-Object { $wanted.ContainsKey($_.Id) }
}

if ($jobs.Count -eq 0) {
    Write-Host 'Нет реплик для генерации.' -ForegroundColor Yellow
    exit 0
}

$made = 0
$skipped = 0
$failed = 0
$started = Get-Date

foreach ($job in $jobs) {
    $path = Join-Path $outDir ($job.Id + '.wav')
    if ((Test-Path $path) -and -not $Force) {
        $skipped++
        continue
    }
    try {
        $ssml = New-Ssml $job.Text $job.Rate $job.Pitch
        $synth.SetOutputToWaveFile($path, $format)
        $synth.SpeakSsml($ssml)
        $synth.SetOutputToNull()
        $size = (Get-Item $path).Length
        if ($size -lt 2000) { throw "файл слишком мал ($size байт)" }
        $made++
        Write-Host ("  + {0,-14} {1,7:N0} байт  {2}" -f $job.Id, $size, $job.Kind)
    }
    catch {
        $failed++
        Write-Warning ("  ! {0}: {1}" -f $job.Id, $_.Exception.Message)
        try { $synth.SetOutputToNull() } catch { }
    }
}

$synth.Dispose()
$elapsed = (Get-Date) - $started

Write-Host ''
Write-Host ("Готово: создано {0}, пропущено {1}, ошибок {2}. Время: {3:N1} с." -f $made, $skipped, $failed, $elapsed.TotalSeconds)
Write-Host ("Каталог: {0}" -f $outDir)
if ($made -gt 0) {
    Write-Host 'Дальше: godot --headless --path game --import'
}
if ($failed -gt 0) { exit 1 }
