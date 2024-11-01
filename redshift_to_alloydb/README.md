#Migracion datos Redshift a AlloyDB


##Descripcion
En la presente documentacion, se desarrolla como objetivo el explicar el funcionamiento implementado en la actual carpeta de la imagen "redshift_to_alloydb". Lo anterior explicado desde los siguientes temas:

1. Backup esquema de datos
2. Restauracion de datos
3. Log de ejecucion del proceso

###Backup base de datos
Para el desarrollo de esta actividad se tomo como base el utilizar el mecanismo "pg_dump", dado a que Redshift como AlloyDB, comparten como motor base el Postgres. Con el comando "pg_dump" lo que se realiza es una generacion de un backup en texto plano y de tipo sql, que permitiera generar todos los objectos que contiene la base de datos en Redshift, sin nada de informacion.

El backup generado cuenta con algunas caracteristicas que son de uso de Redshift y que por tanto Alloydb no puede interpretar, para manejar este tipo de cambios se implementa un intermediario y validador, para lo cual se monta una instancia de PostgreSQL,donde al backup de Redshift se le realizan ajustes para permitir crear el mayor numero de objetos aceptados por PostgreSQL, con estos cambios se procede a realizar un "psql" para la restauracion del sql actualizado.

Con la instancia de PostgreSQL, se procede a generar un nuevo Backup, pero este ya solo con los objetos que son soportados por PostgreSQL y que pueden ser transferidos AlloyDB. De igual forma se usa el comando "psql" para conectar y restaurar el archivo nuevo en la base de datos destino de AlloyDB.

### Restauracion de datos
Para este proceso se utilizan los mecanismo de UNLOAD y COPY, donde:

- UNLOAD : Proceso implementado por AWS para permitir en Redshift generar una copia completa de una data de una tabla y exportarla en distintos formatos hacia un almacenamiento en S3.
- COPY : Proceso implementado dentro de Postgres y que sirve en AlloyDB, para leer un archivo CSV e importarlo por completo en una tabla.

Con los dos procesos anteriores, se implementa un proceso paralelizado, donde se realizan ambas acciones de generar la data en s3, proceder a copiar en GCP, por ultimo subirla AlloyDB. Como las estructura de tablas se tiene en Redshift, pero como se indico en el proceso anterior, no toda se puede migrar, se realiza un proceso para el relacionamiento de los objetos creados y sus estructuras, dado a que COPY solicita las columnas de las tablas, esto se realiza con la ayuda de la ejecucion de la funcion "fnc_create_schema_depency".

###Log de ejecucion
Se espera que este proceso se ejecute dentro de GKE, por tanto el usuario no tendra visibilidad directa de acceder al estado de la ejecucion total, para ayudar con este tema se proceder a crear dos archivos de retroalimentacion:

- DATABASE_DATE.log : Es un archivo que contiene cada uno de los flujos con la fecha en la cual inicio, permitiendo reconocer en donde se ha demorado mas y cuales fueron los procesos ejecutados.
- DATABASE_DATE.tables : Es un archivo con las lista completa de las tablas migradas, con el estado en que terminaron y las fechas inicio y fin, que reflejan su duracion de la carga.

Ademas dentro de estos se adjuntan los archivos SQL de los backups generados, tanto desde Redshift como el del Postgres a AlloyDB.

##Estructura de archivos
Los siguientes son los archivos implementados para el desarrollo de las actividades mencionadas anteriormente:
- **Keys** : En esta carpeta se encuentran las llaves de acceso, que fueron creadas para permitir que la instancia que se cree con esta imagen se pueda conectar via ssh con la instancia que sirve para acceder a Redshift.
- **pg_hba** : Archivo con la configuracion de accesos, el cual le permite al usuario postgres acceder via local, sin autenticacion.
- **postgres.conf** : Contiene las configuraciones para la implementacion de postgres en una instancia de E2.
- **unload_redshift.sh**: Contiene el proceso para la ejecucion del comando UNLOAD en Redshift, donde este archivo no pertenece a este imagen, sino que se encuentra dentro de la instancia VPN.
- **schema_temporal.sql**: Cuenta con la creacion de las Tablas y Funciones, necesarias para permitir el relacionamiento entre tablas foraneas y funciones para la carga de la informacion.
- **restore_cycle_tables.sh** : Es el comando ejecutado por el ciclo de llenado de tablas, este proceso cuenta con una validacion, para validar que existan registros PENDIENTE por ejecutar, consulta cual es la tabla a ejecutar, para proceder a realizar el llamado de "table_redshift_to_alloydb.sh" 
- **table_redshift_to_alloydb.sh** : Contiene los procesos encargados de ejecutar la generacion de los datos en Redshift y luego son transferidos a AlloyDB, para esto realiza:
 - **Generacion de datos**: Procede a realizar la solicitud de UNLOAD, el cual genera unos archivos de formato gz  particionados en un bucket de S3, por lo cual se proceden a descagar, concatenar y descomprimir, permitiendo obtener el archivo CSV.
 - **Carga de datos**: Procede a crear un SQL de carga de COPY con el archivo CSV, para luego a traves de psql conectar AlloyDB y ejecutar el SQL generado.
