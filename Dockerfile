FROM python:3.10.4-alpine3.15

WORKDIR /app

COPY . .
RUN chmod +x service.sh\
&& apk update\
&& apk --no-cache --virtual .dependencies add gcc g++\
&& apk add --no-cache redis openrc supervisor\
&& pip install -r ./requirements.txt --no-cache-dir\
&& echo '*/10    *       *       *       *       /usr/local/bin/python /app/keepalive.py' >> /etc/crontabs/root\
&& crond\
&& mkdir /run/openrc\
&& touch /run/openrc/softlevel\
&& openrc\
&& mkdir /etc/supervisor.d\
&& ln -s /app/sup.ini /etc/supervisor.d/reg_client.ini\
&& rc-service supervisord start\
&& rc-service redis start\
&& apk del .dependencies\
&& rm -rf ./requirements.txt\
# CMD [ "/bin/sh /app/service.sh" ]
