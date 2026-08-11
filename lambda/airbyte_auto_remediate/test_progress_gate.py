"""Progress-gate decision tests — run: python3 test_progress_gate.py

No AWS, no Snowflake: boto3/snowflake are stubbed and the two DynamoDB helpers are
replaced with an in-memory store, so this exercises the pure decision logic of
_evaluate_progress_gate offline.

Guards the 2026-07-22 regression: the Lambda cancelled a Magento drain that was
committing (job 28578 lost 1h21m of work) because staleness alone cannot tell
"frozen" from "slow but progressing". Case 5 is that exact scenario.
"""
import sys, types, os, time
from datetime import datetime, timedelta, timezone

os.environ.setdefault("SNS_TOPIC_ARN", "arn:aws:sns:us-east-1:000000000000:test")
# stub boto3/snowflake antes do import
mod = types.ModuleType("boto3")
class _C:
    def __getattr__(self, n):
        def f(*a, **k): raise RuntimeError("no aws in test")
        return f
mod.client = lambda *a, **k: _C()
sys.modules["boto3"] = mod
for m in ["snowflake", "snowflake.connector"]:
    sys.modules[m] = types.ModuleType(m)
sys.modules["snowflake.connector"].connect = lambda **k: None
crypto = types.ModuleType("cryptography"); sys.modules["cryptography"] = crypto
for m in ["cryptography.hazmat","cryptography.hazmat.primitives","cryptography.hazmat.primitives.serialization","cryptography.hazmat.backends"]:
    sys.modules[m] = types.ModuleType(m)
sys.modules["cryptography.hazmat.primitives.serialization"].load_pem_private_key = lambda *a, **k: None
sys.modules["cryptography.hazmat.backends"].default_backend = lambda: None

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import main

STORE = {}
main._read_progress_observation = lambda c: STORE.get(c)
def _w(c, j, b, r): STORE[c] = {"job_id": str(j or ""), "bytes_synced": b, "rows_synced": r, "observed_at": int(time.time())}
main._write_progress_observation = _w

def run(name, attempt, expect, conn="magento_s3"):
    d, r = main._evaluate_progress_gate(conn, attempt)
    ok = "PASS" if d == expect else "**FAIL**"
    print(f"{ok}  {name}: -> {d} ({r})")
    return d == expect

def iso_ago(seconds, with_seconds=True):
    """startTime de um job iniciado ha N segundos, no formato do jobs API."""
    t = datetime.now(timezone.utc) - timedelta(seconds=seconds)
    return t.strftime("%Y-%m-%dT%H:%M:%SZ" if with_seconds else "%Y-%m-%dT%H:%MZ")

results = []
STORE.clear()
# 1. Assinatura clássica de travamento: job vivo, zero bytes, VELHO -> AGE JÁ
results.append(run("travado: live + 0 bytes + 2h", {"jobId":1,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(7200)}, "ACT"))
# 2. Sem evidência (captura falhou) -> comportamento antigo (AGE)
results.append(run("sem evidencia", None, "ACT"))
# 3. Job já terminado -> AGE
results.append(run("job nao vivo", {"jobId":1,"status":"failed","bytesSynced":5,"rowsSynced":5}, "ACT"))
# 4. Primeira observação com dados -> precisa de baseline (NÃO cancela)
STORE.clear()
results.append(run("1a amostra c/ dados", {"jobId":28621,"status":"running","bytesSynced":100,"rowsSynced":10}, "SKIP_NEED_BASELINE"))
# 5. Segunda observação AVANÇANDO (o caso do incidente) -> NÃO cancela
results.append(run("progredindo (incidente 07-22)", {"jobId":28621,"status":"running","bytesSynced":6283814,"rowsSynced":10986}, "SKIP_PROGRESSING"))
# 6. Contadores PARADOS entre amostras -> travado de verdade -> AGE
results.append(run("contadores parados", {"jobId":28621,"status":"running","bytesSynced":6283814,"rowsSynced":10986}, "ACT"))
# 7. Job NOVO (contadores resetam) -> não comparar entre jobs
results.append(run("job novo reseta contador", {"jobId":28999,"status":"running","bytesSynced":5,"rowsSynced":1}, "SKIP_NEED_BASELINE"))
# 8. Contadores ilegíveis -> AGE
results.append(run("contadores invalidos", {"jobId":1,"status":"running","bytesSynced":"xx","rowsSynced":None}, "ACT"))
# 9. Chave DDB do gate NAO pode colidir com a do breaker
k = main._progress_key("magento_s3")
ok = k != "magento_s3" and k.startswith("progress#")
print(("PASS" if ok else "**FAIL**") + f"  chave DDB isolada do breaker: {k}")
results.append(ok)

