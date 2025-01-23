CREATE OR REPLACE FUNCTION public.get_stock_values(
  units double precision, 
  sale_value double precision, 
  cost_value double precision, 
  "view" character varying, 
  factors_data character varying
  )
 RETURNS double precision 
 LANGUAGE plv8
AS $$       
    var result;

    if (!view || !factors_data) {
        result = 0;
    } else {
        try {
        const factor_dict = {};
        factors_data.split(',').forEach(item => {
            const parts = item.split(':');
            if (parts.length === 2) { 
                factor_dict[parts[0].trim()] = parseFloat(parts[1].trim()); 
            }
        });

        const formattedView = view.replace(/\{(\w+)\}/g, (match, key) => {
            switch (key) {
            case "units":
                return units;
            case "sale_value":
                return sale_value * units;
            case "cost_value":
                return cost_value * units;
            default:
                if (factor_dict.hasOwnProperty(key)) {
                return factor_dict[key];
                }
                return match; 
            }
        });

        result = new Function('return ' + formattedView)();

        } catch (error) {
            result = 0;
        }
    }

    return result;

   $$


CREATE OR REPLACE FUNCTION public.get_suggested_stock_values(suggested double precision, sale_value double precision, cost_value double precision, view character varying, factors_data character varying)  
RETURNS double precision 
LANGUAGE plv8
AS  
$$   

    var result; 

    if (!view || !factors_data || !suggested) {
        result = 0;
    } else {
        try {
        const factor_dict = {};
        factors_data.split(',').forEach(item => {
            const parts = item.split(':');
            if (parts.length === 2) {
            factor_dict[parts[0].trim()] = parseFloat(parts[1].trim());
            } else if (item.trim() !== ""){ 
                throw new Error("Invalid factor data format: " + item);
            }
        });

        const formattedView = view.replace(/\{(\w+)\}/g, (match, key) => {
            switch (key) {
            case "units":
                return suggested; 
            case "sale_value":
                return suggested * sale_value; 
            case "cost_value":
                return suggested * cost_value; 
            default:
                if (factor_dict.hasOwnProperty(key)) {
                return factor_dict[key];
                }
                return match;
            }
        });

        result = new Function('return ' + formattedView)();

        if (isNaN(result)) { 
            result = 0;
        }

        } catch (error) {
            result = 0;
        }
    }
    return result;
  $$;


CREATE OR REPLACE FUNCTION public.f_date_to_year_week(vDate date) 
RETURNS integer
LANGUAGE plv8
AS  
$$   

    const daysInYear = 364; 
    const firstDay = new Date(vDate.getFullYear(), 0, 1); 
    const daysFromStart = Math.ceil((vDate - firstDay) / (7 * 24 * 60 * 60 * 1000)); 
    const week = Math.ceil(daysFromStart / 7);

    if (week === 0) {
        const previousYear = vDate.getFullYear() - 1;
        const previousYearLastWeek = getWeek(new Date(previousYear, 11, 31)); 
        return [previousYear, previousYearLastWeek[1]];
    } else {
        return [vDate.getFullYear(), week];
    }

$$;

CREATE OR REPLACE FUNCTION public.f_py_normalize_string(to_normalize character varying, to_lower boolean, replace_spaces boolean) 
RETURNS character varying
LANGUAGE plv8
AS 
$$

    var toNormalize;

    if (typeof toNormalize !== 'string') {
        toNormalize = String(toNormalize); 
    }

    if (toLower) {
        toNormalize = toNormalize.toLowerCase();
    }

    if (replaceSpaces) {
        toNormalize = toNormalize.replace(/\s/g, ''); 
    }

    toNormalize = toNormalize.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

    return toNormalize;
$$;


CREATE OR REPLACE FUNCTION public.f_format_number(num double precision, thousand_separator character varying, decimal_separator character varying, max_precision integer) 
RETURNS character varying
LANGUAGE plv8
AS $$
    
    num = num || 0; 

  if (typeof num === 'number' || (typeof num === 'string' && Number.isInteger(Number(num)))) {
    const maxPrecision = 0;
    const formatter = new Intl.NumberFormat('en-US', { 
        maximumFractionDigits: maxPrecision,
        minimumFractionDigits: maxPrecision
    });

    const formatted = formatter.format(Number(num)); 

    return formatted
        .replace(/,/g, ' ') 
        .replace(/\./g, decimal_separator) 
        .replace(/ /g, thousand_separator); 
  }
    return num;
        
