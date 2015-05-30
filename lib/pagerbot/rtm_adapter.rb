# Slack rtm integration for pagerbot

require 'slack-rtmapi'
require 'json'

module PagerBot::RtmAdapter
  class PagerDutyPlugin
    def initialize(token, name)
      @token = token
      @name = name

      whoami
      slack_channels
    end

    def whoami
      data = {
        token: configatron.bot.slack.api_token
      }
      resp = RestClient.post "https://slack.com/api/auth.test", data
      data = JSON.parse(resp)
      raise ArgumentError.new("Bot name configured in slack #{data['user']} and bot #{@name} do not match!") if @name != data['user']
      @user_id = data['user_id']
    end

    def slack_channels
      data = {
        token: configatron.bot.slack.api_token
      }
      resp = RestClient.post "https://slack.com/api/channels.list", data
      channel_data = JSON.parse(resp)['channels']
      @channels = Hash[[*channel_data.map {|c| [c['id'], c['name']]}]]
      PagerBot.log.info "Know about #{@channels.count} slack channels."
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
      relevant = m['type'] == 'message' &&
                    (m['text'].start_with?("#{@name}: ") || # without @name
                     m['text'].start_with?("<@#{@user_id}>: ")) #with @name

      return m['text'].gsub(/<@#{@user_id}>/, @name) if relevant
    end

    def event_data(m)
      {
        nick: m['user'],
        channel_name: @channels[m['channel']],
        text: m['text'],
        adapter: :rtm
      }
    end

    def process(m)
      text = relevant? m
      return unless text
      data = event_data(m)
      answer = PagerBot.process(text, data)
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
