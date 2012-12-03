#!/usr/bin/env ruby
# encoding: utf-8

require 'sqlite3'

DB_PATH = './data.db'

#create empty database if not found
if !File.exists?(DB_PATH)
  SQLite3::Database.new(DB_PATH) do |db|
    db.execute "CREATE TABLE users (name VARCHAR(32), matnr INTEGER, balance INTEGER);"
    db.execute "CREATE TABLE drinks (name VARCHAR(32), stock INTEGER, price INTEGER);"
    db.execute "CREATE TABLE logs (time INTEGER, entry VARCHAR(255));"
  end
end

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
    users.each{|r| @users[r[1]] = r[0]}
    @drinks = drinks.map{|a| a[0]}
  end

  #make sure user exists, resolve matnr to username if given
  #create new user if username does not exist
  #return username
  #return nil if argument is invalid matnr
  def touch_user(user)
    name = nil
    if user.class==String && user.numeric? || user.class==Fixnum
      name = @users[user.to_i]
    elsif @users.values.index(user)
      name = user
    end

    if name.nil?
      return nil if user.class==String && user.numeric? #invalid matnr -> no creation, just fail
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

  def set_matnr(user,matnr=-1)
    touch_user user
    matnr = matnr.to_i if matnr.class == String && matnr.numeric?
    @db.execute "UPDATE users SET matnr=#{matnr} WHERE name='#{user}'"
    update_cache
    return nil
  end

  def drink(user, num=1, drink=nil)
    user = touch_user user
    drink = drinks[0][0] if drink.nil?
    drink = touch_drink drink
    num = num.to_i if num.class == String && num.numeric?

    v = get_balance user
    num.times{ v -= get_price drink }
    @db.execute "UPDATE users SET balance=#{v} WHERE name='#{user}'"
    log "#{user} trinkt #{num} Flasche(n) #{drink}."
    return nil
  end

  def pay(user,cent=0)
    user = touch_user user
    cent = cent.to_i if cent.class == String && cent.numeric?

    v = get_balance(user)+cent
    @db.execute "UPDATE users SET balance=#{v} WHERE name='#{user}'"
    log "#{user} zahlt #{"%.2f" % (cent.to_f/100)}€ ein."
    return nil
  end

  def transfer(from, to, cent=0)
    from = touch_user from
    to = touch_user to
    cent = cent.to_i if cent.class == String && cent.numeric?

    fbal = get_balance(from)-cent
    tbal = get_balance(to)+cent
    @db.execute "UPDATE users SET balance=#{fbal} WHERE name='#{from}'"
    @db.execute "UPDATE users SET balance=#{tbal} WHERE name='#{to}'"
    log "#{from} überträgt #{"%.2f" % (cent.to_f/100)}€ auf #{to}."
    return nil
  end

  def get_balance(user)
    user = touch_user user
    @db.execute("SELECT balance FROM users WHERE name='#{user}'")[0][0]
  end

  def get_matnr(user)
    user = touch_user user
    @db.execute("SELECT matnr FROM users WHERE name='#{user}'")[0][0]
  end

  #log

  def get_log
    @db.execute "SELECT * FROM logs"
  end

  def log(str)
    @db.execute "INSERT INTO logs (time, entry) VALUES (#{Time.now.to_i}, '#{str}')"
    return nil
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
    log "Getränk #{drink} kostet nun #{"%.2f" % (cent.to_f/100)}€!"
    return nil
  end

  def add_stock(drink, num=0)
    drink = touch_drink drink
    num = num.to_i if num.class == String && num.numeric?
    oldstock = get_stock drink
    @db.execute "UPDATE drinks SET stock=#{oldstock+num} WHERE name='#{drink}'"
    log "Getränk #{drink} mit #{num} Flasche(n) aufgestockt."
    return nil
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
    return nil
  end

  #private

  #should be NEVER used
  def rm_user(user)
    @db.execute "DELETE FROM users WHERE name='#{user}'"
    log("Meuterer #{user} eliminiert!")
    update_cache
    return nil
  end

  def add_user(user)
    @db.execute "INSERT INTO users (name, matnr, balance) VALUES ('#{user}', -1, 0)"
    log("Wilkommen, #{user}!")
    update_cache
    return nil
  end

  def add_drink(drink)
    @db.execute "INSERT INTO drinks (name, stock, price) VALUES ('#{drink}', 0, 100)"
    log("Neues Getränk #{drink} wurde eingeführt!")
    update_cache
    return nil
  end

end