$$;

CREATE OR REPLACE FUNCTION public.get_sales_values(units double precision, sale_value double precision, cost_value double precision, view character varying, factors_data character varying) RETURNS double precision
 LANGUAGE plv8
AS $$   
    if (!view || !factors_data) {
        return 0;
    } else {
        try {
            const factor_dict = {};
            factors_data.split(',').forEach(item => {
                const parts = item.split(':');
                if (parts.length === 2) {
                    factor_dict[parts[0].trim()] = parseFloat(parts[1].trim()); 
                } else if (item.trim() !== "") {
                    throw new Error("Invalid factor data format: " + item);
                }
            });

            const formattedView = view.replace(/\{(\w+)\}/g, (match, key) => {
                switch (key) {
                    case "units":
                        return units;
                    case "sale_value":
                        return sale_value;
                    case "cost_value":
                        return cost_value;
                    default:
                        if (factor_dict.hasOwnProperty(key)) {
                            return factor_dict[key];
                        }
                        return match; 
                }
            });

            const result = new Function('return ' + formattedView)();

            if (isNaN(result)) {
              result = 0;
            }
            return result;

        } catch (error) {
            return 0;
        }
    }
  $$;


CREATE OR REPLACE FUNCTION public.get_compound_value(formula character varying, factor double precision, fields character varying) RETURNS double precision
 LANGUAGE plv8
AS $$ 
    if (!formula || !fields) {
        return 0;
    } else {
        try {
            const fields_dict = {};
            fields.split(',').forEach(item => {
                const parts = item.split(':');
                if (parts.length === 2) {
                    fields_dict[parts[0].trim()] = parseFloat(parts[1].trim()); 
                } else if (item.trim() !== ""){ 
                    throw new Error("Invalid fields format: " + item);
                }
            });
            fields_dict['factor'] = factor;

            const formattedFormula = formula.replace(/\{(\w+)\}/g, (match, key) => {
                if (fields_dict.hasOwnProperty(key)) {
                    return fields_dict[key];
                }
                return match; 
            });

            const result = new Function('return ' + formattedFormula)();

            if (isNaN(result)) {
                result = 0;
            }

            return result;
        } catch (error) {
            if (error.message.includes("Division by zero")) { 
                return 0;
            } else {
                return 0;
            }
        }
    }
$$;

CREATE OR REPLACE FUNCTION public.f_year_week_to_start_date(year_week integer) RETURNS date
 LANGUAGE plv8
AS $$ 

  if (typeof year_week_str !== 'string' || !/^\d{4}\d{2}$/.test(year_week_str)) {
    return null; // O lanzar un error, según prefieras
  }

  const year = parseInt(year_week_str.substring(0, 4), 10);
  const week = parseInt(year_week_str.substring(4, 6), 10);

  // Crear una fecha para el primer día del año
  let date = new Date(year, 0, 1);

  // Obtener el día de la semana (0 = Domingo, 1 = Lunes, ..., 6 = Sabado)
  let dayOfWeek = date.getDay();

  // Calcular la diferencia de dias para llegar al primer lunes del año
  let diff = date.getDay() <= 4 ? date.getDay() - 1 : 8 - date.getDay();

  // Ajustar la fecha al primer lunes del año
  date.setDate(date.getDate() + diff);

    date.setDate(date.getDate() + (week - 1) * 7);

  return date;

 $$;

CREATE OR REPLACE FUNCTION public.f_year_week_to_end_date(year_week integer) RETURNS date
 LANGUAGE plv8
