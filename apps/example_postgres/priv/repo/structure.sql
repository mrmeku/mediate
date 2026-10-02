--
-- PostgreSQL database dump
--


-- Dumped from database version 18.6
-- Dumped by pg_dump version 18.6

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
-- Name: example_repository_embargo(bigint); Type: FUNCTION; Schema: public; Owner: mediate_owner
--

CREATE FUNCTION public.example_repository_embargo(repository bigint) RETURNS timestamp without time zone
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$SELECT embargo FROM repositories WHERE id = repository$$;


ALTER FUNCTION public.example_repository_embargo(repository bigint) OWNER TO mediate_owner;

--
-- Name: example_repository_owning_team(bigint); Type: FUNCTION; Schema: public; Owner: mediate_owner
--

CREATE FUNCTION public.example_repository_owning_team(repository bigint) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$SELECT owning_team_id FROM repositories WHERE id = repository$$;


ALTER FUNCTION public.example_repository_owning_team(repository bigint) OWNER TO mediate_owner;

--
-- Name: example_repository_project(bigint); Type: FUNCTION; Schema: public; Owner: mediate_owner
--

CREATE FUNCTION public.example_repository_project(repository bigint) RETURNS bigint
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$SELECT project_id FROM repositories WHERE id = repository$$;


ALTER FUNCTION public.example_repository_project(repository bigint) OWNER TO mediate_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: accounts; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.accounts (
    id text NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    person_id text NOT NULL,
    employment text NOT NULL,
    country text NOT NULL
);


ALTER TABLE public.accounts OWNER TO mediate_owner;

--
-- Name: directories; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.directories (
    id bigint NOT NULL,
    repository_id bigint NOT NULL,
    name text NOT NULL,
    contents text NOT NULL,
    labels text[] DEFAULT ARRAY[]::text[] NOT NULL,
    restrictions text[] DEFAULT ARRAY[]::text[] NOT NULL,
    releasable_to text[] DEFAULT ARRAY[]::text[] NOT NULL
);

ALTER TABLE ONLY public.directories FORCE ROW LEVEL SECURITY;


ALTER TABLE public.directories OWNER TO mediate_owner;

--
-- Name: directories_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.directories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.directories_id_seq OWNER TO mediate_owner;

--
-- Name: directories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.directories_id_seq OWNED BY public.directories.id;


--
-- Name: enterprises; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.enterprises (
    id bigint NOT NULL,
    name text NOT NULL,
    country text NOT NULL
);


ALTER TABLE public.enterprises OWNER TO mediate_owner;

--
-- Name: enterprises_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.enterprises_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.enterprises_id_seq OWNER TO mediate_owner;

--
-- Name: enterprises_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.enterprises_id_seq OWNED BY public.enterprises.id;


--
-- Name: labels; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.labels (
    name text NOT NULL,
    sensitive boolean DEFAULT false NOT NULL,
    implied_restrictions text[] DEFAULT ARRAY[]::text[] NOT NULL
);


ALTER TABLE public.labels OWNER TO mediate_owner;

--
-- Name: memberships; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    account_id text NOT NULL,
    project_id bigint NOT NULL,
    role text NOT NULL
);


ALTER TABLE public.memberships OWNER TO mediate_owner;

--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.memberships_id_seq OWNER TO mediate_owner;

--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: override_reports; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.override_reports (
    id bigint NOT NULL,
    repository_id bigint NOT NULL,
    team_id bigint NOT NULL,
    account_id text NOT NULL,
    justification text NOT NULL,
    correlation_id text NOT NULL,
    read_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.override_reports OWNER TO mediate_owner;

--
-- Name: override_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.override_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.override_reports_id_seq OWNER TO mediate_owner;

--
-- Name: override_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.override_reports_id_seq OWNED BY public.override_reports.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.permissions (
    id bigint NOT NULL,
    account_id text NOT NULL,
    permission text NOT NULL
);


ALTER TABLE public.permissions OWNER TO mediate_owner;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO mediate_owner;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name text NOT NULL,
    archived_at timestamp(0) without time zone,
    team_id bigint NOT NULL
);


