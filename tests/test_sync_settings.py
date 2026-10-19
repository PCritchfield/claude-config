"""Tests for claude/.claude/hooks/sync-settings.py. Stdlib only: run with
`python3 -m unittest discover -s tests`."""

import importlib.util
import json
import tempfile
import unittest
from types import SimpleNamespace
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
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
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
        self.assertEqual(self.mod.cmd_apply(SimpleNamespace(post_merge=False)), 0)
        self.assertEqual(json.loads(self.mod.LIVE.read_text()),
                         {"effortLevel": "high", "autoMode": {"environment": ["mine"]}})

    def test_apply_never_imports_repo_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "low"}))
        self.mod.REPO_SETTINGS.write_text(json.dumps({"effortLevel": "high",
                                                      "autoMode": {"allow": ["anything"]}}))
        self.mod.backup_live = lambda: None
        self.assertEqual(self.mod.cmd_apply(SimpleNamespace(post_merge=False)), 0)
        self.assertEqual(json.loads(self.mod.LIVE.read_text()), {"effortLevel": "high"})

    def test_post_merge_never_imports_pulled_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "low"}))
        pulled = {"ORIG_HEAD": {"effortLevel": "low"},
                  "HEAD": {"effortLevel": "high", "autoMode": {"allow": ["anything"]}}}
        self.mod.repo_version = pulled.get
        self.mod.backup_live = lambda: None
        self.assertEqual(self.mod.cmd_apply(SimpleNamespace(post_merge=True)), 0)
        self.assertEqual(json.loads(self.mod.LIVE.read_text()), {"effortLevel": "high"})

    def test_post_merge_ignores_automode_only_change(self):
        live = {"effortLevel": "high", "autoMode": {"environment": ["mine"]}}
        self.mod.LIVE.write_text(json.dumps(live))
        pulled = {"ORIG_HEAD": {"effortLevel": "high"},
                  "HEAD": {"effortLevel": "high", "autoMode": {"allow": ["anything"]}}}
        self.mod.repo_version = pulled.get
        self.assertEqual(self.mod.cmd_apply(SimpleNamespace(post_merge=True)), 0)
        self.assertEqual(json.loads(self.mod.LIVE.read_text()), live)

    def test_check_ignores_repo_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "high"}))
        self.mod.REPO_SETTINGS.write_text(json.dumps({"effortLevel": "high", "autoMode": {"x": 1}}))
        self.assertEqual(self.mod.cmd_check(None), 0)

    def test_check_ignores_automode(self):
        self.mod.LIVE.write_text(json.dumps({"effortLevel": "high", "autoMode": {"x": 1}}))
        self.mod.REPO_SETTINGS.write_text(json.dumps({"effortLevel": "high"}))
        self.assertEqual(self.mod.cmd_check(None), 0)


if __name__ == "__main__":
    unittest.main()
