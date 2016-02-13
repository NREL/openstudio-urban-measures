require 'test_helper'

class TaxlotsControllerTest < ActionController::TestCase
  setup do
    @taxlot = taxlots(:one)
  end

  test 'should get index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:taxlots)
  end

  test 'should get new' do
    get :new
    assert_response :success
  end

  test 'should create taxlot' do
    assert_difference('Taxlot.count') do
      post :create, taxlot: {}
    end

    assert_redirected_to taxlot_path(assigns(:taxlot))
  end

  test 'should show taxlot' do
    get :show, id: @taxlot
    assert_response :success
  end

  test 'should get edit' do
    get :edit, id: @taxlot
    assert_response :success
  end

  test 'should update taxlot' do
    patch :update, id: @taxlot, taxlot: {}
    assert_redirected_to taxlot_path(assigns(:taxlot))
  end

  test 'should destroy taxlot' do
    assert_difference('Taxlot.count', -1) do
      delete :destroy, id: @taxlot
    end

    assert_redirected_to taxlots_path
  end
end
