require 'openssl'
require 'base64'

module Wechat
  module AESCrypt
    # Decrypts a block of data (encrypted_data) given an encryption key
    # and an initialization vector (iv).  Keys, iv's, and the data 
    # returned are all binary strings.  Cipher_type should be
    # "AES-256-CBC", "AES-256-ECB", or any of the cipher types
    # supported by OpenSSL.  Pass nil for the iv if the encryption type
    # doesn't use iv's (like ECB).
    #:return: => String
    #:arg: encrypted_data => String 
    #:arg: key => String
    #:arg: iv => String
    #:arg: cipher_type => String
    def decrypt(encrypted_data, key, iv = nil, cipher_type = 'AES-256-CBC')
      aes = OpenSSL::Cipher::Cipher.new(cipher_type)
      aes.decrypt
      aes.key = key
      aes.iv = iv if iv != nil
      aes.update(encrypted_data) + aes.final  
    end
    
    # Encrypts a block of data given an encryption key and an 
    # initialization vector (iv).  Keys, iv's, and the data returned 
    # are all binary strings.  Cipher_type should be "AES-256-CBC",
    # "AES-256-ECB", or any of the cipher types supported by OpenSSL.  
    # Pass nil for the iv if the encryption type doesn't use iv's (like
    # ECB).
    #:return: => String
    #:arg: data => String 
    #:arg: key => String
    #:arg: iv => String
    #:arg: cipher_type => String  
    def encrypt(data, key, iv = nil, cipher_type = 'AES-256-CBC')
      aes = OpenSSL::Cipher::Cipher.new(cipher_type)
      aes.encrypt
      aes.key = key
      aes.iv = iv if iv != nil
      aes.update(data) + aes.final      
    end

    def decrypt_msg(msg, key)
      aes_key = key
      plain_text = decrypt(Base64.decode64(msg), aes_key)
      pad = plain_text[-1].ord
      content = plain_text[16...-pad]
      len = content[0...4].unpack('N')[0]
      plain_text = content[4...len+4]
    end

    def encrypt_msg(text, key)
      aes_key = key
      random = SecureRandom.hex(8)
      bytes  = text.encode(Encoding::UTF_8)
      len    = [bytes.size].pack('N')
      aeskey = Base64.decode64(key || self.class.wechat.encoding_aes_token)
      content = random + len + bytes + aes_key
      pad_size = (32 - content.size % 32) 
      pad_size = 32 if pad_size == 0
      pad = pad_size.chr * pad_size
      Base64.encode64(encrypt(content+pad, aes_key))
    end

  end
end