AS $$ 
  if (typeof year_week_str !== 'string' || !/^\d{4}\d{2}$/.test(year_week_str)) {
        return null; // O lanzar un error: throw new Error("Formato de entrada inválido");
    }

    const year = parseInt(year_week_str.substring(0, 4), 10);
    const week = parseInt(year_week_str.substring(4, 6), 10);

    // Crear una fecha para el primer día del año
    let date = new Date(year, 0, 1);

    // Calcular la diferencia de días para llegar al primer lunes del año (ISO 8601)
    let diff = date.getDay() <= 4 ? date.getDay() - 1 : 8 - date.getDay();

    // Ajustar la fecha al primer lunes del año
    date.setDate(date.getDate() + diff);

    // Ajustar la fecha al lunes de la semana especificada
    date.setDate(date.getDate() + (week - 1) * 7);

    //Ajustar la fecha al domingo de la semana especificada (sumar 6 dias al lunes)
    date.setDate(date.getDate() + 6);

    return date;

 $$;


CREATE OR REPLACE FUNCTION public.f_year_week_to_end_date(year_week integer) RETURNS date
 LANGUAGE plv8
AS $$ 
  if (typeof year_week_str !== 'string' || !/^\d{4}\d{2}$/.test(year_week_str)) {
        return null; // O lanzar un error: throw new Error("Formato de entrada inválido");
    }

    const year = parseInt(year_week_str.substring(0, 4), 10);
    const week = parseInt(year_week_str.substring(4, 6), 10);

    // Crear una fecha para el primer día del año
    let date = new Date(year, 0, 1);

    // Calcular la diferencia de días para llegar al primer lunes del año (ISO 8601)
    let diff = date.getDay() <= 4 ? date.getDay() - 1 : 8 - date.getDay();

    // Ajustar la fecha al primer lunes del año
    date.setDate(date.getDate() + diff);

    // Ajustar la fecha al lunes de la semana especificada
    date.setDate(date.getDate() + (week - 1) * 7);

    //Ajustar la fecha al domingo de la semana especificada (sumar 6 dias al lunes)
    date.setDate(date.getDate() + 6);

    return date;

 $$;


CREATE OR REPLACE FUNCTION public.remove_duplicate_stock(_schema character varying) RETURNS void
    LANGUAGE plpgsql
    AS  $$
DECLARE
  consolidate RECORD;
BEGIN

    DROP TABLE IF EXISTS consolidate_temp;
    DROP TABLE IF EXISTS consolidate_duplicated;
    DROP TABLE IF EXISTS consolidate_calculate;

    EXECUTE 'CREATE TEMP TABLE consolidate_temp AS ' ||
    'SELECT * FROM ' || _schema || '.consolidated_stock UNION ALL ' ||
    'SELECT * FROM ' || _schema || '.consolidated_stock_cd UNION ALL ' ||
    'SELECT * FROM ' || _schema || '.consolidated_stock_local';
    
    CREATE TEMP TABLE consolidate_duplicated AS
    SELECT (store_code || product_chain_code) AS "store_prod_chain_code", SUM(units)
    FROM consolidate_temp
    GROUP BY "store_prod_chain_code"
    HAVING COUNT(*) > 1;

    CREATE TEMP TABLE consolidate_calculate AS
    SELECT store_code , product_chain_code, min(category), sum(units), max(category)
    FROM consolidate_temp
    WHERE (consolidate_temp.store_code || consolidate_temp.product_chain_code)
    IN (SELECT store_prod_chain_code FROM consolidate_duplicated)  
    GROUP BY consolidate_temp.store_code, consolidate_temp.product_chain_code;
    
    FOR consolidate IN SELECT * FROM consolidate_calculate LOOP

        EXECUTE 'UPDATE ' || _schema || '.consolidated_stock SET units = ' || consolidate.sum ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.min;
        EXECUTE 'UPDATE ' || _schema || '.consolidated_stock_cd SET units = ' || consolidate.sum ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.min;
        EXECUTE 'UPDATE ' || _schema || '.consolidated_stock_local SET units = ' || consolidate.sum ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.min;
    
        EXECUTE 'DELETE FROM ' || _schema || '.consolidated_stock' ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.max;
        EXECUTE 'DELETE FROM ' || _schema || '.consolidated_stock_cd' ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.max;
        EXECUTE 'DELETE FROM ' || _schema || '.consolidated_stock_local' ||
        ' WHERE store_code = ''' || consolidate.store_code || ''' AND product_chain_code = ''' || 
        consolidate.product_chain_code || ''' AND category = ' || consolidate.max;
    
    END LOOP;
    
END;
$$;