"""Tests for claude/.claude/hooks/sync-settings.py. Stdlib only: run with
`python3 -m unittest discover -s tests`."""

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "claude" / ".claude" / "hooks" / "sync-settings.py"


def load_module():
    spec = importlib.util.spec_from_file_location("sync_settings", SCRIPT)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class AutoModeIsAlwaysLocal(unittest.TestCase):
    """autoMode describes one machine's hosts and network. It must never reach
    the public repo, even on a machine with no exclude file."""

    def setUp(self):
        self.mod = load_module()
        self.tmp = Path(tempfile.mkdtemp())
        self.mod.EXCLUDE = self.tmp / "no-such-exclude-file"
        self.mod.LIVE = self.tmp / "live.json"
        self.mod.REPO_SETTINGS = self.tmp / "repo.json"
        self.mod.git_busy = lambda: False

    def test_capture_strips_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "high",
                                             "autoMode": {"environment": ["host 10.0.0.1"]}}))
        self.assertEqual(self.mod.cmd_capture(None), 0)
        self.assertEqual(json.loads(self.mod.REPO_SETTINGS.read_text()), {"effortLevel": "high"})

    def test_apply_keeps_live_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "low",
                                             "autoMode": {"environment": ["mine"]}}))
        self.mod.REPO_SETTINGS.write_text(json.dumps({"effortLevel": "high"}))
        self.mod.backup_live = lambda: None

        class Args:
            post_merge = False

        self.assertEqual(self.mod.cmd_apply(Args()), 0)
        self.assertEqual(json.loads(self.mod.LIVE.read_text()),
                         {"effortLevel": "high", "autoMode": {"environment": ["mine"]}})

    def test_check_ignores_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "high", "autoMode": {"x": 1}}))
        self.mod.REPO_SETTINGS.write_text(json.dumps({"effortLevel": "high"}))
        self.assertEqual(self.mod.cmd_check(None), 0)


if __name__ == "__main__":
    unittest.main()
