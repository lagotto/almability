require "bundler/setup"
require "sinatra"
require "json"

get "/heartbeat" do
  { "status" => "ok" }.to_json
end
