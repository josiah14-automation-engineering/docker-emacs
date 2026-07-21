"""Flight-test for systems-ide's Python glue-script tier.

Mirrors a one-off Fabric-style deployment script: plain stdlib only, no
fabric/paramiko dependency, matching this tier's no-project/no-
dependency-manager scope.
"""

import tasks

SERVICES = ["nginx", "app"]


def main() -> None:
    print(f"hostname: {tasks.run('hostname')}")
    for service in SERVICES:
        tasks.restart_service(service)


if __name__ == "__main__":
    main()
