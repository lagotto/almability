require "bundler/setup"
require "sinatra"
require "json"
require "nokogiri"
require 'faraday'
require 'faraday_middleware'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'net/http'
require 'uri'

CROSSREF_BASE_URL = "http://api.crossref.org/members/"
SAMPLE = 10

require_relative 'lib/network'

get "/heartbeat" do
  { "status" => "ok" }.to_json
end

get "/members/:id" do
  url = CROSSREF_BASE_URL + params[:id]
  response = get_result(url)

  { "status" => "ok",
    "message-type" => "member",
    "message-version" => "1.0.0",
    "message" => { "primary-name" => response.fetch("message", {}).fetch("primary-name", nil),
                   "names" => response.fetch("message", {}).fetch("names", []),
                   "prefixes" => response.fetch("message", {}).fetch("prefixes", []),
                   "counts" => response.fetch("message", {}).fetch("counts", []) }}.to_json
end

get "/members/:id/works" do
  url = CROSSREF_BASE_URL + params[:id] + "/works?sample=" + SAMPLE.to_s
  response = get_result(url)
  items = response.fetch("message", {}).fetch("items", [])
  items = items.map do |item|
    item_response = get_canonical_url("http://doi.org/#{item["DOI"]}")
    if item_response.is_a?(String)
      url = item_response
      error = nil
      status = 200
    else
      # an error occured
      url = nil
      error = item_response.fetch(:error, nil)
      status = item_response.fetch(:status, nil)
    end

    { "doi" => item["DOI"],
      "url" => url,
      "error" => error,
      "status" => status }
  end

  payload = {
    "status" => "ok",
    "message-type" => "work-list",
    "message-version" => "1.0.0",
    "message" => items }
  JSON.pretty_generate(payload)
end
