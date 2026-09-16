"""Compiler dependency records and transactional publication of build outputs."""

import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        checksum = hashlib.sha256()
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
        return checksum.hexdigest()


def snapshot_inputs(paths) -> dict:
    """Hash inputs between stat checks; retain identity/times to detect ABA saves."""
    snapshots = {}
    fields = ("st_dev", "st_ino", "st_size", "st_mtime_ns", "st_ctime_ns")
    for name in paths:
        path = Path(name).absolute()
        try:
            before = path.stat()
        except FileNotFoundError:
            snapshots[str(path)] = None
            continue
        checksum = digest(path)
        after = path.stat()
        before_state = tuple(getattr(before, field) for field in fields)
        after_state = tuple(getattr(after, field) for field in fields)
        if before_state != after_state:
            raise OSError(f"Dependency changed while hashing: {path}")
        snapshots[str(path)] = (checksum, after_state)
    return snapshots


class DependenciesChanged(RuntimeError):
    def __init__(self, paths):
        super().__init__("Dependencies changed or were discovered during compilation/evaluation")
        self.paths = paths


def atomic_write(path: Path, data: str | bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            stream.write(data.encode("utf-8") if isinstance(data, str) else data)
            stream.close()
            temporary.chmod(0o644)
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return default


def validate_metadata(data: dict) -> dict:
    if not isinstance(data, dict) or data.get("schema") != 1:
        raise ValueError("Unsupported page metadata schema")
    for field in ("title", "description", "author", "lang", "date", "link"):
        if not isinstance(data.get(field), str):
            raise ValueError(f"Page metadata requires a string: {field}")
    dirs = data.get("feed-dirs")
    if not isinstance(dirs, list) or not all(isinstance(item, str) for item in dirs):
        raise ValueError("Page metadata requires feed-dirs: array of strings")
    if any(".." in Path(item).parts for item in dirs):
        raise ValueError("Feed directories must stay inside the content directory")
    if data["date"]:
        from datetime import datetime
        datetime.fromisoformat(data["date"])
    return data


class BuildCache:
    def __init__(self, directory: Path, signature: dict):
        self.directory = directory
        self.directory.mkdir(parents=True, exist_ok=True)
        self.signature = signature

    def record_path(self, output: Path) -> Path:
        key = hashlib.sha256(str(output.resolve()).encode()).hexdigest()
        return self.directory / (key + ".json")

    def current(self, output: Path, args: list[str], metadata: bool) -> bool:
        record = read_json(self.record_path(output), {})
        try:
            if record["signature"] != self.signature or record["args"] != args:
                return False
            if not isinstance(record["inputs"], dict) or not record["inputs"]:
                return False
            if digest(output) != record["output"]:
                return False
            if metadata:
                validate_metadata(record["metadata"])
            return all(digest(Path(path)) == value for path, value in record["inputs"].items())
        except (OSError, KeyError, ValueError, TypeError):
            return False

    def known_inputs(self, output: Path, source: Path) -> set[str]:
        record = read_json(self.record_path(output), {})
        inputs = record.get("inputs", {}) if isinstance(record, dict) else {}
        paths = set(inputs) if isinstance(inputs, dict) else set()
        return paths | {str(source.absolute())}

    def publish(self, temporary: Path, output: Path, deps: Path, args: list[str], metadata=None,
                *, inputs_before: dict):
        dependencies = read_json(deps, None)
        if (not isinstance(dependencies, dict)
                or not isinstance(dependencies.get("inputs"), list)
                or not dependencies["inputs"]
                or not all(isinstance(path, str) for path in dependencies["inputs"])):
            raise ValueError("Typst did not emit a valid JSON dependency manifest")
        paths = {str(Path(path).absolute()) for path in dependencies["inputs"]}
        inputs_after = snapshot_inputs(paths)
        if any(inputs_after[path] is None or inputs_before.get(path) != inputs_after[path]
               for path in paths):
            raise DependenciesChanged(paths)
        # Use the verified pre-compilation hashes, never a post-compilation baseline.
        inputs = {path: inputs_before[path][0] for path in paths}
        record = dict(signature=self.signature, args=args, inputs=inputs,
                      output=digest(temporary), metadata=metadata)
        # Publish the cache last: an interrupted publication must cause a rebuild.
        self.record_path(output).unlink(missing_ok=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(output, temporary.read_bytes())
        atomic_write(self.record_path(output), json.dumps(record, ensure_ascii=False))


def build_signature(version: tuple[int, ...], font_path: str) -> dict:
    font_inventory = []
    for directory in filter(None, font_path.split(os.pathsep)):
        for path in sorted(Path(directory).rglob("*")):
            if path.is_file() and path.suffix.lower() in {".ttf", ".otf", ".ttc", ".otc"}:
                stat = path.stat()
                font_inventory.append((str(path.resolve()), stat.st_size, stat.st_mtime_ns))
    return dict(
        schema=1,
        compiler=list(version),
        executable=digest(Path(shutil.which("typst"))),
        implementation=[digest(Path(__file__)), digest(Path(__file__).with_name("build.py"))],
        environment={key: value for key, value in os.environ.items()
                     if key.startswith("TYPST_") or key == "SOURCE_DATE_EPOCH"},
        fonts=[list(entry) for entry in font_inventory],
    )
