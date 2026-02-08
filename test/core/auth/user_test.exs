defmodule Core.Auth.UserTest do
  use Core.DataCase, async: true

  alias Core.Auth.User

  describe "changeset/2" do
    test "valid with required fields" do
      changeset = User.changeset(%User{}, %{name: "John Doe"})

      assert changeset.valid?
    end

    test "requires name" do
      changeset = User.changeset(%User{}, %{})

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
    end

    test "name must be 100 characters or less" do
      changeset = User.changeset(%User{}, %{name: String.duplicate("a", 101)})

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end
  end
end
