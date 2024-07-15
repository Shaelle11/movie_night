require 'sinatra'
require 'sinatra/reloader' if development?
require 'rest-client'
require 'json'
require 'dotenv/load' # For loading environment variables

# Secret passkeys for admin and invitees
ADMIN_PASSKEY = "ADMIN123"
INVITEE_PASSKEY = "INVITE456"
SUPER_ADMIN_PASSKEY = "SUPERADMIN123" # New super admin passkey

enable :sessions

# In-memory storage for tracking data
users = []
transactions = []

def log_user_action(users, session, action, details = {})
  user = users.find { |u| u[:name] == session[:name] && u[:title] == session[:title] }
  if user
    user[:actions] << { action: action, timestamp: Time.now, details: details }
  else
    users << {
      name: session[:name],
      title: session[:title],
      role: session[:role],
      actions: [{ action: action, timestamp: Time.now, details: details }]
    }
  end
end

get '/' do
  erb :index
end

post '/invite' do
  passkey = params[:passkey]
  title = params[:title]
  name = params[:name]

  if passkey == ADMIN_PASSKEY
    session[:role] = "Admin"
    session[:title] = title
    session[:name] = name
    redirect '/invitation'
  elsif passkey == INVITEE_PASSKEY
    session[:role] = "Invitee"
    session[:title] = title
    session[:name] = name
    redirect '/invitation'
  elsif passkey == SUPER_ADMIN_PASSKEY
    session[:role] = "SuperAdmin"
    session[:title] = title
    session[:name] = name
    redirect '/superadmin'
  else
    @error = "Invalid passkey. Please try again."
    erb :index
  end
end

get '/invitation' do
  @role = session[:role]
  @title = session[:title]
  @name = session[:name]
  
  if @role.nil?
    redirect '/'
  else
    erb :invitation
  end
end

post '/log_action' do
  action = params[:action]
  details = params[:details] || {}
  log_user_action(users, session, action, details)
end

get '/preorder_snacks' do
  erb :preorder_snacks
end

post '/preorder' do
  snack_prices = {
    'Popcorn' => 400,
    'Popcorn_with_drink' => 800,
    'Snack' => 1200,
    'Snack_PopCorn' => 1600,
    'Snack_Popcorn_drinks' => 2000,
    'Snack_Popcorn_drinks_pancakes' => 2000,
    'Shawarma_and_drink' => 2500
  }

  snack_choice = params[:'snack-choice']
  quantity = params[:quantity].to_i

  @amount = snack_prices[snack_choice] * quantity * 100 # Convert to kobo
  @email = params[:email]

  response = RestClient.post(
    'https://api.paystack.co/transaction/initialize',
    {
      email: @email,
      amount: @amount
    }.to_json,
    {
      Authorization: "Bearer #{ENV['PAYSTACK_SECRET_KEY']}",
      content_type: :json,
      accept: :json
    }
  )

  result = JSON.parse(response.body)
  
  if result["status"]
    @authorization_url = result["data"]["authorization_url"]
    log_user_action(users, session, 'Preorder Snacks', { snack: snack_choice, quantity: quantity, amount: @amount, email: @email })
    redirect @authorization_url
  else
    @error = result["message"]
    erb :preorder_snacks
  end
rescue RestClient::ExceptionWithResponse => e
  @error = JSON.parse(e.response)['message']
  erb :preorder_snacks
end

get '/payment/callback' do
  @reference = params[:reference]
  
  response = RestClient.get(
    "https://api.paystack.co/transaction/verify/#{@reference}",
    {
      Authorization: "Bearer #{ENV['PAYSTACK_SECRET_KEY']}"
    }
  )

  result = JSON.parse(response.body)

  if result["status"]
    @transaction = result["data"]
    transactions << @transaction
    log_user_action(users, session, 'Payment Completed', @transaction)
    erb :payment_success
  else
    @error = result["message"]
    erb :payment_failure
  end
end

get '/superadmin' do
  @role = session[:role]
  
  if @role != "SuperAdmin"
    redirect '/'
  else
    @users = users
    @transactions = transactions
    erb :superadmin
  end
end

set :port, 4568
