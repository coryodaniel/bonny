workflow "Run tests" {
  on = "push"
  resolves = ["docker run"]
}

action "docker build" {
  uses = "actions/docker/cli@76ff57a"
  args = "build -t bonny:test ."
}

action "docker run" {
  uses = "actions/docker/cli@76ff57a"
  needs = ["docker build"]
  args = "run bonny:test"
}
