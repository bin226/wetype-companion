"""Persistent local recognizer. One JSON request/response per line; no image uploads."""
import argparse
import base64
import contextlib
import json
import re
import sys
import time
import unicodedata
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parent


def create_recognizer(model_type="mobile", allow_download=False):
    import rapidocr
    from rapidocr.ch_ppocr_rec import TextRecognizer
    from rapidocr.utils.parse_parameters import ParseParams
    from rapidocr.utils.typings import ModelType, OCRVersion

    cfg = ParseParams.load(Path(rapidocr.__file__).parent / "config.yaml")
    cfg = ParseParams.update_batch(cfg, {
        "Rec.ocr_version": OCRVersion.PPOCRV5,
        "Rec.model_type": ModelType.MOBILE if model_type == "mobile" else ModelType.SERVER,
        "Global.model_root_dir": str(ROOT / "models"),
        "EngineConfig.onnxruntime.intra_op_num_threads": 2,
        "EngineConfig.onnxruntime.inter_op_num_threads": 1,
    })
    cfg.Rec.engine_cfg = cfg.EngineConfig[cfg.Rec.engine_type.value]
    cfg.Rec.model_root_dir = str(ROOT / "models")
    cfg.Rec.font_path = None
    if not allow_download:
        model = ROOT / "models" / f"ch_PP-OCRv5_rec_{model_type}.onnx"
        if not model.is_file():
            raise FileNotFoundError("Local model missing. Run Setup-Ocr.ps1 first.")
        cfg.Rec.model_path = str(model)
    return TextRecognizer(cfg.Rec)


def prepare_line(image):
    # Native.Normalize supplies light glyphs on a dark background. Tighten the
    # glyph bounds, invert to dark text on white, and retain anti-aliasing.
    channel = image[:, :, 2]
    ys, xs = np.where(channel > 130)
    if len(xs):
        channel = channel[ys.min():ys.max()+1, xs.min():xs.max()+1]
    white = 255 - channel
    white = cv2.copyMakeBorder(white, 4, 4, 4, 4, cv2.BORDER_CONSTANT, value=255)
    return cv2.cvtColor(white, cv2.COLOR_GRAY2BGR)


def normalize_word(raw):
    word = re.sub(r"\s+", "", unicodedata.normalize("NFKC", raw))
    word = re.sub(r"^\d+[.、]?", "", word)
    return word if re.fullmatch(r"[\u3400-\u4dbf\u4e00-\u9fff]{1,30}", word) else ""


def recognize(recognizer, image, preprocess=True):
    from rapidocr.ch_ppocr_rec import TextRecInput
    started = time.perf_counter()
    line = prepare_line(image) if preprocess else image
    result = recognizer(TextRecInput(img=line))
    raw = result.txts[0] if result.txts else ""
    score = float(result.scores[0]) if result.scores else 0.0
    return {"Raw": raw, "Word": normalize_word(raw), "Confidence": score,
            "Milliseconds": (time.perf_counter()-started)*1000, "Engine": "PP-OCRv5-"+recognizer.cfg.model_type.value}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-type", choices=("mobile", "server"), default="mobile")
    parser.add_argument("--image")
    args = parser.parse_args()
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8", line_buffering=True)
    with contextlib.redirect_stdout(sys.stderr):
        recognizer = create_recognizer(args.model_type)
        recognize(recognizer, np.full((48, 120, 3), 20, dtype=np.uint8))
    if args.image:
        data = np.fromfile(args.image, dtype=np.uint8)
        with contextlib.redirect_stdout(sys.stderr):
            result = recognize(recognizer, cv2.imdecode(data, cv2.IMREAD_COLOR))
        print(json.dumps(result, ensure_ascii=False))
        return
    print(json.dumps({"Ready": True, "Engine": "PP-OCRv5-"+args.model_type}))
    for line in sys.stdin:
        request = None
        try:
            request = json.loads(line)
            data = np.frombuffer(base64.b64decode(request["Png"]), dtype=np.uint8)
            image = cv2.imdecode(data, cv2.IMREAD_COLOR)
            if image is None:
                raise ValueError("Invalid PNG")
            with contextlib.redirect_stdout(sys.stderr):
                result = recognize(recognizer, image)
            result["Id"] = request["Id"]
            print(json.dumps(result, ensure_ascii=False))
        except Exception as exc:
            print(json.dumps({"Id": request.get("Id") if request else None, "Error": str(exc)}))


if __name__ == "__main__":
    main()
