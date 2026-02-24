SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: access_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_policies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    principal_type character varying NOT NULL,
    principal_id character varying,
    environments character varying[] DEFAULT '{}'::character varying[],
    paths character varying[] DEFAULT '{}'::character varying[],
    permissions character varying[] DEFAULT '{}'::character varying[],
    conditions jsonb DEFAULT '{}'::jsonb,
    enabled boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: access_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.access_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    token_digest character varying NOT NULL,
    token_prefix character varying NOT NULL,
    environments character varying[] DEFAULT '{}'::character varying[],
    paths character varying[] DEFAULT '{}'::character varying[],
    permissions character varying[] DEFAULT '{read}'::character varying[],
    allowed_ips character varying[] DEFAULT '{}'::character varying[],
    expires_at timestamp(6) without time zone,
    last_used_at timestamp(6) without time zone,
    use_count integer DEFAULT 0,
    active boolean DEFAULT true,
    revoked_at timestamp(6) without time zone,
    revoked_by character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description character varying
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    action character varying NOT NULL,
    resource_type character varying NOT NULL,
    resource_id uuid,
    resource_path character varying,
    actor_type character varying NOT NULL,
    actor_id character varying,
    actor_name character varying,
    ip_address character varying,
    user_agent character varying,
    request_id character varying,
    environment character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    success boolean DEFAULT true,
    error_message text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: connector_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connector_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    connector_id uuid NOT NULL,
    connector_credential_id uuid,
    name character varying,
    status character varying DEFAULT 'connected'::character varying,
    config jsonb DEFAULT '{}'::jsonb,
    enabled boolean DEFAULT true,
    last_executed_at timestamp(6) without time zone,
    execution_count integer DEFAULT 0,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: connector_credentials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connector_credentials (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    connector_id uuid NOT NULL,
    name character varying NOT NULL,
    auth_type character varying NOT NULL,
    encrypted_credentials bytea NOT NULL,
    encryption_iv bytea NOT NULL,
    encryption_key_id character varying NOT NULL,
    encrypted_refresh_token bytea,
    refresh_token_iv bytea,
    refresh_token_key_id character varying,
    token_expires_at timestamp(6) without time zone,
    status character varying DEFAULT 'active'::character varying,
    last_verified_at timestamp(6) without time zone,
    last_used_at timestamp(6) without time zone,
    usage_count integer DEFAULT 0,
    error_message text,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: connector_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connector_executions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    connector_connection_id uuid NOT NULL,
    action_name character varying NOT NULL,
    status character varying NOT NULL,
    duration_ms integer,
    input_hash character varying,
    output_summary jsonb,
    error_message text,
    caller_service character varying,
    caller_request_id character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: connectors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.connectors (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    piece_name character varying NOT NULL,
    display_name character varying NOT NULL,
    description text,
    logo_url character varying,
    category character varying NOT NULL,
    connector_type character varying NOT NULL,
    auth_type character varying,
    auth_schema jsonb DEFAULT '{}'::jsonb,
    version character varying,
    package_name character varying,
    actions jsonb DEFAULT '[]'::jsonb,
    triggers jsonb DEFAULT '[]'::jsonb,
    metadata jsonb DEFAULT '{}'::jsonb,
    enabled boolean DEFAULT true,
    installed boolean DEFAULT false,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: encryption_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.encryption_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    key_id character varying NOT NULL,
    key_type character varying NOT NULL,
    encrypted_key bytea NOT NULL,
    encryption_iv bytea NOT NULL,
    kms_key_arn character varying,
    kms_provider character varying,
    status character varying DEFAULT 'active'::character varying,
    activated_at timestamp(6) without time zone,
    retired_at timestamp(6) without time zone,
    previous_key_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform_project_id uuid NOT NULL,
    name character varying,
    api_key character varying,
    ingest_key character varying,
    environment character varying DEFAULT 'production'::character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archived_at timestamp(6) without time zone
);


--
-- Name: provider_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.provider_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    name character varying NOT NULL,
    provider character varying NOT NULL,
    model_type character varying DEFAULT 'llm'::character varying NOT NULL,
    encrypted_key bytea NOT NULL,
    encryption_iv bytea NOT NULL,
    encryption_key_id character varying NOT NULL,
    key_prefix character varying,
    global boolean DEFAULT false NOT NULL,
    active boolean DEFAULT true NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    last_used_at timestamp(6) without time zone,
    usage_count integer DEFAULT 0 NOT NULL,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: secret_environments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secret_environments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    description text,
    protected boolean DEFAULT false,
    locked boolean DEFAULT false,
    parent_environment_id uuid,
    color character varying,
    "position" integer DEFAULT 0,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: secret_folders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secret_folders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    path character varying NOT NULL,
    description text,
    parent_folder_id uuid,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: secret_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secret_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    secret_id uuid NOT NULL,
    secret_environment_id uuid NOT NULL,
    version integer NOT NULL,
    current boolean DEFAULT true,
    encrypted_value bytea NOT NULL,
    encryption_iv bytea NOT NULL,
    encryption_key_id character varying,
    value_length integer,
    value_hash character varying,
    created_by character varying,
    change_note text,
    expires_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    encrypted_otp_secret bytea,
    otp_secret_iv bytea,
    otp_secret_key_id character varying,
    hotp_counter bigint DEFAULT 0
);


