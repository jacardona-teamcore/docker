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

select * from public.fnc_set_constraint('chain_products', 'chain_products_chain_id_key');
select * from public.fnc_set_constraint('chain_products', 'chain_products_chain_id_key1');
select * from public.fnc_set_constraint('chain_products', 'chain_products_combi_prod_id_fkey');
select * from public.fnc_set_constraint('factors', 'factors_chain_product_id_fkey');
select * from public.fnc_set_constraint('stock', 'stock_chain_prod_id_fkey');
select * from public.fnc_set_constraint('stock', 'stock_category_id_fkey');
select * from public.fnc_set_constraint('stock', 'stock_combi_geo_id_fkey');
select * from public.fnc_set_constraint('sales', 'sales_category_id_fkey');
select * from public.fnc_set_constraint('sales', 'sales_chain_prod_id_fkey');
select * from public.fnc_set_constraint('sales', 'sales_combi_geo_id_fkey');
select * from public.fnc_set_constraint('stock_lost_sales', 'stock_lost_sales_stock_id_fkey');