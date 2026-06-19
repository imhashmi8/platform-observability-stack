# Default StorageClass for the cluster.
#
# EKS ships a gp2 StorageClass that is NOT marked default, so any
# PersistentVolumeClaim that does not name a class (Prometheus, Loki, Tempo,
# Postgres all rely on the default) has nothing to bind to and stays Pending.
# This gp3 class is backed by the EBS CSI driver installed as a cluster addon
# above, marked default, and encrypted.
#
# WaitForFirstConsumer delays volume creation until a pod is scheduled, so the
# volume lands in the same Availability Zone as the pod.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  # The cluster and its EBS CSI addon must exist before the API call.
  depends_on = [module.eks]
}