# --- Guarda de idade minima (incidente 2026-07-27) -------------------------
# Job 30043 do Magento foi cancelado com 83s de vida e bytesSynced=0. Contadores
# so aparecem no commit, e syncs saudaveis chegam a ~20 min (p99). Zero contador
# num job novo nao prova nada.
STORE.clear()
# 10. O caso exato do incidente: 83s de vida -> NAO cancela
results.append(run("30043: live + 0 bytes + 83s (incidente 07-27)",
    {"jobId":30043,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(83)},
    "SKIP_JOB_TOO_YOUNG"))
# 11. Logo abaixo do piso (24 min) -> ainda protegido
STORE.clear()
results.append(run("0 bytes + 24min (abaixo do piso)",
    {"jobId":30044,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(1440)},
    "SKIP_JOB_TOO_YOUNG"))
# 12. Acima do piso -> travamento real, cancela
STORE.clear()
results.append(run("0 bytes + 26min (acima do piso)",
    {"jobId":30044,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(1560)},
    "ACT"))
# 13. startTime SEM segundos (o jobs API emite os dois formatos)
STORE.clear()
results.append(run("startTime sem segundos",
    {"jobId":30046,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(120, with_seconds=False)},
    "SKIP_JOB_TOO_YOUNG"))
# 14. startTime ausente -> vies preservado: evidencia ausente nunca poupa cancel
STORE.clear()
results.append(run("sem startTime -> vies ACT",
    {"jobId":30046,"status":"running","bytesSynced":0,"rowsSynced":0},
    "ACT"))
