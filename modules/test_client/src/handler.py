"""In-VPC test harness that calls the API over mutual TLS.

It exists to prove the path end to end from inside the VPC, because the
endpoint is not reachable from anywhere else. A real consumer would hold its
own certificate rather than fetching this one.
"""

import json
import logging
import os
import ssl
import tempfile
import urllib.error
import urllib.request

import boto3

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

CLIENT_IDENTITY_SECRET = os.environ["CLIENT_IDENTITY_SECRET"]
API_URL = os.environ["API_URL"]
TIMEOUT_SECONDS = 10

_secrets = boto3.client("secretsmanager")
_context = None


def _log(level, request_id, event, **fields):
    LOG.log(level, json.dumps({"request_id": request_id, "event": event, **fields}))


def _tls_context():
    """Built once per execution environment. /tmp is the only writable path."""
    global _context
    if _context is not None:
        return _context

    identity = json.loads(_secrets.get_secret_value(SecretId=CLIENT_IDENTITY_SECRET)["SecretString"])

    paths = {}
    for field in ("certificate", "private_key", "ca"):
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".pem", dir="/tmp", delete=False)
        handle.write(identity[field])
        handle.close()
        paths[field] = handle.name

    context = ssl.create_default_context(cafile=paths["ca"])
    context.load_cert_chain(certfile=paths["certificate"], keyfile=paths["private_key"])
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    _context = context
    return _context


def handler(event, context):
    request_id = context.aws_request_id
    message = (event or {}).get("message", "hello from the in-vpc client")

    request = urllib.request.Request(
        API_URL,
        data=json.dumps({"message": message}).encode(),
        headers={"content-type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS, context=_tls_context()) as response:
            body = json.loads(response.read())
            _log(logging.INFO, request_id, "call_succeeded", status=response.status)
            return {"status": response.status, "body": body}
    except urllib.error.HTTPError as error:
        body = error.read().decode(errors="replace")
        _log(logging.WARNING, request_id, "call_rejected", status=error.code, body=body)
        return {"status": error.code, "body": body}
    except Exception as error:
        _log(logging.ERROR, request_id, "call_failed", error=str(error))
        raise
