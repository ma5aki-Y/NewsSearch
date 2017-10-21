require 'sinatra'
require 'line/bot'
require 'net/http'
require 'uri'

# uri = URI.parse("https://api.apigw.smt.docomo.ne.jp/webCuration/v3/search?APIKEY=#{ENV['DOCOMO_API_KEY']}&keyword=%e3%83%a9%e3%83%bc%e3%83%a1%e3%83%b3&s=1&n=10&lang=ja")
# response = Net::HTTP.get_response(uri)

# puts response.body

get '/' do
  "hello world"
end

def client
  @client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }
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
        message = {
          type: 'text',
          text: event.message['text']
        }
        client.reply_message(event['replyToken'], message)
      when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
        response = client.get_message_content(event.message['id'])
        tf = Tempfile.open("content")
        tf.write(response.body)
      end
    end
  }

  "OK"
end

