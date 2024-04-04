-- Purpose: Define a schema to store sensors data along with the installation and signal metadata.
-- Author: F. Etchezar

-- Instalation uses integer ids for efficient memory representation, index joins, etc
-- Can be expanded with per-installation metadata (type, location, description, etc)

create table installation (
    id int8 primary key not null,
    name text unique not null
);

-- one installation, many signals
-- can be expanded with per-signal metadata (data type, unit, max/min ranges, etc)
create table signal (
    id int8 primary key not null,
    name text unique not null,
    id_installation int8 not null,
    foreign key (id_installation) references installation(id)
);


create table sample (
    id int8 not null,
    tstamp timestamptz not null,
    value_f64 float8,
    value_i64 int8,
    value_bool boolean,
    quality boolean not null,
    primary key (id, tstamp),
    foreign key (id) references signal(id)
);

-- convenience view for users that dont care about precise boolean/int64 representation

create view sample_numeric as
select id,
  tstamp, 
  coalesce(value_f64, value_i64, value_bool::int4) as value,
  quality
from sample;



