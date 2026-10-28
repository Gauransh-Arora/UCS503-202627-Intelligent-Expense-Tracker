"""
OCR Service — converts image/PDF files to raw text using PaddleOCR (with Tesseract fallback).
Includes comprehensive image preprocessing (grayscale, contrast, denoise, upscale) before OCR.

The pipeline intentionally returns raw text.
Structured extraction and confidence scoring are handled by extraction_service.py.
"""
import logging
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageEnhance, ImageFilter, ImageOps

logger = logging.getLogger(__name__)

# PaddleOCR singleton
_PADDLE_OCR = None
_PADDLE_INITIALIZED = False

try:
    import pytesseract
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


def preprocess_image(input_path: Path) -> Path:
    """
    Image preprocessing pipeline:
    1. Check orientation / mode
    2. Upscale if low resolution (width or height < 1200px)
    3. Convert to grayscale
    4. Auto-contrast & sharpness enhancement
    5. Gentle median denoise filter

    Returns temporary Path to preprocessed image.
    """
    try:
        with Image.open(input_path) as img:
            # Handle orientation EXIF
            img = ImageOps.exif_transpose(img)

            # Convert to RGB first if RGBA or indexed
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")

            w, h = img.size
            # Upscale small images to help OCR read small receipt text
            if w < 1200 or h < 1200:
                scale = min(2.0, max(1.2, 1600.0 / max(w, h)))
                new_w = int(w * scale)
                new_h = int(h * scale)
                img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)

            # Convert to Grayscale
            gray = img.convert("L")

            # Auto contrast enhancement
            autocontrast = ImageOps.autocontrast(gray, cutoff=1)

            # Boost contrast slightly
            enhancer = ImageEnhance.Contrast(autocontrast)
            enhanced = enhancer.enhance(1.4)

            # Boost sharpness slightly
            sharpness = ImageEnhance.Sharpness(enhanced)
            sharpened = sharpness.enhance(1.3)

            # Gentle denoise (median filter)
            denoised = sharpened.filter(ImageFilter.MedianFilter(size=3))

            # Save to temp file
            tmp = tempfile.NamedTemporaryFile(suffix=".png", delete=False)
            denoised.save(tmp.name, format="PNG")
            return Path(tmp.name)
    except Exception as exc:
        logger.warning(f"Image preprocessing failed: {exc}, using original image.")
        return input_path


def run_ocr(file_path: str, preprocess: bool = True) -> str:
    """
    Run OCR on an image or PDF file and return the raw extracted text.
    Uses PaddleOCR as primary high-accuracy engine, falling back to Tesseract.
    """
    path = Path(file_path).resolve()
    if not path.exists():
        alt_path = Path.cwd() / file_path
        if alt_path.exists():
            path = alt_path
        else:
            raise FileNotFoundError(f"File not found: {file_path}")

    # For PDFs, convert first page or extract text directly
    if path.suffix.lower() == ".pdf":
        return _ocr_pdf(path)

    # Preprocess image
    working_path = preprocess_image(path) if preprocess else path
    cleanup_temp = working_path != path

    try:
        # 1. Primary: PaddleOCR
        paddle_engine = _get_paddle_ocr()
        if paddle_engine is not None:
            try:
                results = paddle_engine.ocr(str(working_path), cls=True)
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
                image = Image.open(working_path)
                # Try PSM 6 first (uniform text block)
                text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 6", lang="eng")
                if not text.strip() or len(text.strip()) < 10:
                    text = pytesseract.image_to_string(image, config=r"--oem 3 --psm 4", lang="eng")
                if not text.strip():
                    text = pytesseract.image_to_string(image, config=r"--oem 3", lang="eng")

                if text.strip():
                    return text.strip()
            except Exception as e:
                logger.warning(f"Tesseract inference failed on {path.name}: {e}")

        # If preprocessing didn't yield text and we used preprocessed image, try original
        if cleanup_temp:
            return run_ocr(str(path), preprocess=False)

        raise RuntimeError(
            f"Failed to extract text from {path.name}. Both PaddleOCR and Tesseract could not process the image."
        )
    finally:
        if cleanup_temp and working_path.exists():
            try:
                working_path.unlink()
            except Exception:
                pass


def _ocr_pdf(path: Path) -> str:
    """
    Extract text from PDF using pdfplumber if text-based,
    or convert first page to image with pdftoppm / pdf2image and run OCR.
    """
    # 1. Try text extraction from digital PDF
    try:
        import pdfplumber
        with pdfplumber.open(path) as pdf:
            text_pages = [page.extract_text() for page in pdf.pages if page.extract_text()]
            if text_pages:
                full_text = "\n".join(text_pages).strip()
                if len(full_text) > 30:
                    return full_text
    except Exception:
        pass

    # 2. Try rasterizing with pdftoppm (poppler)
    try:
        output_prefix = str(path.with_suffix(""))
        subprocess.run(
            ["pdftoppm", "-r", "300", "-l", "1", str(path), output_prefix],
            check=True,
            capture_output=True,
        )
        ppm_file = Path(f"{output_prefix}-1.ppm")
        if ppm_file.exists():
            try:
                return run_ocr(str(ppm_file))
            finally:
                ppm_file.unlink(missing_ok=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    raise RuntimeError(
        f"Unable to parse or OCR PDF {path.name}. Ensure poppler or pdfplumber is installed."
    )
