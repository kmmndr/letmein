require 'active_record'
require 'bcrypt'

module LetMeIn
  
  Error = Class.new StandardError
  AuthenticationRequired = Class.new StandardError
  AnonymousAccessRequired = Class.new StandardError
  
  class Railtie < Rails::Railtie
    config.to_prepare do
      LetMeIn.initialize
    end
    initializer 'letmein' do |app|
      LetMeIn::Hooks.init!
    end
  end
  
  class Hooks
    def self.init!
      ActiveSupport.on_load(:action_controller) do
        ::ActionController::Base.send :include, LetMeIn::ActionControllerExtension
        ::ActionController::Base.send :before_filter, :optional_authentication
        ::ActionController::Base.send :cattr_accessor, :required_scopes
      end
    end
  end

  module ActionControllerExtension
    def self.included(c)
      c.helper_method :authenticated
      c.helper_method :authenticated?
    end

    def authenticated
      @authenticated_object
    end

    def authenticated?
      !authenticated.blank?
    end

    def optional_authentication
      if session[:authenticated_object_id]
        model = LetMeIn.config.models.first.constantize
        authenticate model.find_by_id(session[:authenticated_object_id])
      end
    rescue ActiveRecord::RecordNotFound
      unauthenticate!
    end

    def require_authentication
      raise AuthenticationRequired.new unless authenticated?
    end

    def require_anonymous_access
      raise AnonymousAccessRequired.new if authenticated?
    end

    def authenticate(account)
      if account
        @authenticated_object = account
        session[:authenticated_object_id] = account.id
      end
    end
    #alias :sign_in= :authenticate

    def unauthenticate!
      @authenticated_object = session[:authenticated_object_id] = nil
    end
  end


  # Configuration class with some defaults. Can be changed like this:
  #   LetMeIn.configure do |conf|
  #     conf.model      = 'Account'
  #     conf.identifier = 'username'
  #   end
  class Config
    ACCESSORS = %w(models attributes passwords salts)
    attr_accessor *ACCESSORS
    def initialize
      @models       = ['User']
      @attributes   = ['email']
      @passwords    = ['password_hash']
      @salts        = ['password_salt']
    end
    ACCESSORS.each do |a|
      define_method("#{a.singularize}=") do |val|
        send("#{a}=", [val].flatten)
      end
    end
  end
  
  # LetMeIn::Session object. Things like UserSession are created
  # automatically after the initialization
  class Session
    
    # class MySession < LetMeIn::Session
    #   @model      = 'User'
    #   @attribute  = 'email'
    # end
    class << self
      attr_accessor :model, :attribute
    end
    
    include ActiveModel::Validations
    
    attr_accessor :login,       # test@test.test
                  :password,    # secretpassword
                  :object       # authenticated object
                  
    validate :authenticate
    
    def initialize(params = { })
      model = self.class.to_s.gsub('Session', '')
      model = LetMeIn.config.models.member?(model) ? model : LetMeIn.config.models.first
      self.class.model      ||= model
      self.class.attribute  ||= LetMeIn.accessor(:attribute, LetMeIn.config.models.index(self.class.model))
      self.login      = params[:login] || params[self.class.attribute.to_sym]
      self.password   = params[:password]
    end
    
    def save
      self.valid?
    end
    
    def save!
      save || raise(LetMeIn::Error, 'Failed to authenticate')
    end
    
    def self.create(params = {})
      object = self.new(params); object.save; object
    end
    
    def self.create!(params = {})
      object = self.new(params); object.save!; object
    end
    
    def method_missing(method_name, *args)
      case method_name.to_s
        when self.class.attribute         then self.login
        when "#{self.class.attribute}="   then self.login = args[0]
        when self.class.model.underscore  then self.object
        else super
      end
    end
    
    def authenticate
      letmein_password = LetMeIn.accessor(:password, LetMeIn.config.models.index(self.class.model))
      letmein_salt = LetMeIn.accessor(:salt, LetMeIn.config.models.index(self.class.model))
      
      object = self.class.model.constantize.where("#{self.class.attribute}" => self.login).first
      self.object = if object && !object.send(letmein_password).blank? && object.send(letmein_password) == BCrypt::Engine.hash_secret(self.password, object.send(letmein_salt))
        object
      else
        errors.add :base, 'Failed to authenticate'
        nil
      end
    end
    
    def to_key
      nil
    end
  end
  
  module Model
    def self.included(base)
      base.instance_eval do
        attr_accessor :password
        before_save :encrypt_password
        
        define_method :encrypt_password do
          if password.present?
            letmein_password = LetMeIn.accessor(:password, LetMeIn.config.models.index(self.class.to_s))
            letmein_salt = LetMeIn.accessor(:salt, LetMeIn.config.models.index(self.class.to_s))
            self.send("#{letmein_salt}=", BCrypt::Engine.generate_salt)
            self.send("#{letmein_password}=", BCrypt::Engine.hash_secret(password, self.send(letmein_salt)))
          end
        end
      end
    end
  end
  
  def self.config
    @config ||= Config.new
  end
  
  def self.configure
    yield config
  end
  
  def self.initialize
    def self.accessor(name, index = 0)
      name = name.to_s.pluralize
      self.config.send(name)[index] || self.config.send(name)[0]
    end
    
    self.config.models.each do |model|
      klass = model.constantize rescue next
      klass.send :include, LetMeIn::Model
      
      session_model = "#{model.to_s.camelize}Session"
      
      # remove the constant if it's defined, so that we don't get spammed with warnings.
      Object.send(:remove_const, session_model) if (Object.const_get(session_model) rescue nil) 
      Object.const_set(session_model, Class.new(LetMeIn::Session))
    end
  end
end
