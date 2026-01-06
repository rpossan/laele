class AddAllowedTrueToExistingUsers < ActiveRecord::Migration[7.0]
  def up
    return unless column_exists?(:users, :allowed)

    say_with_time "Setting allowed = true for existing users" do
      execute <<-SQL.squish
        UPDATE users
        SET allowed = TRUE
        WHERE allowed IS NOT TRUE
      SQL
    end
  end

  def down
    return unless column_exists?(:users, :allowed)

    say_with_time "Reverting allowed to false for all users" do
      execute <<-SQL.squish
        UPDATE users
        SET allowed = FALSE
      SQL
    end
  end
end
