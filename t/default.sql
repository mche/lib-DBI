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
  module_id int not null REFERENCES "modules"(id),
  name character varying not null unique,
  code text,
  content_type text,
  last_modified timestamp without time zone not null,
  "order" numeric,
  disabled boolean,
  autoload boolean
);
