module DeviseSignInHelper
  def sign_in_user(user)
    post '/users/sign_in', params: {
      user: {
        email: user.email,
        password: user.password
      }
    }
  end
end

RSpec.configure do |config|
  config.include DeviseSignInHelper, type: :request
end