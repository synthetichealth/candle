--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.2
-- Dumped by pg_dump version 9.6.2

-- Started on 2017-06-01 13:15:10 EDT

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE fhir;
--
-- TOC entry 2410 (class 1262 OID 16384)
-- Name: fhir; Type: DATABASE; Schema: -; Owner: candle
--

CREATE DATABASE fhir WITH TEMPLATE = template0 ENCODING = 'UTF8' LC_COLLATE = 'en_US.UTF-8' LC_CTYPE = 'en_US.UTF-8';


ALTER DATABASE fhir OWNER TO candle;

\connect fhir

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 1 (class 3079 OID 12655)
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- TOC entry 2412 (class 0 OID 0)
-- Dependencies: 1
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = public, pg_catalog;

--
-- TOC entry 188 (class 1259 OID 19250)
-- Name: observation_id_seq; Type: SEQUENCE; Schema: public; Owner: candle
--

CREATE SEQUENCE observation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE observation_id_seq OWNER TO candle;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- TOC entry 187 (class 1259 OID 19238)
-- Name: observation; Type: TABLE; Schema: public; Owner: candle
--

CREATE TABLE observation (
    id bigint DEFAULT nextval('observation_id_seq'::regclass) NOT NULL,
    patient bigint,
    encounter bigint,
    code character varying(80) NOT NULL,
    resource jsonb NOT NULL
);


ALTER TABLE observation OWNER TO candle;

--
-- TOC entry 186 (class 1259 OID 16387)
-- Name: patient; Type: TABLE; Schema: public; Owner: candle
--

CREATE TABLE patient (
    id bigint NOT NULL,
    name character varying(64),
    resource jsonb NOT NULL,
    race character varying(6),
    ethnicity character varying(6)
);


ALTER TABLE patient OWNER TO candle;

--
-- TOC entry 185 (class 1259 OID 16385)
-- Name: patient_id_seq; Type: SEQUENCE; Schema: public; Owner: candle
--

CREATE SEQUENCE patient_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE patient_id_seq OWNER TO candle;

--
-- TOC entry 2413 (class 0 OID 0)
-- Dependencies: 185
-- Name: patient_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: candle
--

ALTER SEQUENCE patient_id_seq OWNED BY patient.id;


--
-- TOC entry 2275 (class 2604 OID 16390)
-- Name: patient id; Type: DEFAULT; Schema: public; Owner: candle
--

ALTER TABLE ONLY patient ALTER COLUMN id SET DEFAULT nextval('patient_id_seq'::regclass);


--
-- TOC entry 2287 (class 2606 OID 19245)
-- Name: observation observation_pkey; Type: CONSTRAINT; Schema: public; Owner: candle
--

ALTER TABLE ONLY observation
    ADD CONSTRAINT observation_pkey PRIMARY KEY (id);


--
-- TOC entry 2280 (class 2606 OID 16395)
-- Name: patient patient_pkey; Type: CONSTRAINT; Schema: public; Owner: candle
--

ALTER TABLE ONLY patient
    ADD CONSTRAINT patient_pkey PRIMARY KEY (id);


--
-- TOC entry 2283 (class 1259 OID 19248)
-- Name: observation_code_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX observation_code_index ON observation USING btree (code varchar_ops);


--
-- TOC entry 2284 (class 1259 OID 19247)
-- Name: observation_encounter_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX observation_encounter_index ON observation USING btree (encounter);


--
-- TOC entry 2285 (class 1259 OID 19246)
-- Name: observation_patient_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX observation_patient_index ON observation USING btree (patient);


--
-- TOC entry 2288 (class 1259 OID 19249)
-- Name: observation_resource_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX observation_resource_index ON observation USING gin (resource);


--
-- TOC entry 2277 (class 1259 OID 18226)
-- Name: patient_ethnicity_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX patient_ethnicity_index ON patient USING hash (ethnicity);


--
-- TOC entry 2278 (class 1259 OID 18652)
-- Name: patient_name_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX patient_name_index ON patient USING btree (name varchar_ops);


--
-- TOC entry 2281 (class 1259 OID 18225)
-- Name: patient_race_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX patient_race_index ON patient USING hash (race);


--
-- TOC entry 2282 (class 1259 OID 16396)
-- Name: patient_resource_index; Type: INDEX; Schema: public; Owner: candle
--

CREATE INDEX patient_resource_index ON patient USING gin (resource);


-- Completed on 2017-06-01 13:15:11 EDT

--
-- PostgreSQL database dump complete
--

