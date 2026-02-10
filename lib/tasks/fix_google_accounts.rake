namespace :google_accounts do
  desc "Fix login_customer_id for existing Google Accounts - sets manager_customer_id to the first accessible customer"
  task fix_login_customer_ids: :environment do
    puts "🔧 Fixing Google Accounts login_customer_id..."
    
    fixed_count = 0
    error_count = 0
    
    GoogleAccount.where(manager_customer_id: nil).each do |account|
      begin
        # Get the first accessible customer as the manager account
        first_accessible = account.accessible_customers.first
        
        if first_accessible
          manager_id = first_accessible.customer_id
          account.update!(manager_customer_id: manager_id)
          
          # Also ensure login_customer_id is set correctly
          if account.login_customer_id.blank?
            account.update!(login_customer_id: manager_id)
          end
          
          puts "✅ Fixed account #{account.id}: manager_customer_id = #{manager_id}"
          fixed_count += 1
        else
          puts "⚠️  Account #{account.id} has no accessible customers"
          error_count += 1
        end
      rescue => e
        puts "❌ Error fixing account #{account.id}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n📊 Summary:"
    puts "  Fixed: #{fixed_count}"
    puts "  Errors: #{error_count}"
  end

  desc "Verify Google Accounts configuration"
  task verify_configuration: :environment do
    puts "🔍 Verifying Google Accounts configuration...\n"
    
    GoogleAccount.all.each do |account|
      user = account.user
      selection = user.active_customer_selection
      
      puts "User: #{user.email}"
      puts "  Account ID: #{account.id}"
      puts "  Manager Customer ID: #{account.manager_customer_id || '❌ NOT SET'}"
      puts "  Login Customer ID: #{account.login_customer_id || '❌ NOT SET'}"
      puts "  Accessible Customers: #{account.accessible_customers.count}"
      
      if selection
        puts "  Active Selection:"
        puts "    Customer ID: #{selection.customer_id}"
        puts "    Google Account ID: #{selection.google_account_id}"
      else
        puts "  ⚠️  No active customer selection"
      end
      
      puts ""
    end
  end
end
