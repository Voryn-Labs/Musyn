"""Verify bounded, incremental PCM windows without a network/model/video encoder."""
from pathlib import Path
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='musyn-reader-') as folder:
    path = Path(folder)
    executable = path / 'reader-check'
    subprocess.run([
        'xcrun', 'swiftc', '-module-cache-path',
        str(Path(tempfile.gettempdir()) / 'musyn-swift-module-cache'),
        str(root / 'ios/Runner/MusynVocalDSP.swift'),
        str(root / 'ios/Runner/MusynSingEngine.swift'),
        str(root / 'test/native_sing_reader_smoke.swift'),
        '-o', str(executable),
    ], check=True)
    subprocess.run([str(executable), str(path)], check=True, timeout=60)
