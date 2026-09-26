"""Stateful external-command doubles. This file never calls a real command."""
import json
import os
from pathlib import Path
import sys

name = Path(sys.argv[0]).name
args = sys.argv[1:]
state_dir = Path(os.environ['TEST_STATE'])
state_file = state_dir / 'state.json'
state = json.loads(state_file.read_text())
with (state_dir / 'calls.jsonl').open('a') as log:
    log.write(json.dumps([name, *args]) + '\n')


def done(code=0, output=''):
    state_file.write_text(json.dumps(state))
    if output:
        print(output)
    sys.exit(code)


if state.get('fail') == name:
    done(1, 'simulated dependency failure')
if name == 'curl' and state.get('install_homebrew'):
    installer = Path(args[args.index('-o') + 1])
    installer.write_text('ln -s "$TEST_STATE/driver" "$PATH/brew"\n')
    done()
if name == 'brew':
    if args in (['shellenv', 'bash'], ['shellenv', 'fish']):
        done()
    if args[:2] == ['bundle', 'check']:
        done(0 if state.get('bundle') else 1)
    if args[:2] == ['bundle', 'install']:
        state['bundle'] = True
        state['swiftbar'] = True
        done()
    if args[:2] == ['list', '--cask']:
        done(0 if state.get('swiftbar') else 1)
    if args[0] == 'install':
        package = args[-1]
        if package == 'swiftbar':
            state['swiftbar'] = True
        else:
            for tool in (['node', 'npm'] if package == 'node' else [package]):
                destination = Path(os.environ['PATH']) / tool
                if not destination.exists():
                    destination.symlink_to(state_dir / 'driver')
        done()
if name == 'uname':
    done(output={'-s': state.get('os', 'Darwin'), '-m': 'arm64', '-sm': 'Darwin arm64'}[args[0]])
if name == 'id':
    done(output='tester' if args == ['-un'] else '501')
if name in ('dscl', 'getent'):
    shell = state.get('shell', '/bin/zsh')
    done(output='UserShell: ' + shell if name == 'dscl' else 'tester:x:501:20::/tmp:' + shell)
if name == 'grep':
    # Only /etc/shells is mocked; the other patterns are handled in Python.
    if args[-1] == '/etc/shells':
        done(0 if state.get('registered') else 1)
    import re
    if args[-1].startswith('('):
        content = sys.stdin.read()
        pattern = args[-1]
    else:
        content = Path(args[-1]).read_text()
        pattern = args[-2]
    pattern = pattern.replace('[[:space:]]', r'\s')
    done(0 if re.search(pattern, content) else 1)
if name == 'sudo':
    if args[:2] == ['tee', '-a'] and args[2:] == ['/etc/shells']:
        sys.stdin.read()
        state['registered'] = True
        done()
if name == 'chsh':
    state['shell'] = args[-1]
    done()
if name == 'gh':
    if args[:2] == ['auth', 'status']:
        done(0 if state.get('auth', True) else 1)
    if args == ['extension', 'list']:
        done(output='\n'.join(state.get('extensions', [])))
    if args[:2] == ['extension', 'install']:
        state.setdefault('extensions', []).append(args[-1])
        done()
if name == 'stow':
    packages = [a for a in args if not a.startswith('--')]
    if state.get('conflict'):
        done(1, 'existing target is neither a link nor a directory: .config/fish/config.fish')
    if '--simulate' in args:
        done(output='LINK: example => repo/example' if any(p not in state.get('linked', []) for p in packages) else '')
    state['linked'] = sorted(set(state.get('linked', []) + packages))
    done()
if name == 'node':
    if args[0] == '-e':
        done(1 if state.get('old_node') else 0)
    done(output='v24.0.0')
if name == 'npm':
    if args == ['--version']:
        done(output='11.0.0')
    if args[0] == 'ci':
        (Path(args[args.index('--prefix')+1]) / 'node_modules').mkdir(exist_ok=True)
        state['npm'] = True
        done()
    if args[0] == 'ls':
        done(0 if state.get('npm') else 1)
if name == 'defaults':
    if args[0] == 'read':
        done(0 if state.get('plugins') else 1, state.get('plugins', ''))
    state['plugins'] = args[-1]
    done()
if name == 'launchctl':
    if args[0] == 'print':
        done(0 if (state.get('agent') if args[1].count('/') == 2 else state.get('gui', True)) else 1)
    if args[0] == 'bootstrap':
        state['agent'] = True
        done()
if name == 'pgrep':
    done(0 if state.get('running') else 1)
if name == 'osascript':
    state['running'] = False
    done()
if name == 'open':
    state['running'] = True
    done()
if name == 'fish':
    if 'contains' in args[-1]:
        done(0 if state.get('fish_path') else 1)
    state['fish_path'] = True
    done()
if name == 'just':
    done()  # bootstrap handoff, never run a real installer
# Fail closed for all unexpected invocations, including network commands.
done(97, f'UNEXPECTED COMMAND: {name} {args}')
