ExUnit.start(exclude: [integration: true])
Ecto.Adapters.SQL.Sandbox.mode(PhoenixPaas.Repo, :manual)

Mox.defmock(PhoenixPaas.Deploy.RunnerMock, for: PhoenixPaas.Deploy.Runner)
Mox.defmock(PhoenixPaas.AWS.LightsailMock, for: PhoenixPaas.AWS.Lightsail)
Mox.defmock(PhoenixPaas.HetznerMock, for: PhoenixPaas.Hetzner)
Mox.defmock(PhoenixPaas.Deploy.DnsMock, for: PhoenixPaas.Deploy.DnsResolver)
