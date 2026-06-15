#!/usr/bin/env bash
#
# Comprehensive tests for the ansi script
# Run: bash test/ansi-test.sh
#
set -uo pipefail

# Force ANSI support so we don't need a real terminal
export ANSI_FORCE_SUPPORT=1

cd "${0%/*}/.." || exit 1
. ./ansi

_pass=0
_fail=0

# Use od -An -tx1 for portable hex dump
hex() {
    printf '%s' "$1" | od -An -tx1 | tr -d ' \n'
}

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        _pass=$((_pass + 1))
    else
        _fail=$((_fail + 1))
        printf 'FAIL: %s\n' "$desc" >&2
        printf '  expected (hex): %s\n' "$(hex "$expected")" >&2
        printf '  actual   (hex): %s\n' "$(hex "$actual")" >&2
        printf '  expected (str): %q\n' "$expected" >&2
        printf '  actual   (str): %q\n' "$actual" >&2
    fi
}

assert_exit() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        _pass=$((_pass + 1))
    else
        _fail=$((_fail + 1))
        printf 'FAIL: %s\n' "$desc" >&2
        printf '  expected exit: %s\n' "$expected" >&2
        printf '  actual exit:   %s\n' "$actual" >&2
    fi
}

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        _pass=$((_pass + 1))
    else
        _fail=$((_fail + 1))
        printf 'FAIL: %s\n' "$desc" >&2
        printf '  expected to contain: %q\n' "$needle" >&2
        printf '  actual:              %q\n' "$haystack" >&2
    fi
}

# ============================================================
# 1. Regression: basic color/style output
# ============================================================
echo "--- Basic color/style regression tests ---"

# Note: restore sequence for a single code is \E[XXm (no trailing semicolon)
# because the code does m="${m39}" → "39;" → "${m%;}" → "39"
out=$(ansi --no-newline --green "hello")
assert_eq "--green with --no-newline" "${ANSI_CSI}32mhello${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --bold "test")
assert_eq "--bold with --no-newline" "${ANSI_CSI}1mtest${ANSI_CSI}22m" "$out"

out=$(ansi --no-newline --red --bg-blue "text")
assert_eq "--red --bg-blue" "${ANSI_CSI}31m${ANSI_CSI}44mtext${ANSI_CSI}39;49m" "$out"

out=$(ansi --no-newline --italic "x")
assert_eq "--italic" "${ANSI_CSI}3mx${ANSI_CSI}23m" "$out"

out=$(ansi --no-newline --underline "x")
assert_eq "--underline" "${ANSI_CSI}4mx${ANSI_CSI}24m" "$out"

out=$(ansi --no-newline --inverse "x")
assert_eq "--inverse" "${ANSI_CSI}7mx${ANSI_CSI}27m" "$out"

out=$(ansi --no-newline --strike "x")
assert_eq "--strike" "${ANSI_CSI}9mx${ANSI_CSI}29m" "$out"

# ============================================================
# 2. Regression: default restore behavior
# ============================================================
echo "--- Default restore regression tests ---"

out=$(ansi --no-newline --green "test")
assert_contains "default restore includes foreground reset" "${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --bg-red "test")
assert_contains "default restore includes background reset" "${ANSI_CSI}49m" "$out"

out=$(ansi --no-newline --bold "test")
assert_contains "default restore includes normal" "${ANSI_CSI}22m" "$out"

# ============================================================
# 3. Regression: --no-restore behavior
# ============================================================
echo "--- --no-restore regression tests ---"

out=$(ansi --no-newline --no-restore --green "test")
assert_eq "--no-restore --green" "${ANSI_CSI}32mtest" "$out"

out=$(ansi --no-newline --no-restore --bold --red "test")
assert_eq "--no-restore --bold --red" "${ANSI_CSI}1m${ANSI_CSI}31mtest" "$out"

# ============================================================
# 4. Regression: --no-newline
# ============================================================
echo "--- --no-newline regression tests ---"

out=$(ansi --no-newline "plain text")
assert_eq "--no-newline plain" "plain text" "$out"

out=$(ansi -n "plain text")
assert_eq "-n plain" "plain text" "$out"

