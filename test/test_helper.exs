ExUnit.configure(formatters: [ExUnit.CLIFormatter, ExUnitNotifier])

integration_enabled? =
	System.get_env("INTEGRATION_TESTS") in ["1", "true", "TRUE", "yes", "YES"]

exclude_tags = if integration_enabled?, do: [], else: [integration: true]

ExUnit.start(exclude: exclude_tags)
