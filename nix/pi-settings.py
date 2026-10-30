"""Reconcile Nix-owned Pi packages while preserving Pi's writable settings."""

import json
import os
from pathlib import Path
import sys
import tempfile


def reconcile(settings_path, manifest):
    root = manifest["root"] + "/"
    names = manifest["names"]
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    # Use the same lock directory as Pi's proper-lockfile (realpath: false).
    # An active lock stops activation rather than overwriting concurrent edits.
    lock = Path(str(settings_path) + ".lock")
    lock.mkdir()
    temporary = None
    try:
        settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
        packages = settings.get("packages", [])
        if not isinstance(packages, list):
            raise ValueError("Pi settings.packages must be an array")
        merged = []
        seen = set()
        for entry in packages:
            source = entry if isinstance(entry, str) else entry["source"]
            name = next((name for name in names if source == "npm:" + name
                         or source.startswith("npm:" + name + "@")
                         or source == root + name), None)
            if name:
                if name in seen:
                    continue
                seen.add(name)
                merged.append(root + name if isinstance(entry, str)
                              else {**entry, "source": root + name})
            elif not source.startswith(root):
                merged.append(entry)
        merged.extend(root + name for name in names if name not in seen)
        if settings.get("packages") == merged:
            return
        settings["packages"] = merged
        with tempfile.NamedTemporaryFile(mode="w", dir=settings_path.parent,
                                         prefix=".nix-pi-settings-", delete=False) as output:
            temporary = output.name
            json.dump(settings, output, ensure_ascii=False, indent=2)
            output.write("\n")
        os.replace(temporary, settings_path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
        lock.rmdir()


if __name__ == "__main__":
    reconcile(Path(sys.argv[1]), json.loads(Path(sys.argv[2]).read_text()))
