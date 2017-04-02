CREATE SEQUENCE IF NOT EXISTS "ИД";
-- контроллеры
CREATE TABLE IF NOT EXISTS "контроллеры" (
  id integer default nextval('"ИД"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  controller character varying not null,
  descr text null
);

-- действия
CREATE TABLE IF NOT EXISTS  "действия" (
  id integer default nextval('"ИД"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  action character varying not null,
  callback text null,
  descr text null
);

CREATE TABLE IF NOT EXISTS "связи" (
  id integer default nextval('"ИД"'::regclass) not null primary key,
  ts timestamp without time zone not null default now(),
  id1 int not null,
  id2 int not null,
  unique(id1, id2)
  -- also CREATE INDEX on "refs" (id2);
);