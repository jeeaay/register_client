FROM python:3.10.4-alpine3.15

WORKDIR /app

RUN apk update\
&& apk add --no-cache redis openrc\
&& apk --no-cache --virtual .dependencies add gcc git g++ musl-dev libxslt-dev\
&& touch /run/openrc/softlevel\
&& COPY *.py .\
&& COPY *.so .\
&& pip install -r ./requirements.txt --no-cache-dir\
&& echo '*/10    *       *       *       *       run-parts /etc/periodic/15min' >> /etc/crontabs/root\
&& crond\
&& ln -s /app/sup.ini /etc/supervisor.d/reg_client.ini\
&& rc-service redis start\
&& rc-service supervisord start\
&& rm -rf .dependencies
