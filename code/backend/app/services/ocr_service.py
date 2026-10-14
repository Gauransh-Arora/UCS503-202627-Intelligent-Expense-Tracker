"""
OCR Service — converts image/PDF files to raw text using Tesseract.

The pipeline intentionally returns only raw text.
Structured extraction is handled by extraction_service.py.
"""
import subprocess
from pathlib import Path

try:
    import pytesseract
    from PIL import Image
    _TESSERACT_AVAILABLE = True
except ImportError:
    _TESSERACT_AVAILABLE = False


def run_ocr(file_path: str) -> str:
    """
    Run OCR on an image file and return the raw extracted text.

    Args:
        file_path: Absolute path to the image file.

    Returns:
        Raw OCR text string.

    Raises:
        RuntimeError: If Tesseract is not installed or OCR fails.
    """
    if not _TESSERACT_AVAILABLE:
        raise RuntimeError(
            "pytesseract or Pillow is not installed. "
            "Install with: uv add pytesseract pillow\n"
            "Also install Tesseract: brew install tesseract"
        )

    path = Path(file_path).resolve()
    if not path.exists():
        # Also try relative to project root
        alt_path = Path.cwd() / file_path
        if alt_path.exists():
            path = alt_path
        else:
            raise FileNotFoundError(f"File not found: {file_path}")

    # For PDFs, convert first page to image using system tools if available
    if path.suffix.lower() == ".pdf":
        return _ocr_pdf(path)

    image = Image.open(path)
    # Pre-processing: convert to grayscale or RGB
    if image.mode not in ("RGB", "L"):
        image = image.convert("RGB")

    # Try PSM 6 first (uniform block of text, standard for receipts)
    text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 6", lang="eng")
    if not text.strip() or len(text.strip()) < 10:
        # Fallback to PSM 4 (single column of variable text) or default
        text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 4", lang="eng")
    if not text.strip():
        # Final fallback: default page segmentation
        text = pytesseract.image_to_string(image, config=r"--oem 3", lang="eng")

    return text.strip()


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
