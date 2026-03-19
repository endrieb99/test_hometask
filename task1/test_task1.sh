#!/usr/bin/env bash
 
SCRIPT="$(dirname "$0")/task1.sh"
PASS=0
FAIL=0

source "$SCRIPT"

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

echo "= Tests for task1.sh ="
echo ""
 
# Test 1: Script exists and is executable
echo "[1] script exists and is executable"
if [[ -x "$SCRIPT" ]]; then pass "script is executable"
else fail "script not found or not executable"; fi
 
# Test 2: Prints exactly 10 lines of ouput
echo "[2] output has exactly 10 lines"
count=$(bash "$SCRIPT" | wc -l | tr -d ' ')
if [[ "$count" -eq 10 ]]; then pass "output line count == 10"
else fail "expected 10 lines, got $count"; fi
 
# Test 3: Each number 1-10 appears only once
echo "[3] output contains each number 1-10 only once"
output=$(bash "$SCRIPT" | sort -n | tr '\n' ' ' | sed 's/ $//')
expected="1 2 3 4 5 6 7 8 9 10"
if [[ "$output" == "$expected" ]]; then pass "sorted output matches expected: $expected"
else fail "expected '$expected', got '$output'"; fi
 
# Test 4: Output contains only integers from 1 to 10
echo "[4] output contains only integers in range [1, 10]"
non_int=$(bash "$SCRIPT" | grep -cvP '^[1-9]$|^10$' || true)
if [[ "$non_int" -eq 0 ]]; then pass "all the output values are in the range [1, 10]"
else fail "non integer values found or values out of range"; fi
 
# Test 5: Order is non-deterministic
echo "[5] output is non-deterministic across multiple runs"
results=()
for i in 1 2 3 4 5; do
    results+=("$(bash "$SCRIPT" | tr '\n' ' ')")
done
unique=$(printf '%s\n' "${results[@]}" | sort -u | wc -l | tr -d ' ')
if [[ "$unique" -gt 1 ]]; then pass "got $unique different orderings across 5 runs"
else fail "all 5 runs produced the same output"; fi
 
# Test 6: Script exits with code 0
echo "[6] exit code == 0 in case of success"
bash "$SCRIPT" > /dev/null 2>&1
code=$?
if [[ "$code" -eq 0 ]]; then pass "exit code == 0"
else fail "expected exit code 0, got $code"; fi

# ---- Checking array length and content validation ----

# Test 7: Rejects array lengths < 10
echo "[7] array length < 10 raises error"
numbers=(1 2 3 4 5 6 7 8 9)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "array length < 10 raises error"
else fail "array length < 10 did not raise error"; fi

# Test 8: Rejects array lengths > 10
echo "[8] array length > 10 raises error"
numbers=(1 2 3 4 5 6 7 8 9 10 11)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "array length > 10 raises error"
else fail "array length > 10 did not raise error"; fi

# Test 9: Rejects non integer input
echo "[9] non integer input raises error"
numbers=(1 2 3 4 5 6 7 8 9 abc)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "non integer input raises error"
else fail "non integer input did not raise error"; fi

# Test 10: Rejects out of range input
echo "[10] out of range input raises error"
numbers=(1 2 3 4 5 6 7 8 9 99)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "out of range input raises error"
else fail "out of range input did not raise error"; fi

# Test 11: Rejects negative integers
echo "[11] negative integer raises error"
numbers=(1 2 3 4 5 6 7 8 9 -1)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "negative integer raises error"
else fail "negative integer did not raise error"; fi

# Test 12: Rejects float values
echo "[12] float input raises error"
numbers=(1 2 3 4 5 6 7 8 9 1.5)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "float input raises error"
else fail "float input did not raise error"; fi

# Test 13: Rejects leading zeros
echo "[13] leading zero raises error"
numbers=(1 2 3 4 5 6 7 8 9 01)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "leading zero raises error"
else fail "leading zero did not raise error"; fi

# Test 14: Rejects duplicate values
echo "[14] duplicate values raise error"
numbers=(1 2 3 4 5 6 7 8 9 9)
err=$(check_array 2>&1 || true)
if echo "$err" | grep -q "Error:"; then pass "duplicate values raise error"
else fail "duplicate values did not raise error"; fi

# --- Error handling ---

# Test 15: Error messages go to stderr not stdout
echo "[15] errors written to stderr"
numbers=(1 2 3)
stdout=$(check_array 2>/dev/null || true)
if [[ -z "$stdout" ]]; then pass "errors written to stderr"
else fail "errors written to stdout instead of stderr: $stdout"; fi

# Test 16: Exits with code 1 on validation failure
echo "[16] exit code == 1 on validation failure"
numbers=(1 2 3)
check_array > /dev/null 2>&1 || code=$?
if [[ "${code:-0}" -eq 1 ]]; then pass "exit code == 1 on validation failure"
else fail "expected exit code 1, got ${code:-0}"; fi

# Reset array to valid state after all tests
numbers=(1 2 3 4 5 6 7 8 9 10)

echo ""
echo "= Results: $PASS passed, $FAIL failed ="
exit $FAIL
 