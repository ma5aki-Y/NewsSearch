require 'bundler'
Bundler.require

require 'line/bot'
require 'net/http'
require 'uri'
require 'json'

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV['LINE_CHANNEL_SECRET']
    config.channel_token = ENV['LINE_CHANNEL_TOKEN']
  }
end

def news_search(text)
  params = URI.encode_www_form({APIKEY: ENV['DOCOMO_API_KEY'], keyword: text, s: 1, n: 3, lang: 'ja'})
  uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/webCuration/v3/search?#{params}")
  response = Net::HTTP.get(uri)
  response_json = JSON.parse(response)
  count = response_json['itemsPerPage'].to_i 
  unless count == 0
    @message = []
    response_json['articleContents'].each do |content|
      @message << {
        type: 'text',
        text: content['contentData']['title'] + "\n" + content['contentData']['linkUrl']
      }
    end
  else
    @message = {
      type: 'text',
      text: 'Sorry, not found.'
    }
  end
end

def class_cancel_search
  today = Date.today.strftime('%Y-%m-%d')
  #スクレイピング処理
  agent = Mechanize.new
  agent.user_agent_alias = 'Mac Safari 4'
  page = agent.get('https://www.ac04.tamacc.chuo-u.ac.jp/ActiveCampus/module/KyukoDaigakuAll.php').content.toutf8
  contents = Nokogiri::HTML.parse(page, nil, 'utf-8')
  @str = ''
  # 休講情報テーブルの行番号を設定
  table_row = 2
  date = contents.css('div#portlet_acPortlet_0 tr:nth-of-type(2) td:nth-of-type(2)').text
  while date == today
    if contents.css("div#portlet_acPortlet_0 tr:nth-of-type(#{table_row}) td:nth-of-type(4)").text == '商'
      here_document(contents,table_row)
    end
    table_row += 1
    date = contents.css("div#portlet_acPortlet_0 tr:nth-of-type(#{table_row}) td:nth-of-type(2)").text
  end
  unless table_row == 2
    @message = {
      type: 'text',
      text: "本日の休講情報はこちらです。 \n" + @str
    }
  else
    @message = {
      type: 'text',
      text: "現在、#{today}の休講情報は掲載されておりません。\n https://www.ac04.tamacc.chuo-u.ac.jp/ActiveCampus/module/KyukoDaigakuAll.php"
    }
  end
end

post '/callback' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end
  events = client.parse_events_from(body)
  events.each { |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        text = event.message['text']
        case text
        when '休講'
          class_cancel_search
        else
          news_search(text)
        end
        client.reply_message(event['replyToken'], @message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

  "OK"
end

def here_document(contents,table_row)
  class_room = contents.css("div#portlet_acPortlet_0 tr:nth-of-type(#{table_row}) td:nth-of-type(3)").text
  teacher = contents.css("div#portlet_acPortlet_0 tr:nth-of-type(#{table_row}) td:nth-of-type(5)").text
  room = contents.css("div#portlet_acPortlet_0 tr:nth-of-type(#{table_row}) td:nth-of-type(6)").text
  text = <<-"EOS"
--------------
  #{class_room}
  #{teacher}
  #{room}
  EOS
  @str << text
end
