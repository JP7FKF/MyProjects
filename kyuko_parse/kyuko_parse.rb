# encoding: UTF-8
module NITS_Kyuko
  require 'open-uri'
  require 'nokogiri'
  require 'google/api_client'
  require 'date'
  require 'yaml'

  config = YAML.load_file("settings.yaml")

  url = 'http://hirose.sendai-nct.ac.jp/kyuko/kyuko.cgi'

  page = Nokogiri::HTML.parse(open(url), nil, "CP932")

  html = []

  page.xpath('//center/a | //center/table[@width="650"]').each do |elements|
    html.push(elements.attr("html"))
    html += elements.xpath('tr').text.gsub(/^[\s　]+|[\s　]+$/, ' ').strip.split
    html.push elements.css('img').attr('src').value unless elements.css('img').empty?
  end

  html.compact!
  summary = html.each_slice(6).to_a

  # File.open("kyuko_data.txt", "w") do |file|
    summary.each do |detail|
      detail.each {|x| x.tr!('０-９ａ-ｚＡ-Ｚ，－', '0-9a-zA-Z,-')}
      detail[0] = Date.strptime(detail[0], '%m月%d日')
      detail[5] = '変更' if detail[5].include?('henko')
      detail[5] = '休講' if detail[5].include?('kyuko')
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
  #  printf("%s, %s, %s, %s, %s\n",
  #   event.start.date, event.end.date, event.summary, event.description, event.id)
  # end

  # これから3ヶ月先までのイベントを削除する
  events.each do |event|
    params = {'calendarId' => CALENDAR_ID,
              'eventId' => event.id}
    result = client.execute(:api_method => cal.events.delete,
                            :parameters => params)
    # p result.status
  end

  # 取得した最新のデータをカレンダーに追加する
  summary.each do |detail|
    start_date = detail[0].to_s
    end_date = (Date.parse(detail[0].to_s)+1).to_s
    event_name = "[#{detail[5]}]#{detail[1]} #{detail[2]} #{detail[4]}"

    event = {
      'summary' => event_name,
      'start' => {
        'date' => "#{start_date}",
      },
      'end' => {
        'date' => "#{end_date}",
      },
      'description' => "取得日時:#{scrape_time.to_s}",
    }

    result = client.execute(:api_method => cal.events.insert,
                            :parameters => {'calendarId' => CALENDAR_ID},
                            :body => JSON.dump(event),
                            :headers => {'Content-Type' => 'application/json'})

    # p result.status
  end
end