# 15. startTime ilegivel -> mesmo vies
STORE.clear()
results.append(run("startTime ilegivel -> vies ACT",
    {"jobId":30046,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":"ontem de manha"},
    "ACT"))
# 16. Job novo e travado permanece detectavel: amostra gravada agora, contadores
#     parados na proxima invocacao ja acima do piso -> cancela
STORE.clear()
run("piso: 1a amostra grava baseline",
    {"jobId":30060,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(60)},
    "SKIP_JOB_TOO_YOUNG")
results.append(run("piso: mesmo job ja velho e parado -> ACT",
    {"jobId":30060,"status":"running","bytesSynced":0,"rowsSynced":0,"startTime":iso_ago(1800)},
    "ACT"))


# ---------------------------------------------------------------------------
# AUTO-FIX notification gate (2026-08-11): page on the REPEAT, not on success.
# Guards the alert-fatigue failure: magento_s3 was auto-fixed 5x in 15h and each
# email read as a success, so the operator stopped reading the channel entirely.
# ---------------------------------------------------------------------------
def run_notify(name, repeat_count, expect):
    got = main._should_notify_autofix(repeat_count)
    ok = got == expect
    print(f"{'PASS' if ok else 'FALHOU'}  {name}: count={repeat_count} -> notify={got}")
    return ok

print()
results.append(run_notify("query falhou (0) -> notifica, vies fail-loud", 0, True))
results.append(run_notify("1o fix -> silencio", 1, False))
results.append(run_notify("2o fix -> silencio", 2, False))
results.append(run_notify("3o fix -> pagina", 3, True))
results.append(run_notify("5o fix (caso magento 2026-08-11) -> pagina", 5, True))

# A janela deve ser 24h, nao a de kind-bounce (240min): os 5 fixes do magento
# nunca chegaram a 3 em 4h (max 2), entao reusar aquela constante ficaria mudo.
_ok = main.AUTOFIX_NOTIFY_WINDOW_MIN == 1440 and main.AUTOFIX_NOTIFY_COUNT == 3
print(f"{'PASS' if _ok else 'FALHOU'}  janela 24h / limiar 3 "
      f"(got {main.AUTOFIX_NOTIFY_WINDOW_MIN}min / {main.AUTOFIX_NOTIFY_COUNT})")
results.append(_ok)


# ---------------------------------------------------------------------------
# Control-plane restart monitor (2026-08-11). Guards the 13-day blind spot:
# airbyte-abctl-server OOM-killed ~8x/day while freshness stayed green.
# ---------------------------------------------------------------------------
NOW = 1_700_000_000
H = 3600

def run_cp(name, current, state, now, expect):
    got, detail, _ = main._evaluate_cp_restarts(current, state, now)
    ok = got == expect
    print(f"{'PASS' if ok else 'FALHOU'}  {name}: -> {got} ({detail})")
    return ok

def anchor(pods, at, alerted=0):
    return {"pods": pods, "anchored_at": at, "alerted_at": alerted}

print()
results.append(run_cp("1a amostra -> ancora",
    {"airbyte-abctl-server-x": 5}, None, NOW, "ANCHOR"))
results.append(run_cp("amostra vazia -> ancora",
    {}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "ANCHOR"))
results.append(run_cp("cedo demais e sem delta -> WAIT",
    {"airbyte-abctl-server-x": 5}, anchor({"airbyte-abctl-server-x": 5}, NOW - 300), NOW, "WAIT"))
results.append(run_cp("estavel por 2h -> OK",
    {"airbyte-abctl-server-x": 5}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "OK"))
results.append(run_cp("2 restarts (abaixo do limiar) -> OK",
    {"airbyte-abctl-server-x": 7}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "OK"))
# O caso real: server morrendo ~8x/dia. Antes disso nao existia alerta nenhum.
results.append(run_cp("3 restarts em 2h (caso 2026-07-28) -> ALERT",
    {"airbyte-abctl-server-x": 8}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "ALERT"))
results.append(run_cp("ja alertou ha 1h -> COOLDOWN",
    {"airbyte-abctl-server-x": 9}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H, NOW - H), NOW, "COOLDOWN"))
results.append(run_cp("cooldown vencido (25h) -> ALERT",
    {"airbyte-abctl-server-x": 9}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H, NOW - 25*H), NOW, "ALERT"))
results.append(run_cp("janela de 24h rolou -> re-ancora",
    {"airbyte-abctl-server-x": 9}, anchor({"airbyte-abctl-server-x": 5}, NOW - 25*H), NOW, "ANCHOR"))
# Pod trocou de nome: historico do container antigo sumiu, conta desde 0.
results.append(run_cp("pod novo com 4 restarts -> ALERT",
    {"airbyte-abctl-server-y": 4}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "ALERT"))
results.append(run_cp("pod novo ainda com 0 -> OK",
    {"airbyte-abctl-server-y": 0}, anchor({"airbyte-abctl-server-x": 5}, NOW - 2*H), NOW, "OK"))
# Um pod normalmente estavel (0 por 15 dias) subindo sozinho tambem dispara.
results.append(run_cp("workload-launcher subindo -> ALERT",
    {"airbyte-abctl-server-x": 5, "airbyte-abctl-workload-launcher-z": 3},
    anchor({"airbyte-abctl-server-x": 5, "airbyte-abctl-workload-launcher-z": 0}, NOW - 3*H),
    NOW, "ALERT"))
# Uma taxa de 1/h teria ficado MUDA durante os 13 dias (~0.35/h): por isso o
# gatilho e contagem-por-janela, nao taxa horaria.
_ok = main.CP_RESTART_THRESHOLD == 3 and main.CP_RESTART_WINDOW_HOURS == 24
print(f"{'PASS' if _ok else 'FALHOU'}  limiar 3/24h "
      f"(got {main.CP_RESTART_THRESHOLD}/{main.CP_RESTART_WINDOW_HOURS}h)")
results.append(_ok)

print()
print(f"{sum(results)}/{len(results)} passaram")
sys.exit(0 if all(results) else 1)
