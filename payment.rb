require 'sinatra'
require 'json'
require 'rest-client'

# Set your Paystack secret key
PAYSTACK_SECRET_KEY = 'sk_live_6e9e04ef88b035dc41807d77190f9a43fb323721'
PAYSTACK_PUBLIC_KEY = 'pk_live_b05bf0b0e44aa8f20a04529d6d05b4779aebd72b'

# Route to display the snack preorder form
get '/preorder-snacks' do
  erb :preorder_snacks
end

# Route to handle the form submission
post '/create_transaction' do
  snack_choice = params[:snack_choice]
  quantity = params[:quantity]
  amount = 500 * quantity.to_i # Assuming each snack costs 500 Naira

  response = RestClient.post('https://api.paystack.co/transaction/initialize',
                             {
                               email: 'user@example.com', # Replace with user's email
                               amount: amount * 100,
                               callback_url: 'http://localhost:4567/verify_transaction'
                             }.to_json,
                             {
                               content_type: :json,
                               accept: :json,
                               authorization: "Bearer #{PAYSTACK_SECRET_KEY}"
                             })

  result = JSON.parse(response.body)
  if result['status']
    redirect result['data']['authorization_url']
  else
    "Error initializing transaction: #{result['message']}"
  end
end

# Route to handle Paystack's callback and verify the transaction
get '/verify_transaction' do
  reference = params[:reference]
  response = RestClient.get("https://api.paystack.co/transaction/verify/#{reference}",
                            { authorization: "Bearer #{PAYSTACK_SECRET_KEY}" })

  result = JSON.parse(response.body)
  if result['status'] && result['data']['status'] == 'success'
    # Store transaction details
    transaction_details = {
      reference: result['data']['reference'],
      amount: result['data']['amount'],
      status: result['data']['status'],
      snack_choice: params[:snack_choice],
      quantity: params[:quantity]
    }
    File.open("transactions/#{reference}.json", "w") do |f|
      f.write(transaction_details.to_json)
    end
    "Transaction successful! Details: #{transaction_details}"
  else
    "Transaction failed or invalid: #{result['message']}"
  end
end
