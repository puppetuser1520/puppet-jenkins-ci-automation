# control-repo/site-modules/role/manifests/jenkins_controller.pp
#
# Role = business intent: "this node is a Jenkins controller"

class role::jenkins_controller {
  include profile::jenkins
}
