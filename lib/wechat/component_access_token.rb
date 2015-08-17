module Wechat
  class ComponentAccessToken < AccessToken
    attr_accessor :pre_auth_code, :verify_ticket

    def refresh
      data = client.post("component/api_component_token", params:{component_appid: appid, component_appsecret: secret, component_verify_ticket: verify_ticket})
      File.open(token_file, 'w'){|f| f.write(data.to_s)} if valid_token(data)
      return @token_data = data
    end

    private 
    def valid_token token_data
      access_token = token_data["component_access_token"]
      raise "Response didn't have access_token" if  access_token.blank?
      return access_token
    end

  end
end
