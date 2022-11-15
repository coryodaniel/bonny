
import Config

config :bonny,

  # Function to call to get a K8s.Conn object.
  # The function should return a %K8s.Conn{} struct or a {:ok, %K8s.Conn{}} tuple
  get_conn: {<%= assigns[:app_name] %>.K8sConn, :get!, [config_env()]},

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
