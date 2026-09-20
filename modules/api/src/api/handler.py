"""Internal API served through an mTLS-terminating load balancer.

The load balancer verifies the client certificate against the trust store and
passes the verified subject on in a header. Verification proves only that our
CA signed the certificate, so this function additionally checks the subject
against an allow list fetched from Secrets Manager at runtime.
"""

import json
import logging
import os
from datetime import datetime, timezone
from http import HTTPStatus

import boto3

LOG = logging.getLogger()
LOG.setLevel(logging.INFO)

ALLOWED_CLIENTS_SECRET = os.environ["ALLOWED_CLIENTS_SECRET"]
CLIENT_SUBJECT_HEADER = "x-amzn-mtls-clientcert-subject"
MAX_MESSAGE_LENGTH = 4096

_secrets = boto3.client("secretsmanager")
_allowed_cache = None


def _log(level, request_id, event, **fields):
    """One JSON object per line, always carrying the request id."""
    LOG.log(level, json.dumps({"request_id": request_id, "event": event, **fields}))


def _allowed_clients():
    """Cached for the life of the execution environment, never baked into the package."""
    global _allowed_cache
    if _allowed_cache is None:
        payload = _secrets.get_secret_value(SecretId=ALLOWED_CLIENTS_SECRET)
        _allowed_cache = set(json.loads(payload["SecretString"])["allowed_common_names"])
    return _allowed_cache


def _common_name(subject):
    """Extract CN from an RFC 2253 subject such as CN=service,O=org."""
    for component in subject.split(","):
        key, _, value = component.strip().partition("=")
        if key.upper() == "CN":
            return value
    return None


def _respond(status, request_id, body):
    return {
        "statusCode": status.value,
        "statusDescription": f"{status.value} {status.phrase}",
        "isBase64Encoded": False,
        "headers": {
            "content-type": "application/json",
            "x-request-id": request_id,
        },
        "body": json.dumps(body),
    }


def handler(event, context):
    request_id = context.aws_request_id
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    method = event.get("httpMethod", "")

    _log(logging.INFO, request_id, "request_received", method=method, path=event.get("path"))

    if method != "POST":
        _log(logging.WARNING, request_id, "method_not_allowed", method=method)
        return _respond(HTTPStatus.METHOD_NOT_ALLOWED, request_id, {"error": "only POST is accepted"})

    subject = headers.get(CLIENT_SUBJECT_HEADER)
    if not subject:
        _log(logging.WARNING, request_id, "client_certificate_missing")
        return _respond(HTTPStatus.FORBIDDEN, request_id, {"error": "client certificate required"})

    common_name = _common_name(subject)
    try:
        allowed = _allowed_clients()
    except Exception as error:
        _log(logging.ERROR, request_id, "allow_list_unavailable", error=str(error))
        return _respond(HTTPStatus.INTERNAL_SERVER_ERROR, request_id, {"error": "internal error"})

    if common_name not in allowed:
        _log(logging.WARNING, request_id, "client_not_authorised", common_name=common_name)
        return _respond(HTTPStatus.FORBIDDEN, request_id, {"error": "client not authorised"})

    try:
        payload = json.loads(event.get("body") or "")
    except (TypeError, ValueError):
        _log(logging.WARNING, request_id, "body_not_json")
        return _respond(HTTPStatus.BAD_REQUEST, request_id, {"error": "body must be JSON"})

    if not isinstance(payload, dict):
        return _respond(HTTPStatus.BAD_REQUEST, request_id, {"error": "body must be a JSON object"})

    message = payload.get("message")
    if not isinstance(message, str) or not message.strip():
        _log(logging.WARNING, request_id, "message_invalid")
        return _respond(HTTPStatus.BAD_REQUEST, request_id, {"error": "message must be a non-empty string"})

    if len(message) > MAX_MESSAGE_LENGTH:
        return _respond(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, request_id, {"error": "message too long"})

    _log(logging.INFO, request_id, "request_accepted", common_name=common_name)

    return _respond(HTTPStatus.OK, request_id, {
        "message": message,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "request_id": request_id,
        "client": common_name,
    })
