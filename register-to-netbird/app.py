#!/usr/bin/env python3

import os
import re
import sys
import shutil
import subprocess

URL_RE = re.compile(r"https://[^\s]+", re.IGNORECASE)

def ensure_qrencode() -> None:
    if shutil.which("qrencode") is None:
        print("ERROR: `qrencode` is not installed or not in PATH.", file=sys.stderr)
        sys.exit(1)

def extract_url(buf: str) -> str | None:
    m = URL_RE.search(buf)
    return None if not m else m.group(0).replace("\n", "").replace("\r", "")

def print_qr_ansiutf8(data: str) -> None:
    subprocess.run(
        ["qrencode", "-t", "ANSIUTF8", "-m", "2", data],
        check=True,
    )

def main() -> int:
    ensure_qrencode()

    proc = subprocess.Popen(
        ["netbird", "up", "--no-browser", "--allow-server-ssh", f"--hostname={os.environ.get("NB_HOSTNAME")}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )

    buf = ""
    shown = False
    assert proc.stdout is not None
    try:
        for line in proc.stdout:
            if not shown:
                buf += line
                url = extract_url(buf)
                if url:
                    print(f"URL: {url}\n\n[ Scan this QR to log in ]\n", flush=True)
                    print_qr_ansiutf8(url)
                    shown = True
    except KeyboardInterrupt:
        proc.terminate()
    finally:
        return proc.wait()


if __name__ == "__main__":
    sys.exit(main())

