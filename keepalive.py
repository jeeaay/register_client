#!/usr/bin/python3
# -*- coding: UTF-8 -*-

'''
/*
 * @Author: jeay 
 * @Date: 2021-08-06 09:34:42 
 * @Last Modified by: jeay
 * @Last Modified time: 2021-08-06 10:38:50
 */
'''

from rcache import redisHelper
import time, os

class CheckAlive:
    def __init__(self) -> None:
        self.rh = redisHelper()
    def Main(self):
        res = self.rh.getOneLog()
        logtime = res[0].split(':\t')[0]
        last_log_time = time.mktime(time.strptime(logtime,"%Y-%m-%d %H:%M:%S")) - 8 * 3600
        if int(last_log_time) + 600 > int(time.time()):
            self.rh.setlog("检查系统运行情况：最后一次日志时间 {} ，系统运行正常".format(logtime))
        else:
            self.rh.setlog(os.system("/usr/bin/supervisorctl restart reg_client"))
            self.rh.setlog("检查系统运行情况：距离最后一次日志时间 {} 超过十分钟，已重启注册主进程".format(logtime))

if __name__ == "__main__":
    ca = CheckAlive()
    ca.Main()


#  /usr/bin/python3 /www/wwwroot/d.lmzg.org/keepalive.py