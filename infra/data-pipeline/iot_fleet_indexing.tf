resource "aws_iot_indexing_configuration" "aegis" {
  count = var.iot_fleet_indexing_enabled ? 1 : 0

  thing_indexing_configuration {
    thing_indexing_mode              = "REGISTRY"
    thing_connectivity_indexing_mode = "STATUS"
  }
}

data "aws_iam_policy_document" "iot_fleet_console_viewer" {
  statement {
    sid    = "ReadIoTRegistryAndConnectivity"
    effect = "Allow"

    actions = [
      "iot:DescribeCertificate",
      "iot:DescribeEndpoint",
      "iot:DescribeThing",
      "iot:GetIndexingConfiguration",
      "iot:GetThingConnectivityData",
      "iot:ListAttachedPolicies",
      "iot:ListThingPrincipals",
      "iot:ListThings",
      "iot:SearchIndex",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "iot_fleet_console_viewer" {
  count = var.iot_fleet_console_viewer_policy_enabled ? 1 : 0

  name        = "${local.naming_prefix}-IAMPolicy-IoTFleetConsoleViewer"
  description = "Read-only AWS IoT Core fleet and connectivity status access for AEGIS demo/operations verification."
  policy      = data.aws_iam_policy_document.iot_fleet_console_viewer.json
}

resource "aws_iam_role_policy_attachment" "iot_fleet_console_viewer" {
  for_each = var.iot_fleet_console_viewer_policy_enabled ? toset(var.iot_fleet_console_viewer_attach_role_names) : toset([])

  role       = each.value
  policy_arn = aws_iam_policy.iot_fleet_console_viewer[0].arn
}