ALTER TABLE public.projects OWNER TO mediate_owner;

--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.projects_id_seq OWNER TO mediate_owner;

--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: proposals; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.proposals (
    id bigint NOT NULL,
    repository_id bigint NOT NULL,
    proposer_id text NOT NULL,
    reviewer_id text,
    status text DEFAULT 'pending'::text NOT NULL,
    labels text[] DEFAULT ARRAY[]::text[] NOT NULL,
    restrictions text[] DEFAULT ARRAY[]::text[] NOT NULL,
    releasable_to text[] DEFAULT ARRAY[]::text[] NOT NULL,
    invited text[] DEFAULT ARRAY[]::text[] NOT NULL
);

ALTER TABLE ONLY public.proposals FORCE ROW LEVEL SECURITY;


ALTER TABLE public.proposals OWNER TO mediate_owner;

--
-- Name: proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.proposals_id_seq OWNER TO mediate_owner;

--
-- Name: proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.proposals_id_seq OWNED BY public.proposals.id;


--
-- Name: repositories; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.repositories (
    id bigint NOT NULL,
    name text NOT NULL,
    embargo timestamp(0) without time zone,
    project_id bigint NOT NULL,
    owning_team_id bigint NOT NULL
);

ALTER TABLE ONLY public.repositories FORCE ROW LEVEL SECURITY;


ALTER TABLE public.repositories OWNER TO mediate_owner;

--
-- Name: repositories_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.repositories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.repositories_id_seq OWNER TO mediate_owner;

--
-- Name: repositories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.repositories_id_seq OWNED BY public.repositories.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


ALTER TABLE public.schema_migrations OWNER TO mediate_owner;

--
-- Name: team_roles; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.team_roles (
    id bigint NOT NULL,
    account_id text NOT NULL,
    team_id bigint NOT NULL,
    role text NOT NULL
);


ALTER TABLE public.team_roles OWNER TO mediate_owner;

--
-- Name: team_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.team_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.team_roles_id_seq OWNER TO mediate_owner;

--
-- Name: team_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.team_roles_id_seq OWNED BY public.team_roles.id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    name text NOT NULL,
    enterprise_id bigint NOT NULL
);


ALTER TABLE public.teams OWNER TO mediate_owner;

--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teams_id_seq OWNER TO mediate_owner;

--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: visibilities; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.visibilities (
    id bigint NOT NULL,
    repository_id bigint NOT NULL,
    labels text[] DEFAULT ARRAY[]::text[] NOT NULL,
    restrictions text[] DEFAULT ARRAY[]::text[] NOT NULL,
    releasable_to text[] DEFAULT ARRAY[]::text[] NOT NULL,
    invited text[] DEFAULT ARRAY[]::text[] NOT NULL
);

ALTER TABLE ONLY public.visibilities FORCE ROW LEVEL SECURITY;


ALTER TABLE public.visibilities OWNER TO mediate_owner;

--
-- Name: visibilities_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.visibilities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visibilities_id_seq OWNER TO mediate_owner;

--
-- Name: visibilities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.visibilities_id_seq OWNED BY public.visibilities.id;


--
-- Name: directories id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.directories ALTER COLUMN id SET DEFAULT nextval('public.directories_id_seq'::regclass);


