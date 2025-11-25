class MakeRefreshTokenCiphertextNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :google_accounts, :refresh_token_ciphertext, true
  end
end

