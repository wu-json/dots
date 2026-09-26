import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def snapshot(root):
    result = {}
    for directory, folders, files in os.walk(root, followlinks=False):
        for name in folders + files:
            path = Path(directory) / name
            stat = path.lstat()
            result[str(path.relative_to(root))] = (
                stat.st_mode, stat.st_ino, stat.st_size, stat.st_mtime_ns,
                os.readlink(path) if path.is_symlink() else None,
            )
    return result


def main():
    if not (
        platform.system() == 'Darwin'
        and os.environ.get('GITHUB_ACTIONS') == 'true'
        and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted'
    ):
        raise SystemExit('Real installation tests run only on disposable GitHub-hosted macOS runners.')

    with tempfile.TemporaryDirectory(prefix='dots-integration-') as temporary:
        base = Path(temporary).resolve()
        repo = base / 'repo with spaces'
        home = base / 'home'
        home.mkdir()
        for directory in ('scripts', 'homebrew', 'fish', 'gh-dash', 'nvim', 'pi', 'wezterm', 'yazi', 'swiftbar'):
            shutil.copytree(ROOT / directory, repo / directory,
                            ignore=shutil.ignore_patterns('node_modules', '__pycache__'))
        shutil.copy2(ROOT / 'justfile', repo / 'justfile')
        for directory in ('tmp', 'runtime', 'cache'):
            (base / directory).mkdir()
        env = {
            'PATH': os.environ['PATH'],
            'HOME': str(home),
            'FNM_DIR': str(home / '.local/share/fnm'),
            'XDG_CONFIG_HOME': str(home / '.config'),
            'XDG_DATA_HOME': str(home / '.local/share'),
            'XDG_CACHE_HOME': str(base / 'cache'),
            'XDG_RUNTIME_DIR': str(base / 'runtime'),
            'npm_config_cache': str(base / 'cache/npm'),
            'TMPDIR': str(base / 'tmp'),
            'NO_COLOR': '1',
            'TERM': 'dumb',
            'DOTS_NONINTERACTIVE': '1',
            'HOMEBREW_NO_AUTO_UPDATE': '1',
            'HOMEBREW_NO_INSTALL_CLEANUP': '1',
        }

        def run(*args, success=True):
            print('→ ' + ' '.join(args), flush=True)
            result = subprocess.run(args, cwd=repo, env=env, stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=600)
            if (result.returncode == 0) != success:
                print(result.stdout, flush=True)
                raise AssertionError(f'Unexpected exit {result.returncode}: {args}')
            if success:
                print(result.stdout, flush=True)
            else:
                print('✓ Command refused as expected; checking the resulting state.', flush=True)
            return result.stdout

        runtime = ('fnm', 'exec', '--using', '24')
        require(not Path(env['FNM_DIR']).exists(), 'fnm must start empty')
        if shutil.which('fnm'):
            run(*runtime, 'node', '--version', success=False)
        run('bash', 'scripts/bootstrap.sh', 'stow')
        first = run('just', 'bootstrap', 'pi')
        require('Install Node 24 with fnm' in first, 'Fresh setup must install Node')
        require('Install Pi dependencies' in first, 'Fresh setup must install dependencies')
        require(run(*runtime, 'node', '--version').strip().startswith('v24.'), 'Expected Node 24')
        pi = repo / 'pi/.pi/agent/extensions'
        run(*runtime, 'npm', 'ls', '--prefix', str(pi), '--depth=0')
        run(*runtime, 'node', '--input-type=module', '-e',
            'const {createRequire} = await import("node:module"); '
            'const require = createRequire(process.argv[1]); '
            'await import(require.resolve("typebox")); console.log("Pi dependency import passed")',
            str(pi / 'package.json'))
        for source in (repo / 'fish/.config/fish/config.fish', pi / 'package.json',
                       pi / 'node_modules/typebox/package.json'):
            package = source.relative_to(repo).parts[0]
            target = home / source.relative_to(repo / package)
            require(target.resolve() == source.resolve(), f'Incorrect Stow target: {target}')

        account_shell = run('dscl', '.', '-read', '/Users/' + run('id', '-un').strip(), 'UserShell')
        shells = Path('/etc/shells').read_bytes()
        run('just', 'bootstrap', 'fish')
        require(run('dscl', '.', '-read', '/Users/' + run('id', '-un').strip(), 'UserShell') == account_shell,
                'Noninteractive setup changed the account shell')
        require(Path('/etc/shells').read_bytes() == shells, 'Noninteractive setup changed /etc/shells')

        run('fish', '--no-config', '-c',
            'source "$HOME/.config/fish/conf.d/00-homebrew.fish"; '
            'source "$HOME/.config/fish/conf.d/fnm.fish"; '
            'command -q brew; or exit 1; command -q fnm; or exit 1; '
            'node --version; npm --version')

        before = {str(path): snapshot(path) for path in (home, pi / 'node_modules')}
        second = run('bash', 'scripts/bootstrap.sh', 'stow') + run('just', 'bootstrap', 'pi')
        require('→' not in second, 'Second run unexpectedly performed setup work')
        require('Pi dependencies already installed' in second, 'Second run did not reuse dependencies')
        for path, state in before.items():
            require(snapshot(Path(path)) == state, f'Rerun changed installed state: {path}')

        conflict_home = base / 'conflicting home'
        config = conflict_home / '.config/fish/config.fish'
        config.parent.mkdir(parents=True)
        config.write_text('keep this existing config\n')
        env['HOME'] = str(conflict_home)
        output = run('just', 'bootstrap', 'stow', success=False)
        require('move or back up' in output, 'Conflict lacked recovery instructions')
        require(config.read_text() == 'keep this existing config\n', 'Existing config was overwritten')
        require(not (conflict_home / '.pi').exists(), 'Conflict preflight partially linked configs')
        print('✓ Existing dotfile preserved; no partial links created.', flush=True)
        print('Real setup integration passed: install, startup, rerun, and conflict preservation.', flush=True)


if __name__ == '__main__':
    main()
