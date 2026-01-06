class AccessController < ApplicationController
  # Public pending page; skips authentication and the allow check to avoid loops
  skip_before_action :authenticate_user!, raise: false
  skip_before_action :ensure_allowed_user, raise: false

  def pending
    # Use main application layout so header/footer remain consistent
  end
end
