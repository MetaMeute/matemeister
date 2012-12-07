#!/usr/bin/env ruby
#MetaMeute MateMeister
#Copyright (C) 2012 Anton Pirogov
#Licensed under the WTFPL

require 'sinatra'
require 'haml'

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
user_handler = lambda do
  u = params[:username]
  n = params[:num]
  return haml(:error) if u.match(/\w+/).to_s != u
  return haml(:error) if u.empty?
  return haml(:error) if !n.numeric?
  n = n.to_i

  a = params[:action]
  p = params[:p]

  case a
  when 'setid'
    if $b.set_id(u,n)
      haml :users
    else
      haml :error
    end
  when 'drink'
    if $b.drink(u,n,p)
      haml :users
    else
      haml :error
    end
  when 'pay'
    if $b.pay(u,n)
      haml :users
    else
      haml :error
    end
  when 'transfer'
    return haml(:error) if p.nil?
    return haml(:error) if p.match(/\w+/).to_s != p
    if $b.transfer(u,p,n)
      haml :users
    else
      haml :error
    end
  else
    haml :error
  end

end

get '/user/:username/:action/:num/?:p?', &user_handler
post '/', &user_handler

drink_handler = lambda do
  d = params[:drink]
  a = params[:action]
  p = params[:p]
  return haml(:error) if d.match(/\w+/).to_s != d
  return haml(:error) if d.empty?
  return haml(:error) if !p.nil? && !p.numeric?
  p = p.to_i

  case a
  when 'setprice'
    if $b.set_price(d,p)
      haml :drinks
    else
      haml :error
    end
  when 'addstock'
    if $b.add_stock(d,p)
      haml :drinks
    else
      haml :error
    end
  when 'rmdrink'
    if $b.rm_drink(d)
      haml :drinks
    else
      haml :error
    end
  else
    haml :error
  end

end

#drink modification routes
get '/drink/:drink/:action/?:p?', &drink_handler
post '/drink', &drink_handler

#close database on quitting
trap(:INT){ $b.close }
