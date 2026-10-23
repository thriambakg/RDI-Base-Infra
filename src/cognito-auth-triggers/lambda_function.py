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
    elif trigger.startswith("CustomMessage_"):
        _apply_custom_message(event)

    return event


def _apply_custom_message(event: dict) -> None:
    """Branded Cognito emails (signup verify link, resend, forgot password)."""
    trigger = event.get("triggerSource") or ""
    req = event.get("request") or {}
    link = req.get("linkParameter") or ""
    code = req.get("codeParameter") or ""
    # Cognito requires the exact placeholder(s) from the request in the body.
    # Link confirmation: both linkParameter and codeParameter must appear.
    if not code and not link:
        print(f"[cognito-auth] custom-message skip: no link/code for {trigger}")
        return

    if trigger in ("CustomMessage_SignUp", "CustomMessage_ResendCode"):
        event.setdefault("response", {})
        event["response"]["emailSubject"] = "Confirm your RDI account"
        event["response"]["emailMessage"] = _verification_email_html(link=link, code=code)
        print(f"[cognito-auth] custom-message verification email for {trigger}")
    elif trigger == "CustomMessage_ForgotPassword":
        event.setdefault("response", {})
        event["response"]["emailSubject"] = "Reset your RDI password"
        event["response"]["emailMessage"] = _forgot_password_email_html(code or link)
        print("[cognito-auth] custom-message forgot-password email")


def _verification_email_html(*, link: str, code: str) -> str:
    # Table layout + inline CSS for email clients.
    # Placeholders (e.g. {##Verify Email##}, {####}) are substituted by Cognito.
    cta = link or code
    code_fallback = ""
    if code and link:
        code_fallback = f"""
        <tr><td style="padding:0 32px 8px;text-align:center;">
          <p style="margin:0;font-size:12px;line-height:1.5;color:#64748b;">
            Prefer a code? Enter <strong style="color:#e2e8f0;letter-spacing:0.12em;">{code}</strong> in the app.
          </p>
        </td></tr>"""
    return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0b1220;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0b1220;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#0f172a;border:1px solid #1e293b;border-radius:12px;overflow:hidden;">
        <tr><td style="height:4px;background:#3b82f6;font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr><td style="padding:36px 32px 12px;text-align:center;">
          <div style="font-size:28px;font-weight:700;letter-spacing:0.08em;color:#f8fafc;">RDI</div>
          <div style="margin-top:6px;font-size:13px;color:#64748b;letter-spacing:0.04em;">Remote Drone Infrastructure</div>
        </td></tr>
        <tr><td style="padding:8px 32px 0;text-align:center;">
          <h1 style="margin:0;font-size:22px;line-height:1.35;font-weight:700;color:#f8fafc;">Confirm your email</h1>
          <p style="margin:14px 0 0;font-size:15px;line-height:1.6;color:#94a3b8;">
            Welcome to RDI. Verify your email to finish setting up your account and open the console.
          </p>
        </td></tr>
        <tr><td style="padding:28px 32px 12px;text-align:center;">
          <div style="display:inline-block;background:#3b82f6;color:#ffffff;font-size:15px;font-weight:600;padding:14px 28px;border-radius:6px;">
            {cta}
          </div>
        </td></tr>
        {code_fallback}
        <tr><td style="padding:16px 32px 28px;text-align:center;">
          <p style="margin:0;font-size:13px;line-height:1.55;color:#64748b;">
            If you did not create an RDI account, you can ignore this message.
          </p>
        </td></tr>
        <tr><td style="padding:16px 32px 24px;border-top:1px solid #1e293b;text-align:center;">
          <p style="margin:0;font-size:12px;color:#475569;">&copy; RDI</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""


def _forgot_password_email_html(verify_token: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width"></head>
<body style="margin:0;padding:0;background:#0b1220;font-family:Arial,Helvetica,sans-serif;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#0b1220;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#0f172a;border:1px solid #1e293b;border-radius:12px;overflow:hidden;">
        <tr><td style="height:4px;background:#3b82f6;font-size:0;line-height:0;">&nbsp;</td></tr>
        <tr><td style="padding:36px 32px 12px;text-align:center;">
          <div style="font-size:28px;font-weight:700;letter-spacing:0.08em;color:#f8fafc;">RDI</div>
        </td></tr>
        <tr><td style="padding:8px 32px 0;text-align:center;">
          <h1 style="margin:0;font-size:22px;font-weight:700;color:#f8fafc;">Reset your password</h1>
          <p style="margin:14px 0 0;font-size:15px;line-height:1.6;color:#94a3b8;">
            Use the code below to choose a new password for your RDI account.
          </p>
        </td></tr>
        <tr><td style="padding:28px 32px;text-align:center;">
          <div style="display:inline-block;background:#1e293b;border:1px solid #334155;color:#f8fafc;font-size:22px;font-weight:700;letter-spacing:0.2em;padding:14px 28px;border-radius:6px;">
            {verify_token}
          </div>
        </td></tr>
        <tr><td style="padding:0 32px 28px;text-align:center;">
          <p style="margin:0;font-size:13px;color:#64748b;">If you did not request a reset, you can ignore this email.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>"""


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
