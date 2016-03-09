# create a new admin user. Make sure to reset the password on staging and production sites!
u = User.find_or_create_by(email: 'test@nrel.gov')

u.roles = [:admin]
# Remove this if we share the code. This is very dangerous giving the admin a simple password for testing sake!
# only set password if it doesn't already exist
if u.encrypted_password && !u.encrypted_password.empty?
  # use encrypted_password
  puts "using existing password"
else
  puts "setting temp password"
  u.password = 'testing123'
end

u.save!
