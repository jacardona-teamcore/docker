create schema temporal;

drop table if exists temporal.tables_load;
create table temporal.tables_load(
	id serial primary key,
	tabla varchar,
	esquema varchar,
	estado varchar default 'PENDIENTE',
	foraneas integer default 0,
	inicio timestamp,
	fin timestamp,
	redshift_count integer default 0,
	alloydb_count integer default 0
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
	v_column text;

	cursor_columnas cursor is
	SELECT column_name, data_type 
	FROM information_schema.columns 
	WHERE table_schema = p_schema and table_name = p_table;

BEGIN
    
	v_tabla_ddl ='(';

	OPEN cursor_columnas;
    FETCH cursor_columnas INTO registro;
    WHILE found LOOP 
		v_column = case when registro.column_name in ('table', 'order') then '\"' || registro.column_name || '\"' else registro.column_name end;
		v_tabla_ddl =  v_tabla_ddl || ',' || v_column ;

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

drop function if exists fnc_copy_table_info_redshift();
CREATE OR REPLACE function fnc_copy_table_info_redshift(p_id integer, p_folder varchar)
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
	v_clone varchar;
	v_separador varchar;

BEGIN
	v_index = 0;

	-- consultar tabla a extraer datos
	if p_id = 0 then
		v_return = 'NOTHING';
	else

		select id, esquema, tabla
		into registro
		from temporal.tables_load
		where id = p_id;

		v_clone = CASE WHEN registro.tabla in ('categories','chain_products', 'factors') THEN '1' ELSE '0' END;
		v_separador = CASE WHEN registro.tabla in ('chains_views') THEN '1' ELSE '0' END;
	
		drop table if exists tmp_record;
		CREATE temp TABLE tmp_record  (
			respuesta VARCHAR
		);
	
		v_estado = 'CARGADA';
	    v_columns = generate_ddl_columns_table(registro.esquema, registro.tabla);
		v_comando = '/home/postgres/table_redshift_to_alloydb.sh '|| v_clone ||' '|| p_folder ||' '|| registro.esquema ||' '|| registro.tabla ||' "'|| v_columns ||'" '|| v_separador ||' ';
		v_sql = 'COPY tmp_record FROM PROGRAM ''' || v_comando || '''';
					
		BEGIN
			raise notice 'sql: %', v_sql;
			execute v_sql;
		EXCEPTION WHEN OTHERS THEN
			v_estado = 'ERROR';
		END;
	
		if v_clone = '1' then
			v_sql = 'select count(1) from (select distinct * from ' || registro.esquema ||'.'|| registro.tabla || ') as consu';
			EXECUTE v_sql into v_count;

			update temporal.tables_load set 
				estado = v_estado,
				redshift_count = v_count
			where 
				id = registro.id and 
				v_count > 0;
		end if;
	
		v_return = 'OK';
	end if;

    RETURN v_return;
END;
$BODY$
LANGUAGE 'plpgsql' COST 100.0 SECURITY INVOKER;

drop function if exists fnc_get_load_table();
CREATE OR REPLACE FUNCTION public.fnc_get_load_table()
 RETURNS SETOF integer
 LANGUAGE plpgsql
AS $function$
DECLARE

    v_tabla_ddl   varchar;
    registro record;
	v_sql varchar;
	v_count  integer;
	v_index integer;
	v_return integer;

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

	v_return = 0;
	
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
			v_return = registro.id;

			update temporal.tables_load set 
				estado = 'PROCESANDO',
				inicio = now()
			where 
				id = registro.id;

			
			EXIT;
		end if;

		FETCH cursor_tablas INTO registro;
    END LOOP;
    CLOSE cursor_tablas;

	return next v_return;

END;
$function$
;

drop function if exists fnc_set_primary_key(p_table varchar);
CREATE OR REPLACE FUNCTION public.fnc_set_primary_key(p_table varchar)
 RETURNS SETOF integer
 LANGUAGE plpgsql
AS $function$
DECLARE

    registro record;
	v_query varchar;
	v_llave  varchar;
	v_return integer;

	cursor_tablas cursor is
    SELECT distinct
    	 n.nspname::varchar as esquema,
         c.relname::varchar as tabla
	FROM 
		pg_catalog.pg_class c,
		pg_catalog.pg_namespace n 
	where 
		n.nspname not in ('pg_catalog','information_schema', 'pg_toast','temporal')
		and n.oid = c.relnamespace and relam = 2
		and c.relname in (p_table)
	order by 2 desc;

begin

	v_return = 0;
	
	OPEN cursor_tablas;
    FETCH cursor_tablas INTO registro;
    WHILE found LOOP
		SELECT constraint_name into v_llave
		FROM information_schema.table_constraints 
		WHERE 
			table_name = registro.tabla and 
			constraint_schema = registro.esquema and 
		constraint_type = 'PRIMARY KEY' ;

		v_query = 'ALTER TABLE '|| registro.esquema ||'.'|| registro.tabla ||' DROP CONSTRAINT '|| v_llave || ' CASCADE';

		execute v_query;

		FETCH cursor_tablas INTO registro;
    END LOOP;
    CLOSE cursor_tablas;

	return next v_return;

END;
$function$
;

drop function if exists fnc_set_constraint(p_table varchar, p_constraint varchar);
CREATE OR REPLACE FUNCTION public.fnc_set_constraint(p_table varchar, p_constraint varchar)
 RETURNS SETOF integer
 LANGUAGE plpgsql
AS $function$
DECLARE

    registro record;
	v_query varchar;
	v_return integer;

	cursor_tablas cursor is
    SELECT distinct
    	 n.nspname::varchar as esquema,
         c.relname::varchar as tabla
	FROM 
		pg_catalog.pg_class c,
		pg_catalog.pg_namespace n 
	where 
		n.nspname not in ('pg_catalog','information_schema', 'pg_toast','temporal')
		and n.oid = c.relnamespace and relam = 2
		and c.relname in (p_table)
	order by 2 desc;

begin

	v_return = 0;
	
	OPEN cursor_tablas;
    FETCH cursor_tablas INTO registro;
    WHILE found LOOP
		
		v_query = 'ALTER TABLE '|| registro.esquema ||'.'|| registro.tabla ||' DROP CONSTRAINT '|| p_constraint ||' CASCADE';

		BEGIN
			execute v_query;
		EXCEPTION WHEN OTHERS THEN
			v_query = 'ERROR';
		END;

		FETCH cursor_tablas INTO registro;
    END LOOP;
    CLOSE cursor_tablas;

	return next v_return;

END;
$function$
;

drop FUNCTION public.fnc_set_max_table_chains_product(p_schema varchar, p_table varchar);
CREATE OR REPLACE FUNCTION public.fnc_set_max_table_chains_product(p_schema varchar, p_table varchar)
 RETURNS SETOF integer
 LANGUAGE plpgsql
AS $function$
DECLARE

    registro record;
	v_query varchar;
	v_return integer;



begin

	v_return = 0;
	
	CREATE temp TABLE tmp_record  (
		chain_id integer, 
		combi_prod_id integer,
		id integer		
	);
		
	v_query = 'insert into tmp_record select chain_id, combi_prod_id, max(id) from '|| p_schema ||'.'|| p_table ||' group by 1,2 ';
	execute v_query;

	v_query = 'delete from '|| p_schema ||'.'|| p_table ||' where id not in (select id from tmp_record)';

	execute v_query;

	return next v_return;

END;
$function$
;

select * from fnc_create_schema_depency();
select * from fnc_set_primary_key('categories');
select * from fnc_set_primary_key('factors');
select * from fnc_set_primary_key('chain_products');
