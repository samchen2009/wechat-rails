module Wechat
  module Responder
    extend ActiveSupport::Concern

    included do 
      self.skip_before_filter :verify_authenticity_token
      self.prepend_before_filter :verify_signature, only: [:show, :create] #, :auth]
      self.before_filter :decrypt_xml
      #delegate :wehcat, to: :class
    end

    module ClassMethods

      attr_accessor :wechat, :token

      def on message_type, with: nil, respond: nil, &block
        raise "Unknow message type" unless message_type.in? [:text, :image, :voice, :video, :location, :link, :event, :fallback]
        config=respond.nil? ? {} : {:respond=>respond}
        config.merge!(:proc=>block) if block_given?

        if (with.present? && !message_type.in?([:text, :event]))
          raise "Only text and event message can take :with parameters"
        else
          config.merge!(:with=>with) if with.present?
        end

        responders(message_type) << config
        return config
      end

      def responders type
        @responders ||= Hash.new
        @responders[type] ||= Array.new
      end

      def responder_for message, &block
        # info type - https://open.weixin.qq.com/cgi-bin/showdocument?action=dir_list&t=resource/res_list&verify=1&id=open1419318587&lang=zh_CN
        message_type = (message[:MsgType]).to_sym
        responders = responders(message_type)

        case message_type
        when :text
          yield(* match_responders(responders, message[:Content]))

        when :event
          if message[:Event] == 'CLICK'
            yield(* match_responders(responders, message[:EventKey]))
          else
            yield(* match_responders(responders, message[:Event]))
          end
        else
          yield(responders.first)
        end
      end

      private 

      def match_responders responders, value
        matched = responders.inject({scoped:nil, general:nil}) do |matched, responder|
          condition = responder[:with]

          if condition.nil?
            matched[:general] ||= [responder, value]
            next matched
          end
          
          if condition.is_a? Regexp
            matched[:scoped] ||= [responder] + $~.captures if(value =~ condition)
          else
            matched[:scoped] ||= [responder, value] if(value == condition)
          end
          matched
        end
        return matched[:scoped] || matched[:general] 
      end
    end

    
    def show
      render :text => params[:echostr]
    end

    include Wechat::AESCrypt

    def create
      ###
      request = Wechat::Message.from_hash(params[:xml] || post_xml)
      response = self.class.responder_for(request) do |responder, *args|
        responder ||= self.class.responders(:fallback).first

        next if responder.nil?
        next request.reply.text responder[:respond] if (responder[:respond])
        next responder[:proc].call(*args.unshift(request)) if (responder[:proc])
      end

      if response.respond_to? :to_xml
        render xml: response.to_xml
      else
        render :nothing => true, :status => 200, :content_type => 'text/html'
      end
    end

    #component message
    def messages
      mp_id = params[:id]
      request = Wechat::Message.from_hash(params[:xml] || post_xml,  mp_id)
      response = self.class.responder_for(request) do |responder, *args|
        responder ||= self.class.responders(:fallback).first

        next if responder.nil?
        next request.reply.text responder[:respond] if (responder[:respond])
        next responder[:proc].call(*args.unshift(request)) if (responder[:proc])
      end

      if response.respond_to? :to_xml
        render xml: response.to_xml
      else
        render :nothing => true, :status => 200, :content_type => 'text/html'
      end

    end

    def access_token_and_auth_code
      args = {
        component_verifiy_ticket: params[:xml][:ComponentVerifyTicket],
        component_appid:  self.class.wechat.access_token.appid,
        component_appsecret: self.class.wechat.access_token.secret
      }
      begin
        resp = RestClient.post "https://api.weixin.qq.com/cgi-bin/component/api_component_token", args
        self.class.wechat.access_token.component_access_token = resp[:component_access_token] if resp[:component_access_token]

        resp = RestClient.post "https://api.weixin.qq.com/cgi-bin/component/api_create_preauthcode?component_access_token=#{self.class.wechat.token}"
        self.class.wechat.access_token.pre_auth_code = resp[:pre_auth_code]
      rescue 

      end
      render :json => 'success', :status => 200
    end


    # /wechats/auth?signature=6a041a38aea75727cf32dc1371a7ed919be644ab&timestamp=1438863034&nonce=2023004964&encrypt_type=aes&msg_signature=9b5226901ced5c73999052e80a716339975e0854
    def auth
      params[:xml] = {:ComponentVerifyTicket => '12345665123'}
      #debugger
      if params[:xml][:ComponentVerifyTicket]
        access_token_and_auth_code
      else
        auth_code   = params[:auth_code]
        expires_at  = params[:expires_at] 
        resp = RestClient.post("https://api.weixin.qq.com/cgi-bin/component/api_query_auth?component_access_token=#{self.class.wechat.access_token.token}", 
                            {component_appid: self.class.wechat.access_token.appid, authorization_code: auth_code})
        args = {
          appid: resp[:authorizer_appid],
          expires_at: resp[:expires_in].seconds.from_now,
          refresh_token: resp[:authorizer_refresh_token],
          access_token: resp[:authorizer_access_token],
          func_info: resp[:func_info].to_json,
          authorized: true
        }
        WechatComponent.build!(args, user_id: params[:uid])
        render :json => 'success', :status => 200
      end
    end

    private

    def encrypted_msg
      if params[:encrypt_type] =~ /aes/i  
        params[:xml] and params[:xml][:Encrypt]
      end
    end

    def decrypt_xml
      if msg = encrypted_msg
        params[:xml] = decrypt_msg(msg, Base64.decode64(self.class.wechat.encoding_aes_token))
      end
    end

    def verify_signature
      if encrypted_msg
        array = [self.class.token, params[:TimeStamp], params[:Nonce], encrypted_msg].compact.collect(&:to_s).sort
        render :text => "Forbidden", :status => 403 if params[:MsgSignature] != Digest::SHA1.hexdigest(array.join)
      else
        array = [self.class.token, params[:timestamp], params[:nonce]].compact.collect(&:to_s).sort
        render :text => "Forbidden", :status => 403 if params[:signature] != Digest::SHA1.hexdigest(array.join)
      end
    end

    private
    def post_xml
      data = Hash.from_xml(request.raw_post)
      HashWithIndifferentAccess.new_from_hash_copying_default data.fetch('xml', {})
    end
  end
end
