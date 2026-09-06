defmodule PhoenixPaas.Deploy.DnsStub do
  @moduledoc false
  @behaviour PhoenixPaas.Deploy.DnsResolver

  @impl true
  def lookup_a(_host), do: {:error, :no_a_record}
end
