require 'test_helper'

class ScenariosControllerTest < ActionController::TestCase
  setup do
    @scenario = scenarios(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:scenarios)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create scenario" do
    assert_difference('Scenario.count') do
      post :create, scenario: {  }
    end

    assert_redirected_to scenario_path(assigns(:scenario))
  end

  test "should show scenario" do
    get :show, id: @scenario
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @scenario
    assert_response :success
  end

  test "should update scenario" do
    patch :update, id: @scenario, scenario: {  }
    assert_redirected_to scenario_path(assigns(:scenario))
  end

  test "should destroy scenario" do
    assert_difference('Scenario.count', -1) do
      delete :destroy, id: @scenario
    end

    assert_redirected_to scenarios_path
  end
end
