module Wechat
  module Component
    def self.included(base)
      base.extend(ClassMethods)
      base.class_eval do 
        belong_to :user
      end
    end

    module ClassMethods
      def build!(params, user_id)
        self.create params.merge! user_id: user_id
      end
      
      def by_user(user_id)
        return all if user_id.blank?
        where(:user_id => user_id)
      end

      def by_appid(appid)
        return all if appid.blank?
        where(:appid => appid)
      end
    end

    def cancel_auth
      self.update :authorized => false
    end


  end
end