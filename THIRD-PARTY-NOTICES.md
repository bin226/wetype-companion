# Third-party components

The project's GPL-3.0-or-later license does not replace the licenses of the following components. The portable package retains Python's LICENSE.txt and installed packages' metadata, license files and notices under runtime/Lib/site-packages. Do not strip these files when repackaging.

| Component | Source and attribution | License / records |
| --- | --- | --- |
| Qingjian English glossary | Upstream glossary documentation retained in glossary-source.md; imported revision in qingjian-revision.txt | GPL-3.0-or-later; LICENSE and glossary-source.md |
| CC-CEDICT | CC-CEDICT contributors; CEDICT originally started by Paul Denisowski; https://www.mdbg.net/chinese/dictionary?page=cc-cedict | CC-BY-SA-4.0; data/README.md, original data headers and data/cedict-source.json |
| RapidOCR 3.9.2 | RapidOCR Authors / RapidAI; https://github.com/RapidAI/RapidOCR/tree/v3.9.2 | Apache-2.0; licenses/RapidOCR-LICENSE.txt |
| PP-OCRv5 recognition model | PaddleOCR contributors; converted ONNX model distributed by RapidAI | Upstream PaddleOCR license retained in licenses/PaddleOCR-LICENSE.txt; exact model URL and SHA-256 in ocr-model-source.json |
| ONNX Runtime | Microsoft and contributors; https://github.com/microsoft/onnxruntime | MIT; retained runtime package license and ThirdPartyNotices |
| Python 3.12 | Python Software Foundation and contributors; https://www.python.org/ | Retained runtime/LICENSE.txt |
| Other Python dependencies | Names and resolved versions in requirements-lock.txt | Each distribution retains its own metadata and license notices in runtime/Lib/site-packages |

RapidOCR license was copied from https://raw.githubusercontent.com/RapidAI/RapidOCR/v3.9.2/LICENSE and PaddleOCR license from https://raw.githubusercontent.com/PaddlePaddle/PaddleOCR/main/LICENSE on 2026-10-04. Model provenance is recorded separately; the model is not modified by this project.

The portable package includes this project's C# sources, OCR worker and build script. A public release should also link to the corresponding complete source revision, including tests and setup instructions.
