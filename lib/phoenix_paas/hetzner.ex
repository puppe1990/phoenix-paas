defmodule PhoenixPaas.Hetzner do
  @moduledoc """
  Behaviour for Hetzner Cloud instance operations.
  """

  alias PhoenixPaas.AWS.Lightsail.Bundle
  alias PhoenixPaas.AWS.Lightsail.InstanceSpec

  @type location :: String.t()
  @type instance_name :: String.t()
  @type bundle_id :: String.t()

  @callback get_instance(location(), instance_name()) ::
              {:ok, InstanceSpec.t()} | {:error, term()}

  @callback list_bundles(location()) :: {:ok, [Bundle.t()]} | {:error, term()}

  @callback change_bundle(location(), instance_name(), bundle_id()) :: :ok | {:error, term()}

  def client do
    Application.fetch_env!(:phoenix_paas, :hetzner_client)
  end

  def get_instance(location, instance_name) do
    client().get_instance(location, instance_name)
  end

  def list_bundles(location) do
    client().list_bundles(location)
  end

  def change_bundle(location, instance_name, bundle_id) do
    client().change_bundle(location, instance_name, bundle_id)
  end
end
