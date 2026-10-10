"""Generate local codec fixtures from licensed real speech, never product assets."""
import subprocess
from pathlib import Path

ENCODINGS = [('stereo48.wav', 'pcm_s16le', '48000'), ('stereo44.wav', 'pcm_s16le', '44100'),
             ('sample.mp3', 'libmp3lame', '48000'), ('sample.m4a', 'aac', '48000'),
             ('sample.flac', 'flac', '48000'), ('sample.ogg', 'libopus', '48000')]

def create_fixtures(audio, folder, ffmpeg):
    folder = Path(folder)
    folder.mkdir(parents=True, exist_ok=True)
    outputs = []
    for name, codec, rate in ENCODINGS:
        output = folder / name
        subprocess.run([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y', '-i', str(audio),
                        '-ac', '2', '-ar', rate, '-c:a', codec, str(output)], check=True)
        outputs.append(output)
    return outputs
