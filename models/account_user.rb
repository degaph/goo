class AccountUser
  include MongoMapper::Document
  include BCrypt
  key :first_name, String
  key :last_name, String
  key :email, String
  key :account_ids, Array
  key :password_hash, String
  key :temporary_reset_code, BSON::ObjectId
  def is_admin(account_id)
    Account.find(account_id).admin_ids.include?(self.id)
  end

  def accounts
    Account.where(id: self.account_ids)
  end

  def password
    @password ||= Password.new(password_hash)
  end

  def password=(new_password)
    @password = Password.create(new_password)
    self.password_hash = @password
    self.save!
    self.password_hash
  end
  
  def password_matches?(email)
    @user = User.first(email: email)
    if @user.password == params[:password]
      give_token
    else
      redirect_to home_url
    end
  end
  
  def send_reset_email(onboarding=false)
    reset_code = BSON::ObjectId.new.to_s
    subject = 'Password Reset Request for Bot Analysis'
    body = "Hey! Looks like you're having a tough time with your account right now. No worries, just click the following reset link: http://54.208.153.78/users/reset/#{reset_code}"
    if onboarding
      subject = 'Account setup for Bot Analysis'
      body = "Hey! Looks like someone has invited you to join their Bot Analysis account. To finish setting up your account, click this link: http://54.208.153.78/users/onboard/#{reset_code}"
    end
    Pony.mail({
      :to => self.email,
      :from => 'Bot Analysis <botanalysismailer@gmail.com>',
      :via => :smtp,
      :via_options => {
        :address              => 'smtp.gmail.com',
        :port                 => '587',
        :enable_starttls_auto => true,
        :user_name            => 'botanalysismailer',
        :password             => 'gabagool',
        :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
        :domain               => "localhost.localdomain" # the HELO domain provided by the client to the server
      }, 
      :subject => subject, 
      :body => body
      })
    self.temporary_reset_code = reset_code
    self.save
  end

end