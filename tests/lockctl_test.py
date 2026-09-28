"""No real locker/systemctl is executed: PATH resolves only the fake fixture."""
# pyright: reportUninitializedInstanceVariable=false
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class LockctlTest(unittest.TestCase):
    temp: tempfile.TemporaryDirectory[str]
    runtime: Path
    trace: Path
    env: dict[str, str]

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.runtime = Path(self.temp.name)
        (self.runtime / 'quickshell').symlink_to(ROOT / 'tests/fake-quickshell')
        self.trace = self.runtime / 'trace'
        self.env = dict(os.environ, XDG_RUNTIME_DIR=str(self.runtime),
                        WAYLAND_DISPLAY='not-a-real-display', TRACE=str(self.trace),
                        PATH=str(self.runtime) + ':' + os.environ['PATH'])

    def run_ctl(self, scenario, action='lock-and-suspend'):
        return subprocess.run(['bash', str(ROOT / 'scripts/lockctl'), action],
                              env=dict(self.env, SCENARIO=scenario), capture_output=True,
                              text=True, timeout=22)

    def test_secure_ack_precedes_suspend(self):
        self.assertEqual(self.run_ctl('secure').returncode, 0)
        lines = self.trace.read_text().splitlines()
        self.assertLess(next(i for i, s in enumerate(lines) if s.endswith(' status')),
                        next(i for i, s in enumerate(lines) if s.endswith(' suspend')))

    def test_insecure_never_suspends(self):
        for state in ('idle', 'unlocking'):
            self.assertNotEqual(self.run_ctl(state).returncode, 0)
        self.assertNotIn('call locker suspend\n', self.trace.read_text())

    def test_owner_recheck_and_command_failure(self):
        for state in ('race', 'failure'):
            self.assertNotEqual(self.run_ctl(state).returncode, 0)

    def test_concurrent_requests_are_serialized(self):
        command = ['bash', str(ROOT / 'scripts/lockctl'), 'lock']
        a = subprocess.Popen(command, env=self.env)
        b = subprocess.Popen(command, env=self.env)
        self.assertEqual(a.wait(timeout=8), 0)
        self.assertEqual(b.wait(timeout=8), 0)
        lines = self.trace.read_text().splitlines()
        starts = [i for i, s in enumerate(lines) if ' ipc ' not in ' ' + s + ' ']
        self.assertEqual(starts, [0, 3])

    def test_wait_does_not_launch(self):
        self.assertEqual(self.run_ctl('secure', 'wait').returncode, 0)
        self.assertEqual(len(self.trace.read_text().splitlines()), 1)

    def test_missing_ack_times_out_without_suspend_or_kill(self):
        self.assertNotEqual(self.run_ctl('timeout').returncode, 0)
        trace = self.trace.read_text()
        self.assertNotIn('call locker suspend\n', trace)
        self.assertNotIn('kill', trace)


if __name__ == '__main__':
    unittest.main()
