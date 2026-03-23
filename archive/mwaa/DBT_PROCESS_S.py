from airflow import DAG
from airflow.providers.ssh.operators.ssh import SSHOperator
from airflow.providers.ssh.hooks.ssh import SSHHook
from airflow.utils.dates import days_ago
from airflow.operators.python import PythonOperator
from airflow.utils.task_group import TaskGroup
from datetime import timedelta
import requests
import json
import time
import logging

# Configuração de logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Constantes
REDSHIFT_CONN_ID = 'redshift_ammodepot'
SSH_CONN_ID = 'ssh_conn_dbt'
DBT_PROJECT_PATH = '/opt/dbt/projects/ammodepot'
CLIENT_ID = "7293c8f3-41de-4c49-b507-7fdc15104319"
CLIENT_SECRET = "REDACTED_AIRBYTE_SECRET"
AIRBYTE_BASE_URL = "https://airbyte.ammunitiondepotdata.com"
AIRBYTE_CONNECTION_IDS = {
    'magento': '88aa2217-2980-4ba2-a505-f536116ebb43',
    'fishbowl': '2254701f-77fa-4924-93ca-4ccb288665f1',
    'fishbowl_so': 'e1ba0b9e-2f38-416a-8bc7-3762083bc7be',
    'magento_catalog': '5e0511a6-f94f-4876-864a-cb5031be3afc',
    'magento_sales': '3300d80e-f5d0-466f-b5f9-ea5efc9cdd8d'
}

# Função para obter o token
def get_access_token():
    url = f"{AIRBYTE_BASE_URL}/api/v1/applications/token"
    payload = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, json=payload, headers=headers, verify=False)
    if response.status_code != 200:
        raise Exception(f"Erro ao obter token: {response.status_code} - {response.text}")
    token = response.json().get("access_token")
    if not token:
        raise Exception("Token não encontrado na resposta da API.")
    return token

# Executar sincronização Airbyte
def trigger_airbyte_sync(connection_id, **kwargs):
    token = get_access_token()
    url = f"{AIRBYTE_BASE_URL}/api/v1/connections/sync"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    response = requests.post(url, json={"connectionId": connection_id}, headers=headers, verify=False)
    if response.status_code != 200:
        raise Exception(f"Erro ao iniciar sync: {response.status_code} - {response.text}")
    job_id = response.json().get("job", {}).get("id")
    if not job_id:
        raise Exception("Job ID não encontrado na resposta.")
    kwargs['ti'].xcom_push(key='job_id', value=job_id)
    logger.info(f"Sync iniciado para {connection_id} com Job ID: {job_id}")

# Monitorar o status do Job
def monitor_airbyte_sync(connection_id, task_name, **kwargs):
    job_id = kwargs['ti'].xcom_pull(key='job_id', task_ids=f"airbyte_sync.{task_name}_sync")
    if not job_id:
        raise Exception("Job ID não encontrado no XCom.")
    token = get_access_token()
    url = f"{AIRBYTE_BASE_URL}/api/v1/jobs/get"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
    payload = {"id": job_id}
    timeout = time.time() + 60 * 30
    while time.time() < timeout:
        response = requests.post(url, json=payload, headers=headers, verify=False)
        if response.status_code != 200:
            raise Exception(f"Erro ao consultar status do Job: {response.status_code} - {response.text}")
        job = response.json().get("job")
        status = job.get("status")
        logger.info(f"Status do Job {job_id}: {status}")
        if status in ["succeeded", "failed", "cancelled", "incomplete"]:
            if status != "succeeded":
                raise Exception(f"Job {job_id} falhou com status: {status}")
            return
        time.sleep(10)
    raise Exception(f"Timeout ao aguardar conclusão do Job {job_id}")

# DAG
default_args = {
    'owner': 'Paulo',
    'depends_on_past': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=1),
    'execution_timeout': timedelta(hours=3),
}

dag = DAG(
    dag_id='DBT_PROCESS_SIMPLIFIED',
    default_args=default_args,
    start_date=days_ago(1),
    schedule_interval=timedelta(minutes=70),
    catchup=False,
    tags=['dbt', 'airbyte', 'complete']
)

ssh_hook = SSHHook(
    ssh_conn_id=SSH_CONN_ID,
    conn_timeout=600,   # até 10 minutos para conectar
    cmd_timeout=None    # sem timeout no comando
)

with TaskGroup("airbyte_sync", dag=dag) as airbyte_sync:
    for name, conn_id in AIRBYTE_CONNECTION_IDS.items():
        sync_task = PythonOperator(
            task_id=f"{name}_sync",
            python_callable=trigger_airbyte_sync,
            op_args=[conn_id],
            dag=dag
        )
        #monitor_task = PythonOperator(
            #task_id=f"{name}_monitor",
            #python_callable=monitor_airbyte_sync,
            #op_args=[conn_id, name],
           # dag=dag,
          #  retries=0,
         #   trigger_rule='all_done'  # Continue pipeline even if this fails
        #)
       # sync_task >> monitor_task

force_s3_sync = SSHOperator(
    task_id='force_s3_sync',
    ssh_hook=ssh_hook,
    command='''
        S3_BUCKET="s3://meu-dbt-artifacts-bucket/projects/ammodepot/"
        DBT_PATH="/opt/dbt/projects/ammodepot/"
        sudo mkdir -p "$DBT_PATH/logs"
        sudo mkdir -p "$DBT_PATH/target"
        aws s3 sync $S3_BUCKET $DBT_PATH --exclude "*.log" --exclude "target/*" --exclude "logs/*"
        sudo chown -R ec2-user:ec2-user "$DBT_PATH"
        sudo chmod -R 755 "$DBT_PATH"
    ''',
    get_pty=True,
    execution_timeout=timedelta(minutes=15),
    dag=dag
)

run_dbt_debug = SSHOperator(
    task_id='run_dbt_debug',
    ssh_hook=ssh_hook,
    command=f"cd {DBT_PROJECT_PATH} && sudo -E env \"PATH=$PATH\" dbt debug",
    get_pty=True,
    execution_timeout=timedelta(minutes=10),
    dag=dag
)

run_dbt_models = SSHOperator(
    task_id='run_dbt_models',
    ssh_hook=ssh_hook,
    command=f'''
        cd {DBT_PROJECT_PATH}
        echo "Running models ..."
        sudo -E env "PATH=$PATH" dbt run --threads 5
    ''',
    do_xcom_push=True,
    get_pty=True,
    execution_timeout=timedelta(hours=2),
    dag=dag
)

capture_results_task = PythonOperator(
    task_id='capture_results',
    python_callable=lambda **kwargs: logger.info("Capture results mock"),
    dag=dag
)

clean_xcom_task = PythonOperator(
    task_id='clean_xcom',
    python_callable=lambda **kwargs: logger.info("Clean XCom mock"),
    dag=dag,
    trigger_rule='all_done'
)

# Dependências
airbyte_sync >> force_s3_sync >> run_dbt_debug >> run_dbt_models >> capture_results_task >> clean_xcom_task