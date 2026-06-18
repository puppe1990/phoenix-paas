defmodule PhoenixPaas.PrecommitTest do
  use ExUnit.Case, async: false

  test "precommit alias is configured" do
    aliases = PhoenixPaas.MixProject.project() |> Keyword.fetch!(:aliases)
    assert is_list(Keyword.fetch!(aliases, :precommit))
  end
end
