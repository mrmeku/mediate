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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: account_roles; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.account_roles (
    id bigint NOT NULL,
    user_id text NOT NULL,
    role text NOT NULL
);


ALTER TABLE public.account_roles OWNER TO mediate_owner;

--
-- Name: account_roles_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.account_roles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.account_roles_id_seq OWNER TO mediate_owner;

--
-- Name: account_roles_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.account_roles_id_seq OWNED BY public.account_roles.id;


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
    user_id text NOT NULL,
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
    user_id text NOT NULL,
    justification text NOT NULL,
    operation_id text NOT NULL,
    at timestamp(0) without time zone NOT NULL
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
-- Name: repositories; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.repositories (
    id bigint NOT NULL,
    name text NOT NULL,
    embargo timestamp(0) without time zone,
    project_id bigint NOT NULL,
    owning_team_id bigint NOT NULL
);


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
    user_id text NOT NULL,
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
-- Name: users; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.users (
    id text NOT NULL,
    name text NOT NULL,
    kind text NOT NULL,
    person_id text NOT NULL,
    employment text NOT NULL,
    country text NOT NULL
);


ALTER TABLE public.users OWNER TO mediate_owner;

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
-- Name: visibility_proposals; Type: TABLE; Schema: public; Owner: mediate_owner
--

CREATE TABLE public.visibility_proposals (
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


ALTER TABLE public.visibility_proposals OWNER TO mediate_owner;

--
-- Name: visibility_proposals_id_seq; Type: SEQUENCE; Schema: public; Owner: mediate_owner
--

CREATE SEQUENCE public.visibility_proposals_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.visibility_proposals_id_seq OWNER TO mediate_owner;

--
-- Name: visibility_proposals_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: mediate_owner
--

ALTER SEQUENCE public.visibility_proposals_id_seq OWNED BY public.visibility_proposals.id;


--
-- Name: account_roles id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.account_roles ALTER COLUMN id SET DEFAULT nextval('public.account_roles_id_seq'::regclass);


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
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


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
-- Name: visibility_proposals id; Type: DEFAULT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibility_proposals ALTER COLUMN id SET DEFAULT nextval('public.visibility_proposals_id_seq'::regclass);


--
-- Name: account_roles account_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.account_roles
    ADD CONSTRAINT account_roles_pkey PRIMARY KEY (id);


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
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


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
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: visibilities visibilities_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibilities
    ADD CONSTRAINT visibilities_pkey PRIMARY KEY (id);


--
-- Name: visibility_proposals visibility_proposals_pkey; Type: CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibility_proposals
    ADD CONSTRAINT visibility_proposals_pkey PRIMARY KEY (id);


--
-- Name: account_roles_user_id_role_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX account_roles_user_id_role_index ON public.account_roles USING btree (user_id, role);


--
-- Name: memberships_user_id_project_id_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX memberships_user_id_project_id_index ON public.memberships USING btree (user_id, project_id);


--
-- Name: team_roles_user_id_team_id_role_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX team_roles_user_id_team_id_role_index ON public.team_roles USING btree (user_id, team_id, role);


--
-- Name: visibilities_repository_id_index; Type: INDEX; Schema: public; Owner: mediate_owner
--

CREATE UNIQUE INDEX visibilities_repository_id_index ON public.visibilities USING btree (repository_id);


--
-- Name: account_roles account_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.account_roles
    ADD CONSTRAINT account_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: directories directories_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.directories
    ADD CONSTRAINT directories_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: memberships memberships_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: memberships memberships_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: override_reports override_reports_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.override_reports
    ADD CONSTRAINT override_reports_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: projects projects_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


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
-- Name: team_roles team_roles_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles
    ADD CONSTRAINT team_roles_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id);


--
-- Name: team_roles team_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.team_roles
    ADD CONSTRAINT team_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


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
-- Name: visibility_proposals visibility_proposals_proposer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibility_proposals
    ADD CONSTRAINT visibility_proposals_proposer_id_fkey FOREIGN KEY (proposer_id) REFERENCES public.users(id);


--
-- Name: visibility_proposals visibility_proposals_repository_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibility_proposals
    ADD CONSTRAINT visibility_proposals_repository_id_fkey FOREIGN KEY (repository_id) REFERENCES public.repositories(id);


--
-- Name: visibility_proposals visibility_proposals_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: mediate_owner
--

ALTER TABLE ONLY public.visibility_proposals
    ADD CONSTRAINT visibility_proposals_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.users(id);


--
-- Name: TABLE account_roles; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.account_roles TO mediate_app;


--
-- Name: SEQUENCE account_roles_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.account_roles_id_seq TO mediate_app;


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
-- Name: TABLE projects; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.projects TO mediate_app;


--
-- Name: SEQUENCE projects_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.projects_id_seq TO mediate_app;


--
-- Name: TABLE repositories; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.repositories TO mediate_app;


--
-- Name: SEQUENCE repositories_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.repositories_id_seq TO mediate_app;


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
-- Name: TABLE users; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.users TO mediate_app;


--
-- Name: TABLE visibilities; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.visibilities TO mediate_app;


--
-- Name: SEQUENCE visibilities_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.visibilities_id_seq TO mediate_app;


--
-- Name: TABLE visibility_proposals; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE public.visibility_proposals TO mediate_app;


--
-- Name: SEQUENCE visibility_proposals_id_seq; Type: ACL; Schema: public; Owner: mediate_owner
--

GRANT SELECT,USAGE ON SEQUENCE public.visibility_proposals_id_seq TO mediate_app;


--
-- PostgreSQL database dump complete
--


