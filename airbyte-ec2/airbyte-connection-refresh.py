#!/usr/bin/env python3
"""Trigger an Airbyte connection refresh via SSM. Proven on 2026-09-20.

WHY THIS EXISTS
  When a MySQL CDC connector's binlog offset expires ("Saved offset no longer
  present on the server"), the connection fails every sync forever with a
  config_error. No retry, restart or control-plane bounce can repair it -- only a
  refresh that re-snapshots the source and saves a fresh offset.

TWO TRAPS THIS SCRIPT ENCODES
  1. The enum is `Truncate` / `Merge` -- CAPITALISED. Passing "TRUNCATE" returns
     HTTP 400. (Read /api/v1/openapi with a bearer token to settle any schema
     question rather than guessing.)
  2. Pick the mode from the destination sync mode, which lives under SNAKE_CASE
     keys in the stored catalog (`destination_sync_mode`; camelCase silently
     returns null and makes it look unconfigured):
       - `append`       -> Truncate   (Merge would stack duplicate rows)
       - `append_dedup` -> Merge is safe
     Both Ammo Depot connections are `incremental -> append`, so: Truncate.

WHAT TO EXPECT (measured on Magento: 21 streams, 85M rows)
  - Source reads everything and exits 0 in ~5 min; a fresh CDC offset is saved.
  - Freshness recovers immediately; generation-0 stays readable the whole time,
    so downstream BI never sees an empty table.
  - THEN a cleanup phase deletes old-generation files one Iceberg commit at a
    time: ~21 files/min against ~22k files on the big tables = 16-18 HOURS, and
    Airbyte runs NO incremental syncs for that connection until it finishes.
    On 2026-09-20 we cancelled it (DELETE /api/public/v1/jobs/<id>) to get
    incrementals back, accepting landing-table bloat that Silver's
    QUALIFY ROW_NUMBER() dedup already neutralises. See Linear TRI-9 / TRI-14.

  Give the host headroom first: the snapshot wants ~5 GiB source + ~5 GiB
  destination. c6a.2xlarge (~7.6 GiB free) is NOT enough; resize to c6a.4xlarge
  and back, using the graceful shutdown in CLAUDE.md.

USAGE
  ./airbyte-ec2/airbyte-connection-refresh.py <connection-uuid> [Truncate|Merge]
"""
import json
import subprocess
import sys
import time

PROFILE, REGION = "ammodepot", "us-east-1"
INSTANCE = "i-075043415ebad732f"


def aws(*args: str) -> str:
    return subprocess.run(
        ["aws", *args, "--profile", PROFILE, "--region", REGION],
        capture_output=True, text=True, check=True,
    ).stdout.strip()


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    conn, mode = sys.argv[1], (sys.argv[2] if len(sys.argv) > 2 else "Truncate")
    if mode not in ("Truncate", "Merge"):
        print(f"refreshMode must be 'Truncate' or 'Merge' (capitalised), got {mode!r}")
        return 2

    # Credentials are read and used ON THE BOX; they never cross this process.
    # Same mechanism as lambda/airbyte_auto_remediate/ssm-payloads/capture_evidence.json.tmpl.
    ns = "airbyte-abctl"
    k = "sudo docker exec airbyte-abctl-control-plane kubectl get secret -n %s airbyte-auth-secrets" % ns
    cmds = [
        "set -u",
        f"CID=$({k} -o jsonpath='{{.data.instance-admin-client-id}}' | base64 -d)",
        f"CSEC=$({k} -o jsonpath='{{.data.instance-admin-client-secret}}' | base64 -d)",
        'TOKEN=$(jq -nc --arg i "$CID" --arg s "$CSEC" '
        "'{client_id:$i,client_secret:$s,\"grant-type\":\"client_credentials\"}'"
        ' | curl -fsS -X POST http://localhost:8000/api/v1/applications/token'
        ' -H "Content-Type: application/json" -d @- | jq -r .access_token)',
        'if [ -z "$TOKEN" ] || [ "$TOKEN" = null ]; then echo TOKEN_FAILED; exit 1; fi',
        "echo TOKEN_OK",
        f'CODE=$(jq -nc --arg c "{conn}" --arg m "{mode}"'
        " '{connectionId:$c,refreshMode:$m}'"
        ' | curl -s -o /tmp/ref.out -w "%{http_code}" -m 120'
        ' -X POST http://localhost:8000/api/v1/connections/refresh'
        ' -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d @-)',
        'echo "REFRESH_HTTP=$CODE"',
        "head -c 500 /tmp/ref.out; echo",
    ]

    cmd_id = aws("ssm", "send-command", "--instance-ids", INSTANCE,
                 "--document-name", "AWS-RunShellScript", "--timeout-seconds", "300",
                 "--cli-input-json", json.dumps({"Parameters": {"commands": cmds}}),
                 "--query", "Command.CommandId", "--output", "text")
    print(f"SSM command {cmd_id} — refreshing {conn} with mode={mode}")

    while True:
        status = aws("ssm", "get-command-invocation", "--command-id", cmd_id,
                     "--instance-id", INSTANCE, "--query", "Status", "--output", "text")
        if status != "InProgress":
            break
        time.sleep(5)

    print(aws("ssm", "get-command-invocation", "--command-id", cmd_id,
              "--instance-id", INSTANCE, "--query", "StandardOutputContent",
              "--output", "text"))
    print("HTTP 200 means the streams are MARKED for refresh; the work happens on the\n"
          "connection's NEXT scheduled sync, which appears as config_type='refresh'.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
