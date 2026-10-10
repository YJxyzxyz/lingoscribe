"""Evaluate real native output against authorized reference audio/text; no mocks."""
import argparse
import ctypes
import hashlib
import json
import os
import platform
import re
import time
import unicodedata
from pathlib import Path

def digest(path):
    with Path(path).open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

def distance(left, right):
    previous = list(range(len(right) + 1))
    for i, a in enumerate(left, 1):
        current = [i]
        for j, b in enumerate(right, 1):
            current.append(min(current[-1] + 1, previous[j] + 1, previous[j - 1] + (a != b)))
        previous = current
    return previous[-1]

def tokens(text):
    text = unicodedata.normalize('NFKC', text).casefold().replace('’', "'")
    chinese = [char for char in text if 'CJK UNIFIED IDEOGRAPH' in unicodedata.name(char, '')]
    english = re.findall(r"[a-z]+(?:'[a-z]+)*", text)
    numbers = re.findall(r'\d+(?:[.,]\d+)*', text)
    return chinese, english, numbers

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', required=True)
    parser.add_argument('--model', action='append', required=True)
    parser.add_argument('--vad')
    parser.add_argument('--manifest', required=True)
    parser.add_argument('--audio-root', required=True)
    parser.add_argument('--report', default='build/transcription-evaluation.json')
    parser.add_argument('--include-text', action='store_true', help='Opt in to local reference/hypothesis text in reports')
    args = parser.parse_args()
    corpus = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
    assert corpus['clips'], 'Reference clips are required'
    for clip in corpus['clips']:
        assert clip['kind'] in ('synthetic', 'licensed_human', 'private_consented_human')
        assert clip.get('source'), 'Document the audio source'
        if clip['kind'] == 'licensed_human':
            assert clip.get('license'), 'Document the audio license'
        if clip['kind'] == 'private_consented_human':
            assert clip.get('consent') is True, 'Human audio must have recorded authorization'
    if os.name == 'nt' and Path('C:/mingw64/bin').exists():
        os.add_dll_directory('C:/mingw64/bin')
    library = ctypes.CDLL(str(Path(args.library).resolve()))
    create = library.ls_job_create_v2
    create.argtypes = [ctypes.c_char_p] * 5 + [ctypes.c_int32]
    create.restype = ctypes.c_void_p
    library.ls_job_run.argtypes = [ctypes.c_void_p]
    library.ls_job_run.restype = ctypes.c_int32
    library.ls_job_result.argtypes = [ctypes.c_void_p]
    library.ls_job_result.restype = ctypes.c_char_p
    library.ls_job_free.argtypes = [ctypes.c_void_p]
    library.ls_job_free.restype = None
    library.ls_version.restype = ctypes.c_char_p
    results = []
    for model in args.model:
        model_results = []
        for clip in corpus['clips']:
            audio = Path(args.audio_root) / clip['file']
            audio_hash = digest(audio)
            if clip.get('sha256'):
                assert clip['sha256'] == audio_hash
            job = create(os.fsencode(model), os.fsencode(audio), clip.get('language', 'auto').encode(),
                         clip.get('prompt', '').encode(), os.fsencode(args.vad or ''), min(os.cpu_count() or 1, 4))
            assert job, 'Native allocation failed'
            started = time.perf_counter()
            try:
                assert library.ls_job_run(job) == 0, library.ls_job_result(job)
                output = json.loads(library.ls_job_result(job))
            finally:
                library.ls_job_free(job)
            elapsed = time.perf_counter() - started
            hypothesis = ' '.join(segment['text'] for segment in output['segments'])
            reference_cn, reference_en, reference_numbers = tokens(clip['text'])
            hypothesis_cn, hypothesis_en, hypothesis_numbers = tokens(hypothesis)
            cn_errors, en_errors = distance(reference_cn, hypothesis_cn), distance(reference_en, hypothesis_en)
            row = {'id': clip['id'], 'kind': clip['kind'], 'source': clip['source'], 'audioSha256': audio_hash,
                   'license': clip.get('license'), 'datasetLanguage': clip.get('datasetLanguage'),
                   'speakerId': clip.get('speakerId'),
                   'durationMs': output['durationMs'], 'elapsedSeconds': round(elapsed, 3),
                   'rtf': round(elapsed / (output['durationMs'] / 1000), 3),
                   'chineseReferenceChars': len(reference_cn), 'chineseEditDistance': cn_errors,
                   'chineseCER': cn_errors / len(reference_cn) if reference_cn else None,
                   'englishReferenceWords': len(reference_en), 'englishEditDistance': en_errors,
                   'englishWER': en_errors / len(reference_en) if reference_en else None,
                   'numericTokensMatch': reference_numbers == hypothesis_numbers}
            if args.include_text:
                row.update(reference=clip['text'], hypothesis=hypothesis)
            model_results.append(row)
        aggregates = {}
        for group in sorted({row.get('datasetLanguage') or 'all' for row in model_results}):
            group_rows = [row for row in model_results if (row.get('datasetLanguage') or 'all') == group]
            cn_count = sum(row['chineseReferenceChars'] for row in group_rows)
            en_count = sum(row['englishReferenceWords'] for row in group_rows)
            cn_errors = sum(row['chineseEditDistance'] for row in group_rows)
            en_errors = sum(row['englishEditDistance'] for row in group_rows)
            duration = sum(row['durationMs'] for row in group_rows) / 1000
            aggregates[group] = {'clips': len(group_rows), 'durationSeconds': round(duration, 3),
                                 'chineseReferenceChars': cn_count, 'chineseEditDistance': cn_errors,
                                 'chineseCER': cn_errors / cn_count if cn_count else None,
                                 'englishReferenceWords': en_count, 'englishEditDistance': en_errors,
                                 'englishWER': en_errors / en_count if en_count else None,
                                 'rtf': round(sum(row['elapsedSeconds'] for row in group_rows) / duration, 3)}
        results.append({'model': Path(model).name, 'modelSha256': digest(model), 'aggregates': aggregates, 'clips': model_results})
    report = {'engine': library.ls_version().decode(), 'librarySha256': digest(args.library),
              'platform': platform.system(), 'architecture': platform.machine(),
              'vadSha256': digest(args.vad) if args.vad else None, 'results': results,
              'manifestSha256': digest(args.manifest),
              'corpusSelection': corpus.get('selection'),
              'corpusAttribution': corpus.get('attribution'),
              'normalization': 'NFKC, case-insensitive; Han characters for CER, Latin words for WER; punctuation ignored; numbers compared separately; no simplified/traditional conversion',
              'scope': 'Synthetic clips are regression tests, not human accuracy or phone-performance evidence; no memory or power measurement implied'}
    destination = Path(args.report)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Real transcription evaluation written to {destination}')

if __name__ == '__main__':
    main()
