"""Regression checks for the external VVdeC codec's FFmpeg 9 contract."""

import unittest
from pathlib import Path

PATCH = (
    Path(__file__).resolve().parents[1]
    / "securityops/packages/patches/ffmpeg-vvdec-hardening.patch"
)


class FfmpegVvdecPatchTests(unittest.TestCase):
    def test_decoder_does_not_advertise_encoder_only_pixel_formats(self):
        patch = PATCH.read_text(encoding="utf-8")
        self.assertIn("-static const enum AVPixelFormat pix_fmts_vvdec[] = {", patch)
        self.assertIn("-    CODEC_PIXFMTS_ARRAY(pix_fmts_vvdec),", patch)
        self.assertNotIn("+    CODEC_PIXFMTS_ARRAY(pix_fmts_vvdec),", patch)


if __name__ == "__main__":
    unittest.main()
