defmodule PhoenixPaasWeb.AssetHelpersTest do
  use ExUnit.Case, async: true

  alias PhoenixPaasWeb.AssetHelpers

  test "asset_path/1 appends dev cache buster when code_reloader is enabled" do
    endpoint_config = Application.get_env(:phoenix_paas, PhoenixPaasWeb.Endpoint, [])
    original = Keyword.get(endpoint_config, :code_reloader)

    on_exit(fn ->
      Application.put_env(
        :phoenix_paas,
        PhoenixPaasWeb.Endpoint,
        Keyword.put(endpoint_config, :code_reloader, original)
      )
    end)

    Application.put_env(
      :phoenix_paas,
      PhoenixPaasWeb.Endpoint,
      Keyword.put(endpoint_config, :code_reloader, true)
    )

    path = AssetHelpers.asset_path("/assets/css/app.css")

    assert path =~ "/assets/css/app.css?"
    assert path =~ "t="
  end
end
