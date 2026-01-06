class LegalController < ApplicationController
  # Ensure this page is public even if authentication is added globally
  skip_before_action :authenticate_user!, raise: false

  # Public privacy policy page
  def privacy
  end
end
