#!/usr/bin/env python3
"""
process-preview-gif.py

Converts an MP4 gameplay video to an optimized, high-quality GIF
and automatically configures it in the mod's README.md.

Requirements:
    - opencv-python-headless (or opencv-python)
    - pillow
    - numpy
"""

import argparse
import os
import re
import sys
from pathlib import Path

try:
    import cv2
    from PIL import Image
except ImportError as e:
    sys.exit(
        f"Missing required Python dependency: {e}. "
        "Please ensure 'opencv-python-headless' and 'pillow' are installed."
    )


def parse_time(val) -> float:
    """Parses timestamps like '01:23', '85.5', or 10 into seconds."""
    if val is None:
        return 0.0
    if isinstance(val, (int, float)):
        return float(val)
    s = str(val).strip()
    if not s:
        return 0.0
    if ":" in s:
        parts = s.split(":")
        if len(parts) == 2:
            return float(parts[0]) * 60 + float(parts[1])
        elif len(parts) == 3:
            return float(parts[0]) * 3600 + float(parts[1]) * 60 + float(parts[2])
    return float(s)


def convert_video_to_gif(
    video_path: Path,
    output_gif_path: Path,
    max_width: int = 600,
    fps: int = 12,
    start_time: float = 0.0,
    end_time: float | None = None,
    trim_end: float = 0.0,
    max_duration: float = 0.0,
) -> Path:
    """Extracts frames from video, resizes, quantizes, and saves an optimized GIF with trimming."""
    if not video_path.is_file():
        raise FileNotFoundError(f"Input video not found: {video_path}")

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise ValueError(f"Could not open video file: {video_path}")

    orig_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    orig_duration = total_frames / orig_fps

    start_sec = max(0.0, parse_time(start_time))
    
    trim_end_sec = parse_time(trim_end)
    if end_time is not None and parse_time(end_time) > 0:
        end_sec = min(orig_duration, parse_time(end_time))
    elif trim_end_sec > 0:
        end_sec = max(start_sec, orig_duration - trim_end_sec)
    else:
        end_sec = orig_duration

    dur_sec = parse_time(max_duration)
    if dur_sec > 0:
        end_sec = min(end_sec, start_sec + dur_sec)

    start_frame = int(start_sec * orig_fps)
    end_frame = min(total_frames, int(end_sec * orig_fps))
    clip_duration = max(0.0, (end_frame - start_frame) / orig_fps)

    print(f"==> Video Info:")
    print(f"    Source   : {video_path.name}")
    print(f"    Duration : {orig_duration:.2f}s (Total frames: {total_frames}, FPS: {orig_fps:.1f})")
    print(f"    Trim Range: {start_sec:.2f}s -> {end_sec:.2f}s (Clip length: {clip_duration:.2f}s)")

    # Calculate frame stepping to achieve target FPS
    step = max(1, round(orig_fps / fps))

    cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
    current_frame = start_frame
    frames = []

    print(f"==> Processing frames (@ {fps} FPS)...")

    while cap.isOpened() and current_frame < end_frame:
        ret, frame = cap.read()
        if not ret:
            break

        if (current_frame - start_frame) % step == 0:
            h, w = frame.shape[:2]
            if w > max_width:
                new_w = max_width
                new_h = int(h * (max_width / w))
                frame = cv2.resize(frame, (new_w, new_h), interpolation=cv2.INTER_AREA)

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            pil_img = Image.fromarray(rgb)
            # Quantize with adaptive palette and dithering for crisp game graphics
            quantized = pil_img.quantize(
                colors=256,
                method=Image.Quantize.MEDIANCUT,
                dither=Image.Dither.FLOYDSTEINBERG,
            )
            frames.append(quantized)

        current_frame += 1

    cap.release()

    if not frames:
        raise ValueError("No frames could be extracted from video.")

    output_gif_path.parent.mkdir(parents=True, exist_ok=True)
    frame_duration_ms = int(1000 / fps)

    print(f"==> Saving GIF with {len(frames)} frames to: {output_gif_path}...")
    frames[0].save(
        str(output_gif_path),
        save_all=True,
        append_images=frames[1:],
        duration=frame_duration_ms,
        loop=0,
        optimize=True,
    )

    file_size_kb = output_gif_path.stat().st_size / 1024
    if file_size_kb >= 1024:
        print(f"==> Output GIF created: {output_gif_path} ({file_size_kb / 1024:.2f} MB)")
    else:
        print(f"==> Output GIF created: {output_gif_path} ({file_size_kb:.1f} KB)")

    return output_gif_path


def update_readme_with_preview(mod_dir: Path, relative_gif_path: str):
    """Inserts or updates the ## Preview section in README.md with the GIF."""
    readme_path = mod_dir / "README.md"
    if not readme_path.is_file():
        print(f"    [WARN] No README.md found at {readme_path}. Skipping README setup.")
def get_public_gif_url(mod_dir: Path, relative_gif_path: str) -> str:
    """Resolves a permanent public raw GitHub URL for Thunderstore compatibility if git origin exists."""
    try:
        import subprocess
        res = subprocess.run(
            ["git", "-C", str(mod_dir), "config", "--get", "remote.origin.url"],
            capture_output=True,
            text=True,
            check=True,
        )
        url = res.stdout.strip()
        match = re.search(r"github\.com[:/]([^/]+)/([^/.]+?)(?:\.git)?$", url)
        if match:
            user, repo = match.group(1), match.group(2)
            # Normalize posix slashes for web URL
            clean_path = Path(relative_gif_path).as_posix().lstrip("/")
            return f"https://raw.githubusercontent.com/{user}/{repo}/master/{clean_path}"
    except Exception:
        pass
    return relative_gif_path


