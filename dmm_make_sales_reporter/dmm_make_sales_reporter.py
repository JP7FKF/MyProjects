#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# Author: Yudai Hashimoto
# https://jp7fkf.dev/

import os
import requests
import json
import time
import traceback
import re
import chromedriver_binary
from selenium import webdriver
from selenium.webdriver.chrome.options import Options

SLACK_URL = os.environ['SLACK_URL']
DMM_LOGIN_ID = os.environ['DMM_LOGIN_ID']
DMM_LOGIN_PASSWORD = os.environ['DMM_LOGIN_PASSWORD']

def main():
  options = Options()
  options.add_argument("--headless")
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-gpu')
  options.add_argument('--disable-gpu-rasterization')
  options.add_argument("--disable-application-cache")
  options.add_argument("--disable-infobars")
  options.add_argument("--hide-scrollbars")
  options.add_argument("--single-process")
  options.add_argument("--ignore-certificate-errors")
  options.add_argument('--disable-desktop-notifications')
  options.add_argument("--disable-extensions")
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--enable-plugins')
  options.add_argument('--renderer-process-limit=3')

  driver = webdriver.Chrome(options=options)
  driver.implicitly_wait(10)

  try:
    driver.get("https://www.dmm.com/my/-/login/")

    elem_login_id = driver.find_element_by_id("login_id")
    driver.execute_script('document.getElementById("login_id").value="%s";' % DMM_LOGIN_ID)
    #elem_login_id.send_keys(DMM_LOGIN_ID)
    elem_password = driver.find_element_by_id("password")
    driver.execute_script('document.getElementById("password").value="%s";' % DMM_LOGIN_PASSWORD)
    #elem_password.send_keys(DMM_LOGIN_PASSWORD)
    elem_login_button = driver.find_element_by_xpath('//*[@id="loginbutton_script_on"]/span/input')
    elem_login_button.click()

    driver.get("https://make.dmm.com/mypage/")

    monthly_total_sales = driver.find_element_by_class_name('dlData__monthly').find_element_by_xpath('li[1]/div/p[3]/span[1]').text
    monthly_orders = driver.find_element_by_class_name('dlData__monthly').find_element_by_xpath('li[2]/div/p[2]/span[1]').text
    orders_diff_a_day = driver.find_element_by_class_name('dlData__monthly').find_element_by_xpath('li[2]/div/p[3]').text
    # monthly_favs = driver.find_element_by_xpath('//*[@id="columnMain"]/div/form/div[3]/ul/li[3]/div/p[2]/span[1]').text
    # favs_diff_a_day = driver.find_element_by_xpath('//*[@id="columnMain"]/div/form/div[3]/ul/li[3]/div/p[3]').text

    orders_diff_a_day_int_abs = int(re.sub("\\D", "", orders_diff_a_day))

    #print(monthly_total_sales)
    #print(monthly_orders)
    #print(orders_diff_a_day_int_abs)

    # if some diff of orders exists:
    if (orders_diff_a_day_int_abs != 0):
      slack_text = f'売り上げが変化しました: {orders_diff_a_day}\n今月の受注数: {monthly_orders}, 今月の売り上げ: {monthly_total_sales}円'
      send_slack(slack_text)
    else:
      slack_text = f'売り上げに変化はありません: {orders_diff_a_day}\n今月の受注数: {monthly_orders}, 今月の売り上げ: {monthly_total_sales}円'
      #send_slack(slack_text)

  except:
    traceback.print_exc()
    slack_text = f'Exception Occurred!'
    send_slack(slack_text)
  finally:
    driver.quit()

def send_slack(slack_text):
  payload = {
    "username": "DMM.make Sales Reporter",
    "icon_emoji": ':moneybag:',
    "attachments": [{
    "text": slack_text,
    "color": "#439fe0",
    }
  ]}

  data = json.dumps(payload)
  requests.post(SLACK_URL, data)

if __name__ == "__main__":
  main()