--
-- Name: secrets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.secrets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    secret_folder_id uuid,
    key character varying NOT NULL,
    path character varying NOT NULL,
    description text,
    secret_type character varying DEFAULT 'string'::character varying,
    tags jsonb DEFAULT '{}'::jsonb,
    rotation_enabled boolean DEFAULT false,
    rotation_interval_days integer,
    next_rotation_at timestamp(6) without time zone,
    last_rotated_at timestamp(6) without time zone,
    archived boolean DEFAULT false,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    versions_count integer DEFAULT 0 NOT NULL,
    username character varying,
    otp_algorithm character varying DEFAULT 'sha1'::character varying,
    otp_digits integer DEFAULT 6,
    otp_period integer DEFAULT 30,
    otp_issuer character varying,
    url character varying,
    notes text
);


--
-- Name: solid_queue_blocked_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_blocked_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    concurrency_key character varying NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_blocked_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_blocked_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_blocked_executions_id_seq OWNED BY public.solid_queue_blocked_executions.id;


--
-- Name: solid_queue_claimed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_claimed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    process_id bigint,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_claimed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_claimed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_claimed_executions_id_seq OWNED BY public.solid_queue_claimed_executions.id;


--
-- Name: solid_queue_failed_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_failed_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    error text,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_failed_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_failed_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_failed_executions_id_seq OWNED BY public.solid_queue_failed_executions.id;


