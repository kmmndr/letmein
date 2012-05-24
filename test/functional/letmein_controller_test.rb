require 'test_helper'

class LetMeInControllerTest < ActionController::TestCase
  def setup
  end

  test "should get index" do
    get :index
    assert_response :success
  end
end

#class RequireAuthController < ActionController::Base
#  before_filter :require_authentication
#  def index; end
#end
#
#class OptionalAuthController < ActionController::Base
#  before_filter :optional_authentication
#  def index; end
#end
#
#class AnonymousAuthController < ActionController::Base
#  before_filter :require_anonymous_access
#  def index; end
#end
#
#  def load_application!
#    Application.configure do
#      config.active_support.deprecation = :log
#    end
#    Application.initialize!
#  end
#
#  def test_authenticated_from_controller
#    #load_application!
#    user = User.create!(:email => 'test@test.test', :password => 'pass')
#    session = UserSession.create(:email => user.email, :password => 'pass')
#    controller = RequireAuthController.new
#    controller2 = AnonymousAuthController.new
#    controller.index
#    controller2.index
#p controller
#    assert session.errors.blank?
#    assert_equal user, session.object
#    assert_equal user, session.user
#  end
#
#  def test_index
#    get :index
#    assert @response.body.include?('Hello world')
#    assert_equal 'test', assigns('selected_trust')
#  end
