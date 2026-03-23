from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime, timedelta
import requests
import time
import pandas as pd
import psycopg2
import psycopg2.extras
import json
import logging
import hashlib
import gc
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# ========== CONFIGURAÇÕES ==========
BASE_URL = "https://api.listrak.com/email/v1"
AUTH_URL = "https://auth.listrak.com/OAuth2/Token"
CLIENT_ID = "wfatvd6e7uf4fmqqeazb"
CLIENT_SECRET = "REDACTED_LISTRAK_SECRET"
REDSHIFT_CONN_ID = "redshift_ammodepot"
BATCH_SIZE = 10
DAYS_LOOKBACK = 3  # Dias para buscar retroativamente no incremental

# ========== AUTENTICAÇÃO ==========
access_token = None
token_expiration = 0

def get_access_token():
    global access_token, token_expiration
    payload = {
        "grant_type": "client_credentials",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET
    }
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    
    response = requests.post(AUTH_URL, data=payload, headers=headers)
    if response.status_code == 200:
        token_data = response.json()
        access_token = token_data["access_token"]
        expires_in = token_data.get("expires_in", 3600)
        token_expiration = time.time() + expires_in - 60
        logging.info("✅ Token obtido com sucesso!")
    else:
        logging.error(f"❌ Falha ao obter token: {response.status_code}")
        raise Exception("Falha na autenticação")

def get_valid_token():
    if access_token is None or time.time() >= token_expiration:
        logging.info("🔄 Token expirado, gerando novo...")
        get_access_token()
    return access_token

# ========== CONEXÃO COM REDSHIFT ==========
def get_redshift_connection():
    hook = PostgresHook(postgres_conn_id=REDSHIFT_CONN_ID)
    return hook.get_conn()

def execute_redshift_query(query, params=None):
    """Executa query no Redshift e retorna resultado"""
    conn = get_redshift_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(query, params)
        if query.strip().upper().startswith('SELECT'):
            return cursor.fetchall()
        conn.commit()
        return cursor.rowcount
    finally:
        cursor.close()
        conn.close()

# ========== GESTÃO DE WATERMARKS ==========
def get_watermark(table_name):
    """Busca o último watermark para uma tabela"""
    try:
        # Primeiro verificar se a tabela de watermark existe
        check_table_query = """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'control' AND table_name = 'listrak_watermarks'
        )
        """
        table_exists = execute_redshift_query(check_table_query)
        
        if not table_exists or not table_exists[0][0]:
            logging.warning(f"⚠️ Tabela control.listrak_watermarks não existe")
            return None, None
        
        # Buscar watermark específico
        watermark_query = """
        SELECT last_processed_date, last_activity_date
        FROM control.listrak_watermarks
        WHERE table_name = %s
        """
        result = execute_redshift_query(watermark_query, (table_name,))
        
        if result and len(result) > 0:
            last_processed, last_activity = result[0][0], result[0][1]
            logging.info(f"📅 Watermark encontrado para {table_name}: processed={last_processed}, activity={last_activity}")
            return last_processed, last_activity
        else:
            logging.info(f"📅 Nenhum watermark encontrado para {table_name}")
            return None, None
            
    except Exception as e:
        logging.warning(f"⚠️ Erro ao buscar watermark para {table_name}: {str(e)}")
        return None, None

def get_last_activity_from_table():
    """Busca a última data de atividade diretamente da tabela silver"""
    try:
        # Verificar se a tabela existe
        check_table_query = """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'silver' AND table_name = 'listrak_message_activity'
        )
        """
        table_exists = execute_redshift_query(check_table_query)
        
        if not table_exists or not table_exists[0][0]:
            logging.info("📅 Tabela silver.listrak_message_activity não existe ainda")
            return None
        
        # Buscar última data de atividade
        last_date_query = """
        SELECT MAX(CASE 
            WHEN senddate IS NOT NULL AND senddate != '' AND senddate != 'None' 
            THEN CAST(senddate AS TIMESTAMP)
            WHEN activitydate IS NOT NULL AND activitydate != '' AND activitydate != 'None'
            THEN CAST(activitydate AS TIMESTAMP)
            ELSE NULL
        END) as max_date
        FROM silver.listrak_message_activity
        WHERE (senddate IS NOT NULL AND senddate != '' AND senddate != 'None')
           OR (activitydate IS NOT NULL AND activitydate != '' AND activitydate != 'None')
        """
        
        result = execute_redshift_query(last_date_query)
        
        if result and result[0][0]:
            last_date = result[0][0]
            logging.info(f"📅 Última data encontrada na tabela: {last_date}")
            return last_date
        else:
            logging.info("📅 Nenhuma data válida encontrada na tabela")
            return None
            
    except Exception as e:
        logging.warning(f"⚠️ Erro ao buscar última data da tabela: {str(e)}")
        return None

