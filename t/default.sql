CREATE SEQUENCE IF NOT EXISTS "ID";

CREATE TABLE IF NOT EXISTS "modules" (
  id integer default nextval('"ID"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  name character varying not null unique,
  descr text,
  disabled boolean
);


CREATE TABLE IF NOT EXISTS "subs" (
  id integer default nextval('"ID"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  name character varying not null unique,
  code text,
  content_type text,
  last_modified timestamp without time zone not null,
  "order" numeric,
  disabled boolean,
  autoload boolean
);

CREATE TABLE IF NOT EXISTS "refs" (
  id integer default nextval('"ID"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  id1 int not null,
  id2 int not null,
  unique(id1, id2)
  -- also CREATE INDEX on "refs" (id2);
);