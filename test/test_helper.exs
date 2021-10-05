K8s.Sys.Logger.attach()
Bonny.Sys.Logger.attach()

{:ok, _} = K8s.Client.DynamicHTTPProvider.start_link(nil)
{:ok, _} = Whizbang.start_link()
ExUnit.start()
