require 'rest-client'

module Wechat
  class Client

    attr_reader :base

    def initialize(base)
      @base = base
    end

    def get path, header={}, component_id=nil
      request_with_reply(path, header) do |url, header|
        RestClient.get(url, header)
      end
    end

    def post path, payload, header = {}, component_id = nil
      request(path, header) do |url, header|
        resp = RestClient.post(url, payload, header)
      end
    end

    def post_with_reply path, payload, header = {}, component_id = nil
      request_ex(path, header, true) do |url, header|
        resp = RestClient.post(url, payload, header)
      end
    end

    def request_with_reply path, header={}, &block
      request_ex path, header, true, &block
    end
    
    def request path, header={}, &block
      request_ex path, header, false, &block
    end

    def request_ex path, header={}, with_reply, &block
      url = "#{header.delete(:base) || self.base}#{path}"
      as = header.delete(:as)
      header.merge!(:accept => :json)

      response = yield(url, header)

      raise "Request not OK, response code #{response.code}" if response.code >=400
      parse_response(response, as || :json) do |parse_as, data|
        break data unless (parse_as == :json && data["errcode"].present?)

        case data["errcode"]
        when 0 # for request didn't expect results
          with_reply ? response : true

        when 42001, 40014 #42001: access_token超时, 40014:不合法的access_token
          raise AccessTokenExpiredError
          
        else
          raise ResponseError.new(data['errcode'], data['errmsg'])
        end
      end
    end

    private
    def parse_response response, as
      content_type = response.headers[:content_type] 
      parse_as = {
        /^application\/json/ => :json,
        /^image\/.*/ => :file
      }.inject([]){|memo, match| memo<<match[1] if content_type =~ match[0]; memo}.first || as || :text

      case parse_as
      when :file
        file = Tempfile.new("tmp")
        file.binmode
        file.write(response.body)
        file.close
        data = file

      when :json
        data = JSON.parse(response.body.gsub /[\u0000-\u001f]+/, '')

      else
        data = response.body
      end

      return yield(parse_as, data)
    end

  end
end
