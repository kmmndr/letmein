# letmein [![Build Status](http://travis-ci.org/GBH/letmein.png)](http://travis-ci.org/GBH/letmein)

**letmein** is a minimalistic authentication plugin for Rails 3 applications. It doesn't have anything other than the UserSession (or WhateverSession) object that you can use to authenticate logins.

Setup
=====

Plug the thing below into Gemfile and you know what to do after.

    gem 'letmein'

If you want to authenticate *User* with database fields *email*, *password_hash* and *password_salt* you don't need to do anything. If you're authenticating something else, you want something like this in your initializers:
    
    LetMeIn.configure do |conf|
      conf.model      = 'Account'
      conf.attribute  = 'username'
      conf.password   = 'password_crypt'
      conf.salt       = 'salty_salt'
    end
    
When creating/updating a record you have access to *password* accessor.
    
    >> user = User.new(:email => 'example@example.com', :password => 'letmein')
    >> user.save!
    => true
    >> user.password_hash 
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJeD1.FzqkcOZfEKNZ/DNN.w8xOwuFdBCm
    >> user.password_salt
    => $2a$10$0MeSaaE3I7.0FQ5ZDcKPJe
    
Authentication
==============

You authenticate using UserSession object. Example:
    
    >> session = UserSession.new(:email => 'example@example.com', :password => 'letmein')
    >> session.save
    => true
    >> session.user
    => #<User id: 1, email: "example@example.com" ... >
    
When credentials are invalid:
    
    >> session = UserSession.new(:email => 'example@example.com', :password => 'bad_password')
    >> session.save
    => false
    >> session.user
    => nil
    
Usage
=====

There are no built-in routes/controllers/views/helpers, just some helpful methods overloaded into base classes.
Here's an example how you can implement the controller handling the login :

    # app/controllers/sessions_controller.rb
    class SessionsController < ApplicationController
      def create
        @session = UserSession.new(params[:user_session])
        @session.save!
        # log in
        authenticate @session.user
        flash[:notice] = "Welcome back #{@session.user.name}!"
        redirect_to '/'
        
      rescue LetMeIn::Error
        flash.now[:error] = 'Invalid Credentials'
        unauthenticate!
        render :action => :new
      end

      def destroy
        # log off
        unauthenticate!
        redirect_to root_url, :notice => "Logged out!"
      end
    end
    
Upon successful login you have access to `authenticated` which will be the object you've authenticated (Account, User, or anything else), and `authenticated?` which will return true when connected.
These methods are availlable as helper too.

There are some filters you may use within your controllers :

  - `require_authentication`
  - `require_anonymous_access`

They force to be authenticated or not, as shown below :

    # app/controllers/users_controller.rb
    class UsersController < ApplicationController
      before_filter :require_authentication
      # or
      before_filter :require_anonymous_access
      # or none of them
    end

At last, a very simple example to create the view associated

    # app/views/sessions/new.html.erb
    <%= form_for :account_session do |f| %>
      <%= f.label :username %>
      <%= f.text_field :username %>
      <%= f.label :password %>
      <%= f.password_field :password %>
      <%= f.submit "Valider" %>
    <% end %>

The rest is up to you.

Authenticating Multiple Models
==============================
Yes, you can do that too. Let's assume you also want to authenticate admins that don't have email addresses, but have usernames.

    LetMeIn.configure do |conf|
      conf.models     = ['User', 'Admin']
      conf.attributes = ['email', 'username']
    end
    
Bam! You're done. Now you have an AdminSession object that will use *username* and *password* to authenticate.

Overriding Session Authentication
=================================
By default user will be logged in if provided email and password match. If you need to add a bit more logic to that you'll need to create your own session object. In the following example we do an additional check to see if user is 'approved' before letting him in.

    class MySession < LetMeIn::Session
      # Model that is being authenticated is derived from the class name
      # If you're authenticating multiple models you need to specify which one
      @model = 'User'
      
      def authenticate
        super # need to authenticate with email/password first
        unless user && user.is_approved?
          # adding a validation error will prevent login
          errors.add :base, "You are not approved yet, #{user.name}."
        end
      end
    end

Copyright
=========
(c) 2011 Oleg Khabarov, released under the MIT license
