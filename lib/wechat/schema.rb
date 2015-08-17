require 'active_support/deprecation'

module Wechat
  # Provides helper methods that can be used in migrations.
  module Schema
    def wx_components(*args)
      options = args.extract_options!
      args.each do |col|
        column("appid", :string, options)
        column("access_token", :string, options)
        column("expries_at", :timestamp, options)
        column("refresh_token", :string, options)
        column("function_info", :string, options)
        column("authorized", :boolean, options)
      end
    end
    
    def load!
      ::ActiveRecord::ConnectionAdapters::TableDefinition.class_eval { include Wechat::Schema}
    end
  end
end