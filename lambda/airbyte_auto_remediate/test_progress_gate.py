"""Progress-gate decision tests — run: python3 test_progress_gate.py

No AWS, no Snowflake: boto3/snowflake are stubbed and the two DynamoDB helpers are
replaced with an in-memory store, so this exercises the pure decision logic of
_evaluate_progress_gate offline.

Guards the 2026-07-22 regression: the Lambda cancelled a Magento drain that was
committing (job 28578 lost 1h21m of work) because staleness alone cannot tell
"frozen" from "slow but progressing". Case 5 is that exact scenario.
"""
import sys, types, os, time

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

results = []
STORE.clear()
# 1. Assinatura clássica de travamento: job vivo, zero bytes -> AGE JÁ (sem esperar baseline)
results.append(run("travado: live + 0 bytes", {"jobId":1,"status":"running","bytesSynced":0,"rowsSynced":0}, "ACT"))
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

print()
print(f"{sum(results)}/{len(results)} passaram")
sys.exit(0 if all(results) else 1)
