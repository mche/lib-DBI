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
  name character varying not null,
  code text,
  content_type text,
  last_modified timestamp without time zone not null,
  "order" numeric,
  disabled boolean,
  autoload boolean,
  unique(module_id, name)
);


INSERT INTO modules VALUES (4, '2017-04-02 15:32:10', 'Foo2', NULL, NULL);
INSERT INTO modules VALUES (6, '2017-04-02 15:33:10', 'Foo3', NULL, NULL);
INSERT INTO modules VALUES (10, '2017-04-02 15:33:10', 'Foo5.js', NULL, NULL);
INSERT INTO modules VALUES (12, '2017-04-02 15:33:10', 'Foo6', NULL, NULL);

INSERT INTO subs VALUES (5, '2017-04-02 15:35:15', 4, 'init', E'package Foo2;\n', NULL, '2017-04-02 15:35:15', 1, NULL, NULL);
INSERT INTO subs VALUES (8, '2017-04-02 15:35:15', 4, 'new', E'sub new {bless {};}', NULL, '2017-04-02 15:35:15', 2, NULL, NULL);
INSERT INTO subs VALUES (9, '2017-04-02 15:35:15', 4, 'bar', E'sub bar {return "Foo2 bar sub";}', NULL, '2017-04-02 15:35:15', 3, NULL, NULL);


INSERT INTO subs VALUES (7, '2017-04-02 15:36:15', 6, 'bar', E'package Foo3;\n sub new {bless {};}\n sub bar {return "Foo3 bar sub";}\n 1;', NULL, '2017-04-02 15:36:15', NULL, NULL, NULL);

INSERT INTO subs VALUES (11, '2017-04-02 15:36:15', 10, 'bar', E'anfular.module()', NULL, '2017-04-02 15:36:15', NULL, NULL, NULL);

INSERT INTO subs VALUES (13, '2017-04-02 15:36:15', 12, 'bar', E'Foo6 content', NULL, '2017-04-02 15:36:15', NULL, NULL, NULL);
