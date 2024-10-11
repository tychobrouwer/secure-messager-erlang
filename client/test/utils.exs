defmodule UtilsTester do
  use ExUnit.Case

  doctest Utils

  require Logger

  test "exit_on_nil string" do
    try do
      result = Utils.exit_on_nil("value", "name", "location")
      assert result == :ok
    catch
      _ -> flunk("exit_on_nil raised an exception")
    end
  end

  test "exit_on_nil binary" do
    try do
      result = Utils.exit_on_nil(~c"value", "location")
      assert result == :ok
    catch
      _ -> flunk("exit_on_nil raised an exception")
    end
  end

  test "exit_on_nil map" do
    try do
      result = Utils.exit_on_nil(%{}, "location")
      assert result == :ok
    catch
      _ -> flunk("exit_on_nil raised an exception")
    end
  end

  test "exit_on_nil map value" do
    try do
      map = %{key: "value"}
      result = Utils.exit_on_nil(map.key, "location")
      assert result == :ok
    catch
      _ -> flunk("exit_on_nil raised an exception")
    end
  end

  test "exit_on_nil list" do
    try do
      result = Utils.exit_on_nil([], "location")
      assert result == :ok
    catch
      _ -> flunk("exit_on_nil raised an exception")
    end
  end

  test "exit_on_nil with nil value" do
    try do
      result = Utils.exit_on_nil(nil, "location")
      refute result == :ok
    end
  end

  test "exit_on_nil with nil map value" do
    try do
      map = %{key: nil}
      result = Utils.exit_on_nil(map.key, "location")
      refute result == :ok
    end
  end
end
