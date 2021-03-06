import Config

config :git_hooks,
  auto_install: true,
  verbose: true,
  hooks: [
    pre_push: [
      tasks: [
        "mix clean",
        "mix format --check-formatted",
        "mix compile --warnings-as-errors",
        "mix credo --strict",
        "mix test --trace",
        "mix dialyzer"
      ]
    ]
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$date $time $metadata[$level] $message\n",
  metadata: [
    :request_id,
    :proposal_address,
    :transaction_address,
    :transaction_type,
    :beacon_subset,
    :node,
    :address
  ],
  colors: [enabled: true]

config :logger,
  utc_log: true,
  handle_otp_reports: true,
  handle_sasl_reports: false

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :archethic, :src_dir, File.cwd!()

config :archethic, :mut_dir, "data"

config :archethic, :marker, "-=%=-=%=-=%=-"

config :archethic, ArchEthic.Crypto,
  supported_curves: [
    :ed25519,
    :secp256r1,
    :secp256k1
  ],
  supported_hashes: [
    :sha256,
    :sha512,
    :sha3_256,
    :sha3_512,
    :blake2b
  ],
  default_curve: :ed25519,
  default_hash: :sha256,
  storage_nonce_file: "crypto/storage_nonce",
  key_certificates_dir: System.get_env("ARCHETHIC_CRYPTO_CERT_DIR", "~/aebot/key_certificates")

config :archethic, ArchEthic.Crypto.NodeKeystore.SoftwareImpl,
  seed: System.get_env("ARCHETHIC_CRYPTO_SEED")

config :archethic, ArchEthic.DB, ArchEthic.DB.CassandraImpl

config :archethic, ArchEthic.Bootstrap.NetworkInit,
  genesis_seed:
    <<226, 4, 212, 129, 254, 162, 178, 168, 206, 139, 176, 91, 179, 29, 83, 20, 50, 98, 0, 25,
      133, 242, 197, 73, 199, 53, 46, 127, 7, 223, 45, 246>>,
  genesis_daily_nonce_seed:
    <<190, 107, 211, 23, 6, 230, 228, 144, 253, 154, 200, 213, 66, 172, 229, 96, 5, 171, 134, 249,
      80, 160, 149, 4, 106, 249, 155, 116, 186, 125, 77, 192>>,
  genesis_origin_public_keys: [
    "010004AB41291F847A601055AEDD1AF24FF76FA970D6441E2DCA3818A8319B004C96B27B8FEB1DA31A044BA0A4800B4353359735719EBB3A05F98393A9CC599C3FAFD6"
    |> Base.decode16!(case: :mixed)
  ]

config :archethic, ArchEthic.P2P.BootstrappingSeeds,
  backup_file: "p2p/seeds",
  genesis_seeds: System.get_env("ARCHETHIC_P2P_BOOTSTRAPPING_SEEDS")

config :archethic, ArchEthic.P2P.Endpoint,
  nb_acceptors: 100,
  transport: :tcp,
  port: 3002

config :archethic, ArchEthic.SelfRepair.Sync, last_sync_file: "p2p/last_sync"

# Configure the endpoint
config :archethic, ArchEthicWeb.Endpoint,
  secret_key_base: "5mFu4p5cPMY5Ii0HvjkLfhYZYtC0JAJofu70bzmi5x3xzFIJNlXFgIY5g8YdDPMf",
  render_errors: [view: ArchEthicWeb.ErrorView, accepts: ~w(json)],
  pubsub_server: ArchEthicWeb.PubSub,
  live_view: [
    signing_salt: "3D6jYvx3",
    layout: {ArchEthicWeb.LayoutView, "live.html"}
  ]

config :archethic, ArchEthic.Bootstrap.NetworkInit,
  genesis_pools: [
    %{
      address:
        Base.decode16!("002CA95C90A4D75DEEC973D251F5B59CD8EBC787FEC265B9CAC1F6C56A8D9BFCCA",
          case: :mixed
        ),
      amount: 3.82e9
    },
    %{
      address:
        Base.decode16!("00AD6EEC49FED0A936FEF4BD3301FF933FFFE9BA63BE2F6E948DFEC4C2D4543917",
          case: :mixed
        ),
      amount: 2.36e9
    },
    %{
      address:
        Base.decode16!("00D23C33B9B75A272B1E8BCA6F252179A144E0A66A396CCF989C4A6D353CFF3849",
          case: :mixed
        ),
      amount: 9.0e8
    },
    %{
      address:
        Base.decode16!("006FDE9B6EDF98E682561634B814A5FA2127B327D50AF38428AB06B447A4CF8345",
          case: :mixed
        ),
      amount: 5.6e8
    },
    %{
      address:
        Base.decode16!("000F1DFC550CB0492C7BEA2DCFABC6F2E2378A5D1D8AA8B5058FC2F30B62DD5DDC",
          case: :mixed
        ),
      amount: 3.4e8
    },
    %{
      address:
        Base.decode16!("006098E77BA4C675DA94F57091E73797BF2E11B3FAB20867101AB20FBE21ED862A",
          case: :mixed
        ),
      amount: 3.4e8
    },
    %{
      address:
        Base.decode16!("009BD34BB544A9A71536806E52E9E9F4F41FF81751848FD0B1E0E465D2FB95C36C",
          case: :mixed
        ),
      amount: 2.2e8
    }
  ]

config :archethic, ArchEthic.Mining, timeout: 3_000

config :archethic, ArchEthic.OracleChain,
  services: [
    uco: ArchEthic.OracleChain.Services.UCOPrice
  ]

config :archethic, ArchEthic.OracleChain.Services.UCOPrice,
  provider: ArchEthic.OracleChain.Services.UCOPrice.Providers.Coingecko

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