--
-- Name: enterprises id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.enterprises ALTER COLUMN id SET DEFAULT nextval('public.enterprises_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: override_reports id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports ALTER COLUMN id SET DEFAULT nextval('public.override_reports_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: proposals id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.proposals ALTER COLUMN id SET DEFAULT nextval('public.proposals_id_seq'::regclass);


--
-- Name: repositories id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.repositories ALTER COLUMN id SET DEFAULT nextval('public.repositories_id_seq'::regclass);


--
-- Name: team_roles id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles ALTER COLUMN id SET DEFAULT nextval('public.team_roles_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: visibilities id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibilities ALTER COLUMN id SET DEFAULT nextval('public.visibilities_id_seq'::regclass);


--
-- Name: accounts accounts_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.accounts
    ADD CONSTRAINT accounts_pkey PRIMARY KEY (id);


--
-- Name: directories directories_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.directories
    ADD CONSTRAINT directories_pkey PRIMARY KEY (id);


--
-- Name: enterprises enterprises_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.enterprises
    ADD CONSTRAINT enterprises_pkey PRIMARY KEY (id);


--
-- Name: labels labels_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.labels
    ADD CONSTRAINT labels_pkey PRIMARY KEY (name);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: override_reports override_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports
    ADD CONSTRAINT override_reports_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: proposals proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_pkey PRIMARY KEY (id);


--
-- Name: repositories repositories_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: team_roles team_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles
    ADD CONSTRAINT team_roles_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: visibilities visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibilities
    ADD CONSTRAINT visibilities_pkey PRIMARY KEY (id);


--
-- Name: memberships_account_id_project_id_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX memberships_account_id_project_id_index ON public.memberships USING btree (account_id, project_id);


--
-- Name: permissions_account_id_permission_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX permissions_account_id_permission_index ON public.permissions USING btree (account_id, permission);


--
-- Name: team_roles_account_id_team_id_role_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX team_roles_account_id_team_id_role_index ON public.team_roles USING btree (account_id, team_id, role);


--
-- Name: visibilities_repository_id_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX visibilities_repository_id_index ON public.visibilities USING btree (repository_id);


--
-- Name: directories directories_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.directories
    ADD CONSTRAINT directories_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: memberships memberships_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: memberships memberships_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: override_reports override_reports_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports
    ADD CONSTRAINT override_reports_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: override_reports override_reports_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports
    ADD CONSTRAINT override_reports_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: override_reports override_reports_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports
    ADD CONSTRAINT override_reports_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: permissions permissions_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: projects projects_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: proposals proposals_proposer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_proposer_id_fkey FOREIGN KEY (proposer_id) REFERENCES public.accounts(id);


--
-- Name: proposals proposals_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: proposals proposals_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.proposals
    ADD CONSTRAINT proposals_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.accounts(id);


--
-- Name: repositories repositories_owning_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_owning_team_id_fkey FOREIGN KEY (owning_team_id) REFERENCES public.teams(id);


--
-- Name: repositories repositories_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.repositories
    ADD CONSTRAINT repositories_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: team_roles team_roles_account_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles
    ADD CONSTRAINT team_roles_account_id_fkey FOREIGN KEY (account_id) REFERENCES public.accounts(id);


--
-- Name: team_roles team_roles_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles
    ADD CONSTRAINT team_roles_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: teams teams_enterprise_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_enterprise_id_fkey FOREIGN KEY (enterprise_id) REFERENCES public.enterprises(id);


--
-- Name: visibilities visibilities_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibilities
    ADD CONSTRAINT visibilities_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: directories; Type: ROW SECURITY; Schema: public; Owner: mediate_owner
--

ALTER TABLE public.directories ENABLE ROW LEVEL SECURITY;

--
-- Name: visibilities mediate_admit_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_admit_select ON public.visibilities FOR SELECT USING (true);


--
-- Name: directories mediate_exempt_mediate_app_insert; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_insert ON public.directories FOR INSERT WITH CHECK (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: repositories mediate_exempt_mediate_app_insert; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_insert ON public.repositories FOR INSERT WITH CHECK (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: visibilities mediate_exempt_mediate_app_insert; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_insert ON public.visibilities FOR INSERT WITH CHECK (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: directories mediate_exempt_mediate_app_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_select ON public.directories FOR SELECT USING (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: proposals mediate_exempt_mediate_app_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_select ON public.proposals FOR SELECT USING (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: repositories mediate_exempt_mediate_app_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_select ON public.repositories FOR SELECT USING (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: visibilities mediate_exempt_mediate_app_update; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_app_update ON public.visibilities FOR UPDATE USING (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text))) WITH CHECK (((CURRENT_USER = 'mediate_app'::name) AND (COALESCE(current_setting('mediate.action'::text, true), ''::text) = ''::text)));


--
-- Name: directories mediate_exempt_mediate_owner_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_owner_select ON public.directories FOR SELECT USING ((CURRENT_USER = 'mediate_owner'::name));


--
-- Name: proposals mediate_exempt_mediate_owner_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_owner_select ON public.proposals FOR SELECT USING ((CURRENT_USER = 'mediate_owner'::name));


--
-- Name: repositories mediate_exempt_mediate_owner_select; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_exempt_mediate_owner_select ON public.repositories FOR SELECT USING ((CURRENT_USER = 'mediate_owner'::name));


--
-- Name: proposals mediate_filter_approve_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_approve_visibility ON public.proposals FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'approve_visibility'::text) AND ((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(proposals.repository_id)) AND (r.role = ANY (ARRAY['reviewer'::text]))))) AND (proposer_id <> current_setting('mediate.subject_id'::text, true)))));


