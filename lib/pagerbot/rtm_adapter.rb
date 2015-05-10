# Slack rtm integration for pagerbot

require 'slack-rtmapi'
require 'json'

module PagerBot::RtmAdapter
  class PagerDutyPlugin
    def initialize(token, name)
      @token = token
      @name = name
    end

    def connect!
      url = SlackRTM.get_url token: @token
      @client = SlackRTM::Client.new websocket_url: url
      @client.on(:message) { |data| process data }
      @client.on(:error) { |data| raise Exception.new(data) }
      @client.main_loop
    end

    def reply(m, answer)
      data = {
        text: answer[:message],
        channel: m['channel'],
        token: @token,
        type: 'message',
      }
      p({data: data})
      p @client.send(data)
    end

    def relevant?(m)
      m['type'] == 'message' &&
      m['text']=~/@?#{@name}:/
    end 

    def process(m)
      return unless relevant? m
      p({m: m})
      answer = PagerBot.process(m['text'], {})
      p({answer: answer})
      reply(m, answer)
    end
  end

  def self.run!
    require 'pry'
    token = configatron.bot.slack.api_token
    name = configatron.bot.name
    rtm = PagerDutyPlugin.new token, name
    rtm.connect!
    rtm
  end
end
