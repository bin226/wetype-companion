import argparse
import json
import statistics
from pathlib import Path

import cv2
import numpy as np

from ocr_worker import create_recognizer, recognize

parser = argparse.ArgumentParser()
parser.add_argument('--images', default='test-fixtures/live-v1')
parser.add_argument('--repeats', type=int, default=5)
args = parser.parse_args()
recognizer = create_recognizer()
rows = []
for path in sorted(Path(args.images).glob('*-normalized.png')):
    expected = path.stem.removesuffix('-normalized')
    image = cv2.imdecode(np.fromfile(path, dtype=np.uint8), cv2.IMREAD_COLOR)
    recognize(recognizer, image)
    outputs = [recognize(recognizer, image) for _ in range(args.repeats)]
    row = outputs[-1].copy()
    row.update(Expected=expected, Correct=row['Word'] == expected,
               MedianMilliseconds=statistics.median(o['Milliseconds'] for o in outputs),
               Outputs=[o['Word'] for o in outputs])
    rows.append(row)
Path('test-results/rapid-baseline.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(rows, ensure_ascii=False, indent=2))