--
-- Name: repositories mediate_filter_approve_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_approve_visibility ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'approve_visibility'::text) AND (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['reviewer'::text])))))));


--
-- Name: directories mediate_filter_change_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_change_visibility ON public.directories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'change_visibility'::text) AND ((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(directories.repository_id)) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval)))));


--
-- Name: repositories mediate_filter_change_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_change_visibility ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'change_visibility'::text) AND ((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval)))));


--
-- Name: repositories mediate_filter_checkout; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_checkout ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'checkout'::text) AND ((EXISTS ( SELECT 1
   FROM (public.memberships m
     JOIN public.projects p ON ((p.id = m.project_id)))
  WHERE ((m.account_id = current_setting('mediate.subject_id'::text, true)) AND (m.project_id = repositories.project_id) AND (m.role = ANY (ARRAY['maintainer'::text, 'contributor'::text])) AND (p.archived_at IS NULL)))) OR (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text, 'reviewer'::text]))))))));


--
-- Name: repositories mediate_filter_lift_embargo; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_lift_embargo ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'lift_embargo'::text) AND ((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval)))));


--
-- Name: proposals mediate_filter_propose_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_propose_visibility ON public.proposals FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'propose_visibility'::text) AND (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(proposals.repository_id)) AND (r.role = ANY (ARRAY['admin'::text])))))));


--
-- Name: repositories mediate_filter_propose_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_propose_visibility ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'propose_visibility'::text) AND (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text])))))));


--
-- Name: directories mediate_filter_read; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_read ON public.directories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'read'::text) AND (((EXISTS ( SELECT 1
   FROM (public.memberships m
     JOIN public.projects p ON ((p.id = m.project_id)))
  WHERE ((m.account_id = current_setting('mediate.subject_id'::text, true)) AND (m.project_id = public.example_repository_project(directories.repository_id)) AND (m.role = ANY (ARRAY['maintainer'::text, 'contributor'::text])) AND (p.archived_at IS NULL)))) OR (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(directories.repository_id)) AND (r.role = ANY (ARRAY['admin'::text, 'reviewer'::text])))))) AND (NOT (EXISTS ( SELECT 1
   FROM ((((public.visibilities v
     JOIN public.teams t ON ((t.id = public.example_repository_owning_team(directories.repository_id))))
     JOIN public.enterprises e ON ((e.id = t.enterprise_id)))
     JOIN public.accounts a ON ((a.id = current_setting('mediate.subject_id'::text, true))))
     LEFT JOIN public.labels l ON (((l.name = ANY (directories.labels)) AND l.sensitive)))
  WHERE ((v.repository_id = directories.repository_id) AND ((public.example_repository_embargo(directories.repository_id) IS NULL) OR (public.example_repository_embargo(directories.repository_id) > (NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone)) AND (((('employees_only'::text = ANY (directories.restrictions)) OR ('employees_only'::text = ANY (l.implied_restrictions))) AND (a.employment <> 'employee'::text)) OR ((('export_controlled'::text = ANY (directories.restrictions)) OR ('export_controlled'::text = ANY (l.implied_restrictions))) AND (a.country <> e.country)) OR ((('invite_only'::text = ANY (directories.restrictions)) OR ('invite_only'::text = ANY (l.implied_restrictions))) AND (NOT (current_setting('mediate.subject_id'::text, true) = ANY (v.invited)))) OR ((('releasable_to'::text = ANY (directories.restrictions)) OR ('releasable_to'::text = ANY (l.implied_restrictions))) AND (NOT (a.country = ANY (directories.releasable_to))))))))))));


