class AddRefreshTokenToGoogleAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :google_accounts, :refresh_token, :text
  end
end
