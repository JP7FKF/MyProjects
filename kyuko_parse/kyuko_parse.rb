# encoding: utf-8
require 'open-uri'
require 'nokogiri'
require 'google/api_client'
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
url = 'https://www.sendai-nct.ac.jp/sclife/kyuko/ku_hirose'
page = Nokogiri::HTML.parse(open(url), nil, "utf-8")
html = []
slack_message = ''

page.xpath('//*[@id="contents"]//table[@class="table2"]/tbody').each do |elements|
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

CALENDAR_ID = config["account_setting"]["CALENDAR_ID"]
client = Google::APIClient.new(:application_name => 'test')

# 認証
key = Google::APIClient::KeyUtils.load_from_pkcs12(config["account_setting"]["json_path"], config["account_setting"]["secretkey"])
client.authorization = Signet::OAuth2::Client.new(
  token_credential_uri: 'https://accounts.google.com/o/oauth2/token',
  audience: 'https://accounts.google.com/o/oauth2/token',
  scope: 'https://www.googleapis.com/auth/calendar',
  issuer: config["account_setting"]["secret_id"],
  signing_key: key
  )
client.authorization.fetch_access_token!

# google calendar に登録
cal = client.discovered_api('calendar', 'v3')

# 登録されている情報を表示する
scrape_time = DateTime.now
time_max = (scrape_time >> 3).iso8601
time_min = scrape_time.iso8601
params = {'calendarId' => CALENDAR_ID,
          'orderBy' => 'startTime',
          'timeMax' => time_max,
          'timeMin' => time_min,
          'singleEvents' => 'True'}

result = client.execute(:api_method => cal.events.list,
                        :parameters => params)

# イベント格納
events = []
result.data.items.each do |item|
  events << item
end

# 出力
# events.each do |event|
# printf("%s, %s, %s, %s, %s\n",
#   event.start.date, event.end.date, event.summary, event.description, event.id)
# end

# これから3ヶ月先までのイベントを削除する
events.each do |event|
  params = {'calendarId' => CALENDAR_ID,
            'eventId' => event.id}
  result = client.execute(:api_method => cal.events.delete,
                          :parameters => params)
  p result.status
  if result.status != 204
    slack_message << "[#{result.status}] #{event.summary}\n"
  end
end

# 取得した最新のデータをカレンダーに追加する

summary.each do |detail|
  start_date = detail[1].to_s
  end_date = (Date.parse(detail[1].to_s)+1).to_s
  event_name = "[#{detail[0]}]#{detail[2]} #{detail[3]} #{detail[4]}"

  event = {
    'summary' => event_name,
    'start' => {
      'date' => "#{start_date}",
    },
    'end' => {
      'date' => "#{end_date}",
    },
    'description' => "備考: #{detail[6]}\r\n担当: #{detail[5]}\r\n取得日時: #{scrape_time.to_s}",
  }

  result = client.execute(:api_method => cal.events.insert,
                          :parameters => {'calendarId' => CALENDAR_ID},
                          :body => JSON.dump(event),
                          :headers => {'Content-Type' => 'application/json'})

  p result.status
  if result.status != 200
    slack_message << "[#{result.status}] #{event_name}\n"
  end
end
if slack_message != ''
  post_slack(slack_message)
end
