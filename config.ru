require 'rubygems'
require 'bundler'

Bundler.require

disable :run, :reload

require './almability'

run Sinatra::Application
