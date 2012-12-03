#!/usr/bin/env ruby
#MetaMeute MateMeister
#Copyright (C) 2012 Anton Pirogov
#Licensed under the WTFPL

require 'sinatra'
require 'haml'

#finish views
#import data

require './base'

$b = Base.new

#UI
get '/' do
  haml :users
end

get '/users' do
  haml :users
end

get '/drinks' do
  @drinks = $b.drinks
  haml :drinks
end

get '/log' do
  haml :log
end

#direct database routes

#user modification routes
get '/user/:username/:action/:num/?:p?' do
  u = params[:username]
  n = params[:num]
  return haml(:error) if u.match(/\w+/).to_s != u
  return haml(:error) if !n.numeric?
  n = n.to_i

  a = params[:action]
  p = params[:p]

  case a
  when 'setmatnr'
    $b.set_matnr(u,n)
    haml :users
  when 'drink'
    $b.drink(u,n,p)
    haml :users
  when 'pay'
    $b.pay(u,n)
    haml :users
  when 'transfer'
    return haml(:error) if p.nil?
    return haml(:error) if p.match(/\w+/).to_s != p
    $b.transfer(u,p,n)
    haml :users
  else
    haml :error
  end

end

#drink modification routes
get '/drink/:drink/:action/?:p?' do
  d = params[:drink]
  a = params[:action]
  p = params[:p]
end

#close database on quitting
trap(:INT){ $b.close }
