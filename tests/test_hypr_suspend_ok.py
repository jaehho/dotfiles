"""hypr-suspend-ok defers idle suspend for what steno says it is doing.

The fake `steno` prints lines from `steno-contract/`, a copy of
steno's `contract/`: what `steno bar --once` prints in each state and
which fields this script reads, both pinned by steno's tests. To take a
change from steno:

    cp ~/projects/steno/contract/* tests/steno-contract/
"""

import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "home/hypr/.local/bin/hypr-suspend-ok"
CONTRACT = Path(__file__).resolve().parent / "steno-contract"
# A sibling checkout, as on the author's machine; STENO_SRC as steno's
# own launcher reads it.
STENO = Path(os.environ.get("STENO_SRC") or Path.home() / "projects/steno")

DEFER, ALLOW = 1, 0
# Every state steno prints, by (class, manual), and what the gate does.
WANT = {
    ("recording", True): DEFER,  # a meeting you started: nothing else holds it
    ("recording", False): ALLOW,  # a call steno saw: as before the gate
    ("finalizing", False): DEFER,  # notes; steno gives up after 30 min
    ("paused", False): ALLOW,
    ("idle", False): ALLOW,
    ("off", False): ALLOW,
}


def sample_lines():
    text = (CONTRACT / "bar.jsonl").read_text()
    return [line for line in text.splitlines() if line]


def state_of(line):
    printed = json.loads(line)
    return printed["class"], printed["manual"]


class TestGate(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        (self.tmp / "home").mkdir()  # no Claude sessions
        # Only what the script calls, so a real steno is never found.
        for tool in ("jq", "timeout", "cat"):
            found = shutil.which(tool)
            if found is None:
                self.skipTest(f"{tool} is not installed")
            (self.bin / tool).symlink_to(found)

    def fake_steno(self, body):
        path = self.bin / "steno"
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def gate(self):
        env = {"PATH": str(self.bin), "HOME": str(self.tmp / "home")}
        return subprocess.run(
            ["/bin/bash", str(SCRIPT)], env=env, timeout=30,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        ).returncode

    def test_each_state_steno_prints(self):
        lines = sample_lines()
        keys = [state_of(line) for line in lines]
        self.assertEqual(set(keys), set(WANT), "a state with no decision")
        for line, key in zip(lines, keys, strict=True):
            with self.subTest(key):
                (self.tmp / "line").write_text(line + "\n")
                self.fake_steno(f"cat '{self.tmp / 'line'}'")
                self.assertEqual(self.gate(), WANT[key])

    def test_stay_awake_defers(self):
        # hypr-idle-toggle's inhibitor, as `systemd-inhibit --list` shows it.
        (self.bin / "awk").symlink_to(shutil.which("awk"))
        path = self.bin / "systemd-inhibit"
        path.write_text(
            "#!/bin/sh\necho 'hypr-lid-inhibit 1000 jaeho 1234 sleep "
            "handle-lid-switch Stay awake block'\n"
        )
        path.chmod(0o755)
        self.assertEqual(self.gate(), DEFER)

    def test_no_steno_allows(self):
        self.assertEqual(self.gate(), ALLOW)

    def test_a_failing_steno_allows(self):
        self.fake_steno("echo 'steno-live: no .venv' >&2; exit 1")
        self.assertEqual(self.gate(), ALLOW)

    def test_a_hung_steno_allows_within_the_timeout(self):
        self.fake_steno("exec sleep 60")
        (self.bin / "sleep").symlink_to(shutil.which("sleep"))
        start = time.monotonic()
        self.assertEqual(self.gate(), ALLOW)
        self.assertLess(time.monotonic() - start, 10)


class TestCopy(unittest.TestCase):
    @unittest.skipUnless((STENO / "contract").is_dir(), f"no {STENO}/contract")
    def test_the_copy_is_what_steno_promises(self):
        theirs = sorted(p.name for p in (STENO / "contract").iterdir())
        ours = sorted(p.name for p in CONTRACT.iterdir())
        self.assertEqual(ours, theirs)
        for name in theirs:
            with self.subTest(name):
                self.assertEqual(
                    (CONTRACT / name).read_text(),
                    (STENO / "contract" / name).read_text(),
                    f"{name} changed in steno; copy it (see this module)",
                )

    def test_steno_pins_what_this_reads(self):
        consumers = json.loads((CONTRACT / "consumers.json").read_text())
        reads = consumers["hypr-suspend-ok"]["reads"]["bar.jsonl"]
        self.assertLessEqual({"class", "manual"}, set(reads))


if __name__ == "__main__":
    unittest.main()
