"""
OCR Service — converts image/PDF files to raw text using PaddleOCR (with Tesseract fallback).

The pipeline intentionally returns only raw text.
Structured extraction is handled by extraction_service.py.
"""
import logging
import subprocess
from pathlib import Path

logger = logging.getLogger(__name__)

# PaddleOCR singleton
_PADDLE_OCR = None
_PADDLE_INITIALIZED = False

try:
    import pytesseract
    from PIL import Image
    _TESSERACT_AVAILABLE = True
except ImportError:
    _TESSERACT_AVAILABLE = False


def _get_paddle_ocr():
    """Lazily load PaddleOCR engine singleton."""
    global _PADDLE_OCR, _PADDLE_INITIALIZED
    if not _PADDLE_INITIALIZED:
        try:
            from paddleocr import PaddleOCR
            _PADDLE_OCR = PaddleOCR(use_angle_cls=True, lang="en", show_log=False)
            logger.info("PaddleOCR successfully initialized")
        except Exception as e:
            logger.warning(f"PaddleOCR failed to initialize: {e}")
            _PADDLE_OCR = None
        _PADDLE_INITIALIZED = True
    return _PADDLE_OCR


def run_ocr(file_path: str) -> str:
    """
    Run OCR on an image file and return the raw extracted text.
    Uses PaddleOCR as primary high-accuracy engine, falling back to Tesseract.

    Args:
        file_path: Absolute or relative path to the image file.

    Returns:
        Raw OCR text string (newline-separated).

    Raises:
        FileNotFoundError: If the image file doesn't exist.
        RuntimeError: If both OCR engines fail or are unavailable.
    """
    path = Path(file_path).resolve()
    if not path.exists():
        alt_path = Path.cwd() / file_path
        if alt_path.exists():
            path = alt_path
        else:
            raise FileNotFoundError(f"File not found: {file_path}")

    # For PDFs, convert first page to image using system tools if available
    if path.suffix.lower() == ".pdf":
        return _ocr_pdf(path)

    # 1. Primary: PaddleOCR
    paddle_engine = _get_paddle_ocr()
    if paddle_engine is not None:
        try:
            results = paddle_engine.ocr(str(path), cls=True)
            lines = []
            if results and results[0]:
                for item in results[0]:
                    if item and len(item) > 1 and item[1]:
                        text = item[1][0]
                        if text and text.strip():
                            lines.append(text.strip())
            extracted = "\n".join(lines).strip()
            if extracted:
                return extracted
        except Exception as e:
            logger.warning(f"PaddleOCR inference failed on {path.name}: {e}. Falling back to Tesseract.")

    # 2. Fallback: Tesseract
    if _TESSERACT_AVAILABLE:
        try:
            image = Image.open(path)
            if image.mode not in ("RGB", "L"):
                image = image.convert("RGB")

            # Try PSM 6 first (receipts / uniform blocks)
            text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 6", lang="eng")
            if not text.strip() or len(text.strip()) < 10:
                text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 4", lang="eng")
            if not text.strip():
                text = pytesseract.image_to_string(image, config=r"--oem 3", lang="eng")

            if text.strip():
                return text.strip()
        except Exception as e:
            logger.warning(f"Tesseract inference failed on {path.name}: {e}")

    raise RuntimeError(
        f"Failed to extract text from {path.name}. Both PaddleOCR and Tesseract could not process the image."
    )


def _ocr_pdf(path: Path) -> str:
    """
    Convert the first page of a PDF to an image using pdftoppm (poppler),
    then run Tesseract on it.
    Falls back to a message if poppler is not installed.
    """
    try:
        output_prefix = str(path.with_suffix(""))
        subprocess.run(
            ["pdftoppm", "-r", "300", "-l", "1", str(path), output_prefix],
            check=True,
            capture_output=True,
        )
        # pdftoppm creates <prefix>-1.ppm
        ppm_file = Path(f"{output_prefix}-1.ppm")
        if ppm_file.exists():
            return run_ocr(str(ppm_file))
        return ""
    except (subprocess.CalledProcessError, FileNotFoundError):
        raise RuntimeError(
            "PDF OCR requires poppler. Install with: brew install poppler\n"
            "Then retry the document processing."
        )