- **restore_data.sh** : Es el comando solicitado para ser ejecutado por el ENTRYPOINT, donde se reciben los parametros globales para la ejecucion y empiza a realizar las siguientes actividades:
 -  **Instalaciones ** : Se procede a realizar la instalacion del servicio de Postgresql y su usuario.
 - ** Ajustar ambiente ** : Se encarga de copiar los archivos necesarios de los procesos a utilizar dentro del usuario postgres, otorgando tambien los accesos a la instancia de vpn de Redshift
 - **Backup Redshift  **: Genera la solicitud del Backup en Redsfhit, para a continuacion proceder a ejecutar unos reemplazos en el archivos, para permitir cambiar ciertas estructuras del DDL que no son posibles de ejecutar en Postgres, pero que se les puede generar un codigo que simula la misma accion.
 - **Restaracion y Backup Local ** : Se procede a restaurar el backup ajustado dentro de la instancia del Postgres, para a continuacion generar un nuevo backup desde la instancia local, para ser utilizado en AlloyDB.
  - ** Esquema temporal **: Se procede a ejecutar el SQL de esquema temporal, donde se contiene los mecanismos de relacionamiento de tablas.
  - **Restauracion de datos **: Se procede a llevar acabo la ejecucion de las restauracion de todas las tablas que lograron ser restauradas en el Postgresql, para este proceso se realiaza un ciclo, donde se esta validando que se ejecuta mientras el conteo de registro indique que existen por cargar tabla, en caso de ser esto aceptado procede a llamar al comando "restore_cycle_tables.sh".
  - **Retroalimentacion**: Se procede a generar los archivos de Logs y se envian al Bucket.


####Funciones PLSQL
Estas son creadas atraves del llamado al archivo "schema_temporal.sql", dentro de esto se tiene:
- **generate_create_table_statement** : Permite generar el SQL de create de una tabla.
- generate_ddl_columns_table : Permite consulta el listado de las columnas que contiene una tabla, este es usado para el proceso de COPY.
- **fnc_create_schema_depency** : Cuenta con el proceso para reconocer las tablas creadas y sus respectivas foraneas, permitiendo asi conocer las relaciones entre las distintas tablas de toda la base de datos.
- **fnc_copy_table_info_redshift** : Es la funcion encargada de realizar el proceso de carga de Redshift a AlloyDB, esto lo hace en conjunto con el archivo "table_redshift_to_alloydb.sh".
- **fnc_get_load_table** : Como son muchas tablas  el proceso debe cargarlas segun su dependencia, esta funcion se encarga de devolver la tabla que puede ser cargada y que no generar conflicto por dependencias de foraneas.

##Notas
- En esta documentacion se entrega las llaves publica y privadas, la privada para este proceso es cargada por llaves secretas en el GKE, se puede crear a traves del comando "kubectl create secret generic acceso-vpn -n argo --from-file=key=key"
- Las llave publica se debe contenedor dentro del usuario Ubuntu de la instancia de VPN.
- Para el uso de los servicios de Postgres, en la instancia de VPN durante pruebas se usa la version 12, mientras que para la instancia de GKE se instala una version 16.
- No se sube en esta documentacion el archivo de credenciales de AWS, pero debe ser montado a traves de una llave secreta como "kubectl create secret generic acceso-aws -n argo --from-file=credentials=credentials"
- Se comparte el archivo argos.yml, es un archivo con la estructura necesaria para ejecutar esta imagen en GKEa traves de argos y puede servir como ayuda para incluirlo dentro del cron de argos.
- Los parametros que recibe el proceso "restore_data.sh" son los siguientes:
 1. Nombre de base de datos
 2. IP de servicio Redshift
 3. Puerto de Redshift
 4. Usuario de conexion a Redshift
 5. Contraseña de usuario Redshift
 6. IP del cluster AlloyDB
 7. Puerto de acceso AlloyDB
 8. Usuario de acceso a AlloyDB
 9.  Contraseña de acceso de AlloyDB
 10. Bucket de S3, donde se estaran generando los archivos de GZ generados por Unload
 11. Bucket de GCP, es donde se dejaran los archivos del Log
 12. IP de la instancia de VPN que se usa para conectar a AWS
 13. Numero de ciclos que se permiten estar ejecutando para la carga de tablas.