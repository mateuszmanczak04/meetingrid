defmodule Core.AuthTest do
  use Core.DataCase, async: true
  import Core.Factory

  alias Core.Auth
  alias Core.Auth.User

  describe "get_user/2" do
    test "returns user by id" do
      user = insert!(:user, name: "John Doe")

      assert %User{} = found = Auth.get_user(user.id)
      assert found.id == user.id
      assert found.name == "John Doe"
    end

    test "returns nil when user does not exist" do
      assert nil == Auth.get_user(999_999)
    end

    test "preloads associations when requested" do
      user = insert!(:user)

      loaded = Auth.get_user(user.id, preload: [:attendees])

      refute match?(%Ecto.Association.NotLoaded{}, loaded.attendees)
    end
  end

  describe "create_user!/1" do
    test "creates user with valid attributes" do
      attrs = %{"name" => "Jane Doe"}

      user = Auth.create_user!(attrs)

      assert user.name == "Jane Doe"
      assert user.id
    end

    test "raises with invalid attributes" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Auth.create_user!(%{})
      end
    end

    test "raises when name exceeds max length" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        Auth.create_user!(%{"name" => String.duplicate("a", 101)})
      end
    end
  end

  describe "update_user/2" do
    test "updates user with valid attributes" do
      user = insert!(:user, name: "Original")

      assert {:ok, updated} = Auth.update_user(user, %{"name" => "Updated"})
      assert updated.name == "Updated"
    end

    test "fails with invalid attributes" do
      user = insert!(:user)
      assert {:error, _} = Auth.update_user(user, %{"name" => nil})
    end
  end
end
