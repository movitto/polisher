# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_polisher_session',
  :secret      => 'ca03eb97fd6577ab3025ed517d63c2d0217a672727d45208780ed3cd21850a357784fb31e30617021697e9a96254fae30377e5aaf7c44ef944b94806cbe440a8'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
