# #OpenAPI Petstore
#
##This is a sample server Petstore server. For this sample, you can use the api key `special-key` to test the authorization filters.
#
#The version of the OpenAPI document: 1.0.0
#
#Generated by: https://openapi-generator.tech
#OpenAPI Generator version: 5.3.0-SNAPSHOT
#

require "json"
require "time"

module Petstore
  class ApiClient
    # The Configuration object holding settings to be used in the API client.
    property config : Configuration

    # Defines the headers to be used in HTTP requests of all API calls by default.
    #
    # @return [Hash]
    property default_headers : Hash(String, String)

    # Initializes the ApiClient
    # @option config [Configuration] Configuration for initializing the object, default to Configuration.default
    def initialize(@config = Configuration.default)
      @user_agent = "OpenAPI-Generator/#{VERSION}/crystal"
      @default_headers = {
        "User-Agent" => @user_agent
      }
    end

    def self.default
      @@default ||= ApiClient.new
    end

    # Check if the given MIME is a JSON MIME.
    # JSON MIME examples:
    #   application/json
    #   application/json; charset=UTF8
    #   APPLICATION/JSON
    #   */*
    # @param [String] mime MIME
    # @return [Boolean] True if the MIME is application/json
    def json_mime?(mime)
      (mime == "*/*") || !(mime =~ /Application\/.*json(?!p)(;.*)?/i).nil?
    end

    # Deserialize the response to the given return type.
    #
    # @param [Response] response HTTP response
    # @param [String] return_type some examples: "User", "Array<User>", "Hash<String, Integer>"
    def deserialize(response, return_type)
      body = response.body

      # handle file downloading - return the File instance processed in request callbacks
      # note that response body is empty when the file is written in chunks in request on_body callback
      if return_type == "File"
        content_disposition = response.headers["Content-Disposition"].to_s
        if content_disposition && content_disposition =~ /filename=/i
          filename = content_disposition.match(/filename=[""]?([^""\s]+)[""]?/i).try &.[0]
          prefix = sanitize_filename(filename)
        else
          prefix = "download-"
        end
        if !prefix.nil? && prefix.ends_with?("-")
          prefix = prefix + "-"
        end
        encoding = response.headers["Content-Encoding"].to_s

        # TODO add file support
        raise ApiError.new(code: 0, message: "File response not yet supported in the client.") if return_type
        return nil

        #@tempfile = Tempfile.open(prefix, @config.temp_folder_path, encoding: encoding)
        #@tempfile.write(@stream.join.force_encoding(encoding))
        #@tempfile.close
        #Log.info { "Temp file written to #{@tempfile.path}, please copy the file to a proper folder "\
        #                    "with e.g. `FileUtils.cp(tempfile.path, \"/new/file/path\")` otherwise the temp file "\
        #                    "will be deleted automatically with GC. It's also recommended to delete the temp file "\
        #                    "explicitly with `tempfile.delete`" }
        #return @tempfile
      end

      return nil if body.nil? || body.empty?

      # return response body directly for String return type
      return body if return_type == "String"

      # ensuring a default content type
      content_type = response.headers["Content-Type"] || "application/json"

      raise ApiError.new(code: 0, message: "Content-Type is not supported: #{content_type}") unless json_mime?(content_type)

      begin
        data = JSON.parse("[#{body}]")[0]
      rescue e : Exception
        if %w(String Date Time).includes?(return_type)
          data = body
        else
          raise e
        end
      end

      convert_to_type data, return_type
    end

    # Convert data to the given return type.
    # @param [Object] data Data to be converted
    # @param [String] return_type Return type
    # @return [Mixed] Data in a particular type
    def convert_to_type(data, return_type)
      return nil if data.nil?
      case return_type
      when "String"
        data.to_s
      when "Integer"
        data.to_s.to_i
      when "Float"
        data.to_s.to_f
      when "Boolean"
        data == true
      when "Time"
        # parse date time (expecting ISO 8601 format)
        Time.parse! data.to_s, "%Y-%m-%dT%H:%M:%S%Z"
      when "Date"
        # parse date (expecting ISO 8601 format)
        Time.parse! data.to_s, "%Y-%m-%d"
      when "Object"
        # generic object (usually a Hash), return directly
        data
      when /\AArray<(.+)>\z/
        # e.g. Array<Pet>
        sub_type = $1
        data.map { |item| convert_to_type(item, sub_type) }
      when /\AHash\<String, (.+)\>\z/
        # e.g. Hash<String, Integer>
        sub_type = $1
        ({} of Symbol => String).tap do |hash|
          data.each { |k, v| hash[k] = convert_to_type(v, sub_type) }
        end
      else
        # models (e.g. Pet) or oneOf
        klass = Petstore.const_get(return_type)
        klass.respond_to?(:openapi_one_of) ? klass.build(data) : klass.build_from_hash(data)
      end
    end

    # Sanitize filename by removing path.
    # e.g. ../../sun.gif becomes sun.gif
    #
    # @param [String] filename the filename to be sanitized
    # @return [String] the sanitized filename
    def sanitize_filename(filename)
      if filename.nil?
        return nil
      else
        filename.gsub(/.*[\/\\]/, "")
      end
    end

    def build_request_url(path : String, operation : Symbol)
      # Add leading and trailing slashes to path
      path = "/#{path}".gsub(/\/+/, "/")
      @config.base_url(operation) + path
    end

    # Update header and query params based on authentication settings.
    #
    # @param [Hash] header_params Header parameters
    # @param [Hash] query_params Query parameters
    # @param [String] auth_names Authentication scheme name
    def update_params_for_auth!(header_params, query_params, auth_names)
      auth_names.each do |auth_name|
        auth_setting = @config.auth_settings[auth_name]
        next unless auth_setting
        case auth_setting[:in]
        when "header" then header_params[auth_setting[:key]] = auth_setting[:value]
        when "query"  then query_params[auth_setting[:key]] = auth_setting[:value]
        else raise ArgumentError.new("Authentication token must be in `query` of `header`")
        end
      end
    end

    # Sets user agent in HTTP header
    #
    # @param [String] user_agent User agent (e.g. openapi-generator/ruby/1.0.0)
    def user_agent=(user_agent)
      @user_agent = user_agent
      @default_headers["User-Agent"] = @user_agent
    end

    # Return Accept header based on an array of accepts provided.
    # @param [Array] accepts array for Accept
    # @return [String] the Accept header (e.g. application/json)
    def select_header_accept(accepts) : String
      #return nil if accepts.nil? || accepts.empty?
      # use JSON when present, otherwise use all of the provided
      json_accept = accepts.find { |s| json_mime?(s) }
      if json_accept.nil?
        accepts.join(",")
      else
        json_accept
      end
    end

    # Return Content-Type header based on an array of content types provided.
    # @param [Array] content_types array for Content-Type
    # @return [String] the Content-Type header  (e.g. application/json)
    def select_header_content_type(content_types)
      # use application/json by default
      return "application/json" if content_types.nil? || content_types.empty?
      # use JSON when present, otherwise use the first one
      json_content_type = content_types.find { |s| json_mime?(s) }
      json_content_type || content_types.first
    end

    # Convert object (array, hash, object, etc) to JSON string.
    # @param [Object] model object to be converted into JSON string
    # @return [String] JSON string representation of the object
    def object_to_http_body(model)
      return model if model.nil? || model.is_a?(String)
      local_body = nil
      if model.is_a?(Array)
        local_body = model.map { |m| object_to_hash(m) }
      else
        local_body = object_to_hash(model)
      end
      local_body.to_json
    end

    # Convert object(non-array) to hash.
    # @param [Object] obj object to be converted into JSON string
    # @return [String] JSON string representation of the object
    def object_to_hash(obj)
      if obj.respond_to?(:to_hash)
        obj.to_hash
      else
        obj
      end
    end

    # Build parameter value according to the given collection format.
    # @param [String] collection_format one of :csv, :ssv, :tsv, :pipes and :multi
    def build_collection_param(param, collection_format)
      case collection_format
      when :csv
        param.join(",")
      when :ssv
        param.join(" ")
      when :tsv
        param.join("\t")
      when :pipes
        param.join("|")
      when :multi
        # return the array directly as typhoeus will handle it as expected
        param
      else
        fail "unknown collection format: #{collection_format.inspect}"
      end
    end

    # Call an API with given options.
    #
    # @return [Array<(Object, Integer, Hash)>] an array of 3 elements:
    #   the data deserialized from response body (could be nil), response status code and response headers.
    def call_api(http_method : Symbol, path : String, operation : Symbol, return_type : String, post_body : String?, auth_names = [] of String, header_params = {} of String => String, query_params = {} of String => String, form_params = {} of Symbol => String)
      #ssl_options = {
      #  :ca_file => @config.ssl_ca_file,
      #  :verify => @config.ssl_verify,
      #  :verify_mode => @config.ssl_verify_mode,
      #  :client_cert => @config.ssl_client_cert,
      #  :client_key => @config.ssl_client_key
      #}

      #connection = Faraday.new(:url => config.base_url, :ssl => ssl_options) do |conn|
      #  conn.basic_auth(config.username, config.password)
      #  if opts[:header_params]["Content-Type"] == "multipart/form-data"
      #    conn.request :multipart
      #    conn.request :url_encoded
      #  end
      #  conn.adapter(Faraday.default_adapter)
      #end

      update_params_for_auth! header_params, query_params, auth_names

      if !post_body.nil? && !post_body.empty?
        # use JSON string in the payload
        form_or_body = post_body
      else
        # use HTTP forms in the payload
        # TODO use HTTP form encoding
        form_or_body = form_params
      end

      request = Crest::Request.new(http_method,
        build_request_url(path, operation),
        params: query_params,
        headers: header_params,
        #cookies: cookie_params, # TODO add cookies support
        form: form_or_body,
        logging: @config.debugging,
        handle_errors: false
      )

      response = request.execute

      if @config.debugging
        Log.debug {"HTTP response body ~BEGIN~\n#{response.body}\n~END~\n"}
      end

      if !response.success?
        if response.status == 0
          # Errors from libcurl will be made visible here
          raise ApiError.new(code: 0,
                            message: response.body)
        else
          raise ApiError.new(code: response.status_code,
                            response_headers: response.headers,
                            message: response.body)
        end
      end

      return response.body, response.status_code, response.headers
    end

    # Builds the HTTP request
    #
    # @param [String] http_method HTTP method/verb (e.g. POST)
    # @param [String] path URL path (e.g. /account/new)
    # @option opts [Hash] :header_params Header parameters
    # @option opts [Hash] :query_params Query parameters
    # @option opts [Hash] :form_params Query parameters
    # @option opts [Object] :body HTTP body (JSON/XML)
    # @return [Typhoeus::Request] A Typhoeus Request
    def build_request(http_method, path, request, opts = {} of Symbol => String)
      url = build_request_url(path, opts)
      http_method = http_method.to_sym.downcase

      header_params = @default_headers.merge(opts[:header_params] || {} of Symbole => String)
      query_params = opts[:query_params] || {} of Symbol => String
      form_params = opts[:form_params] || {} of Symbol => String

      update_params_for_auth! header_params, query_params, opts[:auth_names]

      req_opts = {
        :method => http_method,
        :headers => header_params,
        :params => query_params,
        :params_encoding => @config.params_encoding,
        :timeout => @config.timeout,
        :verbose => @config.debugging
      }

      if [:post, :patch, :put, :delete].includes?(http_method)
        req_body = build_request_body(header_params, form_params, opts[:body])
        req_opts.update body: req_body
        if @config.debugging
          Log.debug {"HTTP request body param ~BEGIN~\n#{req_body}\n~END~\n"}
        end
      end
      request.headers = header_params
      request.body = req_body
      request.url url
      request.params = query_params
      download_file(request) if opts[:return_type] == "File"
      request
    end

    # Builds the HTTP request body
    #
    # @param [Hash] header_params Header parameters
    # @param [Hash] form_params Query parameters
    # @param [Object] body HTTP body (JSON/XML)
    # @return [String] HTTP body data in the form of string
    def build_request_body(header_params, form_params, body)
      # http form
      if header_params["Content-Type"] == "application/x-www-form-urlencoded"
        data = URI.encode_www_form(form_params)
      elsif header_params["Content-Type"] == "multipart/form-data"
        data = {} of Symbol => String
        form_params.each do |key, value|
          case value
          when ::File, ::Tempfile
            # TODO hardcode to application/octet-stream, need better way to detect content type
            data[key] = Faraday::UploadIO.new(value.path, "application/octet-stream", value.path)
          when ::Array, nil
            # let Faraday handle Array and nil parameters
            data[key] = value
          else
            data[key] = value.to_s
          end
        end
      elsif body
        data = body.is_a?(String) ? body : body.to_json
      else
        data = nil
      end
      data
    end

    # TODO fix streaming response
    #def download_file(request)
    #  @stream = []

    #  # handle streaming Responses
    #  request.options.on_data = Proc.new do |chunk, overall_received_bytes|
    #    @stream << chunk
    #  end
    #end
  end
end