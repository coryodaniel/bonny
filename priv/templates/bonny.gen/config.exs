
import Config

config :bonny,
  # Add each Controller module for this operator to load here
  # Defaults to none. This *must* be set.
  controllers: [],

  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {K8s.Conn, :from_service_account, []},

  # The namespace to watch for Namespaced CRDs.
  # Defaults to "default". `:all` for all namespaces
  # Also configurable via environment variable `BONNY_POD_NAMESPACE`
  namespace: <%= inspect(namespace) %>,

  # Set the Kubernetes API group for this operator.
  group: "<%= api_group %>",

  # Set the Kubernetes API versions for this operator.
  # This should be written in Elixir module form, e.g. YourOperator.API.V1 or YourOperator.API.V1Alpha1:
  versions: [<%= version %>],

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  operator_name: "<%= operator_name %>",

  # Name must only consist of only lowercase letters and hyphens.
  # Defaults to hyphenated mix app name
  service_account_name: "<%= service_account_name %>",

  # Labels to apply to the operator's resources.
  labels: [],

  # Operator deployment resources. These are the defaults.
  resources: <%= inspect(resources) %>
