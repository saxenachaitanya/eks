locals {
  ## Key Pair ##
  key_pair_name = "eks-workers-keypair-${var.region_tag[var.region]}-${var.env}-${var.app_name}"
  # run "ssh-keygen" then copy public key content to public_key
  public_key    = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC4HTWxBn93l3/d8mcJ205nIFp0NX/IKUBWXy9kZYpE7jjixwPfEPRkUIye2roJvlFzHcQzIXXRYsfqVxWHsROe0J2kQB/c73HISluofB3UrBi3BNIPioClGJuUGmBTANa9wT8CXBPifm25MAmSNhYeUPE+CMQfmZ1zTx5hpBcwF3JDa1MTwBhSaV5/KuQp4PCDS4QGAjZKLWZIuyAHpzLtM4IVISmsM40jHFZ5tgPkbKGrgLYpKuou/dvgTUT6Zdrwm/rG5t0hFWqlBiHkbtQdCGk30y5JkY88jCQZCRdM0wnrN9AmmGaToj1mMSE37BFJyuLSW2Lba7btw3ZYS+pgw0PRA6Ri0Hqn1InzUmGu+sTHmB+pIM5PdIRM0T5A1k632TsYA3lGGQNOEJ/HcRh/hQ+Np2Ptflbv7U65jb8j1A6WphMB1pKI/+rRckNQDxhYV7X4fkvt8iDHqjdqxhEMI3LMJZoz/Fs3xtJVhTX8E0NV62eFS177ZApExYLFTsU= root@ip-172-31-40-118"

  ########################################
  ##  KMS for K8s secret's DEK (data encryption key) encryption
  ########################################
  k8s_secret_kms_key_name                    = "alias/cmk-${var.region_tag[var.region]}-${var.env}-k8s-secret-dek"
  k8s_secret_kms_key_description             = "Kms key used for encrypting K8s secret DEK (data encryption key)"
  k8s_secret_kms_key_deletion_window_in_days = "30"
  k8s_secret_kms_key_tags = merge(
    var.tags,
    tomap({
        "Name" = local.k8s_secret_kms_key_name
    })
  )
}

# current account ID
data "aws_caller_identity" "this" {}

data "aws_iam_policy_document" "k8s_api_server_decryption" {
  # Copy of default KMS policy that lets you manage it
  statement {
    sid    = "Allow access for Key Administrators"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.this.account_id}:root"]
    }

    actions = [
      "kms:*"
    ]

    resources = ["*"]
  }

  # Required for EKS
  statement {
    sid    = "Allow service-linked role use of the CMK"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        module.eks_cluster.cluster_iam_role_arn, # required for the cluster / persistentvolume-controller
        "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root", 
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "Allow attachment of persistent resources"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        module.eks_cluster.cluster_iam_role_arn,                                                                                                 # required for the cluster / persistentvolume-controller to create encrypted PVCs
      ]
    }

    actions = [
      "kms:CreateGrant"
    ]

    resources = ["*"]

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}