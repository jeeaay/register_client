#!/bin/sh
###
 # @Email: wrj7887@163.com
 # @Author: Jeay
 # @Date: 2022-04-23 12:10:09
 # @LastEditors: Jeay
 # @LastEditTime: 2022-04-23 13:41:39
 # jeay.net
 # @FilePath: /部署/service.sh
 # @Description: 
 # Copyright (c) 2022 by jeay.net, All Rights Reserved.
### 

rc-service supervisord restart
rc-service redis restart
crond
/bin/sh
