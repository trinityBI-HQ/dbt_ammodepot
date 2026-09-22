/* =============================================================================
   SVC_POWERBI — service account for the Power BI dataflow refresh
   Built 2026-09-22 during a ~7h Power BI outage.

   WHAT ACTUALLY WORKS — a PROGRAMMATIC ACCESS TOKEN presented to Power BI as a
   password ("Basic" in the connector). Everything else was tried and failed; the
   failures are recorded at the bottom so nobody repeats them.

   Verified 2026-09-22 by connecting with password=<token> and reading
   GOLD.F_SALES: ('SVC_POWERBI', 'DASHBOARD_VIEWER_ROLE', 'COMPUTE_WH').

       User          SVC_POWERBI, TYPE = SERVICE, owned by USERADMIN
       Role          DASHBOARD_VIEWER_ROLE       (granted by SECURITYADMIN)
       Warehouse     COMPUTE_WH
       Auth          PAT, role-restricted, 365-day expiry, sent as a password
       Network       POWERBI_SVC_NETWORK_POLICY attached to the user
   ============================================================================= */

-- =============================================================================
-- STEP 1 — the user.  USERADMIN.
-- Per .claude/rules/snowflake-standards.md: Users -> USERADMIN, grants of custom
-- roles -> SECURITYADMIN, and never a blanket USE ROLE ACCOUNTADMIN.
-- Skip if SVC_POWERBI already exists.
-- =============================================================================
use role useradmin;

create user if not exists svc_powerbi
    type              = service
    default_role      = dashboard_viewer_role
    default_warehouse = compute_wh
    comment           = 'Power BI dataflow refresh. Replaces RAFAELA (TYPE=PERSON, blocked by MFA enforcement 2026-09-22).';

alter user svc_powerbi set query_tag = 'powerbi-dataflow-refresh';

-- =============================================================================
-- STEP 2 — the role.  SECURITYADMIN owns DASHBOARD_VIEWER_ROLE, so it grants it.
--
-- Measured, not assumed: RAFAELA (the account Power BI used before) ran 5,721
-- queries in 3 days as DASHBOARD_VIEWER_ROLE on COMPUTE_WH, and that role grants
-- exactly what the dataflow reads —
--     SELECT  20 tables + 15 views   AD_ANALYTICS.GOLD
--     SELECT   4 views               AD_AIRBYTE.AD_REALTIME
--     SELECT   3 tables + 2 views    AD_ANALYTICS.OPS
-- COMPUTE_WH also keeps BI off ETL_WH, which carries ~552k dbt queries a week.
--
-- docs/snowflake_access_setup.md §11 says POWERBI_ROLE and ETL_WH. Both are
-- stale: that section was specced and never provisioned, so it was never
-- contrasted with reality. Update it.
-- =============================================================================
use role securityadmin;

grant role dashboard_viewer_role to user svc_powerbi;

-- =============================================================================
-- STEP 3 — THIS IS THE BLOCK THAT MADE IT WORK.
--
-- The network policy is not optional: PAT_POLICY carries
-- NETWORK_POLICY_EVALUATION = ENFORCED_REQUIRED, so issuing a token fails with
-- "Network Policy is required when creating a programmatic access token for user
-- SVC_POWERBI" until one is attached. Attach it to the USER, never the account.
-- =============================================================================
use role securityadmin;

create network policy if not exists powerbi_svc_network_policy
    allowed_ip_list = ('0.0.0.0/0')
    comment = 'Required by PAT_POLICY (NETWORK_POLICY_EVALUATION=ENFORCED_REQUIRED) for the Power BI service account. Power BI Service uses dynamic Azure egress IPs, so no meaningful CIDR restriction is possible without maintaining Microsoft service-tag ranges.';

use role useradmin;
alter user svc_powerbi set network_policy = powerbi_svc_network_policy;

use role accountadmin;
alter user svc_powerbi add programmatic access token pbi_refresh
    role_restriction = 'DASHBOARD_VIEWER_ROLE'
    days_to_expiry   = 365;

-- The token is returned ONCE. Capture it into the secret manager immediately —
-- Snowflake never shows it again, and there is no recovery, only reissue.

-- =============================================================================
-- STEP 4 — verify from the Snowflake side, not from Power BI's message.
-- =============================================================================
desc user svc_powerbi;
show grants to user svc_powerbi;

-- Fastest end-to-end check — the token is sent exactly as Power BI sends it:
--
--   python -c "
--   import snowflake.connector as sc
--   c = sc.connect(account='<account>', user='svc_powerbi',
--                  password='<the PAT>', warehouse='COMPUTE_WH')
--   cur = c.cursor(); cur.execute('select current_user(), current_role()')
--   print(cur.fetchone())"
--
-- Or, allowing for ACCOUNT_USAGE's ~45 min lag:
--
--   select user_name, is_success, first_authentication_factor, error_message,
--          convert_timezone('America/New_York', event_timestamp) as et
--   from snowflake.account_usage.login_history
--   where user_name = 'SVC_POWERBI' order by event_timestamp desc;

