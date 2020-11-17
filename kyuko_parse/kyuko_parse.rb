#!/usr/bin/env ruby
# encoding: utf-8
require 'open-uri'
require 'nokogiri'
require 'google/apis/calendar_v3'
require 'googleauth'
require 'date'
require 'yaml'
require 'net/http'
require 'uri'
require 'json'

def post_slack(message)
  uri  = URI.parse(ENV['SLACK_URL'])
  payload = {
    "username": "NIT-S, Kyuko-Calendar",
    "icon_emoji": ':ruby:',
    "attachments": [{
      "title": 'Error Occured',
      "text": message,
      "color": "#AA0114",
      }
  ]}

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.start do
    request = Net::HTTP::Post.new(uri.path)
    request.set_form_data(payload: payload.to_json)
    http.request(request)
  end
end

# main
config = YAML.load_file("./settings.yaml")
CLIENT_SECRET_PATH = config["account_setting"]["json_path"]
CALENDAR_ID = config["account_setting"]["CALENDAR_ID"]
APPLICATION_NAME = 'NITS_kyuko_calendar'

url = 'https://www.sendai-nct.ac.jp/sclife/kyuko/ku_hirose'
page = Nokogiri::HTML.parse(URI.open(url), nil, "utf-8")
html = []
slack_message = ''

page.xpath('//*[@id="kuinfo"]/tbody').each do |elements|
  line =  elements.css("tr")
  line.xpath('td').each do |hoge|
    html.push hoge.text
  end
end

html.compact!
summary = html.each_slice(6).to_a

# File.open("kyuko_data.txt", "w") do |file|
  summary.each do |detail|
    detail.each {|x| x.tr!('０-９ａ-ｚＡ-Ｚ，－', '0-9a-zA-Z,-')}
    detail.unshift '変更' if detail[0].include?('変更')
    detail.unshift '休講' if detail[0].include?('休講')
    detail[1] = detail[1].slice(/\d{1,2}月\d{1,2}日/)
    detail[1] = Date.strptime(detail[1], '%m月%d日')
    # file.puts detail.join(",")
  end
# end

#認証
authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
    json_key_io: File.open(CLIENT_SECRET_PATH),
    scope: Google::Apis::CalendarV3::AUTH_CALENDAR)
authorizer.fetch_access_token!

# google calendar に登録
calendar_service = Google::Apis::CalendarV3::CalendarService.new
calendar_service.client_options.application_name = APPLICATION_NAME
calendar_service.authorization = authorizer

# 登録されている情報を表示する
scrape_time = DateTime.now
time_max = (scrape_time >> 3).iso8601
time_min = scrape_time.iso8601

result = calendar_service.list_events(CALENDAR_ID,
          order_by: 'startTime',
          time_max: time_max,
          time_min: time_min,
          single_events: true)

# イベント格納
events = []
result.items.each do |item|
  events << item
end

## 出力
#events.each do |event|
#  printf("%s, %s, %s, %s, %s\n",
#  event.start.date, event.end.date, event.summary, event.description, event.id)
#end

## これから3ヶ月先までのイベントを削除する
events.each do |event|
  result = calendar_service.delete_event(CALENDAR_ID, event.id)
end

# 取得した最新のデータをカレンダーに追加する
summary.each do |detail|
  start_date = detail[1].to_s
  end_date = (Date.parse(detail[1].to_s)+1).to_s
  event_name = "[#{detail[0]}]#{detail[2]} #{detail[3]} #{detail[4]}"

  event = Google::Apis::CalendarV3::Event.new(
    summary: event_name,
    description: "備考: #{detail[6]}\r\n担当: #{detail[5]}\r\n取得日時: #{scrape_time.to_s}",
    start: { date: start_date },
    end: { date: end_date }
  )
  calendar_service.insert_event(CALENDAR_ID, event)
end

