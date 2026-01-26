SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

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
    updated_at timestamp(6) without time zone NOT NULL
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
    created_at timestamp(6) without time zone NOT NULL
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
    updated_at timestamp(6) without time zone NOT NULL
);


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
-- Name: idx_secret_versions_current; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_secret_versions_current ON public.secret_versions USING btree (secret_id, secret_environment_id, current);


--
-- Name: idx_secret_versions_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_secret_versions_unique ON public.secret_versions USING btree (secret_id, secret_environment_id, version);


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
-- Name: index_secrets_on_secret_folder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_secrets_on_secret_folder_id ON public.secrets USING btree (secret_folder_id);


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
-- Name: secret_environments fk_rails_291dac5e35; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_environments
    ADD CONSTRAINT fk_rails_291dac5e35 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secrets fk_rails_37daa44a5f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secrets
    ADD CONSTRAINT fk_rails_37daa44a5f FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secret_versions fk_rails_3a436fb313; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_versions
    ADD CONSTRAINT fk_rails_3a436fb313 FOREIGN KEY (secret_environment_id) REFERENCES public.secret_environments(id);


--
-- Name: secret_environments fk_rails_5138d22b98; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_environments
    ADD CONSTRAINT fk_rails_5138d22b98 FOREIGN KEY (parent_environment_id) REFERENCES public.secret_environments(id);


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
-- Name: access_policies fk_rails_7edca00a5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_policies
    ADD CONSTRAINT fk_rails_7edca00a5b FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: access_tokens fk_rails_cba9a561e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.access_tokens
    ADD CONSTRAINT fk_rails_cba9a561e5 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: secret_versions fk_rails_f4954849cf; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.secret_versions
    ADD CONSTRAINT fk_rails_f4954849cf FOREIGN KEY (secret_id) REFERENCES public.secrets(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
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
('20241226000001');