def update_readme_with_preview(mod_dir: Path, relative_gif_path: str, prefer_raw_url: bool = True):
    """Inserts or updates the ## Preview section in README.md with the GIF."""
    readme_path = mod_dir / "README.md"
    if not readme_path.is_file():
        print(f"    [WARN] No README.md found at {readme_path}. Skipping README setup.")
        return

    target_url = get_public_gif_url(mod_dir, relative_gif_path) if prefer_raw_url else relative_gif_path
    content = readme_path.read_text(encoding="utf-8")
    preview_tag = f"![Gameplay Preview]({target_url})"

    # If already referenced, nothing to do
    if relative_gif_path in content or target_url in content:
        print(f"==> README.md already contains reference to preview GIF.")
        return

    # Check if a ## Preview section already exists
    preview_section_match = re.search(r"(^##\s+Preview[^\n]*\n)([\s\S]*?)(?=\n##\s+|\Z)", content, re.MULTILINE)
    if preview_section_match:
        # Replace existing content of ## Preview
        header = preview_section_match.group(1)
        replacement = f"{header}\n{preview_tag}\n"
        new_content = content[: preview_section_match.start()] + replacement + content[preview_section_match.end() :]
        print("==> Updated existing '## Preview' section in README.md.")
    else:
        # Insert ## Preview right before ## Features, or after the header / badges
        features_match = re.search(r"^##\s+Features", content, re.MULTILINE)
        preview_block = f"## Preview\n\n{preview_tag}\n\n"
        if features_match:
            idx = features_match.start()
            new_content = content[:idx] + preview_block + content[idx:]
            print("==> Injected '## Preview' section before '## Features' in README.md.")
        else:
            # Append at the end of introductory paragraph (after first heading)
            first_h1 = re.search(r"^#[^\n]+\n", content)
            if first_h1:
                idx = first_h1.end()
                new_content = content[:idx] + f"\n{preview_block}" + content[idx:]
                print("==> Injected '## Preview' section under title in README.md.")
            else:
                new_content = f"{preview_block}\n{content}"
                print("==> Prepended '## Preview' section to README.md.")

    readme_path.write_text(new_content, encoding="utf-8")
    print(f"==> README.md successfully updated with gameplay preview ({target_url}).")


def main():
    parser = argparse.ArgumentParser(
        description="Convert MP4 video to optimized GIF and configure in README.md."
    )
    parser.add_argument(
        "-i",
        "--input",
        required=True,
        help="Path to input .mp4 video file.",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="assets/preview.gif",
        help="Output path for .gif (default: assets/preview.gif).",
    )
    parser.add_argument(
        "-m",
        "--mod-path",
        default=".",
        help="Root directory of the mod (default: current directory).",
    )
    parser.add_argument(
        "-w",
        "--max-width",
        type=int,
        default=600,
        help="Maximum width in pixels (default: 600).",
    )
    parser.add_argument(
        "-f",
        "--fps",
        type=int,
        default=12,
        help="Frames per second for output GIF (default: 12).",
    )
    parser.add_argument(
        "-s",
        "--start",
        default="0",
        help="Start timestamp in seconds or MM:SS (e.g. 2.5 or 0:02).",
    )
    parser.add_argument(
        "-e",
        "--end",
        default=None,
        help="End timestamp in seconds or MM:SS (e.g. 14.0 or 0:14).",
    )
    parser.add_argument(
        "--trim-end",
        default="0",
        help="Seconds to cut off from the end of the video.",
    )
    parser.add_argument(
        "-d",
        "--max-duration",
        default="0",
        help="Maximum duration in seconds (default: 0 for all until end).",
    )
    parser.add_argument(
        "--skip-readme",
        action="store_true",
        help="Do not modify README.md.",
    )

    args = parser.parse_args()

    mod_dir = Path(args.mod_path).resolve()
    input_video = Path(args.input).resolve()

    # Determine output path relative to mod_dir if not absolute
    out_arg = Path(args.output)
    if out_arg.is_absolute():
        output_gif = out_arg
    else:
        output_gif = mod_dir / out_arg

    print(f"================ VIDEO TO GIF CONVERTER ================")
    print(f" Mod Directory : {mod_dir}")
    print(f" Input Video   : {input_video}")
    print(f" Output GIF    : {output_gif}")
    print(f"========================================================")

    convert_video_to_gif(
        video_path=input_video,
        output_gif_path=output_gif,
        max_width=args.max_width,
        fps=args.fps,
        start_time=args.start,
        end_time=args.end,
        trim_end=args.trim_end,
        max_duration=args.max_duration,
    )

    if not args.skip_readme:
        try:
            rel_gif = output_gif.relative_to(mod_dir).as_posix()
        except ValueError:
            rel_gif = output_gif.name
        update_readme_with_preview(mod_dir, rel_gif)

    print("\n[SUCCESS] Preview GIF processing and setup complete!")


if __name__ == "__main__":
    main()