def update_watermark(table_name, last_processed_date, last_activity_date=None):
    """Atualiza o watermark para uma tabela"""
    # Delete e Insert para funcionar bem no Redshift
    delete_query = "DELETE FROM control.listrak_watermarks WHERE table_name = %s"
    insert_query = """
    INSERT INTO control.listrak_watermarks 
    (table_name, last_processed_date, last_activity_date, updated_at)
    VALUES (%s, %s, %s, GETDATE())
    """
    
    conn = get_redshift_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(delete_query, (table_name,))
        cursor.execute(insert_query, (table_name, last_processed_date, last_activity_date))
        conn.commit()
        logging.info(f"✅ Watermark atualizado para {table_name}: {last_processed_date}")
    finally:
        cursor.close()
        conn.close()

# ========== EXTRAÇÃO DE DADOS DA API ==========
def fetch_data_with_pagination(url, params=None, max_pages=None):
    """Busca dados paginados da API do Listrak"""
    headers = {"Authorization": f"Bearer {get_valid_token()}"}
    all_data = []
    cursor = "Start"
    page_count = 0
    
    if params is None:
        params = {}
    
    session = requests.Session()
    retry_strategy = Retry(
        total=3,
        backoff_factor=2,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"]
    )
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    while True:
        current_params = params.copy()
        current_params['cursor'] = cursor
        current_params['count'] = 5000
        
        try:
            response = session.get(url, headers=headers, params=current_params, timeout=(30, 60))
            
            if response.status_code == 200:
                response_json = response.json()
                
                if isinstance(response_json, dict):
                    data = response_json.get("data", [])
                    next_cursor = response_json.get("nextPageCursor")
                    has_more = next_cursor is not None or response_json.get("hasMore", False)
                else:
                    data = response_json if isinstance(response_json, list) else []
                    next_cursor = None
                    has_more = False
                
                if isinstance(data, dict):
                    data = [data]
                elif not isinstance(data, list):
                    data = []
                
                if data:
                    all_data.extend(data)
                    page_count += 1
                    logging.info(f"📥 Página {page_count}: {len(data)} registros (Total: {len(all_data)})")
                    
                    if not has_more or not next_cursor:
                        break
                    if max_pages and page_count >= max_pages:
                        break
                    
                    cursor = next_cursor
                    time.sleep(0.1)  # Rate limiting
                else:
                    break
            else:
                logging.error(f"❌ Erro na API: {response.status_code}")
                break
                
        except Exception as e:
            logging.error(f"❌ Erro na requisição: {str(e)}")
            break
    
    session.close()
    logging.info(f"📊 Total extraído: {len(all_data)} registros")
    return pd.DataFrame(all_data)