--
-- Name: solid_queue_jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_jobs (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    class_name character varying NOT NULL,
    arguments text,
    priority integer DEFAULT 0 NOT NULL,
    active_job_id character varying,
    scheduled_at timestamp(6) without time zone,
    finished_at timestamp(6) without time zone,
    concurrency_key character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_jobs_id_seq OWNED BY public.solid_queue_jobs.id;


--
-- Name: solid_queue_pauses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_pauses (
    id bigint NOT NULL,
    queue_name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_pauses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_pauses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_pauses_id_seq OWNED BY public.solid_queue_pauses.id;


--
-- Name: solid_queue_processes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_processes (
    id bigint NOT NULL,
    kind character varying NOT NULL,
    last_heartbeat_at timestamp(6) without time zone NOT NULL,
    supervisor_id bigint,
    pid integer NOT NULL,
    hostname character varying,
    metadata text,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_processes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_processes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_processes_id_seq OWNED BY public.solid_queue_processes.id;


--
-- Name: solid_queue_ready_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_ready_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_ready_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_ready_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_ready_executions_id_seq OWNED BY public.solid_queue_ready_executions.id;


--
-- Name: solid_queue_recurring_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    task_key character varying NOT NULL,
    run_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_executions_id_seq OWNED BY public.solid_queue_recurring_executions.id;


--
-- Name: solid_queue_recurring_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_recurring_tasks (
    id bigint NOT NULL,
    key character varying NOT NULL,
    schedule character varying NOT NULL,
    command character varying(2048),
    class_name character varying,
    arguments text,
    queue_name character varying,
    priority integer DEFAULT 0,
    static boolean DEFAULT true NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_recurring_tasks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_recurring_tasks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_recurring_tasks_id_seq OWNED BY public.solid_queue_recurring_tasks.id;


--
-- Name: solid_queue_scheduled_executions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_scheduled_executions (
    id bigint NOT NULL,
    job_id bigint NOT NULL,
    queue_name character varying NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_scheduled_executions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_scheduled_executions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_scheduled_executions_id_seq OWNED BY public.solid_queue_scheduled_executions.id;


--
-- Name: solid_queue_semaphores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.solid_queue_semaphores (
    id bigint NOT NULL,
    key character varying NOT NULL,
    value integer DEFAULT 1 NOT NULL,
    expires_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.solid_queue_semaphores_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: solid_queue_semaphores_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.solid_queue_semaphores_id_seq OWNED BY public.solid_queue_semaphores.id;


--
-- Name: ssh_client_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ssh_client_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    name character varying NOT NULL,
    key_type character varying NOT NULL,
    fingerprint character varying NOT NULL,
    key_bits integer,
    public_key text NOT NULL,
    encrypted_private_key bytea NOT NULL,
    private_key_iv bytea NOT NULL,
    private_key_key_id character varying NOT NULL,
    encrypted_passphrase bytea,
    passphrase_iv bytea,
    passphrase_key_id character varying,
    comment character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    archived boolean DEFAULT false,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ssh_connections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ssh_connections (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    ssh_client_key_id uuid,
    name character varying NOT NULL,
    host character varying NOT NULL,
    port integer DEFAULT 22 NOT NULL,
    username character varying NOT NULL,
    jump_connection_id uuid,
    options jsonb DEFAULT '{}'::jsonb,
    description text,
    metadata jsonb DEFAULT '{}'::jsonb,
    archived boolean DEFAULT false,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: ssh_server_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ssh_server_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    hostname character varying NOT NULL,
    port integer DEFAULT 22 NOT NULL,
    key_type character varying NOT NULL,
    public_key text NOT NULL,
    fingerprint character varying NOT NULL,
    trusted boolean DEFAULT true,
    verified_at timestamp(6) without time zone,
    comment character varying,
    metadata jsonb DEFAULT '{}'::jsonb,
    archived boolean DEFAULT false,
    archived_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: solid_queue_blocked_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_blocked_executions_id_seq'::regclass);


--
-- Name: solid_queue_claimed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_claimed_executions_id_seq'::regclass);


--
-- Name: solid_queue_failed_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_failed_executions_id_seq'::regclass);


--
-- Name: solid_queue_jobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_jobs_id_seq'::regclass);


--
-- Name: solid_queue_pauses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_pauses_id_seq'::regclass);


--
-- Name: solid_queue_processes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_processes_id_seq'::regclass);


--
-- Name: solid_queue_ready_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_ready_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_executions_id_seq'::regclass);


--
-- Name: solid_queue_recurring_tasks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_recurring_tasks_id_seq'::regclass);


--
-- Name: solid_queue_scheduled_executions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_scheduled_executions_id_seq'::regclass);


--
-- Name: solid_queue_semaphores id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores ALTER COLUMN id SET DEFAULT nextval('public.solid_queue_semaphores_id_seq'::regclass);


--
-- Name: access_policies access_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_policies
    ADD CONSTRAINT access_policies_pkey PRIMARY KEY (id);


--
-- Name: access_tokens access_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT access_tokens_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_logs audit_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);


--
-- Name: connector_connections connector_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_connections
    ADD CONSTRAINT connector_connections_pkey PRIMARY KEY (id);


--
-- Name: connector_credentials connector_credentials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_credentials
    ADD CONSTRAINT connector_credentials_pkey PRIMARY KEY (id);


--
-- Name: connector_executions connector_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_executions
    ADD CONSTRAINT connector_executions_pkey PRIMARY KEY (id);


--
-- Name: connectors connectors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connectors
    ADD CONSTRAINT connectors_pkey PRIMARY KEY (id);


--
-- Name: encryption_keys encryption_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encryption_keys
    ADD CONSTRAINT encryption_keys_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: provider_keys provider_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provider_keys
    ADD CONSTRAINT provider_keys_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: secret_environments secret_environments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_environments
    ADD CONSTRAINT secret_environments_pkey PRIMARY KEY (id);


--
-- Name: secret_folders secret_folders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_folders
    ADD CONSTRAINT secret_folders_pkey PRIMARY KEY (id);


--
-- Name: secret_versions secret_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_versions
    ADD CONSTRAINT secret_versions_pkey PRIMARY KEY (id);


--
-- Name: secrets secrets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secrets
    ADD CONSTRAINT secrets_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_blocked_executions solid_queue_blocked_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT solid_queue_blocked_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_claimed_executions solid_queue_claimed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT solid_queue_claimed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_failed_executions solid_queue_failed_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT solid_queue_failed_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_jobs solid_queue_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_jobs
    ADD CONSTRAINT solid_queue_jobs_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_pauses solid_queue_pauses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_pauses
    ADD CONSTRAINT solid_queue_pauses_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_processes solid_queue_processes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_processes
    ADD CONSTRAINT solid_queue_processes_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_ready_executions solid_queue_ready_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT solid_queue_ready_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_executions solid_queue_recurring_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT solid_queue_recurring_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_recurring_tasks solid_queue_recurring_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_tasks
    ADD CONSTRAINT solid_queue_recurring_tasks_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_scheduled_executions solid_queue_scheduled_executions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT solid_queue_scheduled_executions_pkey PRIMARY KEY (id);


--
-- Name: solid_queue_semaphores solid_queue_semaphores_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_semaphores
    ADD CONSTRAINT solid_queue_semaphores_pkey PRIMARY KEY (id);


--
-- Name: ssh_client_keys ssh_client_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_client_keys
    ADD CONSTRAINT ssh_client_keys_pkey PRIMARY KEY (id);


--
-- Name: ssh_connections ssh_connections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_connections
    ADD CONSTRAINT ssh_connections_pkey PRIMARY KEY (id);


--
-- Name: ssh_server_keys ssh_server_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_server_keys
    ADD CONSTRAINT ssh_server_keys_pkey PRIMARY KEY (id);


--
-- Name: idx_access_policies_principal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_access_policies_principal ON public.access_policies USING btree (project_id, principal_type, principal_id);


--
-- Name: idx_audit_logs_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_actor ON public.audit_logs USING btree (project_id, actor_type, actor_id);


--
-- Name: idx_audit_logs_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_logs_resource ON public.audit_logs USING btree (project_id, resource_type, resource_id);


--
-- Name: idx_connector_conns_project_connector_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_connector_conns_project_connector_enabled ON public.connector_connections USING btree (project_id, connector_id) WHERE (enabled = true);


--
-- Name: idx_connector_conns_project_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connector_conns_project_status ON public.connector_connections USING btree (project_id, status);


--
-- Name: idx_connector_creds_project_connector_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_connector_creds_project_connector_name ON public.connector_credentials USING btree (project_id, connector_id, name);


--
-- Name: idx_connector_creds_project_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connector_creds_project_status ON public.connector_credentials USING btree (project_id, status);


--
-- Name: idx_connector_execs_project_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_connector_execs_project_created ON public.connector_executions USING btree (project_id, created_at);


--
-- Name: idx_secret_versions_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_secret_versions_current ON public.secret_versions USING btree (secret_id, secret_environment_id, current);


--
-- Name: idx_secret_versions_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_secret_versions_unique ON public.secret_versions USING btree (secret_id, secret_environment_id, version);


--
-- Name: idx_secrets_has_versions; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_secrets_has_versions ON public.secrets USING btree (project_id, versions_count);


--
-- Name: idx_ssh_client_keys_project_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ssh_client_keys_project_fingerprint ON public.ssh_client_keys USING btree (project_id, fingerprint);


--
-- Name: idx_ssh_client_keys_project_name_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ssh_client_keys_project_name_active ON public.ssh_client_keys USING btree (project_id, name) WHERE (archived = false);


--
-- Name: idx_ssh_connections_project_name_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ssh_connections_project_name_active ON public.ssh_connections USING btree (project_id, name) WHERE (archived = false);


--
-- Name: idx_ssh_server_keys_project_fingerprint; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ssh_server_keys_project_fingerprint ON public.ssh_server_keys USING btree (project_id, fingerprint);


--
-- Name: idx_ssh_server_keys_project_host_type; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_ssh_server_keys_project_host_type ON public.ssh_server_keys USING btree (project_id, hostname, port, key_type) WHERE (archived = false);


--
-- Name: index_access_policies_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_access_policies_on_project_id ON public.access_policies USING btree (project_id);


--
-- Name: index_access_tokens_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_access_tokens_on_project_id ON public.access_tokens USING btree (project_id);


--
-- Name: index_access_tokens_on_project_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_access_tokens_on_project_id_and_active ON public.access_tokens USING btree (project_id, active);


--
-- Name: index_access_tokens_on_project_id_and_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_access_tokens_on_project_id_and_token_digest ON public.access_tokens USING btree (project_id, token_digest);


--
-- Name: index_audit_logs_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_project_id ON public.audit_logs USING btree (project_id);


--
-- Name: index_audit_logs_on_project_id_and_action; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_project_id_and_action ON public.audit_logs USING btree (project_id, action);


--
-- Name: index_audit_logs_on_project_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_logs_on_project_id_and_created_at ON public.audit_logs USING btree (project_id, created_at);


--
-- Name: index_connector_connections_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_connections_on_project_id ON public.connector_connections USING btree (project_id);


--
-- Name: index_connector_credentials_on_connector_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_credentials_on_connector_id ON public.connector_credentials USING btree (connector_id);


--
-- Name: index_connector_credentials_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_credentials_on_project_id ON public.connector_credentials USING btree (project_id);


--
-- Name: index_connector_executions_on_connector_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_executions_on_connector_connection_id ON public.connector_executions USING btree (connector_connection_id);


--
-- Name: index_connector_executions_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_executions_on_project_id ON public.connector_executions USING btree (project_id);


--
-- Name: index_connector_executions_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connector_executions_on_status ON public.connector_executions USING btree (status);


--
-- Name: index_connectors_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connectors_on_category ON public.connectors USING btree (category);


--
-- Name: index_connectors_on_connector_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connectors_on_connector_type ON public.connectors USING btree (connector_type);


--
-- Name: index_connectors_on_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_connectors_on_enabled ON public.connectors USING btree (enabled);


--
-- Name: index_connectors_on_piece_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_connectors_on_piece_name ON public.connectors USING btree (piece_name);


--
-- Name: index_encryption_keys_on_previous_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_encryption_keys_on_previous_key_id ON public.encryption_keys USING btree (previous_key_id);


--
-- Name: index_encryption_keys_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_encryption_keys_on_project_id ON public.encryption_keys USING btree (project_id);


--
-- Name: index_encryption_keys_on_project_id_and_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_encryption_keys_on_project_id_and_key_id ON public.encryption_keys USING btree (project_id, key_id);


--
-- Name: index_encryption_keys_on_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_encryption_keys_on_project_id_and_status ON public.encryption_keys USING btree (project_id, status);


--
-- Name: index_projects_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_key ON public.projects USING btree (api_key);


--
-- Name: index_projects_on_archived_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_archived_at ON public.projects USING btree (archived_at);


--
-- Name: index_projects_on_ingest_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_ingest_key ON public.projects USING btree (ingest_key);


--
-- Name: index_projects_on_platform_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_platform_project_id ON public.projects USING btree (platform_project_id);


--
-- Name: index_provider_keys_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_active ON public.provider_keys USING btree (active);


--
-- Name: index_provider_keys_on_global; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_global ON public.provider_keys USING btree (global);


--
-- Name: index_provider_keys_on_global_and_provider_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_global_and_provider_and_active ON public.provider_keys USING btree (global, provider, active);


--
-- Name: index_provider_keys_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_project_id ON public.provider_keys USING btree (project_id);


--
-- Name: index_provider_keys_on_project_id_and_provider_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_project_id_and_provider_and_active ON public.provider_keys USING btree (project_id, provider, active);


--
-- Name: index_provider_keys_on_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_provider_keys_on_provider ON public.provider_keys USING btree (provider);


--
-- Name: index_secret_environments_on_parent_environment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_environments_on_parent_environment_id ON public.secret_environments USING btree (parent_environment_id);


--
-- Name: index_secret_environments_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_environments_on_project_id ON public.secret_environments USING btree (project_id);


--
-- Name: index_secret_environments_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_secret_environments_on_project_id_and_name ON public.secret_environments USING btree (project_id, name);


--
-- Name: index_secret_environments_on_project_id_and_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_secret_environments_on_project_id_and_slug ON public.secret_environments USING btree (project_id, slug);


--
-- Name: index_secret_folders_on_parent_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_folders_on_parent_folder_id ON public.secret_folders USING btree (parent_folder_id);


--
-- Name: index_secret_folders_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_folders_on_project_id ON public.secret_folders USING btree (project_id);


--
-- Name: index_secret_folders_on_project_id_and_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_secret_folders_on_project_id_and_path ON public.secret_folders USING btree (project_id, path);


--
-- Name: index_secret_versions_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_versions_on_expires_at ON public.secret_versions USING btree (expires_at);


--
-- Name: index_secret_versions_on_secret_environment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_versions_on_secret_environment_id ON public.secret_versions USING btree (secret_environment_id);


--
-- Name: index_secret_versions_on_secret_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secret_versions_on_secret_id ON public.secret_versions USING btree (secret_id);


--
-- Name: index_secrets_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_project_id ON public.secrets USING btree (project_id);


--
-- Name: index_secrets_on_project_id_and_archived; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_project_id_and_archived ON public.secrets USING btree (project_id, archived);


--
-- Name: index_secrets_on_project_id_and_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_project_id_and_key ON public.secrets USING btree (project_id, key);


--
-- Name: index_secrets_on_project_id_and_path; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_secrets_on_project_id_and_path ON public.secrets USING btree (project_id, path);


--
-- Name: index_secrets_on_project_id_and_secret_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_project_id_and_secret_type ON public.secrets USING btree (project_id, secret_type);


--
-- Name: index_secrets_on_project_id_and_url; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_project_id_and_url ON public.secrets USING btree (project_id, url) WHERE (url IS NOT NULL);


--
-- Name: index_secrets_on_secret_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_secret_folder_id ON public.secrets USING btree (secret_folder_id);


--
-- Name: index_solid_queue_blocked_executions_for_maintenance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON public.solid_queue_blocked_executions USING btree (expires_at, concurrency_key);


--
-- Name: index_solid_queue_blocked_executions_for_release; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_blocked_executions_for_release ON public.solid_queue_blocked_executions USING btree (concurrency_key, priority, job_id);


--
-- Name: index_solid_queue_blocked_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON public.solid_queue_blocked_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON public.solid_queue_claimed_executions USING btree (job_id);


--
-- Name: index_solid_queue_claimed_executions_on_process_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON public.solid_queue_claimed_executions USING btree (process_id, job_id);


--
-- Name: index_solid_queue_dispatch_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_dispatch_all ON public.solid_queue_scheduled_executions USING btree (scheduled_at, priority, job_id);


--
-- Name: index_solid_queue_failed_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON public.solid_queue_failed_executions USING btree (job_id);


--
-- Name: index_solid_queue_jobs_for_alerting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_alerting ON public.solid_queue_jobs USING btree (scheduled_at, finished_at);


--
-- Name: index_solid_queue_jobs_for_filtering; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_for_filtering ON public.solid_queue_jobs USING btree (queue_name, finished_at);


--
-- Name: index_solid_queue_jobs_on_active_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_active_job_id ON public.solid_queue_jobs USING btree (active_job_id);


--
-- Name: index_solid_queue_jobs_on_class_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_class_name ON public.solid_queue_jobs USING btree (class_name);


--
-- Name: index_solid_queue_jobs_on_finished_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_jobs_on_finished_at ON public.solid_queue_jobs USING btree (finished_at);


--
-- Name: index_solid_queue_pauses_on_queue_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON public.solid_queue_pauses USING btree (queue_name);


--
-- Name: index_solid_queue_poll_all; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_all ON public.solid_queue_ready_executions USING btree (priority, job_id);


--
-- Name: index_solid_queue_poll_by_queue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_poll_by_queue ON public.solid_queue_ready_executions USING btree (queue_name, priority, job_id);


--
-- Name: index_solid_queue_processes_on_last_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON public.solid_queue_processes USING btree (last_heartbeat_at);


--
-- Name: index_solid_queue_processes_on_name_and_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON public.solid_queue_processes USING btree (name, supervisor_id);


--
-- Name: index_solid_queue_processes_on_supervisor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_processes_on_supervisor_id ON public.solid_queue_processes USING btree (supervisor_id);


--
-- Name: index_solid_queue_ready_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON public.solid_queue_ready_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON public.solid_queue_recurring_executions USING btree (job_id);


--
-- Name: index_solid_queue_recurring_executions_on_task_key_and_run_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON public.solid_queue_recurring_executions USING btree (task_key, run_at);


--
-- Name: index_solid_queue_recurring_tasks_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON public.solid_queue_recurring_tasks USING btree (key);


--
-- Name: index_solid_queue_recurring_tasks_on_static; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_recurring_tasks_on_static ON public.solid_queue_recurring_tasks USING btree (static);


--
-- Name: index_solid_queue_scheduled_executions_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON public.solid_queue_scheduled_executions USING btree (job_id);


--
-- Name: index_solid_queue_semaphores_on_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_expires_at ON public.solid_queue_semaphores USING btree (expires_at);


--
-- Name: index_solid_queue_semaphores_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON public.solid_queue_semaphores USING btree (key);


--
-- Name: index_solid_queue_semaphores_on_key_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON public.solid_queue_semaphores USING btree (key, value);


--
-- Name: index_ssh_client_keys_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_client_keys_on_project_id ON public.ssh_client_keys USING btree (project_id);


--
-- Name: index_ssh_client_keys_on_project_id_and_archived; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_client_keys_on_project_id_and_archived ON public.ssh_client_keys USING btree (project_id, archived);


--
-- Name: index_ssh_connections_on_jump_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_connections_on_jump_connection_id ON public.ssh_connections USING btree (jump_connection_id);


--
-- Name: index_ssh_connections_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_connections_on_project_id ON public.ssh_connections USING btree (project_id);


--
-- Name: index_ssh_connections_on_project_id_and_archived; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_connections_on_project_id_and_archived ON public.ssh_connections USING btree (project_id, archived);


--
-- Name: index_ssh_connections_on_ssh_client_key_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_connections_on_ssh_client_key_id ON public.ssh_connections USING btree (ssh_client_key_id);


--
-- Name: index_ssh_server_keys_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_server_keys_on_project_id ON public.ssh_server_keys USING btree (project_id);


--
-- Name: index_ssh_server_keys_on_project_id_and_archived; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ssh_server_keys_on_project_id_and_archived ON public.ssh_server_keys USING btree (project_id, archived);


--
-- Name: audit_logs audit_logs_no_delete; Type: RULE; Schema: public; Owner: -
--

CREATE RULE audit_logs_no_delete AS
    ON DELETE TO public.audit_logs DO INSTEAD NOTHING;


--
-- Name: audit_logs audit_logs_no_update; Type: RULE; Schema: public; Owner: -
--

CREATE RULE audit_logs_no_update AS
    ON UPDATE TO public.audit_logs DO INSTEAD NOTHING;


--
-- Name: encryption_keys fk_rails_0ac5dee6ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encryption_keys
    ADD CONSTRAINT fk_rails_0ac5dee6ea FOREIGN KEY (previous_key_id) REFERENCES public.encryption_keys(id);


--
-- Name: ssh_connections fk_rails_11213caf4b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_connections
    ADD CONSTRAINT fk_rails_11213caf4b FOREIGN KEY (ssh_client_key_id) REFERENCES public.ssh_client_keys(id);


--
-- Name: audit_logs fk_rails_177ea135aa; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_logs
    ADD CONSTRAINT fk_rails_177ea135aa FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secret_folders fk_rails_1d4251a2fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_folders
    ADD CONSTRAINT fk_rails_1d4251a2fb FOREIGN KEY (parent_folder_id) REFERENCES public.secret_folders(id);


--
-- Name: secret_folders fk_rails_1fe80f8d96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_folders
    ADD CONSTRAINT fk_rails_1fe80f8d96 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: ssh_connections fk_rails_243f21e80c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_connections
    ADD CONSTRAINT fk_rails_243f21e80c FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secret_environments fk_rails_291dac5e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_environments
    ADD CONSTRAINT fk_rails_291dac5e35 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: solid_queue_recurring_executions fk_rails_318a5533ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_recurring_executions
    ADD CONSTRAINT fk_rails_318a5533ed FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: secrets fk_rails_37daa44a5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secrets
    ADD CONSTRAINT fk_rails_37daa44a5f FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: solid_queue_failed_executions fk_rails_39bbc7a631; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_failed_executions
    ADD CONSTRAINT fk_rails_39bbc7a631 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: secret_versions fk_rails_3a436fb313; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_versions
    ADD CONSTRAINT fk_rails_3a436fb313 FOREIGN KEY (secret_environment_id) REFERENCES public.secret_environments(id);


--
-- Name: solid_queue_blocked_executions fk_rails_4cd34e2228; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_blocked_executions
    ADD CONSTRAINT fk_rails_4cd34e2228 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: ssh_connections fk_rails_4d87f119ad; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_connections
    ADD CONSTRAINT fk_rails_4d87f119ad FOREIGN KEY (jump_connection_id) REFERENCES public.ssh_connections(id);


--
-- Name: secret_environments fk_rails_5138d22b98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_environments
    ADD CONSTRAINT fk_rails_5138d22b98 FOREIGN KEY (parent_environment_id) REFERENCES public.secret_environments(id);


--
-- Name: ssh_client_keys fk_rails_51891d454f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_client_keys
    ADD CONSTRAINT fk_rails_51891d454f FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secrets fk_rails_56f778415a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secrets
    ADD CONSTRAINT fk_rails_56f778415a FOREIGN KEY (secret_folder_id) REFERENCES public.secret_folders(id);


--
-- Name: encryption_keys fk_rails_5d6aaa1b96; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.encryption_keys
    ADD CONSTRAINT fk_rails_5d6aaa1b96 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: provider_keys fk_rails_5ec6fca2a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.provider_keys
    ADD CONSTRAINT fk_rails_5ec6fca2a5 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: connector_connections fk_rails_78cf26e713; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_connections
    ADD CONSTRAINT fk_rails_78cf26e713 FOREIGN KEY (connector_credential_id) REFERENCES public.connector_credentials(id);


--
-- Name: access_policies fk_rails_7edca00a5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_policies
    ADD CONSTRAINT fk_rails_7edca00a5b FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: solid_queue_ready_executions fk_rails_81fcbd66af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_ready_executions
    ADD CONSTRAINT fk_rails_81fcbd66af FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: solid_queue_claimed_executions fk_rails_9cfe4d4944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_claimed_executions
    ADD CONSTRAINT fk_rails_9cfe4d4944 FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: connector_executions fk_rails_9d5cc0c9e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_executions
    ADD CONSTRAINT fk_rails_9d5cc0c9e5 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: connector_connections fk_rails_a3fc9bb6fb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_connections
    ADD CONSTRAINT fk_rails_a3fc9bb6fb FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: connector_credentials fk_rails_ad2cdb1fc4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_credentials
    ADD CONSTRAINT fk_rails_ad2cdb1fc4 FOREIGN KEY (connector_id) REFERENCES public.connectors(id);


--
-- Name: ssh_server_keys fk_rails_bb7e30eca7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ssh_server_keys
    ADD CONSTRAINT fk_rails_bb7e30eca7 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: connector_executions fk_rails_c3fd145ee9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_executions
    ADD CONSTRAINT fk_rails_c3fd145ee9 FOREIGN KEY (connector_connection_id) REFERENCES public.connector_connections(id);


--
-- Name: solid_queue_scheduled_executions fk_rails_c4316f352d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.solid_queue_scheduled_executions
    ADD CONSTRAINT fk_rails_c4316f352d FOREIGN KEY (job_id) REFERENCES public.solid_queue_jobs(id) ON DELETE CASCADE;


--
-- Name: access_tokens fk_rails_cba9a561e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT fk_rails_cba9a561e5 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: connector_connections fk_rails_d4514f4c52; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_connections
    ADD CONSTRAINT fk_rails_d4514f4c52 FOREIGN KEY (connector_id) REFERENCES public.connectors(id);


--
-- Name: secret_versions fk_rails_f4954849cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_versions
    ADD CONSTRAINT fk_rails_f4954849cf FOREIGN KEY (secret_id) REFERENCES public.secrets(id);


--
-- Name: connector_credentials fk_rails_f9eec32fd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.connector_credentials
    ADD CONSTRAINT fk_rails_f9eec32fd5 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260223000004'),
('20250101000001'),
('20260223000003'),
('20260223000002'),
('20260223000001'),
('20260130000002'),
('20260130000001'),
('20260126000003'),
('20260126000002'),
('20260126000001'),
('20260125000001'),
('20260121000002'),
('20260121000001'),
('20260111000002'),
('20260111000001'),
('20241229000001'),
('20241227000001'),
('20241226000009'),
('20241226000008'),
('20241226000007'),
('20241226000006'),
('20241226000005'),
('20241226000004'),
('20241226000003'),
('20241226000002'),
('20241226000001'),
('1');

