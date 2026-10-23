"""
Cognito PostAuthentication trigger — single active login stamp.

On each successful sign-in (email/password or Hosted UI / Google), write
auth_session_epoch to the user-profiles table. Application APIs reject access
tokens whose JWT auth_time is older than that epoch, so a newer login
supersedes older browser/device sessions.

We intentionally do NOT call AdminUserGlobalSignOut in PreAuthentication:
that would run before password verification and could sign out a legitimate
session when an attacker tries the victim's email with a wrong password.
"""

from __future__ import annotations

import os
import time
from typing import Any

import boto3

USER_PROFILES_TABLE = os.environ.get("USER_PROFILES_TABLE", "")

dynamodb = boto3.client("dynamodb")


def lambda_handler(event: dict, context: Any) -> dict:
    trigger = event.get("triggerSource") or ""
    attrs = (event.get("request") or {}).get("userAttributes") or {}
    user_sub = attrs.get("sub") or ""
    user_name = event.get("userName") or ""

    print(f"[cognito-auth] trigger={trigger} userName={user_name!r} sub={user_sub!r}")

    if trigger.startswith("PostAuthentication_"):
        _stamp_session(user_sub)

    return event


def _stamp_session(user_id: str) -> None:
    if not USER_PROFILES_TABLE or not user_id:
        print("[cognito-auth] post-auth skip: missing table or sub")
        return
    # Wall clock; JWT auth_time is within ~1s. APIs allow 2s skew.
    epoch = int(time.time())
    try:
        dynamodb.update_item(
            TableName=USER_PROFILES_TABLE,
            Key={"user_id": {"S": user_id}},
            UpdateExpression="SET auth_session_epoch = :e",
            ExpressionAttributeValues={":e": {"N": str(epoch)}},
            # Never move the epoch backwards if an API claim already advanced it.
            ConditionExpression="attribute_not_exists(auth_session_epoch) OR auth_session_epoch <= :e",
        )
        print(f"[cognito-auth] auth_session_epoch={epoch} user_id={user_id!r}")
    except Exception as e:
        # ConditionalCheckFailed = a newer session already claimed; fine.
        print(f"[cognito-auth] post-auth dynamo note user_id={user_id!r}: {e}")
