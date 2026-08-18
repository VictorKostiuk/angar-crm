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
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


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
-- Name: bikes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bikes (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    brand character varying,
    client_id bigint NOT NULL,
    color character varying,
    created_at timestamp(6) without time zone NOT NULL,
    model character varying,
    name character varying NOT NULL,
    notes text,
    size character varying,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: bikes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.bikes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: bikes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.bikes_id_seq OWNED BY public.bikes.id;


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    kind integer NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: clients; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.clients (
    id bigint NOT NULL,
    bikes_count integer DEFAULT 0 NOT NULL,
    city character varying,
    created_at timestamp(6) without time zone NOT NULL,
    email character varying,
    name character varying NOT NULL,
    notes text,
    orders_count integer DEFAULT 0 NOT NULL,
    phone character varying NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: clients_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.clients_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.clients_id_seq OWNED BY public.clients.id;


--
-- Name: discounts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.discounts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    kind integer DEFAULT 0 NOT NULL,
    value numeric(8,2) NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: discounts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.discounts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: discounts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.discounts_id_seq OWNED BY public.discounts.id;


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.expenses (
    id bigint NOT NULL,
    category character varying NOT NULL,
    amount numeric(12,2) NOT NULL,
    description character varying,
    date date NOT NULL,
    user_id bigint,
    stock_movement_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.expenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.expenses_id_seq OWNED BY public.expenses.id;


--
-- Name: order_number_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_number_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_parts (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    part_id bigint,
    name character varying NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    price numeric(12,2) NOT NULL,
    total numeric(12,2) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: order_parts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_parts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_parts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_parts_id_seq OWNED BY public.order_parts.id;


--
-- Name: order_status_changes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_status_changes (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    user_id bigint NOT NULL,
    from_status character varying NOT NULL,
    to_status character varying NOT NULL,
    comment character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: order_status_changes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_status_changes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_status_changes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_status_changes_id_seq OWNED BY public.order_status_changes.id;


--
-- Name: order_works; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.order_works (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    service_id bigint,
    mechanic_id bigint,
    name character varying NOT NULL,
    quantity numeric(8,2) DEFAULT 1.0 NOT NULL,
    price numeric(12,2) NOT NULL,
    total numeric(12,2) NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: order_works_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.order_works_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: order_works_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.order_works_id_seq OWNED BY public.order_works.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    number integer DEFAULT nextval('public.order_number_seq'::regclass) NOT NULL,
    client_id bigint NOT NULL,
    bike_id bigint NOT NULL,
    mechanic_id bigint,
    accepted_by_id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    problem text,
    comment text,
    accepted_at timestamp(6) without time zone NOT NULL,
    expected_ready_on date,
    closed_at timestamp(6) without time zone,
    cancelled_at timestamp(6) without time zone,
    cancel_reason text,
    payment_status integer DEFAULT 0 NOT NULL,
    paid_at timestamp(6) without time zone,
    payment_method integer,
    receipt_number character varying,
    works_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    parts_total numeric(12,2) DEFAULT 0.0 NOT NULL,
    discount numeric(12,2) DEFAULT 0.0 NOT NULL,
    total numeric(12,2) DEFAULT 0.0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parts (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    base_price numeric(12,2) DEFAULT 0.0 NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    sku character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    supplier_id bigint,
    purchase_price numeric(12,2),
    stock_quantity integer DEFAULT 0 NOT NULL
);


--
-- Name: parts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.parts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: parts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.parts_id_seq OWNED BY public.parts.id;


--
-- Name: payroll_payouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payroll_payouts (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    recorded_by_id bigint NOT NULL,
    amount numeric(12,2) NOT NULL,
    period_month date NOT NULL,
    note character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: payroll_payouts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payroll_payouts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payroll_payouts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payroll_payouts_id_seq OWNED BY public.payroll_payouts.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: services; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.services (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    base_price numeric(12,2) DEFAULT 0.0 NOT NULL,
    category_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: services_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.services_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: services_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.services_id_seq OWNED BY public.services.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    ip_address character varying,
    updated_at timestamp(6) without time zone NOT NULL,
    user_agent character varying,
    user_id bigint NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: stock_movements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stock_movements (
    id bigint NOT NULL,
    part_id bigint NOT NULL,
    user_id bigint,
    order_id bigint,
    kind integer NOT NULL,
    quantity integer NOT NULL,
    note character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: stock_movements_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.stock_movements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: stock_movements_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.stock_movements_id_seq OWNED BY public.stock_movements.id;


--
-- Name: suppliers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.suppliers (
    id bigint NOT NULL,
    name character varying NOT NULL,
    phone character varying,
    email character varying,
    notes text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: suppliers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.suppliers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: suppliers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.suppliers_id_seq OWNED BY public.suppliers.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    email_address character varying NOT NULL,
    name character varying NOT NULL,
    password_digest character varying NOT NULL,
    payroll_percent numeric(5,2) DEFAULT 0.0 NOT NULL,
    phone character varying,
    role integer DEFAULT 0 NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: bikes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bikes ALTER COLUMN id SET DEFAULT nextval('public.bikes_id_seq'::regclass);


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: clients id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients ALTER COLUMN id SET DEFAULT nextval('public.clients_id_seq'::regclass);


--
-- Name: discounts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discounts ALTER COLUMN id SET DEFAULT nextval('public.discounts_id_seq'::regclass);


--
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses ALTER COLUMN id SET DEFAULT nextval('public.expenses_id_seq'::regclass);


--
-- Name: order_parts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_parts ALTER COLUMN id SET DEFAULT nextval('public.order_parts_id_seq'::regclass);


--
-- Name: order_status_changes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_changes ALTER COLUMN id SET DEFAULT nextval('public.order_status_changes_id_seq'::regclass);


--
-- Name: order_works id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_works ALTER COLUMN id SET DEFAULT nextval('public.order_works_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: parts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts ALTER COLUMN id SET DEFAULT nextval('public.parts_id_seq'::regclass);


--
-- Name: payroll_payouts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payouts ALTER COLUMN id SET DEFAULT nextval('public.payroll_payouts_id_seq'::regclass);


--
-- Name: services id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services ALTER COLUMN id SET DEFAULT nextval('public.services_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: stock_movements id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements ALTER COLUMN id SET DEFAULT nextval('public.stock_movements_id_seq'::regclass);


--
-- Name: suppliers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers ALTER COLUMN id SET DEFAULT nextval('public.suppliers_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: bikes bikes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bikes
    ADD CONSTRAINT bikes_pkey PRIMARY KEY (id);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: clients clients_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_pkey PRIMARY KEY (id);


--
-- Name: discounts discounts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.discounts
    ADD CONSTRAINT discounts_pkey PRIMARY KEY (id);


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: order_parts order_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_parts
    ADD CONSTRAINT order_parts_pkey PRIMARY KEY (id);


--
-- Name: order_status_changes order_status_changes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_changes
    ADD CONSTRAINT order_status_changes_pkey PRIMARY KEY (id);


--
-- Name: order_works order_works_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_works
    ADD CONSTRAINT order_works_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: parts parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT parts_pkey PRIMARY KEY (id);


--
-- Name: payroll_payouts payroll_payouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payouts
    ADD CONSTRAINT payroll_payouts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: services services_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT services_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: stock_movements stock_movements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);


--
-- Name: suppliers suppliers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.suppliers
    ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_bikes_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_active ON public.bikes USING btree (active);


--
-- Name: index_bikes_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_bikes_on_client_id ON public.bikes USING btree (client_id);


--
-- Name: index_categories_on_kind_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_categories_on_kind_and_name ON public.categories USING btree (kind, name);


--
-- Name: index_clients_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_clients_on_name ON public.clients USING btree (name);


--
-- Name: index_clients_on_phone; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_clients_on_phone ON public.clients USING btree (phone);


--
-- Name: index_expenses_on_stock_movement_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_expenses_on_stock_movement_id ON public.expenses USING btree (stock_movement_id);


--
-- Name: index_expenses_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_expenses_on_user_id ON public.expenses USING btree (user_id);


--
-- Name: index_order_parts_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_parts_on_order_id ON public.order_parts USING btree (order_id);


--
-- Name: index_order_parts_on_part_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_parts_on_part_id ON public.order_parts USING btree (part_id);


--
-- Name: index_order_status_changes_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_status_changes_on_created_at ON public.order_status_changes USING btree (created_at);


--
-- Name: index_order_status_changes_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_status_changes_on_order_id ON public.order_status_changes USING btree (order_id);


--
-- Name: index_order_status_changes_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_status_changes_on_user_id ON public.order_status_changes USING btree (user_id);


--
-- Name: index_order_works_on_mechanic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_works_on_mechanic_id ON public.order_works USING btree (mechanic_id);


--
-- Name: index_order_works_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_works_on_order_id ON public.order_works USING btree (order_id);


--
-- Name: index_order_works_on_service_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_order_works_on_service_id ON public.order_works USING btree (service_id);


--
-- Name: index_orders_on_accepted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_accepted_by_id ON public.orders USING btree (accepted_by_id);


--
-- Name: index_orders_on_bike_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_bike_id ON public.orders USING btree (bike_id);


--
-- Name: index_orders_on_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_client_id ON public.orders USING btree (client_id);


--
-- Name: index_orders_on_closed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_closed_at ON public.orders USING btree (closed_at);


--
-- Name: index_orders_on_mechanic_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_mechanic_id ON public.orders USING btree (mechanic_id);


--
-- Name: index_orders_on_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_orders_on_number ON public.orders USING btree (number);


--
-- Name: index_orders_on_payment_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_payment_status ON public.orders USING btree (payment_status);


--
-- Name: index_orders_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_status ON public.orders USING btree (status);


--
-- Name: index_orders_on_status_and_accepted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_status_and_accepted_at ON public.orders USING btree (status, accepted_at);


--
-- Name: index_parts_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parts_on_active ON public.parts USING btree (active);


--
-- Name: index_parts_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parts_on_category_id ON public.parts USING btree (category_id);


--
-- Name: index_parts_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parts_on_name ON public.parts USING btree (name);


--
-- Name: index_parts_on_supplier_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_parts_on_supplier_id ON public.parts USING btree (supplier_id);


--
-- Name: index_payroll_payouts_on_recorded_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payroll_payouts_on_recorded_by_id ON public.payroll_payouts USING btree (recorded_by_id);


--
-- Name: index_payroll_payouts_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payroll_payouts_on_user_id ON public.payroll_payouts USING btree (user_id);


--
-- Name: index_services_on_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_active ON public.services USING btree (active);


--
-- Name: index_services_on_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_category_id ON public.services USING btree (category_id);


--
-- Name: index_services_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_services_on_name ON public.services USING btree (name);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_stock_movements_on_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_order_id ON public.stock_movements USING btree (order_id);


--
-- Name: index_stock_movements_on_part_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_part_id ON public.stock_movements USING btree (part_id);


--
-- Name: index_stock_movements_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_stock_movements_on_user_id ON public.stock_movements USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_users_on_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_role ON public.users USING btree (role);


--
-- Name: order_parts fk_rails_0534267129; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_parts
    ADD CONSTRAINT fk_rails_0534267129 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: orders fk_rails_06a0907d53; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_06a0907d53 FOREIGN KEY (bike_id) REFERENCES public.bikes(id);


--
-- Name: parts fk_rails_079855e799; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT fk_rails_079855e799 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: order_status_changes fk_rails_2034632817; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_changes
    ADD CONSTRAINT fk_rails_2034632817 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: orders fk_rails_3418198e54; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_3418198e54 FOREIGN KEY (accepted_by_id) REFERENCES public.users(id);


--
-- Name: order_parts fk_rails_3a172281cb; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_parts
    ADD CONSTRAINT fk_rails_3a172281cb FOREIGN KEY (part_id) REFERENCES public.parts(id);


--
-- Name: expenses fk_rails_3abf476668; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_3abf476668 FOREIGN KEY (stock_movement_id) REFERENCES public.stock_movements(id);


--
-- Name: payroll_payouts fk_rails_597acc77d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payouts
    ADD CONSTRAINT fk_rails_597acc77d9 FOREIGN KEY (recorded_by_id) REFERENCES public.users(id);


--
-- Name: services fk_rails_5a36fd9326; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.services
    ADD CONSTRAINT fk_rails_5a36fd9326 FOREIGN KEY (category_id) REFERENCES public.categories(id);


--
-- Name: orders fk_rails_5c8e53c896; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_5c8e53c896 FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: order_works fk_rails_641fe09bb5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_works
    ADD CONSTRAINT fk_rails_641fe09bb5 FOREIGN KEY (service_id) REFERENCES public.services(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: payroll_payouts fk_rails_826a8f4298; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payroll_payouts
    ADD CONSTRAINT fk_rails_826a8f4298 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: stock_movements fk_rails_99bcc2c44a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_99bcc2c44a FOREIGN KEY (part_id) REFERENCES public.parts(id);


--
-- Name: parts fk_rails_a6f95ed203; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parts
    ADD CONSTRAINT fk_rails_a6f95ed203 FOREIGN KEY (supplier_id) REFERENCES public.suppliers(id);


--
-- Name: order_works fk_rails_a7099870b2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_works
    ADD CONSTRAINT fk_rails_a7099870b2 FOREIGN KEY (mechanic_id) REFERENCES public.users(id);


--
-- Name: stock_movements fk_rails_a739cce371; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_a739cce371 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: stock_movements fk_rails_c399f74509; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stock_movements
    ADD CONSTRAINT fk_rails_c399f74509 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: expenses fk_rails_c3ee69df61; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT fk_rails_c3ee69df61 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: bikes fk_rails_cf97b7d60d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bikes
    ADD CONSTRAINT fk_rails_cf97b7d60d FOREIGN KEY (client_id) REFERENCES public.clients(id);


--
-- Name: order_works fk_rails_d7d9d4e801; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_works
    ADD CONSTRAINT fk_rails_d7d9d4e801 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- Name: orders fk_rails_f4680e5de4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT fk_rails_f4680e5de4 FOREIGN KEY (mechanic_id) REFERENCES public.users(id);


--
-- Name: order_status_changes fk_rails_fba94f0c84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.order_status_changes
    ADD CONSTRAINT fk_rails_fba94f0c84 FOREIGN KEY (order_id) REFERENCES public.orders(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260818190722'),
('20260818180317'),
('20260818150720'),
('20260818125557'),
('20260818123251'),
('20260818122545'),
('20260818114218'),
('20260818113513'),
('20260818113500'),
('20260817222816'),
('20260817214148'),
('20260817214147'),
('20260817214129'),
('20260817212509'),
('20260817212508'),
('20260817212438'),
('20260817211706'),
('20260817211701'),
('20260817204915'),
('20260817204914');

