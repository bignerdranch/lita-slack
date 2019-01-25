module Lita
  module Adapters
    class Slack < Adapter
      class SlackSource < Lita::Source
        def initialize(**args)
          @extensions = args.delete(:extensions)
          super(**args)
        end

        def timestamp
          @extensions[:timestamp]
        end

        def thread_ts
          @extensions[:thread_ts]
        end
      end
    end
  end
end