# Default: should have trailing newline (check last byte of file)
tmpfile=$(mktemp)
ansi "plain text" > "$tmpfile"
lastbyte=$(tail -c 1 "$tmpfile" | od -An -tx1 | tr -d ' \n')
rm -f "$tmpfile"
assert_eq "default has newline" "0a" "$lastbyte"

# ============================================================
# 5. -- separator tests
# ============================================================
echo "--- Separator tests ---"

out=$(ansi --no-newline --green -- "hello world")
assert_eq "-- stops option parsing" "${ANSI_CSI}32mhello world${ANSI_CSI}39m" "$out"

# -- with no text after
out=$(ansi --no-newline --green --)
assert_eq "-- with no text" "${ANSI_CSI}32m${ANSI_CSI}39m" "$out"

# -- followed by something that looks like an option
out=$(ansi --no-newline -- "--bold")
assert_eq "-- followed by option-like text" "--bold" "$out"

# ============================================================
# 6. Text argument edge cases
# ============================================================
echo "--- Text argument edge cases ---"

# Multiple text args
out=$(ansi --no-newline --green "hello" "world")
assert_eq "multiple text args" "${ANSI_CSI}32mhello world${ANSI_CSI}39m" "$out"

# Text with commas
out=$(ansi --no-newline "hello,world")
assert_eq "text with commas" "hello,world" "$out"

# Empty text
out=$(ansi --no-newline "")
assert_eq "empty text" "" "$out"

# Text that looks like an option (after --)
out=$(ansi --no-newline -- "--unknown-option")
assert_eq "option-like text after --" "--unknown-option" "$out"

# Text with percent signs (printf safety)
out=$(ansi --no-newline "100%done")
assert_eq "text with percent" "100%done" "$out"

out=$(ansi --no-newline "%s %d %x")
assert_eq "text with printf format specifiers" "%s %d %x" "$out"

# Text with backslashes
out=$(ansi --no-newline 'back\slash')
assert_eq "text with backslash" 'back\slash' "$out"

# ============================================================
# 7. Combined options: --title, --position, --color + text
# ============================================================
echo "--- Combined options tests ---"

out=$(ansi --no-newline --title="My Title" --green "hello")
expected="${ANSI_OSC}2;My Title${ANSI_ST}${ANSI_CSI}32mhello${ANSI_CSI}39m"
assert_eq "--title + --green + text" "$expected" "$out"

out=$(ansi --no-newline --position=5,10 --red "x")
expected="${ANSI_CSI}5;10H${ANSI_CSI}31mx${ANSI_CSI}39m"
assert_eq "--position + --red + text" "$expected" "$out"

# --title with commas in value (should not be confused with --position)
out=$(ansi --no-newline --title="a,b,c" "text")
expected="${ANSI_OSC}2;a,b,c${ANSI_ST}text"
assert_eq "--title with commas" "$expected" "$out"

# --title + --position + --color + --no-newline
out=$(ansi --no-newline --title="T" --position=1,1 --green "go")
expected="${ANSI_OSC}2;T${ANSI_ST}${ANSI_CSI}1;1H${ANSI_CSI}32mgo${ANSI_CSI}39m"
assert_eq "--title + --position + --green" "$expected" "$out"

# ============================================================
# 8. Invalid parameters
# ============================================================
echo "--- Invalid parameter tests ---"

# Invalid --rgb
ansi --no-newline --rgb=300,0,0 "x" 2>/dev/null
assert_exit "--rgb=300,0,0 fails" "1" "$?"

ansi --no-newline --rgb=abc,0,0 "x" 2>/dev/null
assert_exit "--rgb=abc,0,0 fails" "1" "$?"

ansi --no-newline --rgb=0,0,-1 "x" 2>/dev/null
assert_exit "--rgb=0,0,-1 fails" "1" "$?"

# Invalid --color
ansi --no-newline --color=300 "x" 2>/dev/null
assert_exit "--color=300 fails" "1" "$?"

ansi --no-newline --color=abc "x" 2>/dev/null
assert_exit "--color=abc fails" "1" "$?"

# Invalid --bg-color
ansi --no-newline --bg-color=999 "x" 2>/dev/null
assert_exit "--bg-color=999 fails" "1" "$?"

# Invalid --bg-rgb
ansi --no-newline --bg-rgb=0,0,256 "x" 2>/dev/null
assert_exit "--bg-rgb=0,0,256 fails" "1" "$?"

