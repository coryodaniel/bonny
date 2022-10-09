
import Config

config :bonny,
  # Add each Controller module for this operator to load here
  # Defaults to none. This *must* be set.
  controllers: [],

  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {<%= assigns[:app_name] %>.K8sConn, :get, [config_env()]},

  # The namespace to watch for Namespaced CRDs.
  # Defaults to "default". `:all` for all namespaces
  # Also configurable via environment variable `BONNY_POD_NAMESPACE`
  namespace: "default",

  # Set the Kubernetes API group for this operator.
  group: "<%= assigns[:api_group] %>",

  # Set the Kubernetes API versions for this operator.
  # This should be written in Elixir module form, e.g. YourOperator.API.V1 or YourOperator.API.V1Alpha1:
  versions: [<%= assigns[:version] %>],

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  operator_name: "<%= assigns[:operator_name] %>",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  service_account_name: "<%= assigns[:service_account_name] %>",

  # Labels to apply to the operator's resources.
  labels: %{
    "k8s-app" => "<%= assigns[:operator_name] %>"
  },

  # Operator deployment resources. These are the defaults.
  resources: <%= inspect(assigns[:resources]) %>,

  manifest_override_callback: &Mix.Tasks.Bonny.Gen.Manifest.<%= assigns[:app_name] %>Customizer.override/1
