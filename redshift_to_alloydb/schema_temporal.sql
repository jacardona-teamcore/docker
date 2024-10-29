create type type_get_load_table as(
	id integer,
	tabla varchar,
	esquema varchar
);

create schema temporal;

drop table if exists temporal.tables_load;
create table temporal.tables_load(
	id serial primary key,
	tabla varchar,
	esquema varchar,
	estado varchar default 'PENDIENTE',
	foraneas integer default 0
);

drop table if exists temporal.tables_foreing;
create table temporal.tables_foreing(
	id integer,
	tabla varchar,
	esquema varchar,
	id_foranea integer,
	tabla_foranea varchar,
	esquema_foranea varchar
);

drop table if exists temporal.logs_migration;
create table temporal.logs_migration(
	tabla varchar,
	esquema varchar,
	logs varchar
);

CREATE OR REPLACE FUNCTION generate_create_table_statement(p_schema varchar, p_table varchar)
  RETURNS text AS
$BODY$
DECLARE
    v_tabla_ddl   text;
    registro record;

	cursor_columnas cursor is
	SELECT column_name, data_type 
	FROM information_schema.columns 
	WHERE table_schema = p_schema and table_name = p_table;

BEGIN
    
	v_tabla_ddl ='CREATE TABLE '|| p_schema ||'.'|| p_table ||' (';

	OPEN cursor_columnas;
    FETCH cursor_columnas INTO registro;
    WHILE found LOOP 
		v_tabla_ddl =  v_tabla_ddl || ',' || registro.column_name || ' ' || registro.data_type;

        FETCH cursor_columnas INTO registro;
    END LOOP; 
    CLOSE cursor_columnas;


	v_tabla_ddl = replace(v_tabla_ddl,'(,','(') || ')';

    RETURN v_tabla_ddl;
END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

CREATE OR REPLACE FUNCTION generate_ddl_columns_table(p_schema varchar, p_table varchar)
  RETURNS text AS
$BODY$
DECLARE
    v_tabla_ddl   text;
    registro record;

	cursor_columnas cursor is
	SELECT column_name, data_type 
	FROM information_schema.columns 
	WHERE table_schema = p_schema and table_name = p_table;

BEGIN
    
	v_tabla_ddl ='(';

	OPEN cursor_columnas;
    FETCH cursor_columnas INTO registro;
    WHILE found LOOP 
		v_tabla_ddl =  v_tabla_ddl || ',' || registro.column_name ;

        FETCH cursor_columnas INTO registro;
    END LOOP; 
    CLOSE cursor_columnas;


	v_tabla_ddl = replace(v_tabla_ddl,'(,','');

    RETURN v_tabla_ddl;
END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

CREATE OR REPLACE function fnc_create_schema_depency()
  RETURNS text AS
$BODY$
DECLARE

    v_tabla_ddl   varchar;
    registro record;
	v_sql varchar;
	v_return varchar;
	v_count  integer;
	v_index integer;
	v_estado varchar;

