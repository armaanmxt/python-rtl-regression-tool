# Python RTL Regression Tool

A Python-based regression runner for SystemVerilog designs using Icarus Verilog. The tool reads JSON test configurations, compiles and simulates each design, checks testbench results, and generates Markdown and JSON reports.

The project includes parameterized counter, ALU, and synchronous FIFO designs with self-checking testbenches. A separate defect suite evaluates whether those testbenches detect intentionally introduced RTL bugs.

## Why I Built This

Running individual simulations manually becomes repetitive when testing multiple designs and parameter combinations. This project automates that process and provides a consistent way to review results.

It also explores an important verification question: passing tests demonstrate that the tested cases work, but can those same tests detect a faulty implementation?

## Features

- JSON-configured simulation runs.
- Automated compilation with `iverilog` and simulation with `vvp`.
- Testbench parameter overrides for different widths and FIFO depths.
- Parsing of `TEST_PASS` and `TEST_FAIL` messages.
- Comparison of expected and observed run outcomes.
- Markdown summaries and detailed JSON reports.
- Deliberately faulty RTL implementations for evaluating defect detection.
- Nonzero exit status when a run does not match its expected outcome.

## Designs and Tests

| Design | Configurations | Test scenarios |
|---|---|---|
| Counter | 4-bit and 8-bit | Reset, disabled hold, incrementing, and wraparound |
| ALU | 4-bit and 8-bit | Addition, subtraction, bitwise AND/OR, and addition overflow |
| FIFO | 8-bit × 4 entries; 16-bit × 8 entries | Reset, data ordering, full/empty flags, overflow/underflow protection, and simultaneous read/write |

The SystemVerilog testbenches apply stimulus and compare DUT outputs against expected values. Python handles simulation orchestration and reporting.

## Requirements

- Python 3.
- Icarus Verilog, with both `iverilog` and `vvp` available on your PATH.
- Git, if cloning the repository.

The Python runner uses only the standard library; no additional Python packages are required.

## Quick Start

Clone the repository and enter its directory:

```bash
git clone https://github.com/armaanmxt/python-rtl-regression-tool.git
cd python-rtl-regression-tool
```

Run the standard regression:

```bash
python3 scripts/regression.py
```

Run the injected-defect suite:

```bash
python3 scripts/regression.py --config configs/defects.json
```

On systems where Python is invoked as `python`, use that command instead of `python3`.

Compiled simulation files are written to `build/`. Reports are written to `reports/`.

## Recorded Results

The committed reports contain the following results:

| Suite | Runs matching expected outcome | Passed checks | Defects detected |
|---|---:|---:|---:|
| Standard regression | 6/6 | 64/64 | Not applicable |
| Injected-defect suite | 4/6 | 44/60 | 4/6 |

See the full reports:

- [Standard regression report](reports/regression_results.md)
- [Injected-defect report](reports/defect_results.md)

### Understanding Defect Results

Defect runs use `"expected_status": "FAIL"` because their RTL is intentionally faulty.

If a testbench detects the bug and reports a failure, the runner marks that defect run as `PASS`: the observed outcome matched the expected failure.

The recorded defect suite detected the counter reset and timing defects, along with the FIFO underflow and overflow defects. The injected ALU arithmetic and overflow defects were not detected by the existing test vectors, identifying areas where the tests need improvement.

These results describe the included tests and injected defects; they do not establish exhaustive verification or code coverage.

## Adding a Test

Add a run entry to the configuration's `runs` list:

```json
{
  "name": "counter_width_8",
  "top": "counter_tb",
  "sources": [
    "rtl/counter.sv",
    "testbenches/counter_tb.sv"
  ],
  "parameters": {
    "counter_tb.WIDTH": 8
  }
}
```

Each entry specifies the run name, top-level testbench, source files, and optional parameter overrides. Source paths are relative to the repository root.

Testbenches should print one result message for each check:

```text
TEST_PASS | counter | single_increment
TEST_FAIL | counter | reset | expected=0 actual=1
```

The runner counts lines beginning with `TEST_PASS` or `TEST_FAIL`. A successful simulation with at least one passing check and no failing checks is classified as `PASS`.

For an intentionally faulty design, add:

```json
"expected_status": "FAIL"
```

## Repository Structure

| Path | Purpose |
|---|---|
| `scripts/regression.py` | Compilation, simulation, result parsing, and reporting |
| `configs/regression.json` | Standard parameterized regression |
| `configs/defects.json` | Injected-defect runs |
| `rtl/` | Counter, ALU, and FIFO implementations |
| `rtl/defects/` | Intentionally faulty RTL variants |
| `testbenches/` | Self-checking SystemVerilog testbenches |
| `reports/` | Generated Markdown and JSON results |
| `build/` | Generated simulation executables |

## Current Limitations and Next Steps

- Tests use directed stimulus rather than randomized traffic.
- The runner executes simulations sequentially and does not enforce a timeout.
- The current ALU tests miss two injected defects.
- Waveform dumping and automated code coverage are not currently implemented.

Potential improvements include stronger ALU test vectors, simulation timeouts, randomized testing, waveform generation, and integration with GitHub Actions.
