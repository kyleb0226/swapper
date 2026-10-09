class Current < ActiveSupport::CurrentAttributes
  attribute :user

  def company
    user&.company
  end
end
