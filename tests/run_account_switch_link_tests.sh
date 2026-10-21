#!/bin/sh

set -eu

# Build the real account switch link parser/lockout as a macOS Foundation
# executable and run it.
test_repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_build_dir=$(mktemp -d "${TMPDIR:-/tmp}/apollo-account-switch-link-tests.XXXXXX")
test_binary="$test_build_dir/account_switch_link_tests"
trap 'rm -f -- "$test_binary"; rmdir -- "$test_build_dir"' EXIT HUP INT TERM

xcrun --sdk macosx clang -fobjc-arc -fblocks -Wall -Wextra -Werror \
    -fsanitize=address,undefined \
    -framework Foundation -framework Security \
    -I "$test_repo_root/src" \
    "$test_repo_root/src/ApolloAccountSwitchLink.m" \
    "$test_repo_root/tests/account_switch_link_tests.m" \
    -o "$test_binary"

"$test_binary"