BEGIN
	v_index = 0;
    v_return = 'OK';
	truncate table temporal.tables_load;
	truncate table temporal.tables_foreing;

	insert into temporal.tables_load(tabla, esquema)
	SELECT distinct
         c.relname::varchar as tabla,
    	 n.nspname::varchar as esquema
	FROM 
		pg_catalog.pg_class c,
		pg_catalog.pg_namespace n 
	where 
		n.nspname not in ('pg_catalog','information_schema', 'pg_toast','temporal')
		and n.oid = c.relnamespace and relam = 2
	order by 2 desc;

	-- carga foraneas
	insert into temporal.tables_foreing(esquema, tabla, esquema_foranea,  tabla_foranea)
	select distinct
		    tc.table_schema, 
		    tc.table_name, 
		    ccu.table_schema AS foreign_table_schema,
		    ccu.table_name AS foreign_table_name
		FROM information_schema.table_constraints AS tc 
		JOIN information_schema.key_column_usage AS kcu
		    ON tc.constraint_name = kcu.constraint_name
		    AND tc.table_schema = kcu.table_schema
		JOIN information_schema.constraint_column_usage AS ccu
		    ON ccu.constraint_name = tc.constraint_name
		WHERE tc.constraint_type = 'FOREIGN KEY';

	update temporal.tables_foreing a set
		id = b.id
	from 
		temporal.tables_load b
	where 
		a.tabla = b.tabla and 
		a.esquema = b.esquema;

	update temporal.tables_foreing a set
		id_foranea = b.id
	from 
		temporal.tables_load b
	where 
		a.tabla_foranea = b.tabla and 
		a.esquema_foranea = b.esquema;

	-- actualizar foraneas
	update temporal.tables_load a set
		foraneas = consu.foraneas
	from 
	( select a.id, count(1) as foraneas from 
		temporal.tables_foreing a
		group by 1) as consu
	where 
		a.id = consu.id;	

    RETURN v_return;
END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

CREATE OR REPLACE function fnc_copy_table_info_redshift()
  RETURNS text AS
$BODY$
DECLARE

    v_columns varchar;
    registro record;
	v_sql varchar;
	v_return varchar;
	v_count  integer;
	v_index integer;
	v_estado varchar;
	v_carpeta varchar;
	v_comando varchar;

BEGIN
	v_index = 0;
    v_return = '(';

	select count(1) into v_count from temporal.tables_load a where a.estado = 'PENDIENTE';

	WHILE v_index < v_count LOOP
		-- consultar tabla a extraer datos
		select id, esquema, tabla
		into registro
		from fnc_get_load_table();

		drop table if exists tmp_record;
		CREATE TEMP TABLE tmp_record  (
			respuesta VARCHAR
		) ON COMMIT DROP;

		v_estado = 'CARGADA';
        v_columns = generate_ddl_columns_table(registro.esquema, registro.tabla);
		v_comando = '/home/postgres/table_redshift_to_alloydb.sh '|| registro.esquema ||' '|| registro.tabla ||' "'|| v_columns ||'" ';
		v_sql = 'COPY tmp_record FROM PROGRAM ''' || v_comando || '''';
				
		BEGIN
			raise notice 'sql: %', v_sql;
			execute v_sql;
		EXCEPTION WHEN OTHERS THEN
			v_estado = 'ERROR';
		END;

		insert into temporal.logs_migration 
		select 
			registro.esquema,
			registro.tabla,
			respuesta
		from 
			tmp_record ;

		update temporal.tables_load set 
			estado = v_estado
		where 
			id = registro.id;

	    v_index = v_index + 1;
  	END LOOP;

	v_return = 'OK';

    RETURN v_return;
END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

CREATE OR REPLACE function fnc_get_load_table()
  RETURNS SETOF  type_get_load_table AS
$BODY$
DECLARE

    v_tabla_ddl   varchar;
    registro record;
	v_sql varchar;
	v_count  integer;
	v_index integer;
	v_return type_get_load_table;

	cursor_tablas cursor is
    SELECT 
		id,
       	tabla,
       	esquema
    FROM
        temporal.tables_load b
    where
        estado = 'PENDIENTE'
	order by foraneas asc;

begin
	
	OPEN cursor_tablas;
    FETCH cursor_tablas INTO registro;
    WHILE found LOOP
		select count(1) into v_count
		from 
			temporal.tables_load a,
			temporal.tables_foreing b
		where 
			a.estado = 'PENDIENTE' and 
			registro.id = b.id and
			b.id_foranea = a.id ;
	
		if v_count = 0 then
			v_return = registro;
			return next v_return;
			EXIT;
		end if;

		FETCH cursor_tablas INTO registro;
    END LOOP;
    CLOSE cursor_tablas;

END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

select * from fnc_create_schema_depency();