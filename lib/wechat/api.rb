require 'wechat/client'
require 'wechat/access_token'
require 'wechat/component_access_token'

class Wechat::Api
  attr_reader :access_token, :client, :encoding_aes_token

  API_BASE = "https://api.weixin.qq.com/cgi-bin/"
  FILE_BASE = "http://file.api.weixin.qq.com/cgi-bin/"

  def initialize opts 
    #appid, secret, token_file, encoding_aes_token = nil, encoding_aes_token= nil, component_account = false
    @client = Wechat::Client.new(API_BASE)
    if opts[:component_account]
      @access_token = Wechat::ComponentAccessToken.new(@client, opts[:appid], opts[:secret], opts[:access_token_file])
    else
      @access_token = Wechat::AccessToken.new(@client, opts[:appid], opts[:secret], opts[:access_token_file])
    end
    @encoding_aes_token= opts[:encoding_aes_token]
    @encoding_aes_token_backup= opts[:encoding_aes_key_token]
  end

  def users nextid = nil, component_id = nil
    params = {params: {next_openid: nextid}} if nextid.present?
    get('user/get', params||{}, component_id)
  end

  def user openid, component_id = nil
    get "user/info", {:params => {openid: openid}}, component_id
  end

  def menu component_id = nil
    get("menu/get", {}, component_id)
  end

  def menu_delete component_id = nil
    get("menu/delete", {}, component_id)
  end

  def menu_create menu, component_id = nil
    # 微信不接受7bit escaped json(eg \uxxxx), 中文必须UTF-8编码, 这可能是个安全漏洞
    post("menu/create", JSON.generate(menu), component_id)
  end

  def media media_id, component_id = nil
    response = get "media/get", {params:{media_id: media_id}, base: FILE_BASE, as: :file}, component_id
  end

  def media_create type, file, component_id = nil
    post "media/upload", {upload:{media: file}}, {params:{type: type, base: FILE_BASE}}, component_id
  end

  def custom_message_send message, component_id = nil
    post "message/custom/send", message.to_json, {content_type: :json}, component_id
  end
  
  def template_message_send message, component_id = nil
    post "message/template/send", message.to_json, {content_type: :json}, component_id
  end

  protected
  def get path, headers={}, component_id = nil
    with_access_token(headers[:params]){|params| client.get path, headers.merge(params: params), component_id}
  end

  def post path, payload, headers = {}, component_id = nil
    with_access_token(headers[:params]){|params| client.post path, payload, headers.merge(params: params), component_id}
  end

  def with_access_token params={}, tries=2, component_appid = nil
    begin
      params ||= {}
      if component_appid
        yield(params.merge(access_token: WxComponent.where(:appid => component_appid).first.access_token))
      else
        yield(params.merge(access_token: access_token.token))
      end
    rescue Wechat::AccessTokenExpiredError => ex
      access_token.refresh
      retry unless (tries -= 1).zero?
    end
  end

end
