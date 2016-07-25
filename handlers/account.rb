def current_user
  if session[:user_id] && @account_user.nil?
    @account_user = AccountUser.find(session[:user_id])
    return @account_user
  elsif !@account_user.nil?
    return @account_user
  else 
    return nil
  end
end

def set_user
  redirect "/" if session[:user_id].nil?
  @user = AccountUser.find(params[:user_id])
  @account = Account.find(params[:account_id])
end
def self.account_onboard(account_name, bot_name, platforms_supported)
  account = nil
  if Account.first(account_name: account_name).nil?
    Account.create(account_name: account_name)
    account = Account.first(account_name: account_name)
    Bot.create(account_id: account.id, bot_name: bot_name, platforms_supported: platforms_supported)
    bot = Bot.first(account_id: account.id, bot_name: bot_name)
    account.bot_ids << bot.id
    account.save!
  else
    return {error: "Account already existing, choose new name"}
  end
  {success: account}
end

post '/create_account' do
  if params[:password] == params[:password_confirm]
    account = Account.new(account_name: params[:account_name])
    account.save!
    bot = Bot.new(account_id: account.id, bot_name: params[:bot_name], platforms_supported: [])
    bot.save!
    account.bot_ids << bot.id
    account.save!
    @user = AccountUser.first_or_create(email: params[:email])
    @user.first_name = params[:first_name]
    @user.last_name = params[:last_name]
    @user.password = params[:password]
    account.admin_ids = [@user.id]
    account.account_user_ids << au.id
    account.save!
    @user.account_ids << account.id
    @user.save!
    session[:account_name] = account.account_name
    session[:account_id] = account.id.to_s
    session[:user_id] = @user.id.to_s
    redirect "/"
  else
    @warning = "Sorry but your passwords didn't match. Please try signing up again."
    erb :"login"
  end
end
get '/users/reset/:reset_code' do
  @onboarding = false
  @user = AccountUser.first(temporary_reset_code: params[:reset_code])
  erb :"accounts/user/password_reset"
end

get '/users/onboard/:reset_code' do
  @onboarding = true
  @user = AccountUser.first(temporary_reset_code: params[:reset_code])
  erb :"accounts/user/password_reset"
end

post "/users/set_password" do
  @user = AccountUser.find(params[:user_id])
  if params[:password] == params[:password_confirm]
    @user.password = params[:password]
    @user.temporary_reset_code = nil
    @user.save!
    if @user.account_ids.length == 1
      session[:account_name] = @user.accounts.first.account_name
      session[:account_id] = @user.accounts.first.id.to_s
      session[:user_id] = @user.id.to_s
      redirect "/accounts/#{@user.accounts.first.id}"
    else
      redirect "/login/#{@user.id}/account_select"
    end
  else
    @warning = "Sorry, but your passwords didn't match - please try again."
    @onboarding = params[:onboarding].to_s == "true"
    erb :"accounts/user/password_reset"
  end
end

get "/login/:user_id/account_select" do
  @user = AccountUser.find(params[:user_id])
  erb :"accounts/select"
end

get "/login/:user_id/account_select/:account_id" do
  account = Account.find(params[:account_id])
  user = AccountUser.find(params[:user_id])
  session[:account_name] = account.account_name
  session[:account_id] = account.id.to_s
  session[:user_id] = user.id.to_s
  redirect "/accounts/#{account.id}"
end

post "/login" do
  user = AccountUser.first(email: params[:email])
  if user && user.password == params[:password]
    if user.accounts.count == 1
      account = user.accounts.first
      session[:account_name] = account.account_name
      session[:account_id] = account.id.to_s
      session[:user_id] = user.id.to_s
      redirect "/"
    else
      redirect "/login/#{user.id}/account_select"
    end
  else
    @warning = "Sorry, we couldn't find an account associated with that email address. Please try again."
    erb :"login"
  end
end

get "/logout" do
  session[:account_name] = nil
  session[:account_id] = nil
  session[:user_id] = nil
  redirect "/"
end

get '/accounts/:account_id' do
  set_user
  @account = Account.find(params[:account_id])
  erb :"accounts/account"
end

post '/password_reset' do
  @user = AccountUser.first(email: params[:email])
  if @user
    @warning = "We've sent a reset link that should be in your inbox shortly."
    @user.send_reset_email
  else
    @warning = "Sorry, but it looks like there's no one associated with that email - maybe you used a different email address?"
  end
  erb :"login"
end
get '/accounts/:account_id/drop_user/:user_id' do
  set_user
  redirect "/accounts/#{params[:account_id]}"
end

post '/accounts/:account_id/update_user' do
  set_user
  au = AccountUser.find(params[:user_id])
  if au.nil?
    @warning = "Weird. Something strange happened when trying to update your account. Try again."
    redirect "/accounts/#{params[:account_id]}"
  else
    au.email = params[:email]
    au.first_name = params[:first_name]
    au.last_name = params[:last_name]
    au.save!
    redirect "/accounts/#{params[:account_id]}"
  end
end

post '/accounts/:account_id/create_user' do
  set_user
  if AccountUser.first(email: params[:email], account_id: BSON::ObjectId(params[:account_id].to_s))
    @warning = "Sorry but an account for that e-mail address already exists - please try again."
    return "/accounts/#{params[:account_id]}/create_user"
  elsif params[:email].to_s.empty? || params[:first_name].to_s.empty? || params[:last_name].to_s.empty?
    @warning = "Sorry but some fields were missing. Please try submitting this again."
    return "/accounts/#{params[:account_id]}/create_user"    
  else
    au = AccountUser.new(email: params[:email], account_id: BSON::ObjectId(params[:account_id].to_s))
    account = Account.find(BSON::ObjectId(params[:account_id].to_s))
    account.account_user_ids << au.id
    account.save!
    au.first_name = params[:first_name]
    au.last_name = params[:last_name]
    au.send_reset_email(true)
    au.save!
  end
  redirect "/accounts/#{params[:account_id]}"
end

get '/users/:user_id/reset_password_submit/:account_id' do
  set_user
  user = AccountUser.find(params[:user_id])
  user.send_reset_email
  redirect "/accounts/#{params[:account_id]}"
end