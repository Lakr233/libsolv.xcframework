#!/usr/bin/env python3
"""Validate every architecture, including arm64e, against its declared OS floor."""
import pathlib, plistlib, re, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parent.parent
framework = root / 'BinaryTarget/CLibSolv.xcframework'
info = plistlib.loads((framework / 'Info.plist').read_bytes())
expected = {
    ('macos', ''): {'x86_64': '10.13', 'arm64': '11.0'},
    ('ios', 'maccatalyst'): {'x86_64': '13.1', 'arm64': '14.0'},
    ('ios', ''): {'arm64': '12.0', 'arm64e': '14.0'},
    ('ios', 'simulator'): {'x86_64': '12.0', 'arm64': '14.0'},
    ('tvos', ''): {'arm64': '12.0'},
    ('tvos', 'simulator'): {'x86_64': '12.0', 'arm64': '14.0'},
    ('watchos', ''): {'arm64_32': '5.0', 'arm64': '26.0'},
    ('watchos', 'simulator'): {'x86_64': '5.0', 'arm64': '7.0'},
    ('xros', ''): {'arm64': '1.0'},
    ('xros', 'simulator'): {'arm64': '1.0'},
}
def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL)
def version(value):
    return tuple(map(int, value.split('.'))) + (0,) * (3-len(value.split('.')))
assert len(info['AvailableLibraries']) == len(expected)
for library in info['AvailableLibraries']:
    key = (library['SupportedPlatform'], library.get('SupportedPlatformVariant', ''))
    arches = expected.pop(key)
    assert set(library['SupportedArchitectures']) == set(arches), key
    binary = framework / library['LibraryIdentifier'] / library['LibraryPath'] / 'CLibSolv'
    for arch, maximum in arches.items():
        with tempfile.TemporaryDirectory() as work:
            thin = pathlib.Path(work) / 'slice.a'
            if len(arches) > 1:
                subprocess.run(['lipo', str(binary), '-thin', arch, '-output', str(thin)], check=True)
            else:
                thin.write_bytes(binary.read_bytes())
            commands = run('otool', '-l', str(thin))
            floors = re.findall(r'\bminos (\d+(?:\.\d+)*)', commands)
            floors += re.findall(r'cmd LC_VERSION_MIN_\w+\s+cmdsize \d+\s+version (\d+(?:\.\d+)*)', commands)
            assert floors and max(map(version, floors)) <= version(maximum), (key, arch, set(floors), maximum)
            symbols = run('nm', '-u', str(thin))
            assert not re.search(r'\b_(strchrnul|Py\w*|ruby\w*|perl\w*|lzma_\w*)$', symbols, re.M)
            assert not re.search(rb'/(Users|home|opt/homebrew|usr/local)/', thin.read_bytes()), (key, arch, 'absolute path')
            print(key, arch, sorted(set(floors)))
assert not expected
for path in ['LICENSE', 'Licenses/libsolv-BSD.txt', 'Licenses/libsolv-source-notices.txt', 'Upstream.versions']:
    assert (framework / path).is_file(), path
