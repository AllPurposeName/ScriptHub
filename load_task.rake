require 'faker'
require "capybara/poltergeist"
require 'pry'
require 'launchy'

desc "simulate load against HubStub app"
task :load_test do
  4.times.map { |i| Thread.new {Raker.new(i).new_users}; Thread.new {Raker.new(i).admin_surfing};
    Thread.new {Raker.new(i).user_adventures}; Thread.new {Raker.new(i).add_random_ticket};
    Thread.new {Raker.new(i).user_adventures}; Thread.new {Raker.new(i).add_random_ticket} }.map(&:join)
end

class Raker
  attr_reader :iteration, :session

  def initialize(iteration)
    @iteration = iteration
    @session = Capybara::Session.new(:poltergeist)
  end

  #admin surfing hits admin base end points
  #user adventures utilizes the "adventure" randomization feature and adds tickets to a cart
  #new users creates, logs out, and logs back in users

  def admin_surfing
    puts "starting admin surfing"
    as_admin
    loop do
      session.visit(admin_url.root)
      session.visit(admin_url.events)
      session.visit(admin_url.categories)
      session.visit(admin_url.users)
      session.visit(admin_url.venue)
      puts "visited admin endpoints, iteration: #{iteration}"
    end
  end

  def user_adventures
    puts "starting user adventures"
    loop do
      new_user
      adventure
      add_ticket_to_cart
    end
  end

  def new_users
    puts "starting creating new users"
    loop do
      new_user
    end
  end

  def add_random_tickets
    puts "starting adding random tickets"
    loop do
      number_of_tickets = rand(1..3)
      number_of_tickets.times do
        session.visit(url(rand(1..15)).event_page)
        add_ticket_to_cart
      end
      puts "#{number_of_tickets} ticket(s) added to unassigned cart, iteration: #{iteration}"
    end
  end

  private

  def new_user
    name = "#{Faker::Name.name} #{Faker::Name.suffix}"
    email = Faker::Internet.email
    password = Faker::Internet.password(8)
    sign_up(name, email, password)
    log_out
    log_in(email, password)
    puts "User #{name} signed up on #{session.current_path}, iteration: #{iteration}"
    puts "#{session.current_path}"
  end

  def adventure
    session.visit(url.root)
    session.click_link_or_button("Adventure")
  end


  def add_ticket_to_cart
    if session.has_css?("td.vert-align")
      click_cart
      puts "added a random ticket from #{session.current_path}"
    else
      puts "no tickets left on #{session.current_path}"
    end
  end


  def click_cart
    session.within("table.event-tickets") do
      session.all("a").sample.click
    end
  end

  def sign_up(name, email, password)
    session.visit(url.log_in)
    session.click_link_or_button("here")
    session.fill_in("user[full_name]", with: (name))
    session.fill_in("user[display_name]", with: (name))
    session.fill_in("user[email]", with: (email))
    session.fill_in("user[street_1]", with: Faker::Address.street_address)
    session.fill_in("user[street_2]", with: Faker::Address.building_number)
    session.fill_in("user[city]", with: ("#{Faker::Address.city_prefix} #{Faker::Address.city_suffix}"))
    session.fill_in("user[zipcode]", with: (Faker::Address.zip))
    session.fill_in("user[password]", with: (password))
    session.fill_in("user[password_confirmation]", with: (password))
    session.click_link_or_button("Create my account!")
  end

  def as_admin
    email = "admin@admin.com"
    password = "password"
    log_in(email, password)
  end

  def log_out
    session.visit(url.log_out)
  end

  def log_in(email, password)
    session.visit(url.log_in)
    session.fill_in("session[email]", with: (email))
    session.fill_in("session[password]", with: (password))
    session.click_link_or_button("Log in")
  end

  def domain
    "http://localhost:3000"
  end

  def url(event_id=1)
    OpenStruct.new(root: "#{domain}",
                   events_index: "#{domain}/events",
                   event_page: "#{domain}/events/#{event_id}",
                   tickets_index: "#{domain}/tickets",
                   log_out: "#{domain}/logout",
                   log_in: "#{domain}/login")
  end

  def admin_url
    OpenStruct.new(root: "#{domain}/admin",
                   events: "#{domain}/admin/events",
                   venues: "#{domain}/admin/venues",
                   categories: "#{domain}/admin/categories",
                   users: "#{domain}/admin/users")
  end
end
