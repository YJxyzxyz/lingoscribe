# LingoScribe native offline API

This contains the unmodified native offline Dart API files from sherpa_onnx 1.13.8, with original copyright headers and Apache-2.0 license. `UPSTREAM.json` records the verified source archive and included files.

The loader is local. The package has no dependency on upstream platform binaries. Android/iOS use the pinned sherpa-onnx source build linked into `offline_engine`, with TTS, espeak/piper, diarization, GPU, web sockets and examples disabled. Other development hosts require an explicit comparison-library directory and are not distribution targets.
