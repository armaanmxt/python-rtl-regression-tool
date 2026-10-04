import argparse
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parent.parent


def load_config(config_path):                     #config path is the location of the JSON file
    with config_path.open("r", encoding="utf-8") as file:          #Open the configuration file for reading and temporarily call the opened file file.  
        return json.load(file)                      #This reads the JSON and converts it into normal Python objects


def create_compile_command(config, run, output_file):
    command = [
        config["compiler"],
        config["systemverilog_flag"],
        "-s",
        run["top"],
        "-o",
        str(output_file),
    ]

    for parameter, value in run.get("parameters", {}).items():
        command.append(f"-P{parameter}={value}")

    for source in run["sources"]:
        command.append(str(PROJECT_ROOT / source))

    return command


def execute_command(command):
    return subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def count_test_results(output):
    passed = 0
    failed = 0

    for line in output.splitlines():
        if line.startswith("TEST_PASS"):
            passed += 1
        elif line.startswith("TEST_FAIL"):
            failed += 1

    return passed, failed


def run_regression(config):
    build_directory = PROJECT_ROOT / "build"
    build_directory.mkdir(exist_ok=True)

    results = []

    for index, run in enumerate(config["runs"], start=1):
        run_name = run["name"]

        expected_status = run.get(
            "expected_status",
            "PASS",
        )

        output_file = build_directory / f"{run_name}.vvp"

        print(
            f"\n[{index}/{len(config['runs'])}] "
            f"Running {run_name}"
        )

        compile_command = create_compile_command(
            config,
            run,
            output_file,
        )

        compile_process = execute_command(compile_command)

        if compile_process.returncode != 0:
            print("COMPILE_FAIL")
            print(compile_process.stderr)

            results.append(
                {
                    "name": run_name,
                    "defect_category": run.get(
                        "defect_category",
                        "none",
                    ),
                    "expected_status": expected_status,
                    "observed_status": "COMPILE_FAIL",
                    "status": "FAIL",
                    "passed_checks": 0,
                    "failed_checks": 0,
                    "compile_command": compile_command,
                    "simulation_command": [],
                    "compile_stderr": compile_process.stderr,
                    "simulation_stdout": "",
                    "simulation_stderr": "",
                }
            )

            continue

        simulation_command = [
            config["runtime"],
            str(output_file),
        ]

        simulation_process = execute_command(
            simulation_command
        )

        combined_output = (
            simulation_process.stdout
            + "\n"
            + simulation_process.stderr
        )

        print(simulation_process.stdout, end="")

        if simulation_process.stderr:
            print(simulation_process.stderr, end="")

        passed_checks, failed_checks = count_test_results(
            combined_output
        )

        if failed_checks > 0:
            observed_status = "FAIL"
        elif (
            simulation_process.returncode == 0
            and passed_checks > 0
        ):
            observed_status = "PASS"
        else:
            observed_status = "ERROR"

        if observed_status == expected_status:
            status = "PASS"
        else:
            status = "FAIL"

        print(
            f"RUN_STATUS | {run_name} "
            f"| expected={expected_status} "
            f"| observed={observed_status} "
            f"| result={status}"
        )

        results.append(
            {
                "name": run_name,
                "defect_category": run.get(
                    "defect_category",
                    "none",
                ),
                "expected_status": expected_status,
                "observed_status": observed_status,
                "status": status,
                "passed_checks": passed_checks,
                "failed_checks": failed_checks,
                "compile_command": compile_command,
                "simulation_command": simulation_command,
                "compile_stderr": compile_process.stderr,
                "simulation_stdout": simulation_process.stdout,
                "simulation_stderr": simulation_process.stderr,
            }
        )

    return results


def write_reports(results, report_name):
    reports_directory = PROJECT_ROOT / "reports"
    reports_directory.mkdir(exist_ok=True)

    total_runs = len(results)

    passed_runs = sum(
        result["status"] == "PASS"
        for result in results
    )

    failed_runs = total_runs - passed_runs

    total_checks = sum(
        result["passed_checks"] + result["failed_checks"]
        for result in results
    )

    passed_checks = sum(
        result["passed_checks"]
        for result in results
    )

    failed_checks = sum(
        result["failed_checks"]
        for result in results
    )

    defect_runs = sum(
        result["expected_status"] == "FAIL"
        for result in results
    )

    detected_defects = sum(
        result["expected_status"] == "FAIL"
        and result["status"] == "PASS"
        for result in results
    )

    generated_at = datetime.now(
        timezone.utc
    ).isoformat()

    summary = {
        "total_runs": total_runs,
        "passed_runs": passed_runs,
        "failed_runs": failed_runs,
        "total_checks": total_checks,
        "passed_checks": passed_checks,
        "failed_checks": failed_checks,
        "defect_runs": defect_runs,
        "detected_defects": detected_defects,
    }

    report_data = {
        "generated_at": generated_at,
        "summary": summary,
        "runs": results,
    }

    json_report = (
        reports_directory / f"{report_name}.json"
    )

    with json_report.open(
        "w",
        encoding="utf-8",
    ) as file:
        json.dump(report_data, file, indent=2)

    markdown_lines = [
        "# RTL Regression Report",
        "",
        f"Generated: {generated_at}",
        "",
        "## Summary",
        "",
        f"- Total runs: {total_runs}",
        f"- Passed runs: {passed_runs}",
        f"- Failed runs: {failed_runs}",
        f"- Total checks: {total_checks}",
        f"- Passed checks: {passed_checks}",
        f"- Failed checks: {failed_checks}",
        f"- Defects tested: {defect_runs}",
        f"- Defects detected: {detected_defects}",
        "",
        "## Individual Runs",
        "",
        (
            "| Run | Category | Expected | Observed | "
            "Result | Passed checks | Failed checks |"
        ),
        (
            "|---|---|---:|---:|---:|---:|---:|"
        ),
    ]

    for result in results:
        markdown_lines.append(
            f"| {result['name']} "
            f"| {result['defect_category']} "
            f"| {result['expected_status']} "
            f"| {result['observed_status']} "
            f"| {result['status']} "
            f"| {result['passed_checks']} "
            f"| {result['failed_checks']} |"
        )

    markdown_report = (
        reports_directory / f"{report_name}.md"
    )

    with markdown_report.open(
        "w",
        encoding="utf-8",
    ) as file:
        file.write("\n".join(markdown_lines) + "\n")

    return summary


def main():
    parser = argparse.ArgumentParser(
        description="Run the RTL regression suite."
    )

    parser.add_argument(
        "--config",
        default="configs/regression.json",
        help="Path to the regression JSON configuration.",
    )

    arguments = parser.parse_args()

    config_path = Path(arguments.config)

    if not config_path.is_absolute():
        config_path = PROJECT_ROOT / config_path

    config = load_config(config_path)

    results = run_regression(config)

    report_name = config.get(
        "report_name",
        "regression_results",
    )

    summary = write_reports(
        results,
        report_name,
    )

    print("\nREGRESSION COMPLETE")
    print(
        f"Runs: "
        f"{summary['passed_runs']}/"
        f"{summary['total_runs']} passed"
    )

    if summary["defect_runs"] > 0:
        print(
            f"Defects: "
            f"{summary['detected_defects']}/"
            f"{summary['defect_runs']} detected"
        )
    else:
        print(
            f"Checks: "
            f"{summary['passed_checks']}/"
            f"{summary['total_checks']} passed"
        )

    print(
        f"Report: reports/{report_name}.md"
    )

    if summary["failed_runs"] > 0:
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())