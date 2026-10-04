## Commands

- run: n/a: collection of scripts, no single entry point
- test: `git ls-files '*.lua' | xargs luac -p`
- test-changed: `scripts/test_changed.sh`
- lint: `shellcheck install.sh uninstall.sh scripts/*.sh`
- coverage: n/a: no coverage tooling for Lua/redscript mods
- coverage-gaps: n/a: no coverage report exists
