defmodule PhoenixPaas.Encrypted do
  @moduledoc false

  defmodule Binary do
    @moduledoc false
    use Cloak.Ecto.Binary, vault: PhoenixPaas.Vault
  end
end
