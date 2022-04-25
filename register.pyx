#!/usr/bin/python3
# -*- coding: UTF-8 -*-

'''
/*
 * @Author: Jeay 
 * @Date: 2019-06-18 13:46:45 
 * @Last Modified by: jeay
 * @Last Modified time: 2021-11-25 10:07:36
 */
'''

import time, requests, json, re
from datetime import datetime
import hashlib
from pytz import timezone
import threading

from rcache import redisHelper

import requests
from requests.auth import HTTPBasicAuth
from requests.packages.urllib3.exceptions import InsecureRequestWarning
# 禁用安全请求警告
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

# 远程通信类
from remote import Remote
RMT = Remote()

# redis 缓存
RH = redisHelper()

# 引入配置类
from config import Config

# 读取配置
config = Config()

# 引入数据库模块
from db import DB
#  实例化数据库模块
db = DB()

class DomainCore:
    def __init__(self):
        self.tasks = {}
    '''
    获取任务
    用于获取当前时间待执行的任务
    返回任务的主要信息列表
    '''
    def TaskList(self):
        now = int(time.time())
        sql = 'SELECT * FROM domain WHERE status = 1 and start_time < {} and end_time > {}'.format(now,now)
        res = db.query_db(sql)
        task = {}
        for item in res:
            task[item['uuid']] = self._HandleField(item)
        # 缓存任务
        RH.jset('task', task)
    '''
    线程控制
    '''
    def MainController(self):
        while True:
            # 从数据库中获取任务
            self.TaskList()
            # 注册线程，缓存的任务中每有一个任务就开启一个线程
            self.tasks = RH.jget('task')
            if self.tasks != None and len(self.tasks) > 0:
                # 发起线程
                for uuid in self.tasks:
                    # 判断是否已经开启过线程
                    if RH.cget('task_thread_'+uuid) == None:
                        RH.cset('task_thread_'+uuid, 1, 20)
                        # 开启任务线程
                        threading.Thread(target=self.TaskThread, args=(uuid,)).start()
                    # 记录/更新线程 只存20秒 防止任务无法停止 或中断后无法启动
                    RH.cset('task_thread_'+uuid, 1, 20)
            # 每隔10秒检查一次
            time.sleep(10)

    '''
    任务线程
    '''
    def TaskThread(self, uuid):
        # 循环 直到任务结束
        while True:
            if RH.jget('task') == None or uuid not in RH.jget('task') or RH.cget('task_thread_'+uuid) == None:
                RH.setlog('任务停止')
                RH.cdel('task_thread_'+uuid)
                break
            RH.setlog(json.dumps(RH.jget('task')[uuid]))
            try:
                req_int = float(RH.jget('task')[uuid]['req_int'])
                # 开启请求线程
                threading.Thread(target=self.SendReq, args=(RH.jget('task')[uuid],)).start()
                # self.SendReq(RH.jget('task')[uuid])
            except Exception as e:
                RH.setlog(str(e))
            time.sleep(req_int)
    '''
    发送请求
    '''
    def SendReq(self, task):
        print(task)
        uri = task['url']
        needBearer= False
        token = ''
        try:
            if task['auth_type'] == 3:
                # OpenProvider专用认证方式 使用用户名密码换取token
                OpenProvider_token = OpenProvider(task['auth_id'], task['access_key'], task['uid']).GetToken()
                if OpenProvider_token and len(OpenProvider_token)>10:
                    needBearer = True
                    token = OpenProvider_token
                else:
                    RH.setlog("未能正确获取OpenProvider Token", task['uid'])
        except Exception as e:
            RH.setlog(task['domain_name'] + ' 发生错误1：' + str(e), task['uid'])
        try:
            header = json.loads(task['header']) if task['header'].strip() != '' else {}
            if needBearer and len(token)>0:
                header['Authorization'] = 'Bearer {}'.format(token)
            body = json.loads(task['body']) if task['body'].strip() != '' else{}
            # RH.setlog(task['body'], task['uid'])
            params = json.loads(task['params']) if task['params'].strip() != '' else{}
            params.update(body)
        except Exception as e:
            RH.setlog(task['domain_name'] + ' 发生错误2：' + str(e), task['uid'])
        try:
            s = requests.Session()
            s.headers.update(header)
            s.timeout=15
            if task['auth_type'] == 1:
                s.auth = (task['auth_id'], task['access_key'])
                s.verify=False
            if task['auth_type'] == 2:
                # wedos专用认证方式：sha1( 用户名 + sha1(密码) + 当前‘时’ )
                prague = timezone('Europe/Prague')
                loc_dt =  datetime.now(prague)
                hash1 = task['auth_id'] + hashlib.sha1(task['access_key'].encode("utf-8")).hexdigest() + loc_dt.strftime('%H')
                hash2 = hashlib.sha1(hash1.encode("utf-8")).hexdigest()
                request_data = {
                    "request": {
                        "user": task['auth_id'],
                        "auth": hash2,
                        "command": "domain-create",
                        # "test": 1,
                        "data": body
                    }
                }
            # 发送时间
            req_time = time.strftime("%Y-%m-%d %H:%M:%S", time.gmtime(time.time() + 8*3600))
            res = ''
            try:
                if task['auth_type'] != 2:
                    if task['method'] == 'post':
                        res = s.post(uri, json=params).text
                    else:
                        res = s.get(uri, params=params).text
                if task['auth_type'] == 2:
                    # wedos专用请求
                    res = s.post(uri, data={"request": json.dumps(request_data)}).text
            except Exception as e:
                RH.setlog(task['domain_name'] + ' 发生错误3：' + str(e), task['uid'])
            RH.setlog(json.dumps(res.text))
            try:
                RH.setlog(task['domain_name'] + " " + res , task['uid'])
                # 开始判断成功标识
                if task['sflag'] and re.search(task['sflag'], res, re.M) != None:
                    RH.setlog(task['domain_name']+' 注册成功', task['uid'])
                    # 将当前域名设置为成功状态
                    db.update_dict('domain', {'status': 3}, 'id = {}'.format(task['id']))
                    # 发送成功消息到服务端
                    res = RMT.sendMsg({'domain_name': task['domain_name'], 'uid': task['uid'], 'uuid': task['uuid'], 'req_time': req_time}, task['rs_id'])
                # 开始判断失败标识
                if task['fflag'] != None and task['fflag'] != '':
                    if re.search(task['fflag'], res, re.M) != None:
                        RH.setlog(task['domain_name']+' 注册失败', task['uid'])
                        # 将当前域名设置为失败状态
                        db.update_dict('domain', {'status': 0}, 'id = {} and status = 1'.format(task['id']))
                        # 发送失败消息到服务端
                        res = RMT.sendMsg({'domain_name': task['domain_name'], 'uid': task['uid'], 'uuid': task['uuid'], 'req_time': req_time}, task['rs_id'], 'domain_fail')
            except Exception as e:
                RH.setlog(task['domain_name'] + ' 发生错误4：' + str(e), task['uid'])
        except Exception as e:
            RH.setlog(task['domain_name'] + ' 发生错误5：' + str(e), task['uid'])
    '''
    替换链接、头部等字段中的标签，解密密码
    返回字典
    '''
    def _HandleField(self, taskDict):
        taskDict['access_key'] = self._RepField(taskDict, 'access_key')
        taskDict['params'] = self._RepField(taskDict, 'params')
        taskDict['header'] = self._RepField(taskDict, 'header')
        taskDict['body'] = self._RepField(taskDict, 'body')
        taskDict['url'] = self._RepField(taskDict, 'url')
        return taskDict
    def _RepField(self, taskDict, field):
        res = taskDict[field].replace('{{auth_id}}', taskDict['auth_id']).replace('{{access_key}}', taskDict['access_key']).replace('{{domain_name}}', taskDict['domain_name'])
        domain_split = taskDict['domain_name'].split('.',1)
        if domain_split[1] != '' and len(domain_split[1])>1:
            res = res.replace('{{domain_body}}', domain_split[0]).replace('{{domain_suffix}}', domain_split[1])
        if taskDict['extension']:
            res = res.replace('{{extension}}', taskDict['extension'])
        return res
    def _filter(self, param=''):
        return param.strip().replace('"', '&quot;').replace('\'', '&#39;').replace('@', '&#64;')

'''
OpenProvider专用类
'''
class OpenProvider:
    def __init__(self, username, password, uid) -> None:
        self.username = username
        self.password = password
        self.uid = uid
        pass
    def GetToken(self):
        token = self._GetTokenFromCache()
        if token:
            return token
        else:
            return self._GenToken()
    def _GetTokenFromCache(self):
        return RH.cget('OpenProvider_' + self.username)
    def _GenToken(self):
        token = ''
        json_data = {
            "username": self.username,
            "password": self.password,
            "ip": "0.0.0.0"
        }
        try:
            r = requests.post('https://api.openprovider.eu/v1beta/auth/login',json=json_data)
            res = r.json()
            if res['code'] == 0 and res['data'] != '':
                token = res['data']['token']
            else:
                RH.setlog('获取token时上游返回了错误代码： ' + r.text, self.uid)
        except Exception as e:
            RH.setlog('没有正确获取到Token，请核对用户名：{}，密码：{}'.format(self.username, self.password), self.uid)
        else:
            # 缓存Token
            RH.cset('OpenProvider_' + self.username, token, 1800)
            return token
if __name__ == "__main__":
    dc = DomainCore()
    dc.MainController()