# ========== SALVAMENTO NO REDSHIFT ==========
def save_to_redshift_replace(df, table_name, schema='gold'):
    """Salva dados com estratégia REPLACE (truncate and load)"""
    if df.empty:
        logging.warning(f"⚠️ Nenhum dado para salvar em {table_name}")
        return 0
    
    # Normalizar nomes das colunas
    df.columns = [col.lower().replace(' ', '_').replace('-', '_') for col in df.columns]
    table_name = table_name.lower()
    
    # Converter tudo para string
    for col in df.columns:
        df[col] = df[col].astype(str).replace('nan', '')
    
    # Adicionar timestamp
    df['updated_at'] = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    
    conn = get_redshift_connection()
    cursor = conn.cursor()
    
    try:
        # Criar schema se não existir
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
        
        # Dropar e recriar tabela
        cursor.execute(f"DROP TABLE IF EXISTS {schema}.{table_name}")
        
        # Criar tabela
        columns = []
        for col in df.columns:
            columns.append(f'"{col}" VARCHAR(65535)')
        
        create_sql = f"""
        CREATE TABLE {schema}.{table_name} (
            {', '.join(columns)}
        ) DISTSTYLE AUTO
        """
        cursor.execute(create_sql)
        
        # Inserir dados
        columns_str = ', '.join([f'"{col}"' for col in df.columns])
        data_tuples = [tuple(row) for row in df.values]
        insert_query = f"INSERT INTO {schema}.{table_name} ({columns_str}) VALUES %s"
        
        # Inserir em lotes
        chunk_size = 5000
        for i in range(0, len(data_tuples), chunk_size):
            chunk = data_tuples[i:i + chunk_size]
            psycopg2.extras.execute_values(cursor, insert_query, chunk, page_size=500)
        
        conn.commit()
        logging.info(f"✅ {len(df)} registros salvos em {schema}.{table_name} (REPLACE)")
        return len(df)
        
    except Exception as e:
        conn.rollback()
        logging.error(f"❌ Erro ao salvar: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

def save_to_redshift_incremental(df, table_name, schema='silver'):
    """Salva dados com estratégia INCREMENTAL (merge)"""
    if df.empty:
        logging.warning(f"⚠️ Nenhum dado para salvar em {table_name}")
        return 0
    
    # Normalizar nomes das colunas
    df.columns = [col.lower().replace(' ', '_').replace('-', '_') for col in df.columns]
    table_name = table_name.lower()
    
    # Converter tudo para string
    for col in df.columns:
        df[col] = df[col].astype(str).replace('nan', '')
    
    # Adicionar timestamp
    df['updated_at'] = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    
    conn = get_redshift_connection()
    cursor = conn.cursor()
    
    try:
        # Criar schema se não existir
        cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")
        
        # Verificar se tabela existe
        cursor.execute(f"""
            SELECT EXISTS (
                SELECT 1 FROM information_schema.tables 
                WHERE table_schema = '{schema}' AND table_name = '{table_name}'
            )
        """)
        table_exists = cursor.fetchone()[0]
        
        # Criar tabela se não existir
        if not table_exists:
            columns = []
            for col in df.columns:
                columns.append(f'"{col}" VARCHAR(65535)')
            
            create_sql = f"""
            CREATE TABLE {schema}.{table_name} (
                {', '.join(columns)}
            ) 
            DISTSTYLE KEY
            DISTKEY (messageid)
            SORTKEY (messageid, activitydate)
            """
            cursor.execute(create_sql)
            logging.info(f"✅ Tabela {schema}.{table_name} criada")
        
        # Criar tabela temporária
        temp_table = f"temp_{table_name}_{int(time.time())}"
        columns = []
        for col in df.columns:
            columns.append(f'"{col}" VARCHAR(65535)')
        
        create_temp_sql = f"CREATE TEMP TABLE {temp_table} ({', '.join(columns)})"
        cursor.execute(create_temp_sql)
        
        # Inserir dados na temp
        columns_str = ', '.join([f'"{col}"' for col in df.columns])
        data_tuples = [tuple(row) for row in df.values]
        insert_query = f"INSERT INTO {temp_table} ({columns_str}) VALUES %s"
        
        psycopg2.extras.execute_values(cursor, insert_query, data_tuples, page_size=500)
        
        # Determinar range de datas para deletar
        cursor.execute(f"SELECT MIN(senddate), MAX(senddate) FROM {temp_table}")
        date_range = cursor.fetchone()
        min_date, max_date = date_range[0], date_range[1]
        
        # Deletar dados existentes no range
        delete_sql = f"""
        DELETE FROM {schema}.{table_name}
        WHERE senddate >= '{min_date}' AND senddate <= '{max_date}'
        """
        deleted_rows = cursor.execute(delete_sql)
        
        # Inserir novos dados
        insert_sql = f"INSERT INTO {schema}.{table_name} SELECT * FROM {temp_table}"
        cursor.execute(insert_sql)
        
        conn.commit()
        logging.info(f"✅ {len(df)} registros salvos em {schema}.{table_name} (INCREMENTAL)")
        return len(df)
        
    except Exception as e:
        conn.rollback()
        logging.error(f"❌ Erro ao salvar incremental: {e}")
        raise
    finally:
        cursor.close()
        conn.close()

# ========== TASKS DA DAG ==========

def setup_control_tables(**context):
    """Cria tabelas de controle necessárias"""
    logging.info("🛠️ Configurando tabelas de controle...")
    
    # Criar esquemas
    schemas = ['gold', 'silver', 'control']
    for schema in schemas:
        execute_redshift_query(f"CREATE SCHEMA IF NOT EXISTS {schema}")
    
    # Tabela de watermarks
    watermark_sql = """
    CREATE TABLE IF NOT EXISTS control.listrak_watermarks (
        table_name VARCHAR(100) PRIMARY KEY,
        last_processed_date TIMESTAMP,
        last_activity_date TIMESTAMP,
        updated_at TIMESTAMP DEFAULT GETDATE()
    )
    """
    execute_redshift_query(watermark_sql)
    
    logging.info("✅ Tabelas de controle configuradas")

def diagnose_watermark_status(**context):
    """Diagnostica o status dos watermarks e dados existentes"""
    logging.info("🔍 DIAGNÓSTICO DE WATERMARKS E DADOS")
    logging.info("=" * 50)
    
    try:
        # 1. Verificar se tabela de watermark existe
        check_watermark_table = """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'control' AND table_name = 'listrak_watermarks'
        )
        """
        watermark_table_exists = execute_redshift_query(check_watermark_table)
        
        if watermark_table_exists and watermark_table_exists[0][0]:
            logging.info("✅ Tabela control.listrak_watermarks existe")
            
            # Verificar watermarks existentes
            watermarks_query = "SELECT * FROM control.listrak_watermarks ORDER BY table_name"
            watermarks = execute_redshift_query(watermarks_query)
            
            if watermarks:
                logging.info("📋 Watermarks encontrados:")
                for wm in watermarks:
                    logging.info(f"  - {wm[0]}: last_processed={wm[1]}, last_activity={wm[2]}, updated_at={wm[3]}")
            else:
                logging.info("⚠️ Tabela de watermarks existe mas está vazia")
        else:
            logging.warning("⚠️ Tabela control.listrak_watermarks NÃO EXISTE")
        
        # 2. Verificar tabela de atividades
        check_activity_table = """
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'silver' AND table_name = 'listrak_message_activity'
        )
        """
        activity_table_exists = execute_redshift_query(check_activity_table)
        
        if activity_table_exists and activity_table_exists[0][0]:
            logging.info("✅ Tabela silver.listrak_message_activity existe")
            
            # Verificar dados existentes
            activity_stats_query = """
            SELECT 
                COUNT(*) as total_records,
                COUNT(DISTINCT messageid) as unique_messages,
                MIN(CASE 
                    WHEN senddate IS NOT NULL AND senddate != '' AND senddate != 'None' 
                    THEN senddate::timestamp 
                    ELSE NULL 
                END) as min_senddate,
                MAX(CASE 
                    WHEN senddate IS NOT NULL AND senddate != '' AND senddate != 'None' 
                    THEN senddate::timestamp 
                    ELSE NULL 
                END) as max_senddate,
                MAX(updated_at::timestamp) as last_updated
            FROM silver.listrak_message_activity
            WHERE senddate IS NOT NULL AND senddate != '' AND senddate != 'None'
            """
            
            stats = execute_redshift_query(activity_stats_query)
            if stats and stats[0]:
                total, unique_msgs, min_date, max_date, last_updated = stats[0]
                logging.info(f"📊 Estatísticas da tabela de atividades:")
                logging.info(f"  - Total de registros: {total:,}")
                logging.info(f"  - Mensagens únicas: {unique_msgs:,}")
                logging.info(f"  - Data mais antiga: {min_date}")
                logging.info(f"  - Data mais recente: {max_date}")
                logging.info(f"  - Última atualização: {last_updated}")
                
                # Verificar dados recentes
                recent_query = """
                SELECT COUNT(*) 
                FROM silver.listrak_message_activity 
                WHERE senddate::timestamp >= CURRENT_DATE - INTERVAL '7 days'
                """
                recent_count = execute_redshift_query(recent_query)
                if recent_count:
                    logging.info(f"  - Registros dos últimos 7 dias: {recent_count[0][0]:,}")
        else:
            logging.warning("⚠️ Tabela silver.listrak_message_activity NÃO EXISTE")
        
        # 3. Verificar tabela de mensagens
        messages_stats_query = """
        SELECT 
            COUNT(*) as total_messages,
            MIN(senddate::timestamp) as min_senddate,
            MAX(senddate::timestamp) as max_senddate
        FROM gold.listrak_messages
        WHERE senddate IS NOT NULL AND senddate != '' AND senddate != 'None'
        """
        
        msg_stats = execute_redshift_query(messages_stats_query)
        if msg_stats and msg_stats[0]:
            total_msgs, min_msg_date, max_msg_date = msg_stats[0]
            logging.info(f"📧 Estatísticas de mensagens:")
            logging.info(f"  - Total de mensagens: {total_msgs:,}")
            logging.info(f"  - Mensagem mais antiga: {min_msg_date}")
            logging.info(f"  - Mensagem mais recente: {max_msg_date}")
        
    except Exception as e:
        logging.error(f"❌ Erro no diagnóstico: {str(e)}")
    
    logging.info("=" * 50)

def reset_watermark_if_needed(**context):
    """Reseta watermark se necessário - USE COM CUIDADO!"""
    # Esta função só roda se o parâmetro force_reset_watermark for True
    force_reset = context.get('params', {}).get('force_reset_watermark', False)
    
    if not force_reset:
        logging.info("ℹ️ Reset de watermark não solicitado (force_reset_watermark=False)")
        return
    
    logging.warning("⚠️ RESETANDO WATERMARK - força total!")
    
    try:
        # Deletar watermark específico
        delete_query = "DELETE FROM control.listrak_watermarks WHERE table_name = 'message_activities'"
        execute_redshift_query(delete_query)
        
        logging.warning("✅ Watermark de message_activities REMOVIDO - próxima execução será incremental baseada na tabela")
        
    except Exception as e:
        logging.error(f"❌ Erro ao resetar watermark: {str(e)}")

def extract_lists_full(**context):
    """Extrai dados de listas (FULL RELOAD)"""
    logging.info("📋 Extraindo Listas (FULL RELOAD)...")
    
    lists_df = fetch_data_with_pagination(f"{BASE_URL}/list")
    
    if not lists_df.empty:
        records_saved = save_to_redshift_replace(lists_df, "listrak_lists", schema='gold')
        logging.info(f"✅ Listas: {records_saved} registros salvos")
    else:
        logging.info("ℹ️ Nenhuma lista encontrada")

def extract_campaigns_full(**context):
    """Extrai dados de campanhas (FULL RELOAD)"""
    logging.info("📢 Extraindo Campanhas (FULL RELOAD)...")
    
    # Buscar list_ids
    list_ids_query = "SELECT DISTINCT listid FROM gold.listrak_lists"
    list_ids_result = execute_redshift_query(list_ids_query)
    
    if not list_ids_result:
        logging.warning("⚠️ Nenhuma lista encontrada para campanhas")
        return
    
    list_ids = [row[0] for row in list_ids_result]
    all_campaigns = []
    
    for list_id in list_ids:
        campaigns_df = fetch_data_with_pagination(f"{BASE_URL}/list/{list_id}/campaign")
        if not campaigns_df.empty:
            campaigns_df["listid"] = list_id
            all_campaigns.append(campaigns_df)
    
    if all_campaigns:
        final_campaigns_df = pd.concat(all_campaigns, ignore_index=True)
        records_saved = save_to_redshift_replace(final_campaigns_df, "listrak_campaigns", schema='gold')
        logging.info(f"✅ Campanhas: {records_saved} registros salvos")
    else:
        logging.info("ℹ️ Nenhuma campanha encontrada")

def extract_messages_full(**context):
    """Extrai dados de mensagens (FULL RELOAD)"""
    logging.info("✉️ Extraindo Mensagens (FULL RELOAD)...")
    
    # Buscar list_ids
    list_ids_query = "SELECT DISTINCT listid FROM gold.listrak_lists"
    list_ids_result = execute_redshift_query(list_ids_query)
    
    if not list_ids_result:
        logging.warning("⚠️ Nenhuma lista encontrada para mensagens")
        return
    
    list_ids = [row[0] for row in list_ids_result]
    all_messages = []
    
    # Buscar mensagens dos últimos 90 dias
    start_date = (datetime.utcnow() - timedelta(days=90)).strftime('%Y-%m-%dT%H:%M:%SZ')
    end_date = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    
    for list_id in list_ids:
        messages_df = fetch_data_with_pagination(
            f"{BASE_URL}/list/{list_id}/message",
            params={"startDate": start_date, "endDate": end_date}
        )
        if not messages_df.empty:
            messages_df["listid"] = list_id
            all_messages.append(messages_df)
    
    if all_messages:
        final_messages_df = pd.concat(all_messages, ignore_index=True)
        records_saved = save_to_redshift_replace(final_messages_df, "listrak_messages", schema='gold')
        
        # Atualizar watermark para mensagens
        if 'senddate' in final_messages_df.columns:
            final_messages_df['senddate'] = pd.to_datetime(final_messages_df['senddate'], errors='coerce')
            latest_date = final_messages_df['senddate'].max()
            if pd.notna(latest_date):
                update_watermark('messages', latest_date)
        
        logging.info(f"✅ Mensagens: {records_saved} registros salvos")
    else:
        logging.info("ℹ️ Nenhuma mensagem encontrada")

def extract_summaries_full(**context):
    """Extrai resumos de mensagens (FULL RELOAD)"""
    logging.info("📊 Extraindo Resumos (FULL RELOAD)...")
    
    # Buscar mensagens recentes (últimos 30 dias)
    messages_query = """
    SELECT DISTINCT messageid, listid 
    FROM gold.listrak_messages 
    WHERE senddate >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY senddate DESC
    LIMIT 500
    """
    
    try:
        messages_result = execute_redshift_query(messages_query)
    except:
        # Fallback se não tiver coluna senddate
        messages_query = "SELECT DISTINCT messageid, listid FROM gold.listrak_messages LIMIT 100"
        messages_result = execute_redshift_query(messages_query)
    
    if not messages_result:
        logging.warning("⚠️ Nenhuma mensagem encontrada para resumos")
        return
    
    all_summaries = []
    headers = {"Authorization": f"Bearer {get_valid_token()}"}
    
    for row in messages_result:
        message_id, list_id = row[0], row[1]
        
        try:
            response = requests.get(
                f"{BASE_URL}/list/{list_id}/message/{message_id}/summary",
                headers=headers,
                timeout=30
            )
            
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict):
                    data["messageid"] = message_id
                    data["listid"] = list_id
                    all_summaries.append(data)
            
            time.sleep(0.1)  # Rate limiting
            
        except Exception as e:
            logging.warning(f"⚠️ Erro ao buscar resumo {message_id}: {str(e)}")
            continue
    
    if all_summaries:
        final_summary_df = pd.DataFrame(all_summaries)
        records_saved = save_to_redshift_replace(final_summary_df, "listrak_message_summary", schema='gold')
        logging.info(f"✅ Resumos: {records_saved} registros salvos")
    else:
        logging.info("ℹ️ Nenhum resumo encontrado")

