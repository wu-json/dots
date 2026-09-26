import json
import os
from pathlib import Path
import pty
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLS = 'brew uname id dscl getent grep sudo chsh gh git stow node npm defaults launchctl pgrep osascript open fish just curl'.split()


class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='dots-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.repo = self.base / 'repo with spaces'
        self.repo.mkdir()
        for item in ('scripts', 'homebrew', 'pi'):
            shutil.copytree(ROOT / item, self.repo / item, ignore=shutil.ignore_patterns('node_modules', '__pycache__'))
        shutil.copy(ROOT / 'justfile', self.repo)
        # Redirect fallback Homebrew discovery inside the copied script as well;
        # even tests with brew absent must never find the host installation.
        script = self.repo / 'scripts/init.sh'
        content = script.read_text()
        for index, prefix in enumerate(('/opt/homebrew', '/usr/local', '/home/linuxbrew/.linuxbrew')):
            content = content.replace(prefix + '/bin/brew', str(self.base / f'prefix{index}/bin/brew'))
        script.write_text(content)
        self.home = self.base / 'home'
        self.home.mkdir()
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        self.state_file = self.base / 'state.json'
        self.state_file.write_text('{}')
        driver = self.base / 'driver'
        driver.write_text(f'#!{sys.executable}\n' + (ROOT / 'tests/fake_command.py').read_text())
        driver.chmod(0o755)
        for tool in TOOLS:
            (self.bin / tool).symlink_to(driver)
        # Only safe, local utilities can escape the doubles. No real package
        # manager, network client, sudo, shell changer, or desktop tool on PATH.
        for tool in ('bash', 'dirname', 'mktemp', 'rm', 'cat', 'awk', 'cut', 'cksum', 'mkdir', 'tar', 'install', 'ln'):
            (self.bin / tool).symlink_to(shutil.which(tool))
        self.env = {'PATH': str(self.bin), 'HOME': str(self.home), 'TEST_STATE': str(self.base), 'NO_COLOR': '1', 'LC_ALL': 'C', 'TMPDIR': str(self.base)}

    def state(self, **updates):
        state = json.loads(self.state_file.read_text())
        state.update(updates)
        self.state_file.write_text(json.dumps(state))
        return state

    def calls(self):
        path = self.base / 'calls.jsonl'
        return [json.loads(line) for line in path.read_text().splitlines()] if path.exists() else []

    def run_setup(self, task='init', tty=False, success=True):
        command = ['/bin/bash', str(self.repo / 'scripts/init.sh'), task]
        if tty:
            master, slave = pty.openpty()
            try:
                result = subprocess.run(command, env=self.env, stdin=slave, capture_output=True, text=True, timeout=30)
            finally:
                os.close(master)
                os.close(slave)
        else:
            result = subprocess.run(command, env=self.env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30)
        if success:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result.stdout + result.stderr

    def test_fresh_init_then_rerun_has_no_mutations(self):
        first = self.run_setup(tty=True)
        self.assertIn('Login shell changed', first)
        before = len(self.calls())
        second = self.run_setup(tty=True)
        self.assertIn('already', second)
        self.assertNotIn('→', second)
        self.assertNotIn('\x1b', second)
        forbidden = {'sudo', 'chsh', 'open', 'osascript'}
        for call in self.calls()[before:]:
            self.assertNotIn(call[0], forbidden, call)
            self.assertFalse(call[:2] in [['npm', 'ci'], ['brew', 'install'], ['defaults', 'write'], ['launchctl', 'bootstrap']], call)
            self.assertNotEqual(call[:3], ['gh', 'extension', 'install'])
            if call[0] == 'stow':
                self.assertIn('--simulate', call)
        self.assertTrue(any(c[:3] == ['brew', 'bundle', 'install'] and '--no-upgrade' in c for c in self.calls()))

    def test_fish_installs_missing_dependency_and_only_changes_once(self):
        (self.bin / 'fish').unlink()
        self.run_setup('fish', tty=True)
        self.assertIn(['brew', 'install', 'fish'], self.calls())
        self.assertEqual(self.state()['shell'], str(self.bin / 'fish'))
        before = len(self.calls())
        self.run_setup('fish', tty=True)
        self.assertFalse(any(c[0] in ('sudo', 'chsh') for c in self.calls()[before:]))

    def test_fish_uses_account_shell_not_stale_environment(self):
        self.env['SHELL'] = str(self.bin / 'fish')
        self.run_setup('fish', tty=True)
        self.assertTrue(any(c[0] == 'chsh' for c in self.calls()))

    def test_unauthed_headless_init_continues_with_instructions(self):
        self.state(auth=False, gui=False)
        output = self.run_setup()
        for text in ('gh auth login', 'just init-fish', 'no GUI session', '3 skipped'):
            self.assertIn(text, output)
        self.assertTrue(self.state()['npm'])
        self.assertFalse(any(c[0] in ('sudo', 'chsh', 'open') for c in self.calls()))

    def test_old_node_warns_without_attempting_npm_install(self):
        self.state(old_node=True)
        output = self.run_setup('pi')
        self.assertIn('Node >=22.19', output)
        self.assertIn('just init-pi-extensions', output)
        self.assertFalse(any(c[:2] == ['npm', 'ci'] for c in self.calls()))

    def test_missing_node_installed_for_standalone_pi(self):
        (self.bin / 'node').unlink()
        (self.bin / 'npm').unlink()
        self.run_setup('pi')
        self.assertIn(['brew', 'install', 'node'], self.calls())

    def test_pi_manifest_change_and_missing_dependencies_reinstall(self):
        self.run_setup('pi')
        manifest = self.repo / 'pi/.pi/agent/extensions/package.json'
        manifest.write_text(manifest.read_text() + '\n')
        self.run_setup('pi')
        self.state(npm=False)
        self.run_setup('pi')
        self.assertEqual(sum(c[:2] == ['npm', 'ci'] for c in self.calls()), 3)

    def test_failure_reports_diagnostics_and_can_retry(self):
        self.state(fail='npm')
        output = self.run_setup('pi', success=False)
        self.assertIn('simulated dependency failure', output)
        self.assertFalse((self.repo / 'pi/.pi/agent/extensions/node_modules/.dots-install').exists())
        self.state(fail=None)
        self.run_setup('pi')

    def test_conflict_preserves_files_and_stops(self):
        self.state(conflict=True)
        output = self.run_setup('stow', success=False)
        self.assertIn('move or back up', output)
        self.assertTrue(all('--simulate' in c for c in self.calls() if c[0] == 'stow'))

    def test_missing_sudo_has_actionable_error(self):
        (self.bin / 'sudo').unlink()
        output = self.run_setup('fish', tty=True, success=False)
        self.assertIn('Register the Fish path in /etc/shells', output)

    def test_explicit_noninteractive_does_not_change_shell(self):
        self.env['DOTS_NONINTERACTIVE'] = '1'
        self.assertIn('skipped', self.run_setup('fish', tty=True))
        self.assertFalse(any(c[0] in ('sudo', 'chsh') for c in self.calls()))

    def test_linux_skips_desktop_recipes(self):
        self.state(os='Linux')
        self.assertIn('macOS only', self.run_setup('insomnia'))
        self.assertIn('macOS only', self.run_setup('tailscale'))

    def test_bootstrap_without_homebrew_or_just(self):
        (self.bin / 'brew').unlink()
        (self.bin / 'just').unlink()
        self.state(install_homebrew=True)
        self.run_setup('bootstrap')
        self.assertIn(['brew', 'install', 'just'], self.calls())
        self.assertTrue(any(c[0] == 'curl' for c in self.calls()))
        self.assertTrue(any(c[0] == 'just' for c in self.calls()))

    def test_bootstrap_download_failure_explains_recovery(self):
        (self.bin / 'brew').unlink()
        self.state(fail='curl')
        self.assertIn('Check your network connection and rerun', self.run_setup('bootstrap', success=False))
        self.assertFalse(any(c[0] == 'just' for c in self.calls()))

    def test_bootstrap_hands_off_to_just(self):
        self.run_setup('bootstrap')
        self.assertIn(['just', '--justfile', str(self.repo / 'justfile'), 'init'], self.calls())

    def test_obscura_matching_version_does_not_download(self):
        target = self.home / '.local/bin'
        target.mkdir(parents=True)
        for tool in ('obscura', 'obscura-worker'):
            binary = target / tool
            binary.write_text('#!/bin/bash\nprintf "obscura 0.1.8\\n"\n')
            binary.chmod(0o755)
        self.assertIn('already installed', self.run_setup('obscura'))
        self.assertFalse(any(c[0] == 'curl' for c in self.calls()))

    @unittest.skipUnless(shutil.which('fish'), 'Install Fish to test startup prerequisites')
    def test_fish_startup_with_missing_optional_tools(self):
        config_dir = ROOT / 'fish/.config/fish/conf.d'
        result = subprocess.run(
            [shutil.which('fish'), '--no-config', '-c',
             'source "$argv[1]/00-homebrew.fish"; source "$argv[1]/fnm.fish"', str(config_dir)],
            env=self.env, cwd=self.home, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, '')
        self.assertIn(['brew', 'shellenv', 'fish'], self.calls())

    @unittest.skipUnless(shutil.which('stow'), 'Install GNU Stow to run real symlink integration')
    def test_real_stow_rerun_and_conflict(self):
        for package in ('fish', 'gh-dash', 'nvim', 'wezterm', 'yazi'):
            shutil.copytree(ROOT / package, self.repo / package)
        (self.bin / 'stow').unlink()
        (self.bin / 'stow').symlink_to(shutil.which('stow'))
        self.run_setup('stow')
        config = self.home / '.config/fish/config.fish'
        self.assertTrue(config.exists())
        self.assertEqual(config.resolve(), (self.repo / 'fish/.config/fish/config.fish').resolve())
        self.assertIn('already linked', self.run_setup('stow'))
        # Unfold the linked directory into independent files before creating a conflict.
        fish_dir = self.home / '.config/fish'
        if (self.home / '.config').is_symlink():
            target = (self.home / '.config').resolve()
            (self.home / '.config').unlink()
            shutil.copytree(target, self.home / '.config', symlinks=True)
        if fish_dir.is_symlink():
            target = fish_dir.resolve()
            fish_dir.unlink()
            shutil.copytree(target, fish_dir, symlinks=True)
        if config.is_symlink():
            config.unlink()
        config.write_text('keep my config\n')
        self.run_setup('stow', success=False)
        self.assertEqual(config.read_text(), 'keep my config\n')
