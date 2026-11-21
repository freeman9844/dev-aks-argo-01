import argparse
import json
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="Pin the chart image to an ACR digest.")
    parser.add_argument("chart", type=Path)
    parser.add_argument("repository")
    parser.add_argument("digest")
    args = parser.parse_args()
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", args.digest):
        parser.error("invalid digest: expected sha256 followed by 64 lowercase hex digits")
    path = args.chart / "values.yaml"
    # values.yaml is stored as JSON (valid YAML) so CI needs no YAML library.
    values = json.loads(path.read_text(encoding="utf-8"))
    values["image"] = {"repository": args.repository, "digest": args.digest}
    path.write_text(json.dumps(values, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
