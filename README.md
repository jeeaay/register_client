<!--
 * @Email: wrj7887@163.com
 * @Author: Jeay
 * @Date: 2022-04-21 14:28:49
 * @LastEditors: Jeay
 * @LastEditTime: 2022-04-26 15:19:52
 * jeay.net
 * @FilePath: \部署\README.md
 * @Description: 
 * Copyright (c) 2022 by jeay.net, All Rights Reserved.
-->
apk --no-cache --virtual .dependencies add gcc g++
pip install cython
pip install easycython

easycython *.pyx


git clone https://github.com/jeeaay/register_client.git .


docker run -it -d --name reg -p 8808:8808 jeeaay/reg /bin/sh -c /app/service.sh

docker run -it -d pyx_web /bin/sh

docker-compose up

docker tag pyx_web jeeaay/reg:2.9\
&& docker tag jeeaay/reg:2.9 jeeaay/reg:latest\
&& docker push jeeaay/reg:2.9\
&& docker push jeeaay/reg

docker cp a5:/app/register.so /root/docker/pyx/