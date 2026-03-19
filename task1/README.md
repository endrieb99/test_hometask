# Task 1 - Shuffle Numbers

The aim of this task is to design a script that prints the numbers 1-10 in random order, with each number appearing only once.

---

## Project Structure

```
.
|-- task1.sh        # main script
|-- test_task1.sh   # tests for the script
|-- README.md       # documentation
```

---

## Build Instructions

No compilation or installation required. The only dependency is **Bash ≥ 4.0**.

Make both scripts executable:

```bash
chmod +x task1.sh test_task1.sh
```

To verify your Bash version:

```bash
bash --version
```

---

## Usage

Run the script directly:

```bash
./task1.sh
```

**Example output:**

```text
$ ./task1.sh
1
10
2
5
4
9
8
3
6
7
```

Each run produces a different random order of the numbers 1-10, one per line.

---

## Running the Tests

```bash
./test_task1.sh
```

**Expected output:**

```text
= Tests for task1.sh =

[1] script exists and is executable
  PASS: script is executable
[2] output has exactly 10 lines
  PASS: output line count == 10
[3] output contains each number 1-10 only once
  PASS: sorted output matches expected: 1 2 3 4 5 6 7 8 9 10
[4] output contains only integers in range [1, 10]
  PASS: all the output values are in the range [1, 10]
[5] output is non-deterministic across multiple runs
  PASS: got 5 different orderings across 5 runs
[6] exit code == 0 in case of success
  PASS: exit code == 0
[7] array length < 10 raises error
  PASS: array length < 10 raises error
[8] array length > 10 raises error
  PASS: array length > 10 raises error
[9] non integer input raises error
  PASS: non integer input raises error
[10] out of range input raises error
  PASS: out of range input raises error
[11] negative integer raises error
  PASS: negative integer raises error
[12] float input raises error
  PASS: float input raises error
[13] leading zero raises error
  PASS: leading zero raises error
[14] duplicate values raise error
  PASS: duplicate values raise error
[15] errors written to stderr
  PASS: errors written to stderr
[16] exit code == 1 on validation failure
  PASS: exit code == 1 on validation failure

= Results: 16 passed, 0 failed =
```

The test suite covers: script setup, output correctness, array length validation, integer and range validation, duplicate detection, and Unix error handling conventions.

---

## Description

`task1.sh` implements a Fisher-Yates shuffle directly in Bash. The algorithm iterates through the array from the last element down to the first, swapping each element with a randomly chosen element at or before its position. This guarantees a uniformly random permutation in O(n) time.

The script is structured in three functions:
- `check_array` — validates the array length, element range, and duplicates before shuffling
- `shuffle` — performs Fisher-Yates shuffle on the array
- `main` — orchestrates validation, shuffle, and output

A `BASH_SOURCE` guard ensures `main` only runs when the script is executed directly, not when sourced by the test suite. This makes each function independently testable without side effects.

`$RANDOM` is an internal Bash variable used to generate a random decimal integer number. It is used in the shuffle function to generate a random index for each swap.

---

## Test Design

The test suite sources `task1.sh` directly via `source "$SCRIPT"` rather than spawning subshells or temp files for each validation test. This allows `check_array` to be called directly with controlled input, keeping tests fast, readable, and independent of implementation details outside the function itself.

A `BASH_SOURCE` guard in `task1.sh` ensures that sourcing the script never triggers `main`, so no side effects occur during the test run.

---

## Known Limitations / Bugs

- **`$RANDOM` is not cryptographically secure.** Bash's built-in PRNG has a range of 0-32767 and is not suitable for security-sensitive applications. For cryptographic use cases, a language with a crypto-grade RNG should be used instead.

- **Slight modulo bias.** Using `RANDOM % (i + 1)` introduces a minor bias when `i + 1` does not evenly divide 32768. For a 10-element array this bias is negligible in practice, but the distribution is not perfectly uniform in a strict mathematical sense.

- **`$RANDOM` does not scale to large arrays.** `$RANDOM` generates values in the range 0-32767. For arrays larger than 32767 elements, some indices would become completely unreachable, not just biased but mathematically impossible to reach. For this task with 10 elements this is not an issue, but the script cannot be extended to large arrays without replacing `$RANDOM` with a stronger RNG.

- **Bash ≥ 4.0 required.** The script uses indexed arrays and arithmetic expressions not available in POSIX `sh` or Bash 3.x, for example the default `/bin/sh` on older macOS versions.

- **Array is hardcoded.** The numbers array is defined inside the script rather than accepted as input. This is intentional for the scope of this task, but would need to change if the script were extended to support arbitrary ranges or external input.

- **Test 5 has a theoretical false-failure rate.** The test runs the script 5 times and checks that at least 2 runs produce a different ordering. There is a very small chance that all 5 runs produce the same order by pure luck, which would cause the test to fail even though the script is working correctly.
