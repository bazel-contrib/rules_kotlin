#!/usr/bin/env python3
"""Measure the checked-out rules with a dedicated, warm Bazel server."""

import argparse
import json
from pathlib import Path
import subprocess
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target")
    parser.add_argument("--label", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=6)
    parser.add_argument("--warmups", type=int, default=2)
    parser.add_argument("--memory", action="store_true", help="Force phase GCs; keep these runs separate from timing results")
    parser.add_argument("--diagnostic", action="store_true", help="Also collect Starlark CPU and server JFR profiles")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    workspace = Path(__file__).resolve().parents[2]
    bazel = ["bazel", f"--output_base={output / 'server'}", "--host_jvm_args=-Xmx4g"]

    for i in range(-args.warmups, args.runs):
        name = f"{args.label}-{'warm' if i < 0 else 'run'}-{abs(i)}"
        stem = output / name
        with Path(f"{stem}.clean.log").open("w") as log:
            subprocess.run(bazel + ["clean"], cwd=workspace, stdout=log, stderr=subprocess.STDOUT, check=True)
        command = bazel + [
            "build", "--nobuild", "--jobs=8", "--loading_phase_threads=8", "--noshow_progress",
            f"--profile={stem}.json.gz", f"--build_event_json_file={stem}.bep.json",
        ]
        if args.memory:
            command += [f"--memory_profile={stem}.memory", "--memory_profile_stable_heap_parameters=2,0"]
        if args.diagnostic:
            command += [f"--starlark_cpu_profile={stem}.pprof", "--experimental_command_profile=cpu"]
        with Path(f"{stem}.log").open("w") as log:
            start = time.monotonic()
            subprocess.run(command + [args.target], cwd=workspace, stdout=log, stderr=subprocess.STDOUT, check=True)
            wall = time.monotonic() - start
        with Path(f"{stem}.bep.json").open() as events:
            metrics = next(event["buildMetrics"] for event in map(json.loads, events) if "buildMetrics" in event)
        heap = subprocess.check_output(
            bazel + ["info", "used-heap-size-after-gc"], cwd=workspace, stderr=subprocess.DEVNULL, text=True,
        ).strip()
        if args.diagnostic:
            (output / "server" / "cpu.jfr").replace(Path(f"{stem}.jfr"))
        row = {
            "label": args.label, "iteration": i, "target": args.target,
            "client_wall_s": wall, "retained_heap": heap,
            "timing": metrics["timingMetrics"], "memory": metrics["memoryMetrics"],
            "targets": metrics["targetMetrics"], "packages": metrics["packageMetrics"],
            "actions_created": metrics["actionSummary"]["actionsCreated"],
        }
        with (output / "measurements.jsonl").open("a") as results:
            results.write(json.dumps(row) + "\n")
        print(json.dumps(row), flush=True)


if __name__ == "__main__":
    main()
