"""Score the actual Dart/native output with the unchanged regression rules."""
import argparse
import json
from pathlib import Path
from evaluate_transcription import digest, distance, tokens

parser = argparse.ArgumentParser()
parser.add_argument('--outputs', required=True)
parser.add_argument('--manifest', required=True)
parser.add_argument('--report', required=True)
args = parser.parse_args()
actual = json.loads(Path(args.outputs).read_text(encoding='utf-8'))
corpus = json.loads(Path(args.manifest).read_text(encoding='utf-8'))
assert actual['manifestSha256'] == digest(args.manifest)
references = {clip['id']: clip for clip in corpus['clips']}
assert len(actual['outputs']) == len(references)
assert len(references) == len(corpus['clips']), 'Duplicate reference clip IDs'
assert {output['id'] for output in actual['outputs']} == set(references), 'Missing or duplicated output clip IDs'
rows = []
for output in actual['outputs']:
    clip = references[output['id']]
    assert clip['sha256'] == output['audioSha256']
    reference_cn, reference_en, reference_numbers = tokens(clip['text'])
    actual_cn, actual_en, actual_numbers = tokens(output['hypothesis'])
    rows.append({'id': clip['id'], 'language': clip['datasetLanguage'], 'speakerId': clip['speakerId'],
        'audioSha256': clip['sha256'], 'chineseReferenceChars': len(reference_cn),
        'chineseEditDistance': distance(reference_cn, actual_cn), 'englishReferenceWords': len(reference_en),
        'englishEditDistance': distance(reference_en, actual_en), 'numericTokensMatch': reference_numbers == actual_numbers,
        'speechIntervals': output['speechIntervals'], 'elapsedSeconds': output['elapsedSeconds'],
        **({'inputContextPolicy': output['inputContextPolicy'], 'pcmReadPolicy': output.get('pcmReadPolicy', 'floor_ms'), 'decodedWindows': output['decodedWindows']} if output.get('inputContextPolicy') else {})})
groups = {}
for language in sorted({row['language'] for row in rows}):
    selected = [row for row in rows if row['language'] == language]
    cn = sum(row['chineseReferenceChars'] for row in selected)
    en = sum(row['englishReferenceWords'] for row in selected)
    groups[language] = {'clips': len(selected),
        'chineseCER': sum(row['chineseEditDistance'] for row in selected) / cn if cn else None,
        'englishWER': sum(row['englishEditDistance'] for row in selected) / en if en else None,
        'chineseReferenceChars': cn, 'englishReferenceWords': en}
report = {'manifestSha256': actual['manifestSha256'], 'scope': actual['scope'],
    'normalization': 'Same NFKC/Han-CER/Latin-WER rules as evaluate_transcription.py; no script conversion',
    'corpusSelection': corpus['selection'], 'corpusAttribution': corpus['attribution'],
    'aggregates': groups, 'clips': rows}
Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(groups, indent=2))
