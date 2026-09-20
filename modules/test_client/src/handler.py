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

# Set up once when the function starts, not on each call. Lambda keeps a
# function in memory between calls, so the certificate is fetched and prepared
# once and reused until the function is recycled.
_secrets = boto3.client("secretsmanager")
_context = None


def _log(level, request_id, event, **fields):
    LOG.log(level, json.dumps({"request_id": request_id, "event": event, **fields}))


def _tls_context():
    """Prepares the certificate this client presents and the authority it trusts."""
    global _context
    if _context is not None:
        return _context

    # One secret holding three things: the certificate to present, the key that
    # proves it is ours, and the CA certificate used to check the load balancer.
    identity = json.loads(_secrets.get_secret_value(SecretId=CLIENT_IDENTITY_SECRET)["SecretString"])

    # Python's TLS library loads these from files rather than from memory, and
    # /tmp is the only place a Lambda function is allowed to write.
    paths = {}
    for field in ("certificate", "private_key", "ca"):
        handle = tempfile.NamedTemporaryFile(mode="w", suffix=".pem", dir="/tmp", delete=False)
        handle.write(identity[field])
        handle.close()
        paths[field] = handle.name

    # Naming a CA file here replaces the list of public certificate authorities
    # Python normally trusts, rather than adding to it. This client therefore
    # trusts our CA alone and would reject any load balancer but ours.
    context = ssl.create_default_context(cafile=paths["ca"])
    # The certificate this client presents when the load balancer asks for one.
    context.load_cert_chain(certfile=paths["certificate"], keyfile=paths["private_key"])
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    _context = context
    return _context


def handler(event, context):
    request_id = context.aws_request_id
    message = (event or {}).get("message", "hello from the in-vpc client")

    # An ordinary POST. Nothing here concerns certificates: the mutual TLS setup
    # is handed to the call below instead.
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
        # The API answered and refused, so the handshake succeeded. A 403 here
        # is a meaningful result, so it is returned rather than raised.
        body = error.read().decode(errors="replace")
        _log(logging.WARNING, request_id, "call_rejected", status=error.code, body=body)
        return {"status": error.code, "body": body}
    except Exception as error:
        # Anything else means the connection or the handshake failed. Re-raised
        # so the invocation is recorded as an error rather than a response.
        _log(logging.ERROR, request_id, "call_failed", error=str(error))
        raise
