require 'test_helper'

class DistrictSystemsControllerTest < ActionController::TestCase
  setup do
    @district_system = district_systems(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:district_systems)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create district_system" do
    assert_difference('DistrictSystem.count') do
      post :create, district_system: {  }
    end

    assert_redirected_to district_system_path(assigns(:district_system))
  end

  test "should show district_system" do
    get :show, id: @district_system
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @district_system
    assert_response :success
  end

  test "should update district_system" do
    patch :update, id: @district_system, district_system: {  }
    assert_redirected_to district_system_path(assigns(:district_system))
  end

  test "should destroy district_system" do
    assert_difference('DistrictSystem.count', -1) do
      delete :destroy, id: @district_system
    end

    assert_redirected_to district_systems_path
  end
end
