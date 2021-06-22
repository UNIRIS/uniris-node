File.rm_rf!(Uniris.Utils.mut_dir())

ExUnit.start(
  exclude: [:infrastructure, :CI, :CD, :oracle_provider],
  timeout: :infinity,
  max_failures: 1
)

Mox.defmock(MockClient, for: Uniris.P2P.Client)
Mox.defmock(MockTransport, for: Uniris.P2P.TransportImpl)

Mox.defmock(MockCrypto,
  for: [Uniris.Crypto.NodeKeystore, Uniris.Crypto.SharedSecretsKeystore]
)

Mox.defmock(MockDB, for: Uniris.DB)
Mox.defmock(MockGeoIP, for: Uniris.P2P.GeoPatch.GeoIP)
Mox.defmock(MockUCOPriceProvider, for: Uniris.OracleChain.Services.UCOPrice.Providers.Impl)
