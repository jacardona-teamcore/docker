FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD ./restore_data.sh /home/restore_data.sh
ADD ./schema_temporal.sql /home/schema_temporal.sql
ADD ./pgsql_migration.sql /home/pgsql_migration.sql
ADD ./table_redshift_to_alloydb.sh /home/table_redshift_to_alloydb.sh
ADD ./unload_redshift.sh /home/unload_redshift.sh
ADD ./pg_hba.conf /home/pg_hba.conf
ADD ./postgresql.conf /home/postgresql.conf
ADD ./postgresql8.conf /home/postgresql8.conf
ADD ./postgresql12.conf /home/postgresql12.conf
ADD ./restore_cycle_tables.sh /home/restore_cycle_tables.sh
ADD ./schema_constraint.sql /home/schema_constraint.sql

EXPOSE 80 5432 6432 22 5439

RUN bash /root/configuracion.sh
RUN chmod +x /home/restore_data.sh

ENTRYPOINT ["/home/restore_data.sh"]