--
-- Name: repositories mediate_filter_read; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_read ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'read'::text) AND (((EXISTS ( SELECT 1
   FROM (public.memberships m
     JOIN public.projects p ON ((p.id = m.project_id)))
  WHERE ((m.account_id = current_setting('mediate.subject_id'::text, true)) AND (m.project_id = repositories.project_id) AND (m.role = ANY (ARRAY['maintainer'::text, 'contributor'::text])) AND (p.archived_at IS NULL)))) OR (EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text, 'reviewer'::text])))))) AND (NOT (EXISTS ( SELECT 1
   FROM ((((public.visibilities v
     JOIN public.teams t ON ((t.id = repositories.owning_team_id)))
     JOIN public.enterprises e ON ((e.id = t.enterprise_id)))
     JOIN public.accounts a ON ((a.id = current_setting('mediate.subject_id'::text, true))))
     LEFT JOIN public.labels l ON (((l.name = ANY (v.labels)) AND l.sensitive)))
  WHERE ((v.repository_id = repositories.id) AND ((repositories.embargo IS NULL) OR (repositories.embargo > (NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone)) AND (((('employees_only'::text = ANY (v.restrictions)) OR ('employees_only'::text = ANY (l.implied_restrictions))) AND (a.employment <> 'employee'::text)) OR ((('export_controlled'::text = ANY (v.restrictions)) OR ('export_controlled'::text = ANY (l.implied_restrictions))) AND (a.country <> e.country)) OR ((('invite_only'::text = ANY (v.restrictions)) OR ('invite_only'::text = ANY (l.implied_restrictions))) AND (NOT (current_setting('mediate.subject_id'::text, true) = ANY (v.invited)))) OR ((('releasable_to'::text = ANY (v.restrictions)) OR ('releasable_to'::text = ANY (l.implied_restrictions))) AND (NOT (a.country = ANY (v.releasable_to))))))))))));


--
-- Name: repositories mediate_filter_set_embargo; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_filter_set_embargo ON public.repositories FOR SELECT USING (((current_setting('mediate.action'::text, true) = 'set_embargo'::text) AND ((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval)))));


--
-- Name: proposals mediate_gate_approve_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_approve_visibility ON public.proposals FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(proposals.repository_id)) AND (r.role = ANY (ARRAY['reviewer'::text]))))) AND (proposer_id <> current_setting('mediate.subject_id'::text, true))));


--
-- Name: visibilities mediate_gate_approve_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_approve_visibility ON public.visibilities FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(visibilities.repository_id)) AND (r.role = ANY (ARRAY['reviewer'::text]))))) AND (EXISTS ( SELECT 1
   FROM public.proposals p
  WHERE ((p.repository_id = visibilities.repository_id) AND (p.status = 'pending'::text) AND (p.proposer_id <> current_setting('mediate.subject_id'::text, true)))))));


--
-- Name: directories mediate_gate_change_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_change_visibility ON public.directories FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(directories.repository_id)) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval))));


--
-- Name: repositories mediate_gate_change_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_change_visibility ON public.repositories FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval))));


--
-- Name: visibilities mediate_gate_change_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_change_visibility ON public.visibilities FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(visibilities.repository_id)) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval))));


--
-- Name: repositories mediate_gate_lift_embargo; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_lift_embargo ON public.repositories FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval))));


--
-- Name: proposals mediate_gate_propose_visibility; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_propose_visibility ON public.proposals FOR INSERT WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = public.example_repository_owning_team(proposals.repository_id)) AND (r.role = ANY (ARRAY['admin'::text]))))) AND (proposer_id = current_setting('mediate.subject_id'::text, true))));


--
-- Name: repositories mediate_gate_set_embargo; Type: POLICY; Schema: public; Owner: mediate_owner
--

