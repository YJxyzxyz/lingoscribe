# Run with Windows PowerShell 5.1. Uses installed Windows voices only for local tests.
param([string]$OutputDirectory = 'O:\devtools\qa-audio')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$qaSynth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$qaFormat = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(16000, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
try {
    $qaVoices = $qaSynth.GetInstalledVoices()
    $qaChinese = ($qaVoices | Where-Object { $_.VoiceInfo.Culture.Name -eq 'zh-CN' } | Select-Object -First 1).VoiceInfo.Name
    $qaEnglish = ($qaVoices | Where-Object { $_.VoiceInfo.Culture.Name -eq 'en-US' } | Select-Object -First 1).VoiceInfo.Name
    if (-not $qaChinese -or -not $qaEnglish) { throw 'Install Chinese and English Windows voices before this optional synthetic test.' }
    $qaSynth.SetOutputToWaveFile((Join-Path $OutputDirectory 'synthetic-zh.wav'), $qaFormat)
    $qaSynth.SelectVoice($qaChinese)
    $qaSynth.Speak('今天我们讨论离线语音转写。这个应用支持中文和英文，录音不会上传。请检查时间戳，然后保存校对结果。')
    $qaSynth.SetOutputToNull()
    $qaSynth.SetOutputToWaveFile((Join-Path $OutputDirectory 'synthetic-mixed.wav'), $qaFormat)
    $qaSynth.SelectVoice($qaChinese); $qaSynth.Speak('今天我们讨论产品发布。')
    $qaSynth.SelectVoice($qaEnglish); $qaSynth.Speak('Please review the Android release and export the transcript.')
    $qaSynth.SelectVoice($qaChinese); $qaSynth.Speak('请检查离线转写，然后保存结果。')
    $qaSynth.SetOutputToNull()
    Write-Output 'Generated local synthetic Chinese and mixed-language smoke-test audio. This is not a real-world accuracy benchmark.'
} finally { $qaSynth.Dispose() }
