#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Author: Yudai Hashimoto
# https://jp7fkf.dev/

import os
import requests
import json
import traceback
import urllib.request
from dotenv import load_dotenv

load_dotenv()

SLACK_URL = os.environ['SLACK_URL']
IPINFO_URL = 'https://ipinfo.io/ip'
IPFILE_PATH = 'ipaddress.txt'

def send_slack(slack_text):
  payload = {
    "username": "IP Address Change Notificator",
    "icon_emoji": ':rotating_light:',
    "attachments": [{
    "text": slack_text,
    "color": "#ff0000",
    }
  ]}

  data = json.dumps(payload)
  requests.post(SLACK_URL, data)

def main():
  previous_ipaddr = ''

  response = urllib.request.urlopen(IPINFO_URL)
  html = response.read()
  current_ipaddr = html.decode('utf-8')

  try:
    f = open(IPFILE_PATH, mode='r')
    try:
      previous_ipaddr = f.read()
    except:
      print(traceback.format_exc())
    finally:
      f.close()
  except IOError:
    previous_ipaddr = ''

  # if some diff of addrs exists:
  if (current_ipaddr != previous_ipaddr):
    try:
      f = open(IPFILE_PATH, mode='w')
      try:
        f.write(current_ipaddr)
      except:
        print(traceback.format_exc())
      finally:
        f.close()
    except:
      print(traceback.format_exc())
    slack_text = f'IP Address Changed! : {current_ipaddr}'
    send_slack(slack_text)

if __name__ == "__main__":
  main()
