# frozen_string_literal: true

class TestObjectsController < ActionController::Base
  def update
    @test_object = TestObject.find(params[:id])

    @test_object.update(test_object_params)

    if @test_object.save
      render json: { status: :ok, message: "Test object updated successfully." }
    else
      render json: { status: :unprocessable_entity, message: "Failed to update test object." }
    end
  end

  private

  def test_object_params
    params.require(:test_object).permit(:first_name, :last_name, :email, :phone)
  end
end
