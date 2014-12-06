# Networking constants
DEFAULT_TIMEOUT = 60
NETWORKABLE_EXCEPTIONS = [Faraday::Error::ClientError,
                          URI::InvalidURIError,
                          Encoding::UndefinedConversionError,
                          ArgumentError,
                          NoMethodError,
                          TypeError]

def get_result(url, options = { content_type: 'json' })
  conn = faraday_conn(options[:content_type])
  conn.basic_auth(options[:username], options[:password]) if options[:username]
  conn.authorization :Bearer, options[:bearer] if options[:bearer]
  conn.options[:timeout] = options[:timeout] || DEFAULT_TIMEOUT
  if options[:data]
    response = conn.post url, {}, options[:headers] do |request|
      request.body = options[:data]
    end
  else
    response = conn.get url, {}, options[:headers]
  end
  # parsing by content type is not reliable, so we check the response format
  if is_json?(response.body)
    JSON.parse(response.body)
  elsif is_xml?(response.body)
    Hash.from_xml(response.body)
  else
    response.body
  end
rescue *NETWORKABLE_EXCEPTIONS => e
  rescue_faraday_error(url, e, options)
end

def faraday_conn(content_type = 'json')
  accept_header =
    case content_type
    when 'html' then 'text/html; charset=UTF-8'
    else 'application/json'
    end

  Faraday.new do |c|
    c.headers['Accept'] = accept_header
    c.headers['User-Agent'] = "Almability - http://#{ENV['HOSTRNAME']}"
    c.use      FaradayMiddleware::FollowRedirects, :limit => 10, :cookie => :all
    c.request  :multipart
    c.request  :json if accept_header == 'application/json'
    c.use      Faraday::Response::RaiseError
    c.adapter  Faraday.default_adapter
  end
end

def rescue_faraday_error(url, error, options={})
  if error.is_a?(Faraday::ResourceNotFound)
    status = 404
    if error.response.blank? && error.response[:body].blank?
      { error: "resource not found", status: status }
    # we raise an error if we find a canonical URL mismatch
    elsif options[:doi_mismatch]
      work = Work.where(id: options[:work_id]).first
      Notification.create(exception: error.exception,
                          class_name: "Net::HTTPNotFound",
                          message: error.response[:message],
                          details: error.response[:body],
                          status: status,
                          work_id: work.id,
                          target_url: url)
      { error: error.response[:message], status: status }
    # we raise an error if a DOI can't be resolved
    elsif options[:doi_lookup]
      work = Work.where(id: options[:work_id]).first
      Notification.create(exception: error.exception,
                          class_name: "Net::HTTPNotFound",
                          message: "DOI #{work.doi} could not be resolved",
                          details: error.response[:body],
                          status: status,
                          work_id: work.id,
                          target_url: url)
      { error: "DOI #{work.doi} could not be resolved", status: status }
    else
      error = parse_error_response(error.response[:body])
      { error: error, status: status }
    end
  else
    details = nil

    if error.is_a?(Faraday::Error::TimeoutError)
      status = 408
    elsif error.respond_to?('status')
      status = error[:status]
    elsif error.respond_to?('response') && error.response.present?
      status = error.response[:status]
      details = error.response[:body]
    else
      status = 400
    end

    if error.respond_to?('exception')
      exception = error.exception
    else
      exception = ""
    end

    class_name = class_by_status(status) || error.class
    level = level_by_status(status)

    message = parse_error_response(error.message)
    message = "#{message} for #{url}"
    message = "#{message} with rev #{options[:data][:rev]}" if class_name == Net::HTTPConflict

    Notification.create(exception: exception,
                        class_name: class_name.to_s,
                        message: message,
                        details: details,
                        status: status,
                        target_url: url,
                        level: level,
                        work_id: options[:work_id],
                        agent_id: options[:agent_id])
    { error: message, status: status }
  end
end

def class_by_status(status)
  class_name =
    case status
    when 400 then Net::HTTPBadRequest
    when 401 then Net::HTTPUnauthorized
    when 403 then Net::HTTPForbidden
    when 404 then Net::HTTPNotFound
    when 406 then Net::HTTPNotAcceptable
    when 408 then Net::HTTPRequestTimeOut
    when 409 then Net::HTTPConflict
    when 417 then Net::HTTPExpectationFailed
    when 429 then Net::HTTPTooManyRequests
    when 500 then Net::HTTPInternalServerError
    when 502 then Net::HTTPBadGateway
    when 503 then Net::HTTPServiceUnavailable
    when 504 then Net::HTTPGatewayTimeOut
    else nil
    end
end

def level_by_status(status)
  level =
    case status
    # temporary network problems should be WARN not ERROR
    when 408, 502, 503, 504 then 2
    else 3
    end
end

def parse_error_response(string)
  if is_json?(string)
    string = JSON.parse(string)
  elsif is_xml?(string)
    string = Hash.from_xml(string)
  end
  string = string['error'] if string.is_a?(Hash) && string['error']
  string
end

def is_xml?(string)
  Nokogiri::XML(string).errors.empty?
end

def is_json?(string)
  JSON.parse(string)
rescue JSON::ParserError
  false
end

def get_canonical_url(url, options = {})
  conn = faraday_conn('html')

  conn.options[:timeout] = options[:timeout]
  response = conn.get url, {}, options[:headers]

  # Priority to find URL:
  # 1. <link rel=canonical />
  # 2. <meta property="og:url" />
  # 3. URL from header

  body = Nokogiri::HTML(response.body, nil, 'utf-8')
  body_url = body.at('link[rel="canonical"]')['href'] if body.at('link[rel="canonical"]')
  if !body_url && body.at('meta[property="og:url"]')
    body_url = body.at('meta[property="og:url"]')['content']
  end

  if body_url
    # remove percent encoding
    body_url = CGI.unescape(body_url)

    # make URL lowercase
    body_url = body_url.downcase

    # remove parameter used by IEEE
    body_url = body_url.sub("reload=true&", "")
  end

  url = response.env[:url].to_s
  if url
    # remove percent encoding
    url = CGI.unescape(url)

    # make URL lowercase
    url = url.downcase

    # remove jsessionid used by J2EE servers
    url = url.gsub(/(.*);jsessionid=.*/, '\1')

    # remove parameter used by IEEE
    url = url.sub("reload=true&", "")

    # remove parameter used by ScienceDirect
    url = url.sub("?via=ihub", "")
  end

  # get relative URL
  path = URI.split(url)[5]

  # we will raise an error if 1. or 2. doesn't match with 3. as this confuses Facebook
  if body_url.present? && ![url, path].include?(body_url)
    options[:doi_mismatch] = true
    response.env[:message] = "Canonical URL mismatch: #{body_url} for #{url}"
    fail Faraday::ResourceNotFound, response.env
  end

  # URL must be a string that contains at least one number
  # we don't want to store publisher landing or error pages
  fail Faraday::ResourceNotFound, response.env unless url =~ /\d/

  url
rescue *NETWORKABLE_EXCEPTIONS => e
  rescue_faraday_error(url, e, options.merge(doi_lookup: true))
end
