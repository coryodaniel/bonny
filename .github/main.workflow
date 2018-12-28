workflow "Run tests" {
  on = "push"
  resolves = ["docker run"]
}

action "docker run" {
  uses = "actions/docker/cli@76ff57a"
}
