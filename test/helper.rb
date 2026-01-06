require 'rubygems'
require 'bundler'

begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end

require 'test-unit'
require 'shoulda-context'
# require 'mocha/setup'
require 'webmock/test_unit'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'pipedrive-ruby'

class Test::Unit::TestCase
  extend Shoulda::Context::DSL

  def stub method, resource, body_file_name, request_body=nil, api_version='v2'
    # Determine base path based on API version
    base_path = api_version == 'v2' ? '/api/v2' : '/v1'

    # v2 uses header auth, v1 uses query param auth
    if api_version == 'v2'
      # v2: no api_token in query string
      if method == :get
        uri = "https://api.pipedrive.com#{base_path}/#{resource}"
        # Add request params to uri if any
        unless request_body.nil?
          uri += "?" + request_body.map{|k,v| "#{k}=#{v}"}.join('&')
        end
        request_stubbed = stub_request(:get, uri)
        request_stubbed.with(headers: request_headers_v2)
      else
        # Use PATCH for v2 update operations
        actual_method = (method == :put) ? :patch : method
        request_stubbed = stub_request(actual_method, "https://api.pipedrive.com#{base_path}/#{resource}")
        # POST/PATCH in v2 use JSON content type
        request_stubbed.with(headers: request_headers_v2_json)
      end
    else
      # v1: api_token in query string
      if method == :get
        uri = "https://api.pipedrive.com#{base_path}/#{resource}?api_token=some-token"
        # Add request params to uri if any
        unless request_body.nil?
          uri += request_body.map{|k,v| "#{k}=#{v}"}.join('&')
        end
        request_stubbed = stub_request(:get, uri)
      else
        request_stubbed = stub_request(method, "https://api.pipedrive.com#{base_path}/#{resource}?api_token=some-token")
      end
      request_stubbed.with(headers: request_headers)
    end

    request_stubbed.to_return(
        status: 200,
        body: File.read(File.join(File.dirname(__FILE__), "data", body_file_name)),
        headers: response_headers
      )
  end
  
  def request_headers
    {
      'Accept'=>'application/json',
      'Content-Type'=>'application/x-www-form-urlencoded',
      'User-Agent'=>'Ruby.Pipedrive.Api'
    }
  end

  def request_headers_v2
    {
      'Accept'=>'application/json',
      'Content-Type'=>'application/x-www-form-urlencoded',
      'User-Agent'=>'Ruby.Pipedrive.Api',
      'x-api-token'=>'some-token'
    }
  end

  def request_headers_v2_json
    {
      'Accept'=>'application/json',
      'Content-Type'=>'application/json',
      'User-Agent'=>'Ruby.Pipedrive.Api',
      'x-api-token'=>'some-token'
    }
  end

  def response_headers
    {
      "server" => "nginx/1.2.4",
      "date" => "Fri, 01 Mar 2013 14:01:03 GMT",
      "content-type" => "application/json",
      "content-length" => "1260",
      "connection" => "keep-alive",
      "access-control-allow-origin" => "*"
    }
  end
end
