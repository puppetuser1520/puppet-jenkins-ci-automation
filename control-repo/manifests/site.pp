# control-repo/manifests/site.pp
#
# Node classification: in a real setup this would come from ENC/classifier.
# For the challenge we keep it runnable via puppet apply on a clean host.

node default {
  include role::jenkins_controller
}
