module Wechat
  require 'rails'
  if defined? Rails::Railtie
    class Railtie < Rails::Railtie
      initializer 'wx_railtile.insert_into_active_record' do |app|
        ActiveSupport.on_load :active_record do
          Wechat::Railtie.insert
        end
      end
    end
  end

  class Railtie
    include Wechat::Schema
    def self.insert
      if defined?(::ActiveRecord)
        load!
        #::ActiveRecord::Base.extend(Model::ActiveRecord)
      end
    end
  end  
end