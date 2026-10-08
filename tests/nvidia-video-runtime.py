#!/usr/bin/env python3
"""Exercise installed NVIDIA video consumers without activating a GPU."""

import argparse
import json
import os
import subprocess
import tempfile
from pathlib import Path


def command(arguments):
    result = subprocess.run(
        [str(argument) for argument in arguments],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=90,
    )
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ffmpeg9", type=Path)
    parser.add_argument("ffmpeg8", type=Path)
    parser.add_argument("recorder", type=Path)
    parser.add_argument("turborec", type=Path)
    parser.add_argument("driver_store_path")
    parser.add_argument("ffmpeg8_store_path")
    parser.add_argument("state", type=Path)
    args = parser.parse_args()
    assert os.getuid() != 0
    assert {path.name for path in Path("/sys/class/net").iterdir()} == {"lo"}
    assert not any(Path("/dev").glob("nvidia*"))
    with tempfile.TemporaryDirectory(prefix="nvidia-video-", dir=args.state) as private:
        state = Path(private)
        os.environ.update(HOME=str(state), XDG_CONFIG_HOME=str(state / "config"))
        for root, version in ((args.ffmpeg9, "9.0.2"), (args.ffmpeg8, "8.1.3")):
            ffmpeg = root / "bin/ffmpeg"
            assert f"ffmpeg version {version}" in command([ffmpeg, "-version"])
            encoders = command([ffmpeg, "-hide_banner", "-encoders"])
            for encoder in ("h264_nvenc", "hevc_nvenc", "av1_nvenc"):
                assert encoder in encoders, (version, encoder)
            codec = next((root / "lib").glob("libavcodec.so.*"))
            binary = codec.read_bytes()
            for library in ("libcuda.so.1", "libnvidia-encode.so.1"):
                assert (args.driver_store_path + "/lib/" + library).encode() in binary
            output = state / f"ffmpeg-{version}.mkv"
            command(
                [
                    ffmpeg,
                    "-hide_banner",
                    "-loglevel",
                    "error",
                    "-f",
                    "lavfi",
                    "-i",
                    "testsrc2=size=96x64:rate=20:duration=1",
                    "-f",
                    "lavfi",
                    "-i",
                    "sine=frequency=440:sample_rate=44100:duration=1",
                    "-c:v",
                    "libx264",
                    "-preset",
                    "ultrafast",
                    "-pix_fmt",
                    "yuv420p",
                    "-c:a",
                    "aac",
                    "-shortest",
                    output,
                ]
            )
            streams = json.loads(
                command(
                    [
                        root / "bin/ffprobe",
                        "-v",
                        "error",
                        "-count_frames",
                        "-show_streams",
                        "-of",
                        "json",
                        output,
                    ]
                )
            )["streams"]
            video = next(
                stream for stream in streams if stream["codec_type"] == "video"
            )
            audio = next(
                stream for stream in streams if stream["codec_type"] == "audio"
            )
            assert video["codec_name"] == "h264" and video["nb_read_frames"] == "20"
            assert (video["width"], video["height"]) == (96, 64)
            assert audio["codec_name"] == "aac" and int(audio["nb_read_frames"]) > 0
            decoded = command(
                [
                    ffmpeg,
                    "-v",
                    "error",
                    "-i",
                    output,
                    "-map",
                    "0:v:0",
                    "-f",
                    "framemd5",
                    "-",
                ]
            )
            assert (
                len([line for line in decoded.splitlines() if not line.startswith("#")])
                == 20
            )
            print(
                f"PASS: FFmpeg {version} CPU encode/probe/decode and matched NVENC loader"
            )
        recorder = args.recorder / "bin/wf-recorder"
        assert "Usage" in command([recorder, "--help"])
        dependencies = command(["ldd", recorder])
        assert "not found" not in dependencies
        assert args.ffmpeg8_store_path + "/lib/libavcodec.so." in dependencies
        assert "turbo" in command([args.turborec / "bin/turborec", "--version"]).lower()
        assert "usage:" in command([args.turborec / "bin/turborec", "--help"]).lower()
        command([args.turborec / "bin/turborecorder", "-h"])
        print(
            "PASS: recorder links the matched FFmpeg 8; both TurboRec launchers execute"
        )
        print("Hardware encoding, display capture and GPU activation were not tested.")


if __name__ == "__main__":
    main()
