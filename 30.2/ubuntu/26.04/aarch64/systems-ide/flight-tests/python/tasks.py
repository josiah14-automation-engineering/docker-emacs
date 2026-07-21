"""Small stdlib-only helpers a one-off deployment script might use."""

import subprocess


def run(command: str) -> str:
    """Run COMMAND in a subshell and return its stdout, stripped."""
    result = subprocess.run(
        command, shell=True, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def restart_service(name: str) -> None:
    print(f"would restart: {name}")
