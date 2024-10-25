FROM ubuntu:latest

ADD ./configuracion.sh /root/configuracion.sh
ADD ./restore_data.sh /home/restore_data.sh
ADD ./schema_temporal.sql /home/schema_temporal.sql
ADD ./restore_redshift_to_alloydb.sql /home/restore_redshift_to_alloydb.sql
ADD ./table_redshift_to_alloydb.sh /home/table_redshift_to_alloydb.sh
ADD ./unload_redshift.sh.sh /home/unload_redshift.sh
ADD ./pg_hba.conf /home/pg_hba.conf

EXPOSE 80 5432 6432 22 5439

RUN bash /root/configuracion.sh
RUN chmod +x /home/restore_data.sh

ENTRYPOINT ["/home/restore_data.sh"]
