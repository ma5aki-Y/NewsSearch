require 'sinatra'
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
  @message = []
  unless count == 0
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
        news_search(text)
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


