# Gemfile
gem 'sinatra-activerecord'
gem 'sqlite3'

# Run bundle install
# $ bundle install

# Create migration file
# $ bundle exec rake db:create_migration NAME=create_users

# db/migrate/YYYYMMDDHHMMSS_create_users.rb
class CreateUsers < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :title
      t.string :name
      t.string :role
      t.string :email
      t.timestamps
    end

    create_table :downloads do |t|
      t.references :user, foreign_key: true
      t.boolean :downloaded_invitation, default: false
      t.boolean :downloaded_invitee1, default: false
      t.boolean :downloaded_invitee2, default: false
      t.timestamps
    end

    create_table :songs do |t|
      t.references :user, foreign_key: true
      t.string :recommendation
      t.timestamps
    end

    create_table :transactions do |t|
      t.references :user, foreign_key: true
      t.string :snack
      t.integer :quantity
      t.datetime :timestamp
      t.timestamps
    end
  end
end

# Run migration
# $ bundle exec rake db:migrate
