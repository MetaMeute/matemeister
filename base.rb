#!/usr/bin/env ruby
# encoding: utf-8

require 'sqlite3'

DB_PATH = './data.db'
CURRENCY = ""

class String
  def numeric?
    # Check if every character is a digit
    !!self.match(/\A-?[0-9]+\Z/)
  end
end

#interface to database
class Base
  def update_cache
    @users = {}
    @drinks = {}
    users.each{|r| @users[r[1]] = r[0]}
    @drinks = drinks.map{|a| a[0]}
  end

  #make sure user exists, resolve id to username if given
  #create new user if username does not exist
  #return username
  #return nil if argument is invalid id
  def touch_user(user)
    name = nil
    if user.class==String && user.numeric? || user.class==Fixnum
      name = @users[user.to_i]
    elsif @users.values.index(user)
      name = user
    end

    if name.nil?
      return nil if user.class==String && user.numeric? || user.class==Fixnum #invalid id -> no creation, just fail

      #create new user in system
      add_user(user)
      name = user
    end

    return name
  end

  #make sure drink exists => create it, return drink name back
  def touch_drink(drink)
    add_drink(drink) if !@drinks.index(drink)
    return drink
  end

  #open database for access
  def initialize
    @db = SQLite3::Database.new(DB_PATH)
    update_cache
  end

  #to be called when the application finishes
  def close
    @db.close
  end

  #user functions

  #list of all user names
  def users
    @db.execute "SELECT * FROM users"
  end

  def set_id(user,id=-1)
    touch_user user
    return false if user.nil?

    id = id.to_i if id.class == String && id.numeric?

    #no duplicate IDs
    return false if id<=0 || users.map{|u| u[1]}.index(id)

    @db.execute "UPDATE users SET id=#{id} WHERE name='#{user}'"
    update_cache
    return true
  end

  def drink(user, num=1, drink=nil)
    user = touch_user user
    return false if user.nil?

    drink = drinks[0][0] if drink.nil?
    drink = touch_drink drink
    num = num.to_i if num.class == String && num.numeric?

    v = get_balance user
    num.times{ v -= get_price drink }
    @db.execute "UPDATE users SET balance=#{v}, sum=sum+#{num} WHERE name='#{user}'"
    add_stock(drink,-num,false)
    log "#{user} trinkt #{num} Flasche#{num>1?'n':''} #{drink}."
    return true
  end

  def pay(user,cent=0)
    user = touch_user user
    return false if user.nil?

    cent = cent.to_i if cent.class == String && cent.numeric?
    cent *= 100

    v = get_balance(user)+cent
    @db.execute "UPDATE users SET balance=#{v} WHERE name='#{user}'"
    log "#{user} zahlt #{"%.2f" % (cent.to_f/100)}#{CURRENCY} ein."
    return true
  end

  def transfer(from, to, cent=0)
    from = touch_user from
    to = touch_user to
    return false if from.nil?
    return false if to.nil?

    return true if from == to

    cent = cent.to_i if cent.class == String && cent.numeric?
    cent *= 100

    fbal = get_balance(from)-cent
    tbal = get_balance(to)+cent
    @db.execute "UPDATE users SET balance=#{fbal} WHERE name='#{from}'"
    @db.execute "UPDATE users SET balance=#{tbal} WHERE name='#{to}'"
    log "#{from} überträgt #{"%.2f" % (cent.to_f/100)}#{CURRENCY} auf #{to}."
    return true
  end

  def get_balance(user)
    user = touch_user user
    return false if user.nil?

    @db.execute("SELECT balance FROM users WHERE name='#{user}'")[0][0]
  end

  def get_id(user)
    user = touch_user user
    return false if user.nil?

    @db.execute("SELECT id FROM users WHERE name='#{user}'")[0][0]
  end

  #log

  def get_log
    @db.execute "SELECT * FROM logs"
  end

  def log(str)
    @db.execute "INSERT INTO logs (time, entry) VALUES (#{Time.now.to_i}, '#{str}')"
    return true
  end

  #drink functions

  #list of all drink names
  def drinks
    @db.execute "SELECT * FROM drinks"
  end

  def set_price(drink, cent=100)
    drink = touch_drink drink
    cent = cent.to_i if cent.class == String && cent.numeric?
    @db.execute "UPDATE drinks SET price=#{cent} WHERE name='#{drink}'"
    log "Getränk #{drink} kostet nun #{"%.2f" % (cent.to_f/100)}#{CURRENCY}!"
    return true
  end

  def add_stock(drink, num=0, l=true)
    drink = touch_drink drink
    num = num.to_i if num.class == String && num.numeric?
    oldstock = get_stock drink
    @db.execute "UPDATE drinks SET stock=#{oldstock+num} WHERE name='#{drink}'"
    log "Getränk #{drink} mit #{num} Flasche#{num>1?'n':''} aufgestockt." if l
    return true
  end

  def get_price(drink)
    drink = touch_drink drink
    return @db.execute("SELECT price FROM drinks WHERE name='#{drink}'")[0][0]
  end

  def get_stock(drink)
    drink = touch_drink drink
    return @db.execute("SELECT stock FROM drinks WHERE name='#{drink}'")[0][0]
  end

  def rm_drink(drink)
    @db.execute "DELETE FROM drinks WHERE name='#{drink}'"
    log("Getränk #{drink} entfernt!")
    update_cache
    return true
  end

  #private

  #should be NEVER used
  def rm_user(user)
    @db.execute "DELETE FROM users WHERE name='#{user}'"
    log("Meuterer #{user} eliminiert!")
    update_cache
    return true
  end

  def add_user(user)
    return false if users.map{|u| u[0]}.index(user)

    @db.execute "INSERT INTO users (name, id, balance, sum) VALUES ('#{user}', -1, 0, 0)"
    log("Wilkommen, #{user}!")
    update_cache
    return true
  end

  def add_drink(drink)
    return false if drinks.map{|d| d[0]}.index(drink)

    @db.execute "INSERT INTO drinks (name, stock, price) VALUES ('#{drink}', 0, 100)"
    log("Neues Getränk #{drink} wurde eingeführt!")
    update_cache
    return true
  end
end

#create empty database if not found
if !File.exists?(DB_PATH)
  SQLite3::Database.new(DB_PATH) do |db|
    db.execute "CREATE TABLE users (name VARCHAR(32), id INTEGER, balance INTEGER, sum INTEGER);"
    db.execute "CREATE TABLE drinks (name VARCHAR(32), stock INTEGER, price INTEGER);"
    db.execute "CREATE TABLE logs (time INTEGER, entry VARCHAR(255));"
    db.execute "INSERT INTO drinks (name, stock, price) VALUES ('mate', 0, 100)"
  end
end


