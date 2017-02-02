require 'test_helper'

class OptionSetsControllerTest < ActionController::TestCase
  setup do
    @option_set = option_sets(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:option_sets)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create option_set" do
    assert_difference('OptionSet.count') do
      post :create, option_set: {  }
    end

    assert_redirected_to option_set_path(assigns(:option_set))
  end

  test "should show option_set" do
    get :show, id: @option_set
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @option_set
    assert_response :success
  end

  test "should update option_set" do
    patch :update, id: @option_set, option_set: {  }
    assert_redirected_to option_set_path(assigns(:option_set))
  end

  test "should destroy option_set" do
    assert_difference('OptionSet.count', -1) do
      delete :destroy, id: @option_set
    end

    assert_redirected_to option_sets_path
  end
end
