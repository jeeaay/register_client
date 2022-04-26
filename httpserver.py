#!/usr/bin/python3
# -*- coding: UTF-8 -*-
'''
Email: wrj7887@163.com
Author: Jeay
Date: 2022-04-06 10:35:58
LastEditors: Jeay
LastEditTime: 2022-04-26 15:00:44
jeay.net
FilePath: \部署\httpserver.py
Description: HTTP服务 基于flask
Copyright (c) 2022 by jeay.net, All Rights Reserved.
'''
from http import server
import os, json

# 引入flask
from flask import Flask, jsonify, request
# , session, g, render_template, redirect,  abort

# 实例化flask
app = Flask(__name__)

# 引入redis助手
from rcache import redisHelper

# 实例化助手
RH = redisHelper()

import requests

# 引入数据库模块
from db import DB
#  实例化数据库模块
db = DB()

# 引入配置类
from config import Config

# 读取配置
config = Config()

# 引入crypt加密解密
from crypt import Rsa

# 远程通信类
from remote import Remote

# flask首页
@app.route('/')
def index():
    if config.installed:
        return '<h1>欢迎使用域名服务！</h1>'
    # 未安装，提示安装信息
    # 写入服务器地址
    if not config.server:
        server_url = 'https://d.lmzg.org'
        # server_url = 'http://127.0.0.1:5678'
        config.write_config({'server': server_url})
    # 获取服务端公钥
    if not config.pubkey:
        try:
            res = requests.get(f'{config.server}/client_msg/getpubkey')
            res = res.json()
        except:
            return '<h1>服务器连接失败，可能是配置文件中的服务器地址错误</h1>'
        if res['errno'] == 200:
            # 保存公钥
            config.write_config({'pubkey': res['data']})
            config.write_config({'installed': 1})
    return f'''<h3>创建成功！</h3>\n
    <p>请在抢注平台>远程服务器>添加、部署</p>
    '''

# AES密钥传输方法 使用公钥加密后返回服务端
@app.route('/getkey/', methods=['POST','GET'])
def getkey():
    # 获取公钥
    pubkey = config.pubkey
    # 获取密钥
    aeskey = config.secret_key
    # 加密密钥
    res_crypt = Rsa()
    aeskey = res_crypt.encrypt(aeskey, pubkey)
    return jsonify({'errno': 200, 'data': aeskey})

# 返回远程日志
@app.route('/getlogs/', methods=['POST','GET'])
def getlogs():
    # 获取GET数据
    # print(request.args)
    errno = request.args.get('errno', default=None)
    if errno == None or errno != '200':
        return jsonify({'errno': 404, 'data': '请求错误'})
    data = request.args.get('data', default=None)
    if data == None or data.strip() == '':
        return jsonify({'errno': 404, 'data': '缺少data'})
    uid = request.args.get('uid', default=None)
    if uid == None or uid.strip() == '':
        return jsonify({'errno': 404, 'data': '缺少uid'})
    rmt = Remote()
    offset = request.args.get('offset', default=0)
    count = request.args.get('count', default=20)
    res = rmt.sendLog(data, uid, offset, count)
    # print(res)
    return jsonify({'errno': 200, 'data': res})


# robots.txt
@app.route('/robots.txt')
def robots():
    # 设置响应头为文本
    return 'User-agent: *\nDisallow: /\n', 200, {'Content-Type': 'text/plain'}
# 远程通信管理类


# 接收任务
@app.route('/add_task', methods=['POST'])
def add_task():
    # 获取post数据
    json_data = request.get_json()
    # print(json_data)
    rmt = Remote()
    res = rmt.addTask(json_data["data"])
    # print(res)
    if res['status']:
        return jsonify({'code': 200, 'msg': res['msg'], 'data': res['data']})
    else:
        return jsonify({'code': 500, 'msg': res['msg'], 'data': res['data']})

# 运行flask
if __name__ == '__main__':
    # app.debug = True
    app.run(host='0.0.0.0',port=config.port)