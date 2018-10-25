require 'lita/adapters/slack/chat_service'
require 'lita/adapters/slack/rtm_connection'

module Lita
  module Adapters
    # A Slack adapter for Lita.
    # @api private
    class Slack < Adapter
      # Required configuration attributes.
      config :token, type: String, required: true
      config :proxy, type: String
      config :parse, type: [String]
      config :link_names, type: [true, false]
      config :unfurl_links, type: [true, false]
      config :unfurl_media, type: [true, false]

      # Provides an object for Slack-specific features.
      def chat_service
        ChatService.new(config)
      end

      def mention_format(name)
        "@#{name}"
      end

      # Starts the connection.
      def run
        return if rtm_connection

        @rtm_connection = RTMConnection.build(robot, config)
        rtm_connection.run
      end

      # Returns UID(s) in an Array or String for:
      # Channels, MPIMs, IMs
      def roster(target)
        api = API.new(config)
        room_roster target.id, api
      end

      def send_messages(target, strings)
        Lita.logger.debug("*******")

        api = API.new(config)
        str = strings
        # thread_ts = nil
        channel = channel_for(target)
        threaded_reply = nil

        if strings[0] == "$_karma_$"
          ignored_channels = strings[1].split(',')
          summary = strings[2]
          full_text = strings[3]

          if ignored_channels.include? channel
            str = full_text
          else
            threaded_reply = full_text
            str = summary

          end
        end

        msg = api.send_messages(channel, [str])
        api.send_messages(channel, [threaded_reply], msg['ts']) unless threaded_reply.nil?


        # comps = strings[0].split("$_BNR_TS_$")
        # if comps.count > 1
        #   str = [comps[1]]
        #   # should move this into a config
        #   # C0DS5627N = #thanks
        #   # C024FA2V7 = #serious-business
        #   thread_ts = comps[0] unless (channel == 'C0DS5627N' || channel == 'C024FA2V7')
        #
        # end
        #
        # msg = api.send_messages(channel, str, thread_ts)

        Lita.logger.debug(target)
        Lita.logger.debug(channel_for(target))
        Lita.logger.debug(strings)
        Lita.logger.debug(msg)
        Lita.logger.debug("*******")
        msg
      end

      def set_topic(target, topic)
        channel = target.room
        Lita.logger.debug("Setting topic for channel #{channel}: #{topic}")
        API.new(config).set_topic(channel, topic)
      end

      def shut_down
        return unless rtm_connection

        rtm_connection.shut_down
        robot.trigger(:disconnected)
      end

      private

      attr_reader :rtm_connection

      def channel_for(target)
        if target.private_message?
          rtm_connection.im_for(target.user.id)
        else
          target.room
        end
      end

      def channel_roster(room_id, api)
        response = api.channels_info room_id
        response['channel']['members']
      end

      # Returns the members of a group, but only can do so if it's a member
      def group_roster(room_id, api)
        response = api.groups_list
        group = response['groups'].select { |hash| hash['id'].eql? room_id }.first
        group.nil? ? [] : group['members']
      end

      # Returns the members of a mpim, but only can do so if it's a member
      def mpim_roster(room_id, api)
        response = api.mpim_list
        mpim = response['groups'].select { |hash| hash['id'].eql? room_id }.first
        mpim.nil? ? [] : mpim['members']
      end

      # Returns the user of an im
      def im_roster(room_id, api)
        response = api.mpim_list
        im = response['ims'].select { |hash| hash['id'].eql? room_id }.first
        im.nil? ? '' : im['user']
      end

      def room_roster(room_id, api)
        case room_id
        when /^C/
          channel_roster room_id, api
        when /^G/
          # Groups & MPIMs have the same room ID pattern, check both if needed
          roster = group_roster room_id, api
          roster.empty? ? mpim_roster(room_id, api) : roster
        when /^D/
          im_roster room_id, api
        end
      end
    end

    # Register Slack adapter to Lita
    Lita.register_adapter(:slack, Slack)
  end
end
