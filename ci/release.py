import argparse
import json
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    parser.add_argument("repository")
    parser.add_argument("digest")
    args = parser.parse_args()
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", args.digest):
        parser.error("invalid digest: expected sha256 followed by 64 lowercase hex digits")
    path = args.directory / "kustomization.yaml"
    config = json.loads(path.read_text(encoding="utf-8"))
    matches = [entry for entry in config["images"] if entry["name"] == "demo-app"]
    if len(matches) != 1:
        parser.error("expected exactly one demo-app image")
    matches[0].pop("newTag", None)
    matches[0].update(newName=args.repository, digest=args.digest)
    path.write_text(json.dumps(config, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