/* =============================================================================
   IN POWER BI
     Settings -> Data source credentials -> Edit credentials
       Authentication method   Basic
       User name               svc_powerbi
       Password                the PAT, in full
     Then trigger a manual refresh; do not wait for the schedule.

   Credentials in Power BI are PER DATAFLOW. Check every dataflow that hits
   Snowflake (there were five in this workspace) or some pages stay stale and it
   looks like the fix failed.

   =============================================================================
   WHAT DID NOT WORK — do not spend a night rediscovering this
   =============================================================================

   PASSWORD AUTH — impossible on this account.
     MFA is enforced account-wide for password sign-ins. Proven by a direct
     connection attempt, not inferred:
         250001 (08001): Multi-factor authentication is required for this
         account. Log in to Snowsight to enroll.
     Looks like counter-evidence but is not: LOGIN_HISTORY shows humans with
     first_authentication_factor = PASSWORD after the outage began — those are
     Snowsight logins, where the second factor is completed in the browser. A
     programmatic client cannot do that.
     A user-level AUTHENTICATION POLICY with MFA_ENROLLMENT = OPTIONAL does NOT
     override it: the property silently stayed at REQUIRED_PASSWORD_ONLY.
     TYPE = SERVICE is exempt from MFA but cannot hold a password at all, and
     LEGACY_SERVICE does not exist here (10.34.101 accepts PERSON, SERVICE or
     untyped only).

   AUTHENTICATION POLICIES — actively harmful here.
     A policy with AUTHENTICATION_METHODS = ('PASSWORD') BLOCKS key-pair for that
     user, which took out the one method that was working:
         Authentication attempt rejected by the current authentication policy.
     If a policy is ever attached to this user, list EVERY method it must allow.
     The final setup has no authentication policy on purpose.

   KEY-PAIR — authenticates, but the dataflow cannot use it.
     SVC_POWERBI signed in with RSA_KEYPAIR seven times on 2026-09-22 and the
     credential dialog reports "Connection successful". The REFRESH still fails,
     every table, in under a second, never reaching Snowflake:
         Error: Internal error Can't convert 12 to proper M credential Type.
     12 is the KeyPair credential type. The credential dialog is new UI; the
     **Dataflow Gen1** runtime is the old Power Query engine and has no such type
     in its enum. Interactive validation and the refresh engine are separate
     paths. This is what docs/snowflake_access_setup.md §11 meant by "not
     natively without an on-premises data gateway".

     The key FORMAT is irrelevant: PKCS#8 encrypted and unencrypted both fail
     identically. The failure is type mapping, not parsing. Do not retry formats.

     If key-pair is ever wanted, generate the pair with (outside the repo):
         umask 077
         openssl genrsa 2048 \
           | openssl pkcs8 -topk8 -inform PEM -out svc_powerbi_key.p8 -nocrypt
         openssl rsa -in svc_powerbi_key.p8 -pubout -out svc_powerbi_key.pub
         grep -v '^-----' svc_powerbi_key.pub | tr -d '\n'   # value for SQL
     then: alter user svc_powerbi set rsa_public_key = '<that value>';
     It will authenticate and still not refresh, until one of these exists:
       - an on-premises data gateway (software is free, needs a Windows host), or
       - the dataflow on Gen2 — requires PAID Fabric capacity, and three semantic
         models hang off the Gen1 dataflow and would need repointing. Unverified
         that Gen2 even accepts KeyPair here: test with a throwaway Gen2 dataflow
         and one small table before committing to a migration.

   =============================================================================
   DEBT — none of this is finished business
   =============================================================================
   1. THE TOKEN EXPIRES ~2027-09-22. Power BI will then break exactly the way it
      broke today, with no warning. Put a reminder somewhere that survives.

   2. allowed_ip_list = ('0.0.0.0/0') restricts nothing. It satisfies Snowflake's
      formal requirement and no more. What bounds the risk instead: the policy is
      attached to this one user, the token is role-restricted to a read-only role,
      and it expires. Tighten to Azure service tags, or move to a gateway.

   3. RAFAELA is TYPE = PERSON with TOTP enrolled and may be a real person's
      login. Do NOT delete it. Its failed logins stop once no dataflow uses it.

   4. POWERBI_READER fails separately with INCORRECT_USERNAME_PASSWORD — a wrong
      or expired password, not MFA. Different problem.

   5. POWERBI_AD is TYPE = PERSON and still runs a legacy dataflow on
      PC_FIVETRAN_WH against AD_AIRBYTE. It will hit the same MFA wall.

   6. Nobody has established WHO enabled MFA enforcement and when. It began around
      12:45 ET with no change on our side. If it was a deliberate account setting
      it may allow a service-account exemption, cleaner than all of the above.
   ============================================================================= */