def extract_activities_incremental(**context):
    """Extrai atividades de mensagens (INCREMENTAL)"""
    logging.info("🎯 Extraindo Atividades (INCREMENTAL)...")
    
    # Buscar último watermark
    last_processed_date, last_activity_date = get_watermark('message_activities')
    
    # Determinar data de início
    start_date = None
    process_type = "incremental"
    
    if last_activity_date:
        # Incremental: começar alguns dias antes do último processamento
        start_date = (last_activity_date - timedelta(days=DAYS_LOOKBACK)).strftime('%Y-%m-%dT%H:%M:%SZ')
        logging.info(f"📅 Carga incremental com watermark desde: {start_date}")
        
    else:
        # Watermark não encontrado, tentar buscar da própria tabela
        logging.info("📅 Watermark não encontrado, buscando última data da tabela...")
        last_table_date = get_last_activity_from_table()
        
        if last_table_date:
            # Usar a data da tabela com overlap
            start_date = (last_table_date - timedelta(days=DAYS_LOOKBACK)).strftime('%Y-%m-%dT%H:%M:%SZ')
            logging.info(f"📅 Retomando da última data da tabela: {start_date}")
            process_type = "recovery"
        else:
            # Primeira execução: últimos 30 dias
            start_date = (datetime.utcnow() - timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%SZ')
            logging.info(f"📅 Primeira execução completa desde: {start_date}")
            process_type = "initial"
    
    end_date = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')
    logging.info(f"🎯 Tipo de processamento: {process_type.upper()}")
    logging.info(f"📅 Período: {start_date} até {end_date}")
    
    # Buscar mensagens para processar
    messages_query = """
    SELECT DISTINCT messageid, listid 
    FROM gold.listrak_messages 
    WHERE senddate >= %s
    ORDER BY senddate DESC
    """
    
    try:
        # Tentar com data (converter start_date para formato de data)
        lookup_date = datetime.strptime(start_date, '%Y-%m-%dT%H:%M:%SZ').strftime('%Y-%m-%d')
        messages_result = execute_redshift_query(messages_query, (lookup_date,))
        logging.info(f"📧 Filtro por data aplicado: mensagens desde {lookup_date}")
    except Exception as e:
        # Fallback: todas as mensagens
        logging.warning(f"⚠️ Erro no filtro por data ({str(e)}), processando todas as mensagens")
        messages_query = "SELECT DISTINCT messageid, listid FROM gold.listrak_messages ORDER BY messageid"
        messages_result = execute_redshift_query(messages_query)
    
    if not messages_result:
        logging.warning("⚠️ Nenhuma mensagem encontrada para atividades")
        return
    
    logging.info(f"📧 Processando {len(messages_result)} mensagens em lotes de {BATCH_SIZE}")
    
    total_records = 0
    latest_activity_date = last_activity_date
    
    # Processar em lotes
    for i in range(0, len(messages_result), BATCH_SIZE):
        batch = messages_result[i:i + BATCH_SIZE]
        batch_num = (i // BATCH_SIZE) + 1
        
        logging.info(f"🔄 Processando lote {batch_num}/{(len(messages_result) + BATCH_SIZE - 1) // BATCH_SIZE}")
        
        batch_activities = []
        
        for row in batch:
            message_id, list_id = row[0], row[1]
            
            try:
                # Buscar atividades com filtro de data
                params = {"startDate": start_date, "endDate": end_date}
                
                activity_df = fetch_data_with_pagination(
                    f"{BASE_URL}/List/{list_id}/Message/{message_id}/Activity",
                    params=params
                )
                
                if not activity_df.empty:
                    activity_df["messageid"] = message_id
                    activity_df["listid"] = list_id
                    
                    # Rastrear data mais recente
                    for date_col in ['activitydate', 'senddate']:
                        if date_col in activity_df.columns:
                            activity_df[date_col] = pd.to_datetime(activity_df[date_col], errors='coerce')
                            max_date = activity_df[date_col].max()
                            if pd.notna(max_date) and (latest_activity_date is None or max_date > latest_activity_date):
                                latest_activity_date = max_date
                    
                    batch_activities.append(activity_df)
                    
            except Exception as e:
                logging.warning(f"⚠️ Erro ao processar mensagem {message_id}: {str(e)}")
                continue
        
        # Salvar lote se houver dados
        if batch_activities:
            batch_df = pd.concat(batch_activities, ignore_index=True)
            records_saved = save_to_redshift_incremental(batch_df, "listrak_message_activity", schema='silver')
            total_records += records_saved
            logging.info(f"✅ Lote {batch_num}: {records_saved} atividades salvas")
            
            # Limpar memória
            del batch_df, batch_activities
            gc.collect()
        
        # Pequena pausa entre lotes
        time.sleep(1)
    
    # Atualizar watermark se houver nova data
    if latest_activity_date and total_records > 0:
        update_watermark(
            'message_activities',
            last_processed_date=datetime.utcnow(),
            last_activity_date=latest_activity_date
        )
        logging.info(f"✅ Watermark atualizado: {latest_activity_date}")
    
    logging.info(f"🎯 Atividades concluídas: {total_records} registros processados ({process_type})")

def verify_data_quality(**context):
    """Verifica qualidade dos dados carregados"""
    logging.info("🔍 Verificando qualidade dos dados...")
    
    tables_to_check = [
        ('gold', 'listrak_lists'),
        ('gold', 'listrak_campaigns'), 
        ('gold', 'listrak_messages'),
        ('gold', 'listrak_message_summary'),
        ('silver', 'listrak_message_activity')
    ]
    
    for schema, table in tables_to_check:
        try:
            # Contar registros
            count_query = f"SELECT COUNT(*) FROM {schema}.{table}"
            count_result = execute_redshift_query(count_query)
            total_count = count_result[0][0] if count_result else 0
            
            # Contar registros de hoje
            today_query = f"""
            SELECT COUNT(*) FROM {schema}.{table} 
            WHERE DATE(updated_at) = CURRENT_DATE
            """
            today_result = execute_redshift_query(today_query)
            today_count = today_result[0][0] if today_result else 0
            
            logging.info(f"📊 {schema}.{table}: {total_count:,} total ({today_count:,} hoje)")
            
        except Exception as e:
            logging.warning(f"⚠️ Erro ao verificar {schema}.{table}: {str(e)}")
    
    # Verificar watermarks
    try:
        watermarks_query = "SELECT * FROM control.listrak_watermarks ORDER BY table_name"
        watermarks_result = execute_redshift_query(watermarks_query)
        
        if watermarks_result:
            logging.info("⏰ Watermarks atuais:")
            for wm in watermarks_result:
                logging.info(f"  {wm[0]}: {wm[1]} | {wm[2]}")
        
    except Exception as e:
        logging.warning(f"⚠️ Erro ao verificar watermarks: {str(e)}")

# ========== CONFIGURAÇÃO DA DAG ==========

default_args = {
    'owner': 'Paulo',
    'depends_on_past': False,
    'start_date': datetime(2025, 1, 20),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 2,
    'retry_delay': timedelta(minutes=5),
}

dag = DAG(
    'LISTRAK_INCREMENTAL_V2',
    default_args=default_args,
    description='Listrak ETL com processamento incremental otimizado',
    schedule_interval='0 2 * * *',  # Todo dia às 2h
    catchup=False,
    max_active_runs=1,
    tags=['listrak', 'incremental', 'etl', 'redshift'],
    params={
        "force_reset_watermark": False,  # True para forçar reset do watermark
        "debug_mode": True,              # True para logs detalhados
        "batch_size_override": 10,       # Sobrescrever BATCH_SIZE se necessário
        "days_lookback_override": 3      # Sobrescrever DAYS_LOOKBACK se necessário
    }
)

# ========== DEFINIÇÃO DAS TASKS ==========

# Setup e diagnóstico
setup_task = PythonOperator(
    task_id='setup_control_tables',
    python_callable=setup_control_tables,
    dag=dag,
)

diagnose_task = PythonOperator(
    task_id='diagnose_watermark_status',
    python_callable=diagnose_watermark_status,
    dag=dag,
)

# Task opcional para reset (só roda se force_reset_watermark=True nos params)
reset_watermark_task = PythonOperator(
    task_id='reset_watermark_if_needed',
    python_callable=reset_watermark_if_needed,
    dag=dag,
)

# Extrações FULL (Gold)
extract_lists_task = PythonOperator(
    task_id='extract_lists_full',
    python_callable=extract_lists_full,
    dag=dag,
)

extract_campaigns_task = PythonOperator(
    task_id='extract_campaigns_full',
    python_callable=extract_campaigns_full,
    dag=dag,
)

extract_messages_task = PythonOperator(
    task_id='extract_messages_full',
    python_callable=extract_messages_full,
    dag=dag,
)

extract_summaries_task = PythonOperator(
    task_id='extract_summaries_full',
    python_callable=extract_summaries_full,
    dag=dag,
)

# Extração INCREMENTAL (Silver)
extract_activities_task = PythonOperator(
    task_id='extract_activities_incremental',
    python_callable=extract_activities_incremental,
    dag=dag,
)

# Verificação final
verify_task = PythonOperator(
    task_id='verify_data_quality',
    python_callable=verify_data_quality,
    dag=dag,
)

# ========== DEPENDÊNCIAS ==========

# Fluxo principal com diagnóstico
setup_task >> diagnose_task >> reset_watermark_task >> extract_lists_task
extract_lists_task >> [extract_campaigns_task, extract_messages_task]
extract_messages_task >> [extract_summaries_task, extract_activities_task]
[extract_campaigns_task, extract_summaries_task, extract_activities_task] >> verify_task