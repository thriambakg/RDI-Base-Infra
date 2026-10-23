"""
Cognito auth triggers — protect an active console session (pilot lock).

Policy (drone / live-control threat model):
  - While the account has recent API activity, reject NEW sign-ins
    (PreAuthentication). A credential thief cannot kick the pilot mid-flight.
  - After idle timeout, or explicit logout that clears the lock, sign-in is allowed.
  - PostAuthentication stamps auth_session_epoch for API token checks.

We never GlobalSignOut in PreAuthentication (wrong-password DoS).
"""

from __future__ import annotations

import os
import time
from typing import Any

import boto3
from botocore.exceptions import ClientError

USER_PROFILES_TABLE = os.environ.get("USER_PROFILES_TABLE", "")
# No successful API activity within this window → treat session as idle; allow login.
AUTH_SESSION_IDLE_SECONDS = int(os.environ.get("AUTH_SESSION_IDLE_SECONDS", "900"))

dynamodb = boto3.client("dynamodb")


class SessionActiveError(Exception):
    """Raised from PreAuth to deny Cognito authentication."""


def lambda_handler(event: dict, context: Any) -> dict:
    trigger = event.get("triggerSource") or ""
    attrs = (event.get("request") or {}).get("userAttributes") or {}
    user_sub = attrs.get("sub") or ""
    user_name = event.get("userName") or ""

    print(f"[cognito-auth] trigger={trigger} userName={user_name!r} sub={user_sub!r}")

    if trigger.startswith("PreAuthentication_"):
        _reject_if_session_active(user_sub, user_name)
    elif trigger.startswith("PostAuthentication_"):
        _stamp_session(user_sub)

    return event


def _reject_if_session_active(user_id: str, user_name: str) -> None:
    if not USER_PROFILES_TABLE or not user_id:
        print("[cognito-auth] pre-auth skip: missing table or sub")
        return

    try:
        resp = dynamodb.get_item(
            TableName=USER_PROFILES_TABLE,
            Key={"user_id": {"S": user_id}},
            ProjectionExpression="auth_session_last_seen",
            ConsistentRead=True,
        )
    except Exception as e:
        print(f"[cognito-auth] pre-auth dynamo error user_id={user_id!r}: {e}")
        # Fail open on Dynamo errors so Cognito outage isn't a total lockout.
        return

    item = resp.get("Item") or {}
    last_raw = (item.get("auth_session_last_seen") or {}).get("N")
    if last_raw is None:
        print(f"[cognito-auth] pre-auth allow: no last_seen user_id={user_id!r}")
        return

    try:
        last_seen = int(last_raw)
    except (TypeError, ValueError):
        return

    age = int(time.time()) - last_seen
    if age < AUTH_SESSION_IDLE_SECONDS:
        print(
            f"[cognito-auth] pre-auth DENY active session user_id={user_id!r} "
            f"age_s={age} idle_s={AUTH_SESSION_IDLE_SECONDS} userName={user_name!r}"
        )
        raise SessionActiveError(
            "This account is already signed in on another device. "
            "Sign out there first, or wait until that session goes idle."
        )

    print(f"[cognito-auth] pre-auth allow: idle age_s={age} user_id={user_id!r}")


def _stamp_session(user_id: str) -> None:
    if not USER_PROFILES_TABLE or not user_id:
        print("[cognito-auth] post-auth skip: missing table or sub")
        return
    now = int(time.time())
    try:
        dynamodb.update_item(
            TableName=USER_PROFILES_TABLE,
            Key={"user_id": {"S": user_id}},
            UpdateExpression=(
                "SET auth_session_epoch = :e, auth_session_last_seen = :e"
            ),
            ExpressionAttributeValues={":e": {"N": str(now)}},
            ConditionExpression=(
                "attribute_not_exists(auth_session_epoch) OR auth_session_epoch <= :e"
            ),
        )
        print(f"[cognito-auth] post-auth epoch/last_seen={now} user_id={user_id!r}")
    except ClientError as e:
        print(f"[cognito-auth] post-auth dynamo note user_id={user_id!r}: {e}")
    except Exception as e:
        print(f"[cognito-auth] post-auth dynamo error user_id={user_id!r}: {e}")