# Invalid --position
ansi --no-newline --position=abc,10 "x" 2>/dev/null
assert_exit "--position=abc,10 fails" "1" "$?"

ansi --no-newline --position=5,xyz "x" 2>/dev/null
assert_exit "--position=5,xyz fails" "1" "$?"

# Error messages on stderr
tmpfile=$(mktemp)
ansi --no-newline --rgb=300,0,0 "x" 2>"$tmpfile" || true
stderr_out=$(<"$tmpfile")
rm -f "$tmpfile"
assert_contains "--rgb error message on stderr" "0-255" "$stderr_out"

tmpfile=$(mktemp)
ansi --no-newline --color=abc "x" 2>"$tmpfile" || true
stderr_out=$(<"$tmpfile")
rm -f "$tmpfile"
assert_contains "--color error message on stderr" "0-255" "$stderr_out"

tmpfile=$(mktemp)
ansi --no-newline --position=abc,1 "x" 2>"$tmpfile" || true
stderr_out=$(<"$tmpfile")
rm -f "$tmpfile"
assert_contains "--position error message on stderr" "numeric" "$stderr_out"

# ============================================================
# 9. Report command error handling
# ============================================================
echo "--- Report error handling tests ---"

# Report with redirected stdin (not a tty) should fail gracefully
tmpfile=$(mktemp)
ansi --report-position < /dev/null 2>"$tmpfile"
rc=$?
stderr_out=$(<"$tmpfile")
rm -f "$tmpfile"
assert_exit "report with /dev/null stdin fails" "1" "$rc"
assert_contains "report /dev/null error message" "terminal on stdin" "$stderr_out"

# Report with /dev/null stdin (different command)
tmpfile=$(mktemp)
ansi --report-window-chars < /dev/null 2>"$tmpfile"
rc=$?
stderr_out=$(<"$tmpfile")
rm -f "$tmpfile"
assert_exit "report-window-chars with /dev/null fails" "1" "$rc"
assert_contains "report-window-chars error" "terminal on stdin" "$stderr_out"

# ============================================================
# 10. --rep= option (was broken with --rep=N pattern)
# ============================================================
echo "--- --rep= option test ---"

out=$(ansi --no-newline --rep=3)
assert_eq "--rep=3 outputs repeat code" "${ANSI_CSI}3b" "$out"

out=$(ansi --no-newline --repeat=5)
assert_eq "--repeat=5 outputs repeat code" "${ANSI_CSI}5b" "$out"

# ============================================================
# 11. --reset-ideogram (was calling non-existent function)
# ============================================================
echo "--- --reset-ideogram test ---"

out=$(ansi --no-newline --reset-ideogram)
assert_eq "--reset-ideogram outputs correct code" "${ANSI_CSI}65m" "$out"

out=$(ansi --no-newline --ideogram-right "x")
assert_eq "--ideogram-right + restore" "${ANSI_CSI}60mx${ANSI_CSI}65m" "$out"

# ============================================================
# 12. --font= option
# ============================================================
echo "--- --font= option test ---"

out=$(ansi --no-newline --font=3 "x")
assert_eq "--font=3" "${ANSI_CSI}13mx${ANSI_CSI}10m" "$out"

out=$(ansi --no-newline --font=0)
assert_eq "--font=0 resets font" "${ANSI_CSI}10m" "$out"

# ============================================================
# 13. Unknown options treated as text
# ============================================================
echo "--- Unknown option behavior ---"

out=$(ansi --no-newline --unknown-flag "text")
assert_eq "unknown option becomes text" "--unknown-flag text" "$out"

# ============================================================
# 14. --no-restore combined with --save-cursor
# ============================================================
echo "--- --no-restore + --save-cursor ---"

out=$(ansi --no-newline --save-cursor "x")
assert_contains "--save-cursor restores by default" "${ANSI_CSI}u" "$out"

out=$(ansi --no-newline --no-restore --save-cursor "x")
expected="${ANSI_CSI}sx"
assert_eq "--no-restore --save-cursor no restore" "$expected" "$out"

# ============================================================
# 15. --hide-cursor restore
# ============================================================
echo "--- --hide-cursor restore ---"

