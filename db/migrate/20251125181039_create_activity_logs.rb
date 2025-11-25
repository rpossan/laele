class CreateActivityLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :activity_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :resource_type
      t.string :resource_id
      t.jsonb :metadata, default: {}
      t.text :description
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :activity_logs, [:user_id, :created_at]
    add_index :activity_logs, [:action, :created_at]
    add_index :activity_logs, [:resource_type, :resource_id]
  end
end
