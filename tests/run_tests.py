# -*- coding: utf-8 -*-
"""Run the Balathstone headless test-suite under LuaJIT (via lupa).

    python tests/run_tests.py

Loads tests/mock_balatro.lua (a small Balatro/Steamodded simulation), then the
real Balathstone.lua entry point and every src/*.lua file, then runs
tests/test_cards.lua. Exit code is the number of failing tests.
"""
import os
import sys

from lupa import luajit21 as lupa

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__))).replace('\\', '/') + '/'


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    run = lua.eval('function(path, ...) return assert(loadfile(path))(...) end')
    run(ROOT + 'tests/mock_balatro.lua', ROOT)
    run(ROOT + 'Balathstone.lua')
    failures = run(ROOT + 'tests/test_cards.lua')
    sys.exit(int(failures or 0))


if __name__ == '__main__':
    main()