out=$(ansi --no-newline --hide-cursor "x")
assert_contains "--hide-cursor auto shows cursor" "${ANSI_CSI}?25h" "$out"

out=$(ansi --no-newline --no-restore --hide-cursor "x")
assert_eq "--no-restore --hide-cursor no show" "${ANSI_CSI}?25lx" "$out"

# ============================================================
# 16. --position edge cases
# ============================================================
echo "--- --position edge cases ---"

out=$(ansi --no-newline --position=)
assert_eq "--position= (empty)" "${ANSI_CSI}H" "$out"

out=$(ansi --no-newline --position=5)
assert_eq "--position=5 (row only)" "${ANSI_CSI}5H" "$out"

out=$(ansi --no-newline --position=3,7)
assert_eq "--position=3,7" "${ANSI_CSI}3;7H" "$out"

out=$(ansi --no-newline --position=,5)
assert_eq "--position=,5 (col only)" "${ANSI_CSI};5H" "$out"

# ============================================================
# 17. --color and --bg-color valid edge cases
# ============================================================
echo "--- --color edge cases ---"

out=$(ansi --no-newline --color=0)
assert_eq "--color=0" "${ANSI_CSI}38;5;0m${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --color=255)
assert_eq "--color=255" "${ANSI_CSI}38;5;255m${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --bg-color=42 "x")
assert_eq "--bg-color=42" "${ANSI_CSI}48;5;42mx${ANSI_CSI}49m" "$out"

# ============================================================
# 18. --rgb valid edge cases
# ============================================================
echo "--- --rgb edge cases ---"

out=$(ansi --no-newline --rgb=0,0,0)
assert_eq "--rgb=0,0,0" "${ANSI_CSI}38;2;0;0;0m${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --rgb=255,255,255)
assert_eq "--rgb=255,255,255" "${ANSI_CSI}38;2;255;255;255m${ANSI_CSI}39m" "$out"

out=$(ansi --no-newline --bg-rgb=128,64,32 "x")
assert_eq "--bg-rgb=128,64,32" "${ANSI_CSI}48;2;128;64;32mx${ANSI_CSI}49m" "$out"

# ============================================================
# 19. --bell
# ============================================================
echo "--- --bell test ---"

out=$(ansi --no-newline --bell)
assert_eq "--bell" $'\007' "$out"

# ============================================================
# 20. --reset option
# ============================================================
echo "--- --reset test ---"

out=$(ansi --no-newline --reset)
assert_contains "--reset contains resetColor" "${ANSI_CSI}0m" "$out"
assert_contains "--reset contains eraseDisplay" "${ANSI_CSI}2J" "$out"
assert_contains "--reset contains position 1,1" "${ANSI_CSI}1;1H" "$out"
assert_contains "--reset contains showCursor" "${ANSI_CSI}?25h" "$out"
assert_contains "--reset contains resetFont" "${ANSI_CSI}10m" "$out"

# ============================================================
# 21. --no-restore should NOT emit any restore codes
# ============================================================
echo "--- --no-restore suppresses all restore codes ---"

out=$(ansi --no-newline --no-restore --bold --italic --underline --red --bg-blue "x")
# Should only have the style codes and text, no restore sequence
expected="${ANSI_CSI}1m${ANSI_CSI}3m${ANSI_CSI}4m${ANSI_CSI}31m${ANSI_CSI}44mx"
assert_eq "--no-restore complex combo" "$expected" "$out"

# ============================================================
# 22. Multiple colors: last one wins, restore matches
# ============================================================
echo "--- Multiple colors ---"

out=$(ansi --no-newline --red --green --blue "x")
# All three color codes emitted, restore is single 39
expected="${ANSI_CSI}31m${ANSI_CSI}32m${ANSI_CSI}34mx${ANSI_CSI}39m"
assert_eq "multiple foreground colors" "$expected" "$out"

out=$(ansi --no-newline --bg-red --bg-green "x")
expected="${ANSI_CSI}41m${ANSI_CSI}42mx${ANSI_CSI}49m"
assert_eq "multiple background colors" "$expected" "$out"

# ============================================================
# Summary
# ============================================================
echo ""
echo "==============================="
echo "Passed: $_pass"
echo "Failed: $_fail"
echo "==============================="

if [[ $_fail -gt 0 ]]; then
    exit 1
fi
exit 0
