# Vendored whisper.cpp

Upstream: https://github.com/ggml-org/whisper.cpp
Tag: v1.9.4
Commit: 7d75b14994ae7f59623e2471445e2355fe506ed2
Source archive: https://api.github.com/repos/ggml-org/whisper.cpp/tarball/v1.9.4
Downloaded archive SHA-256: 261de3e2edeb7b3fa8bd3b35d000848fb023933ca220bf4d15937e31f8992ec8

Vendored unchanged: root CMakeLists.txt, LICENSE, README.md, cmake/, include/, src/, ggml/.
Examples, model binaries, test media, bindings and documentation are excluded.
License: MIT; included in whisper.cpp/LICENSE. Individual ggml files may carry additional notices, retained verbatim.

Vendoring avoids network-dependent source fetches during mobile builds. Updating requires refreshing these files together, pinning the commit here, reviewing license changes and rerunning native and device tests. This directory is a source snapshot, not a Git submodule.
