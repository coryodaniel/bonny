{:ok, _} = Application.ensure_all_started(:k8s)
{:ok, _} = K8s.Client.DynamicHTTPProvider.start_link(nil)

K8s.Sys.Logger.attach()
Bonny.Sys.Logger.attach()

ExUnit.start()