CREATE POLICY mediate_gate_set_embargo ON public.repositories FOR UPDATE USING (true) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.team_roles r
  WHERE ((r.account_id = current_setting('mediate.subject_id'::text, true)) AND (r.team_id = repositories.owning_team_id) AND (r.role = ANY (ARRAY['admin'::text]))))) AND ((((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) >= '00:00:00'::interval) AND (((NULLIF(current_setting('mediate.now'::text, true), ''::text))::timestamp without time zone - (NULLIF(current_setting('mediate.reauthenticated_at'::text, true), ''::text))::timestamp without time zone) <= '00:15:00'::interval))));


--
-- Name: proposals; Type: ROW SECURITY; Schema: public; Owner: mediate_owner
--

ALTER TABLE public.proposals ENABLE ROW LEVEL SECURITY;

--
-- Name: repositories; Type: ROW SECURITY; Schema: public; Owner: mediate_owner
--

ALTER TABLE public.repositories ENABLE ROW LEVEL SECURITY;

--
-- Name: visibilities; Type: ROW SECURITY; Schema: public; Owner: mediate_owner
--

ALTER TABLE public.visibilities ENABLE ROW LEVEL SECURITY;

--
-- Name: FUNCTION example_repository_embargo(repository bigint); Type: ACL; Schema: public; Owner: mediate_owner
--

REVOKE ALL ON FUNCTION public.example_repository_embargo(repository bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.example_repository_embargo(repository bigint) TO mediate_app;


--
-- Name: FUNCTION example_repository_owning_team(repository bigint); Type: ACL; Schema: public; Owner: mediate_owner
--

REVOKE ALL ON FUNCTION public.example_repository_owning_team(repository bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.example_repository_owning_team(repository bigint) TO mediate_app;


--
-- Name: FUNCTION example_repository_project(repository bigint); Type: ACL; Schema: public; Owner: mediate_owner
--

REVOKE ALL ON FUNCTION public.example_repository_project(repository bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.example_repository_project(repository bigint) TO mediate_app;


--
-- Name: TABLE accounts; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.accounts TO mediate_app;


--
-- Name: TABLE directories; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.directories TO mediate_app;


--
-- Name: SEQUENCE directories_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.directories_id_seq TO mediate_app;


--
-- Name: TABLE enterprises; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.enterprises TO mediate_app;


--
-- Name: SEQUENCE enterprises_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.enterprises_id_seq TO mediate_app;


--
-- Name: TABLE labels; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.labels TO mediate_app;


--
-- Name: TABLE memberships; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.memberships TO mediate_app;


--
-- Name: SEQUENCE memberships_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.memberships_id_seq TO mediate_app;


--
-- Name: TABLE override_reports; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.override_reports TO mediate_app;


--
-- Name: SEQUENCE override_reports_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.override_reports_id_seq TO mediate_app;


--
-- Name: TABLE permissions; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.permissions TO mediate_app;


--
-- Name: SEQUENCE permissions_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.permissions_id_seq TO mediate_app;


--
-- Name: TABLE projects; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.projects TO mediate_app;


--
-- Name: SEQUENCE projects_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.projects_id_seq TO mediate_app;


--
-- Name: TABLE proposals; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.proposals TO mediate_app;


--
-- Name: SEQUENCE proposals_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.proposals_id_seq TO mediate_app;


--
-- Name: TABLE repositories; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.repositories TO mediate_app;


--
-- Name: SEQUENCE repositories_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.repositories_id_seq TO mediate_app;


--
-- Name: TABLE schema_migrations; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT ON TABLE public.schema_migrations TO mediate_app;


--
-- Name: TABLE team_roles; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.team_roles TO mediate_app;


--
-- Name: SEQUENCE team_roles_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.team_roles_id_seq TO mediate_app;


--
-- Name: TABLE teams; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.teams TO mediate_app;


--
-- Name: SEQUENCE teams_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.teams_id_seq TO mediate_app;


--
-- Name: TABLE visibilities; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.visibilities TO mediate_app;


--
-- Name: SEQUENCE visibilities_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.visibilities_id_seq TO mediate_app;


--
-- PostgreSQL database dump complete
--


